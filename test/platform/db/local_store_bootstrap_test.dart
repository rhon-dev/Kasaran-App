import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';

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
  @override
  Future<void> protectDirectory(String path) async => directoryCalls++;
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
    dir = await Directory.systemTemp.createTemp('kasaran-bootstrap-');
    key = _Store();
    safety = _Safety();
  });
  tearDown(() async => dir.delete(recursive: true));

  test(
    'protects directory and file before returning the opened store',
    () async {
      safety.locked = true;
      final result = await LocalStoreBootstrap(dir, key, safety).open();
      expect(result.warningNeeded, isFalse);
      expect(safety.directoryCalls, 1);
      expect(safety.fileCalls, 1);
      expect(
        await result.db.customSelect('PRAGMA user_version').get(),
        hasLength(1),
      );
      await result.db.close();
    },
  );

  test('unlocked device warning is available once, not repeatedly', () async {
    final first = await LocalStoreBootstrap(dir, key, safety).open();
    expect(first.warningNeeded, isTrue);
    await first.db.close();
    await safety.markLockWarningShown();
    final second = await LocalStoreBootstrap(dir, key, safety).open();
    expect(second.warningNeeded, isFalse);
    await second.db.close();
  });

  test('file-protection failure prevents exposing the database', () async {
    final failing = _FailingSafety();
    await expectLater(
      LocalStoreBootstrap(dir, key, failing).open(),
      throwsA(isA<StateError>()),
    );
  });
}

class _FailingSafety extends _Safety {
  @override
  Future<void> protectFile(String path) async =>
      throw StateError('protection failed');
}
