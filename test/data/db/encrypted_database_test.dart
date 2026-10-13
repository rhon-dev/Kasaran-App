import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
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

Future<void> _createEncryptedFixture(
  File file,
  _MemoryKeyStore store, {
  required int version,
}) async {
  final random = Random.secure();
  final key = List<int>.generate(
    32,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  await store.write(key);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    expect(raw.select('PRAGMA cipher'), isNotEmpty);
    raw.execute("PRAGMA key = '$key'");
    raw.execute('CREATE TABLE legacy_sentinel(value TEXT NOT NULL)');
    raw.execute("INSERT INTO legacy_sentinel VALUES ('preserve-local-row')");
    raw.execute('PRAGMA user_version = $version');
  } finally {
    raw.dispose();
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

  test(
    'encrypted v1 upgrade preserves unrelated rows and original key',
    () async {
      await _createEncryptedFixture(file, store, version: 1);
      final originalKey = store.value;
      final db = await EncryptedDatabaseOpener(file, store).open();
      expect(db.schemaVersion, 2);
      final sentinel = await db
          .customSelect('SELECT value FROM legacy_sentinel')
          .get();
      expect(sentinel.single.read<String>('value'), 'preserve-local-row');
      expect(db.allTables, hasLength(7));
      await db.close();
      expect(store.value, originalKey);
      expect(store.writes, 1);
      final reopened = await EncryptedDatabaseOpener(file, store).open();
      expect(
        (await reopened.customSelect('PRAGMA user_version').get()).single
            .read<int>('user_version'),
        2,
      );
      await reopened.close();
    },
  );

  test('future encrypted version fails before changing file bytes', () async {
    await _createEncryptedFixture(file, store, version: 3);
    final originalBytes = await file.readAsBytes();
    await expectLater(
      EncryptedDatabaseOpener(file, store).open(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Encrypted local schema newer than supported',
        ),
      ),
    );
    expect(await file.readAsBytes(), originalBytes);
    expect(store.writes, 1);
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
          2,
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
