import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/account_store_runtime.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';

class _Identity implements VerifiedLocalIdentity {
  VerifiedSessionSnapshot? session;
  @override
  VerifiedSessionSnapshot? capture() => session;
}

class _Metadata implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _LegacyKeys implements DatabaseKeyStore {
  @override
  Future<String?> read() async =>
      throw StateError('Legacy key must not be read');
  @override
  Future<void> write(String value) async =>
      throw StateError('Legacy key must not be changed');
}

class _Security implements LocalDeviceSecurity {
  @override
  Future<void> protectDirectory(String path) async {}
  @override
  Future<void> protectFile(String path) async {}
  @override
  Future<bool> hasDeviceLock() async => true;
  @override
  Future<bool> hasShownLockWarning() async => false;
  @override
  Future<void> markLockWarningShown() async {}
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('kasaran-auth-runtime-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'Auth initialization precedes trusted path and signed-out selects no financial file',
    () async {
      final auth = Completer<void>();
      final identity = _Identity();
      final metadata = _Metadata();
      var pathRequests = 0;
      final opening = AccountStoreRuntime.initialize(
        initializeAuth: () => auth.future,
        identity: () => identity,
        applicationSupportDirectory: () async {
          pathRequests++;
          return root;
        },
        metadata: metadata,
        legacyKeys: _LegacyKeys(),
        security: _Security(),
      );
      await Future<void>.delayed(Duration.zero);
      expect(pathRequests, 0);
      auth.complete();
      final runtime = await opening;
      await runtime.coordinator.observeSession();
      expect(pathRequests, 1);
      expect(metadata.values, isEmpty);
      expect(await root.list().toList(), isEmpty);
      expect(runtime.coordinator.isReady, isFalse);
      await runtime.coordinator.close();
    },
  );

  test(
    'fresh verified account opens scoped encrypted file without global bootstrap',
    () async {
      final identity = _Identity()
        ..session = const VerifiedSessionSnapshot('synthetic-a', Object());
      final runtime = await AccountStoreRuntime.initialize(
        initializeAuth: () async {},
        identity: () => identity,
        applicationSupportDirectory: () async => root,
        metadata: _Metadata(),
        legacyKeys: _LegacyKeys(),
        security: _Security(),
      );
      await runtime.coordinator.observeSession();
      expect(runtime.coordinator.isReady, isTrue);
      final device = await runtime.deviceIdentity.resolve(runtime.coordinator);
      expect(device, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(await runtime.deviceIdentity.resolve(runtime.coordinator), device);
      await runtime.coordinator.withAccount(
        (lease) => lease.run((db) async {
          final cipher = await db.customSelect('PRAGMA cipher').getSingle();
          expect(cipher.data.values.single, isNotEmpty);
        }),
      );
      expect(File('${root.path}/kasaran.sqlite').existsSync(), isFalse);
      final files = await root
          .list(recursive: true)
          .where((entry) => entry.path.endsWith('/kasaran.sqlite'))
          .toList();
      expect(files, hasLength(1));
      expect(files.single.path, contains('/account_stores/'));
      await runtime.coordinator.close();
    },
  );

  for (final suffix in ['', '-journal', '-wal', '-shm']) {
    test(
      'legacy source $suffix blocks scope without original key or reset',
      () async {
        final source = File('${root.path}/kasaran.sqlite$suffix');
        await source.writeAsBytes([11, 22, 33]);
        final identity = _Identity()
          ..session = const VerifiedSessionSnapshot('synthetic-a', Object());
        final runtime = await AccountStoreRuntime.initialize(
          initializeAuth: () async {},
          identity: () => identity,
          applicationSupportDirectory: () async => root,
          metadata: _Metadata(),
          legacyKeys: _LegacyKeys(),
          security: _Security(),
        );
        await expectLater(
          runtime.coordinator.observeSession(),
          throwsStateError,
        );
        expect(runtime.coordinator.isReady, isFalse);
        expect(runtime.coordinator.hasFailure, isTrue);
        expect(await source.readAsBytes(), [11, 22, 33]);
        final destinations = await root
            .list(recursive: true)
            .where(
              (entry) =>
                  entry.path.contains('/account_stores/') && entry is File,
            )
            .toList();
        expect(destinations, isEmpty);
        await runtime.coordinator.close();
      },
    );
  }
}
