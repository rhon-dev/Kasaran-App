import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';

abstract interface class LocalDeviceSecurity {
  Future<void> protectDirectory(String path);
  Future<void> protectFile(String path);
  Future<bool> hasDeviceLock();
  Future<bool> hasShownLockWarning();
  Future<void> markLockWarningShown();
}

/// Native iOS file protection and backup exclusion, Android device-lock check.
/// Missing handlers are fatal: do not silently proceed without SEC-16.
final class PlatformLocalDeviceSecurity implements LocalDeviceSecurity {
  PlatformLocalDeviceSecurity({
    MethodChannel? channel,
    FlutterSecureStorage? storage,
  }) : _channel = channel ?? const MethodChannel('app.kasaran/local_security'),
       _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
             aOptions: AndroidOptions(migrateWithBackup: true),
           );

  static const warningKey = 'kasaran.device_lock_warning.v1';
  final MethodChannel _channel;
  final FlutterSecureStorage _storage;

  @override
  Future<void> protectDirectory(String path) async =>
      _channel.invokeMethod<void>('protectDirectory', {'path': path});

  @override
  Future<void> protectFile(String path) async =>
      _channel.invokeMethod<void>('protectFile', {'path': path});

  @override
  Future<bool> hasDeviceLock() async =>
      await _channel.invokeMethod<bool>('hasDeviceLock') ??
      (throw StateError('Device-lock check unavailable'));

  @override
  Future<bool> hasShownLockWarning() async =>
      await _storage.read(key: warningKey) == 'shown';

  @override
  Future<void> markLockWarningShown() =>
      _storage.write(key: warningKey, value: 'shown');
}

final class LocalStoreResult {
  LocalStoreResult(this.db, {required this.warningNeeded});
  final AppDatabase db;
  final bool warningNeeded;
}

/// Runs before the app router becomes visible. No backend call is performed.
final class LocalStoreBootstrap {
  LocalStoreBootstrap(this.supportDirectory, this.keys, this.security);

  final Directory supportDirectory;
  final DatabaseKeyStore keys;
  final LocalDeviceSecurity security;

  Future<LocalStoreResult> open() async {
    await supportDirectory.create(recursive: true);
    await security.protectDirectory(supportDirectory.path);
    final file = File('${supportDirectory.path}/kasaran.sqlite');
    final db = await EncryptedDatabaseOpener(file, keys).open();
    try {
      await security.protectFile(file.path);
      final locked = await security.hasDeviceLock();
      final warningNeeded = !locked && !await security.hasShownLockWarning();
      return LocalStoreResult(db, warningNeeded: warningNeeded);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }
}
