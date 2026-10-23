import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/account_store_registry.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';

class _Metadata implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Store implements DatabaseKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async => value = key;
}

class _Safety implements LocalDeviceSecurity {
  bool locked = false;
  bool warned = false;
  int directoryCalls = 0;
  int fileCalls = 0;
  final protectedDirectories = <String>[];
  String? freshAccountFile;
  bool protectedBeforeDatabaseCreation = false;
  @override
  Future<void> protectDirectory(String path) async {
    expect(Directory(path).existsSync(), isTrue);
    if (freshAccountFile != null &&
        path == File(freshAccountFile!).parent.path) {
      protectedBeforeDatabaseCreation = !File(freshAccountFile!).existsSync();
    }
    protectedDirectories.add(path);
    directoryCalls++;
  }

  @override
  Future<void> protectFile(String path) async => fileCalls++;
  @override
  Future<bool> hasDeviceLock() async => locked;
  @override
  Future<bool> hasShownLockWarning() async => warned;
  @override
  Future<void> markLockWarningShown() async => warned = true;
}

void main() {
  late Directory dir;
  late _Store key;
  late _Safety safety;
  setUp(() async {
    final fixture = await Directory.systemTemp.createTemp('kasaran-bootstrap-');
    dir = Directory(await fixture.resolveSymbolicLinks());
    key = _Store();
    safety = _Safety();
  });
  tearDown(() async => dir.delete(recursive: true));

  test('fresh account open creates and protects final before SQLite', () async {
    final metadata = _Metadata();
    final location = await AccountStoreRegistry(
      dir,
      metadata,
      safety,
    ).resolveVerified(const VerifiedSessionSnapshot('A', Object()));
    expect(location.file.parent.existsSync(), isFalse);
    safety.freshAccountFile = location.file.path;
    final db = await LocalStoreBootstrap(
      dir,
      key,
      safety,
    ).openAccount(location);
    expect(location.file.parent.existsSync(), isTrue);
    expect(safety.protectedDirectories, contains(location.file.parent.path));
    expect(safety.protectedBeforeDatabaseCreation, isTrue);
    expect(location.file.existsSync(), isTrue);
    await db.close();
    final reopened = await LocalStoreBootstrap(
      dir,
      key,
      safety,
    ).openAccount(location);
    await reopened.close();
  });

  test('mapped account with vanished database refuses replacement', () async {
    final metadata = _Metadata();
    final location = await AccountStoreRegistry(
      dir,
      metadata,
      safety,
    ).resolveVerified(const VerifiedSessionSnapshot('A', Object()));
    final bootstrap = LocalStoreBootstrap(dir, key, safety);
    final db = await bootstrap.openAccount(location);
    await db.close();
    await location.file.delete();
    final retainedKey = await location.keys.read();
    await expectLater(
      bootstrap.openAccount(location),
      throwsA(isA<StateError>()),
    );
    expect(location.file.existsSync(), isFalse);
    expect(await location.keys.read(), retainedKey);
  });

  test('prepare checks warning without opening the legacy database', () async {
    final bootstrap = LocalStoreBootstrap(dir, key, safety);
    expect(await bootstrap.prepare(), isTrue);
    expect(await bootstrap.prepare(), isTrue);
    expect(safety.directoryCalls, 1);
    expect(safety.fileCalls, 0);
    expect(File('${dir.path}/kasaran.sqlite').existsSync(), isFalse);
    expect(key.value, isNull);
  });

  test(
    'protects directory and file before returning the opened store',
    () async {
      safety.locked = true;
      final location = await AccountStoreRegistry(
        dir,
        _Metadata(),
        safety,
      ).resolveVerified(const VerifiedSessionSnapshot('A', Object()));
      final bootstrap = LocalStoreBootstrap(dir, key, safety);
      expect(await bootstrap.prepare(), isFalse);
      final db = await bootstrap.openAccount(location);
      expect(safety.protectedDirectories, contains(location.file.parent.path));
      expect(safety.fileCalls, greaterThan(0));
      expect(await db.customSelect('PRAGMA user_version').get(), hasLength(1));
      await db.close();
    },
  );

  test('unlocked device warning is available once, not repeatedly', () async {
    final first = await LocalStoreBootstrap(dir, key, safety).prepare();
    expect(first, isTrue);
    await safety.markLockWarningShown();
    final second = await LocalStoreBootstrap(dir, key, safety).prepare();
    expect(second, isFalse);
    expect(File('${dir.path}/kasaran.sqlite').existsSync(), isFalse);
  });

  test('file-protection failure prevents exposing the database', () async {
    final failing = _FailingSafety();
    final location = await AccountStoreRegistry(
      dir,
      _Metadata(),
      safety,
    ).resolveVerified(const VerifiedSessionSnapshot('A', Object()));
    await expectLater(
      LocalStoreBootstrap(dir, key, failing).openAccount(location),
      throwsA(isA<StateError>()),
    );
  });
}

class _FailingSafety extends _Safety {
  @override
  Future<void> protectFile(String path) async {
    if (path.endsWith('/kasaran.sqlite')) {
      throw StateError('protection failed');
    }
    await super.protectFile(path);
  }
}
