import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';

/// Reject links at every account-store component, including dangling links.
/// Dart's path-based SQLite API cannot eliminate a concurrent symlink swap;
/// callers must keep the app-support directory inaccessible to other writers.
Future<void> rejectAccountPathLinks(Directory root, [String? id]) async {
  final rootPath = root.absolute.path;
  // Check the lexical chain, not just the resolved root: resolving first
  // hides symlinks in ancestors above the app-support directory.
  var ancestor = rootPath.startsWith(Platform.pathSeparator)
      ? Platform.pathSeparator
      : '';
  for (final component in rootPath.split(Platform.pathSeparator)) {
    if (component.isEmpty) continue;
    if (component == '.' || component == '..') {
      throw StateError('Invalid account store path');
    }
    ancestor = ancestor == Platform.pathSeparator
        ? '$ancestor$component'
        : ancestor.isEmpty
        ? component
        : '$ancestor${Platform.pathSeparator}$component';
    // ignore: avoid_slow_async_io
    if (await FileSystemEntity.type(ancestor, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError('Linked account store path');
    }
  }
  final paths = <String>[
    rootPath,
    '$rootPath/account_stores',
    if (id != null) ...[
      '$rootPath/account_stores/$id',
      '$rootPath/account_stores/$id/kasaran.sqlite',
      for (final suffix in ['-journal', '-wal', '-shm'])
        '$rootPath/account_stores/$id/kasaran.sqlite$suffix',
    ],
  ];
  for (final path in paths) {
    // ignore: avoid_slow_async_io
    if (await FileSystemEntity.type(path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError('Linked account store path');
    }
  }
  if (id != null) {
    final canonicalRoot = await root.resolveSymbolicLinks();
    final parent = Directory('$rootPath/account_stores');
    final account = Directory('${parent.path}/$id');
    // ignore: avoid_slow_async_io
    if (await parent.exists() &&
        await parent.resolveSymbolicLinks() !=
            '$canonicalRoot/account_stores') {
      throw StateError('Account store path outside root');
    }
    // ignore: avoid_slow_async_io
    if (await account.exists() &&
        await account.resolveSymbolicLinks() !=
            '$canonicalRoot/account_stores/$id') {
      throw StateError('Account store path outside root');
    }
  }
}

/// An opaque location only; authentication and current-session matching belong
/// to the lifecycle coordinator, not the registry.
final class AccountStoreLocation {
  AccountStoreLocation._(this.storeId, this.file, this.keys);
  final String storeId;
  final File file;
  final AccountDatabaseKeyStore keys;
}

/// Maps a coordinator-verified identity to an independent protected local file.
final class AccountStoreRegistry {
  AccountStoreRegistry(this.supportDirectory, this.metadata, this.security);

  static const metadataKey = 'kasaran.account_stores.v1';
  static final _pending = <String, Future<void>>{};
  final Directory supportDirectory;
  final SecureKeyValueStore metadata;
  final LocalDeviceSecurity security;

  Future<AccountStoreLocation> resolveVerified(
    VerifiedSessionSnapshot session,
  ) async {
    try {
      return await withAccountLock(() => _resolve(session));
    } catch (_) {
      throw StateError('Account store unavailable');
    }
  }

  /// Shared support-root lock for registry resolution and migration staging.
  /// Never invoke resolveVerified from inside this callback (non-reentrant).
  Future<T> withAccountLock<T>(Future<T> Function() operation) async {
    await rejectAccountPathLinks(supportDirectory);
    await supportDirectory.create(recursive: true);
    await security.protectDirectory(supportDirectory.path);
    final canonicalRoot = await supportDirectory.resolveSymbolicLinks();
    final lockPath = '$canonicalRoot/.account_stores.lock';
    final previous = _pending[canonicalRoot];
    final done = Completer<void>();
    _pending[canonicalRoot] = done.future;
    try {
      if (previous != null) await previous;
      final lockFile = File(lockPath);
      // ignore: avoid_slow_async_io
      if (await FileSystemEntity.type(lockPath, followLinks: false) ==
          FileSystemEntityType.link) {
        throw StateError('Invalid account lock');
      }
      final handle = await lockFile.open(mode: FileMode.append);
      try {
        await security.protectFile(lockPath);
        await handle.lock();
        return await operation();
      } finally {
        await handle.close();
      }
    } finally {
      done.complete();
      if (identical(_pending[canonicalRoot], done.future)) {
        // ignore: unawaited_futures
        _pending.remove(canonicalRoot);
      }
    }
  }

  /// Runs [operation] only when the secure registry and filesystem prove that
  /// this installation retains exactly the admitted account store. Holds the
  /// real shared registry lock through the entire awaited callback. This does
  /// not prove that the database is pristine: the callback must check the leased
  /// database, verify its main path equals the supplied file, and create metadata
  /// before returning. Never call resolveVerified/withAccountLock in the callback.
  ///
  /// Conservatively rejects other mappings (even absent files), unknown root or
  /// account entries, staging/legacy artifacts, links and missing directories.
  /// Only filesystem names/types are inspected; other stores are never opened.
  /// Callers must use the actual installation registry and keep unrelated sync
  /// writers quiescent; this is not a lock against database writers/path swaps.
  Future<T> withSoleAccountStore<T>(
    String verifiedUserId,
    Future<T> Function(File file) operation,
  ) async {
    // Do not recreate a missing support root as evidence of a fresh install.
    // ignore: avoid_slow_async_io
    if (await FileSystemEntity.type(
          supportDirectory.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.directory) {
      throw StateError('Account store inventory unavailable');
    }
    return withAccountLock(() async {
      await rejectAccountPathLinks(supportDirectory);
      final raw = await metadata.read(metadataKey);
      if (raw == null) throw StateError('Account store inventory unavailable');
      final accounts = _parse(raw);
      final id = accounts[verifiedUserId];
      if (verifiedUserId.isEmpty || accounts.length != 1 || id == null) {
        throw StateError('Account store inventory unavailable');
      }
      await rejectAccountPathLinks(supportDirectory, id);
      final root = await supportDirectory.resolveSymbolicLinks();
      final parent = Directory('$root/account_stores');
      final account = Directory('${parent.path}/$id');
      final file = File('${account.path}/kasaran.sqlite');
      // Fail closed on all unknown installation entries, including legacy
      // sources and staged migrations, without inspecting their contents.
      await for (final entry in supportDirectory.list(followLinks: false)) {
        if (entry.path != parent.path &&
            entry.path != '$root/.account_stores.lock') {
          throw StateError('Account store inventory unavailable');
        }
      }
      await for (final entry in parent.list(followLinks: false)) {
        if (entry.path != account.path || entry is! Directory) {
          throw StateError('Account store inventory unavailable');
        }
      }
      final allowed = <String>{
        file.path,
        for (final suffix in ['-journal', '-wal', '-shm'])
          '${file.path}$suffix',
      };
      await for (final entry in account.list(followLinks: false)) {
        if (entry is! File || !allowed.contains(entry.path)) {
          throw StateError('Account store inventory unavailable');
        }
      }
      // ignore: avoid_slow_async_io
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('Account store inventory unavailable');
      }
      return operation(file);
    });
  }

  /// Check the persisted secure registry mapping under [withAccountLock].
  /// Neither a matching path nor a caller-provided key proves ownership.
  Future<void> requireMappedLocation(
    String verifiedUserId,
    AccountStoreLocation destination,
  ) async {
    if (verifiedUserId.isEmpty) {
      throw StateError('Account store unavailable');
    }
    final raw = await metadata.read(metadataKey);
    if (raw == null || _parse(raw)[verifiedUserId] != destination.storeId) {
      throw StateError('Account store unavailable');
    }
  }

  Future<AccountStoreLocation> _resolve(VerifiedSessionSnapshot session) async {
    if (session.userId.isEmpty) {
      throw StateError('Verified account identity unavailable');
    }
    // The coordinator must verify the snapshot against a fresh capture first.
    try {
      final raw = await metadata.read(metadataKey);
      final accounts = raw == null ? <String, String>{} : _parse(raw);
      var id = accounts[session.userId];
      if (id == null) {
        // ignore: avoid_slow_async_io
        final existing = await Directory(
          '${supportDirectory.path}/account_stores',
        ).exists();
        if (raw == null && existing) {
          throw StateError('Account store metadata unavailable');
        }
        final random = Random.secure();
        do {
          id = List<int>.generate(
            16,
            (_) => random.nextInt(256),
          ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
        } while (accounts.containsValue(id));
        accounts[session.userId] = id;
        // Persist before creating/opening the file. A failed secure write cannot
        // silently create an untracked store.
        await metadata.write(
          metadataKey,
          jsonEncode({'version': 1, 'accounts': accounts}),
        );
      }
      await rejectAccountPathLinks(supportDirectory, id);
      await supportDirectory.create(recursive: true);
      await security.protectDirectory(supportDirectory.path);
      final parent = Directory('${supportDirectory.path}/account_stores');
      await parent.create();
      await rejectAccountPathLinks(supportDirectory, id);
      await security.protectDirectory(parent.path);
      final directory = Directory('${parent.path}/$id');
      // Leave a fresh final name free for atomic stage-directory publication.
      // A previously opened final remains protected on resolution.
      // ignore: avoid_slow_async_io
      if (await directory.exists()) {
        await security.protectDirectory(directory.path);
      }
      return AccountStoreLocation._(
        id,
        File('${directory.path}/kasaran.sqlite'),
        AccountDatabaseKeyStore(metadata, id),
      );
    } catch (_) {
      // External secure storage/filesystem/device errors may contain paths or
      // values. Never forward them in a user-facing account selection error.
      throw StateError('Account store unavailable');
    }
  }

  Map<String, String> _parse(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 2 ||
        decoded['version'] != 1 ||
        decoded['accounts'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid account registry');
    }
    final result = <String, String>{};
    final seen = <String>{};
    for (final entry in (decoded['accounts'] as Map<String, dynamic>).entries) {
      if (entry.key.isEmpty ||
          entry.value is! String ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(entry.value as String) ||
          !seen.add(entry.value as String)) {
        throw const FormatException('Invalid account registry entry');
      }
      result[entry.key] = entry.value as String;
    }
    return result;
  }
}
