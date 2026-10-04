import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kasaran/data/db/app_database.dart';

/// The DB key must live in platform secure storage, never in the database.
abstract interface class DatabaseKeyStore {
  Future<String?> read();
  Future<void> write(String key);
}

/// iOS uses a non-migrating, when-unlocked Keychain item; Android uses the
/// plugin's Keystore-backed RSA-OAEP / AES-GCM storage. Never use a plaintext
/// fallback when the OS reports an error.
final class PlatformDatabaseKeyStore implements DatabaseKeyStore {
  PlatformDatabaseKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
            aOptions: AndroidOptions(migrateWithBackup: true),
          );

  static const keyName = 'kasaran.local_db.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: keyName);

  @override
  Future<void> write(String key) => _storage.write(key: keyName, value: key);
}

/// Opens the local store only when an encrypted SQLite build and the original
/// secure key are available. A missing key for an existing file is fatal: never
/// create an empty replacement, downgrade to plaintext, or discard offline data.
final class EncryptedDatabaseOpener {
  EncryptedDatabaseOpener(this.file, this.keyStore);

  final File file;
  final DatabaseKeyStore keyStore;

  Future<AppDatabase> open() async {
    // ignore: avoid_slow_async_io
    final existing = await file.exists();
    var key = await keyStore.read();
    if (key == null) {
      if (existing) {
        throw StateError('Encrypted local database key unavailable');
      }
      final random = Random.secure();
      key = List<int>.generate(
        32,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      await keyStore.write(key);
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
      throw StateError('Encrypted local database key invalid');
    }
    // The setup callback runs before drift inspects the file, including its
    // schema version. A cipher check in release builds prevents a missing
    // native hook from silently creating an unencrypted database.
    final db = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          if (raw.select('PRAGMA cipher').isEmpty) {
            throw StateError('Encrypted SQLite backend unavailable');
          }
          raw.execute("PRAGMA key = '$key'");
        },
      ),
    );
    try {
      await db.customSelect('PRAGMA user_version').get();
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }
}
