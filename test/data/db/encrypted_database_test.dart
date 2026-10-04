import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';

class _MemoryKeyStore implements DatabaseKeyStore {
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String key) async {
    value = key;
    writes++;
  }
}

void main() {
  late Directory directory;
  late File file;
  late _MemoryKeyStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasaran-encrypted-db-');
    file = File('${directory.path}/plan.sqlite');
    store = _MemoryKeyStore();
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'reopen preserves a value with the secure-store key, no plaintext file',
    () async {
      final first = await EncryptedDatabaseOpener(file, store).open();
      await first.customStatement(
        'CREATE TABLE phase05_probe(value TEXT NOT NULL)',
      );
      await first.customStatement('INSERT INTO phase05_probe VALUES (?)', [
        'offline-private-supplier',
      ]);
      await first.close();

      expect(store.value, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(store.writes, 1);
      final bytes = await file.readAsBytes();
      expect(
        utf8.decode(bytes.take(16).toList(), allowMalformed: true),
        isNot('SQLite format 3\u0000'),
      );
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('offline-private-supplier')),
      );
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains(store.value)),
      );

      final reopened = await EncryptedDatabaseOpener(file, store).open();
      final rows = await reopened
          .customSelect('SELECT value FROM phase05_probe')
          .get();
      expect(rows.single.read<String>('value'), 'offline-private-supplier');
      expect(store.writes, 1);
      await reopened.close();
    },
  );

  test('existing database without its secure key fails closed', () async {
    final db = await EncryptedDatabaseOpener(file, store).open();
    await db.customStatement('CREATE TABLE phase05_probe(value INTEGER)');
    await db.close();
    store.value = null;
    await expectLater(
      EncryptedDatabaseOpener(file, store).open(),
      throwsA(isA<StateError>()),
    );
    expect(store.writes, 1);
  });

  test('wrong key does not read an existing encrypted database', () async {
    final db = await EncryptedDatabaseOpener(file, store).open();
    await db.customStatement('CREATE TABLE phase05_probe(value INTEGER)');
    await db.close();
    store.value = 'b' * 64;
    await expectLater(
      EncryptedDatabaseOpener(file, store).open(),
      throwsA(isA<Exception>()),
    );
  });

  test('open and read do not attempt a network request', () async {
    var attempts = 0;
    await HttpOverrides.runZoned(
      () async {
        final db = await EncryptedDatabaseOpener(file, store).open();
        expect(
          (await db.customSelect('PRAGMA user_version').get()).single.read<int>(
            'user_version',
          ),
          1,
        );
        await db.close();
      },
      createHttpClient: (context) {
        attempts++;
        throw StateError('Database path attempted HTTP');
      },
    );
    expect(attempts, 0);
  });
}
