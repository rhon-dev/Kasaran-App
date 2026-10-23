import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/account_store_registry.dart';
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

/// Runs before the app router becomes visible. No backend call is performed.
final class LocalStoreBootstrap {
  LocalStoreBootstrap(this.supportDirectory, this.keys, this.security);

  static final _pendingOpens = <String, Future<void>>{};
  final Directory supportDirectory;
  final DatabaseKeyStore keys;
  final LocalDeviceSecurity security;
  Future<bool>? _preparation;

  /// Check device protection once without opening any financial file.
  Future<bool> prepare() => _preparation ??= _prepare();

  Future<bool> _prepare() async {
    await supportDirectory.create(recursive: true);
    await security.protectDirectory(supportDirectory.path);
    final locked = await security.hasDeviceLock();
    return !locked && !await security.hasShownLockWarning();
  }

  /// Only the verified account location is opened; the legacy source remains
  /// untouched. Existing staging files cannot authorize a new encryption key.
  Future<AppDatabase> openAccount(AccountStoreLocation location) async {
    try {
      await rejectAccountPathLinks(supportDirectory, location.storeId);
      final root = await supportDirectory.resolveSymbolicLinks();
      final previous = _pendingOpens[root];
      final done = Completer<void>();
      _pendingOpens[root] = done.future;
      try {
        if (previous != null) await previous;
        final lockPath = '$root/.account_stores.lock';
        // ignore: avoid_slow_async_io
        if (await FileSystemEntity.type(lockPath, followLinks: false) !=
            FileSystemEntityType.file) {
          throw StateError('Account lock unavailable');
        }
        final handle = await File(lockPath).open(mode: FileMode.append);
        try {
          await security.protectFile(lockPath);
          await handle.lock();
          return await _openAccount(location);
        } finally {
          await handle.close();
        }
      } finally {
        done.complete();
        if (identical(_pendingOpens[root], done.future)) {
          // ignore: unawaited_futures
          _pendingOpens.remove(root);
        }
      }
    } catch (_) {
      throw StateError('Account store unavailable');
    }
  }

  Future<AppDatabase> _openAccount(AccountStoreLocation location) async {
    AppDatabase? db;
    try {
      if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(location.storeId) ||
          location.file.parent.parent.path !=
              '${supportDirectory.path}/account_stores' ||
          location.file.parent.path !=
              '${supportDirectory.path}/account_stores/${location.storeId}' ||
          location.file.path !=
              '${supportDirectory.path}/account_stores/${location.storeId}/kasaran.sqlite') {
        throw StateError('Invalid account store location');
      }
      await rejectAccountPathLinks(supportDirectory, location.storeId);
      // Task 3 cannot yet attest durable directory publication and matching
      // manifest. A legacy source (or orphaned journal) must not be bypassed
      // by creating an empty account store through the normal bootstrap.
      for (final suffix in ['', '-journal', '-wal', '-shm']) {
        // ignore: avoid_slow_async_io
        if (await FileSystemEntity.type(
              '${supportDirectory.path}/kasaran.sqlite$suffix',
              followLinks: false,
            ) !=
            FileSystemEntityType.notFound) {
          throw StateError('Legacy migration unavailable');
        }
      }
      await prepare();
      await security.protectDirectory(location.file.parent.parent.path);
      final staging = [
        File('${location.file.path}-journal'),
        File('${location.file.path}-wal'),
        File('${location.file.path}-shm'),
      ];
      // ignore: avoid_slow_async_io
      final hasFile = await location.file.exists();
      var hasStaging = false;
      for (final file in staging) {
        // ignore: avoid_slow_async_io
        if (await file.exists()) {
          hasStaging = true;
          await security.protectFile(file.path);
        }
      }
      final attempt = await location.keys.readAttempt();
      final key = await location.keys.read();
      if (attempt != null && attempt != 'attempted') {
        throw StateError('Invalid account open state');
      }
      if ((hasFile || hasStaging) && key == null ||
          !hasFile && !hasStaging && (key != null || attempt != null)) {
        throw StateError('Encrypted account store unavailable');
      }
      // Durable intent precedes key generation and SQLite's first file create.
      // An interrupted first open cannot later be mistaken for a fresh account.
      if (attempt == null) await location.keys.markAttempted();
      await rejectAccountPathLinks(supportDirectory, location.storeId);
      await location.file.parent.create();
      await rejectAccountPathLinks(supportDirectory, location.storeId);
      await security.protectDirectory(location.file.parent.path);
      db = await EncryptedDatabaseOpener(location.file, location.keys).open();
      await rejectAccountPathLinks(supportDirectory, location.storeId);
      await security.protectFile(location.file.path);
      for (final file in staging) {
        // ignore: avoid_slow_async_io
        if (await file.exists()) await security.protectFile(file.path);
      }
      return db;
    } catch (_) {
      await db?.close();
      throw StateError('Account store unavailable');
    }
  }
}
