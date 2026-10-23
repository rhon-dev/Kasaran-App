import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/account_store_registry.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/legacy_store_migration.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import '../../fixtures/encrypted_v2_fixture.dart';

class _Key implements DatabaseKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async => value = key;
}

class _SidecarOnKeyRead implements DatabaseKeyStore {
  _SidecarOnKeyRead(this.delegate, this.sidecar);
  final _Key delegate;
  final Link sidecar;
  @override
  Future<String?> read() async {
    await sidecar.create('${sidecar.path}.missing');
    return delegate.read();
  }

  @override
  Future<void> write(String key) => delegate.write(key);
}

class _Metadata implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _DelayedMetadata implements SecureKeyValueStore {
  _DelayedMetadata(this.backing);
  final _Metadata backing;
  @override
  Future<String?> read(String key) async {
    final value = await backing.read(key);
    if (key.startsWith('kasaran.account_db.v1.')) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return value;
  }

  @override
  Future<void> write(String key, String value) => backing.write(key, value);
  @override
  Future<void> delete(String key) => backing.delete(key);
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
  late File legacy;
  late _Key key;
  late AccountStoreRegistry registry;
  late AccountStoreLocation destination;
  late _Security security;
  late _Metadata metadata;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kasaran-migration-');
    root = Directory(await root.resolveSymbolicLinks());
    legacy = File('${root.path}/kasaran.sqlite');
    key = _Key();
    security = _Security();
    metadata = _Metadata();
    registry = AccountStoreRegistry(root, metadata, security);
    destination = await registry.resolveVerified(
      const VerifiedSessionSnapshot('verified-A', Object()),
    );
    final db = await openCanonicalV2(legacy, key);
    await db.customStatement('''
      INSERT INTO plans (id, creator_user_id, wedding_date,
        total_budget_cents, guest_cap, region_code, ruleset_version,
        driving_rsvp_status, created_at)
      VALUES ('solo', 'verified-A', '2026-10-14',
        9007199254740991, 2, 'PH', 'v1', 'pending', '2026-10-14')
    ''');
    await db.customStatement('''
      INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id)
      VALUES ('solo-A','solo','verified-A')
    ''');
    await db.customStatement('''
      INSERT INTO plan_members (plan_id,user_id,plan_member_id,role,joined_at)
      VALUES ('solo','verified-A','solo-A','creator','2026-10-14')
    ''');
    await db.close();
  });
  tearDown(() async => root.delete(recursive: true));

  for (final emptyDestination in [false, true]) {
    test(
      'missing source rejects ${emptyDestination ? 'empty' : 'missing'} destination without writes',
      () async {
        await legacy.delete();
        final originalKey = key.value;
        if (emptyDestination) {
          await destination.file.parent.create(recursive: true);
          await destination.file.create();
        }
        await expectLater(
          LegacyStoreMigrator(
            legacy,
            key,
            registry,
            security,
          ).ensurePromoted('verified-A', destination),
          throwsA(
            isA<LocalStoreUnavailable>().having(
              (error) => error.reason,
              'missing source barrier',
              'sourceUnavailable',
            ),
          ),
        );
        expect(
          FileSystemEntity.typeSync(legacy.path, followLinks: false),
          FileSystemEntityType.notFound,
        );
        expect(key.value, originalKey);
        expect(destination.file.existsSync(), emptyDestination);
        if (emptyDestination) {
          expect(await destination.file.length(), 0);
        }
      },
    );
  }

  test('current v3 is not reinterpreted as canonical legacy v2',()async {
    final upgraded=await EncryptedDatabaseOpener(legacy,key).open();await upgraded.close();
    final before=await legacy.readAsBytes();
    await expectLater(LegacyStoreMigrator(legacy,key,registry,security).ensurePromoted('verified-A',destination),throwsA(isA<LocalStoreUnavailable>().having((e)=>e.reason,'source version','unsupportedSourceVersion')));
    expect(await legacy.readAsBytes(),before);expect(await destination.keys.read(),isNull);expect(destination.file.existsSync(),isFalse);
  });
  test('dangling sidecar appearing after initial check fails closed', () async {
    final before = await legacy.readAsBytes();
    final originalKey = key.value;
    final sidecar = Link('${legacy.path}-wal');
    await expectLater(
      LegacyStoreMigrator(
        legacy,
        _SidecarOnKeyRead(key, sidecar),
        registry,
        security,
      ).ensurePromoted('verified-A', destination),
      throwsA(
        isA<LocalStoreUnavailable>().having(
          (error) => error.reason,
          'post-open sidecar barrier',
          'unsupportedSourceSidecar',
        ),
      ),
    );
    expect(
      FileSystemEntity.typeSync(sidecar.path, followLinks: false),
      FileSystemEntityType.link,
    );
    expect(await legacy.readAsBytes(), before);
    expect(key.value, originalKey);
    expect(destination.file.existsSync(), isFalse);
  });

  test(
    'encrypted v2 source is sealed and never exposed before durable promotion',
    () async {
      final before = await legacy.readAsBytes();
      final originalKey = key.value;
      final migrator = LegacyStoreMigrator(legacy, key, registry, security);
      await expectLater(
        migrator.ensurePromoted('verified-A', destination),
        throwsA(
          isA<LocalStoreUnavailable>().having(
            (error) => error.reason,
            'publication barrier',
            'durabilityUnverified',
          ),
        ),
      );
      expect(await legacy.readAsBytes(), before);
      expect(key.value, originalKey);
      expect(destination.file.existsSync(), isFalse);
      final stageDirectory = Directory(
        '${destination.file.parent.parent.path}/.stage-${destination.storeId}',
      );
      final stageFile = File('${stageDirectory.path}/kasaran.sqlite');
      final stage = sqlite.sqlite3.open(
        stageFile.path,
        mode: sqlite.OpenMode.readOnly,
      );
      stage.execute("PRAGMA key = '${await destination.keys.read()}'");
      try {
        expect(
          stage.select('SELECT id,total_budget_cents FROM plans').single['id'],
          'solo',
        );
        expect(
          stage
              .select('SELECT total_budget_cents FROM plans')
              .single['total_budget_cents'],
          9007199254740991,
        );
      } finally {
        stage.close();
      }
      final bytes = await stageFile.readAsBytes();
      expect(bytes.take(16), isNot(utf8.encode('SQLite format 3\u0000')));
      final manifest =
          jsonDecode(
                await File(
                  '${stageDirectory.path}/migration-manifest.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(manifest['store_id'], destination.storeId);
      expect(manifest['copy_format_version'], 1);
      expect(
        manifest['source_fingerprint'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    },
  );

  test(
    'complete retained stage revalidates on restart without rewriting',
    () async {
      final migrator = LegacyStoreMigrator(legacy, key, registry, security);
      final blocked = isA<LocalStoreUnavailable>().having(
        (error) => error.reason,
        'publication barrier',
        'durabilityUnverified',
      );
      await expectLater(
        migrator.ensurePromoted('verified-A', destination),
        throwsA(blocked),
      );
      final stage = Directory(
        '${destination.file.parent.parent.path}/.stage-${destination.storeId}',
      );
      final dbFile = File('${stage.path}/kasaran.sqlite');
      final manifest = File('${stage.path}/migration-manifest.json');
      final sourceBytes = await legacy.readAsBytes();
      final stageBytes = await dbFile.readAsBytes();
      final manifestBytes = await manifest.readAsBytes();
      final retainedKey = await destination.keys.read();
      final restartedRegistry = AccountStoreRegistry(root, metadata, security);
      final resumed = await restartedRegistry.resolveVerified(
        const VerifiedSessionSnapshot('verified-A', Object()),
      );
      await expectLater(
        LegacyStoreMigrator(
          legacy,
          key,
          restartedRegistry,
          security,
        ).ensurePromoted('verified-A', resumed),
        throwsA(blocked),
      );
      expect(await legacy.readAsBytes(), sourceBytes);
      expect(await dbFile.readAsBytes(), stageBytes);
      expect(await manifest.readAsBytes(), manifestBytes);
      expect(await resumed.keys.read(), retainedKey);
      expect(resumed.file.parent.existsSync(), isFalse);
    },
  );

  test('retained stage cannot reuse the sealed legacy encryption key', () async {
    final migrator = LegacyStoreMigrator(legacy, key, registry, security);
    await expectLater(
      migrator.ensurePromoted('verified-A', destination),
      throwsA(isA<LocalStoreUnavailable>()),
    );
    final stage = File(
      '${destination.file.parent.parent.path}/.stage-${destination.storeId}/kasaran.sqlite',
    );
    final sourceBytes = await legacy.readAsBytes();
    await stage.writeAsBytes(sourceBytes, flush: true);
    await destination.keys.write(key.value!);
    await expectLater(
      migrator.ensurePromoted('verified-A', destination),
      throwsA(
        isA<LocalStoreUnavailable>().having(
          (error) => error.reason,
          'independent encryption barrier',
          'stageKeyNotIndependent',
        ),
      ),
    );
    expect(await legacy.readAsBytes(), sourceBytes);
    expect(await stage.readAsBytes(), sourceBytes);
    expect(await destination.keys.read(), key.value);
    expect(destination.file.parent.existsSync(), isFalse);
  });

  Future<void> seedShared() async {
    final db = await openCanonicalV2(legacy, key);
    try {
      await db.customStatement("DELETE FROM plan_members WHERE plan_id='solo'");
      await db.customStatement(
        "DELETE FROM plan_member_aliases WHERE plan_id='solo'",
      );
      await db.customStatement('''
        INSERT INTO plans (id, creator_user_id, wedding_date,
          total_budget_cents, guest_cap, region_code, ruleset_version,
          driving_rsvp_status, created_at)
        VALUES ('shared', 'verified-B', '2026-10-14',
          9007199254740991, 2, 'PH', 'v1', 'pending', '2026-10-14')
      ''');
      for (final row in [
        ['shared', 'verified-A', 'shared-A', 'partner'],
        ['shared', 'verified-B', 'shared-B', 'creator'],
      ]) {
        await db.customStatement(
          'INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id) VALUES (?,?,?)',
          [row[2], row[0], row[1]],
        );
        await db.customStatement(
          'INSERT INTO plan_members (plan_id,user_id,plan_member_id,role,joined_at) VALUES (?,?,?,?,?)',
          [row[0], row[1], row[2], row[3], '2026-10-14'],
        );
      }
      await db.customStatement('''
        INSERT INTO ledger_entries (id,plan_id,category_code,entry_type,
          supplier_name,estimated_cents,pricing_mode,created_at,deleted_at)
        VALUES ('tombstone','shared','buffer','standard','Raw supplier',
          9007199254740991,'flat','2026-10-14','2026-10-15')
      ''');
      for (final row in [
        ['a-event', 'shared', 'shared-A'],
        ['b-event', 'shared', 'shared-B'],
      ]) {
        await db.customStatement(
          '''
          INSERT INTO change_log (id,plan_id,entity_type,entity_id,field_name,
            schema_version,old_value,new_value,device_monotonic,device_id,
            plan_member_id,created_at)
          VALUES (?,?,'future_unknown','tombstone','opaque_field',87,
            '{"raw": [1, 2]}','{"unknown":9007199254740991}',9,
            'same-device',?,'2026-10-14')
        ''',
          [row[0], row[1], row[2]],
        );
        await db.customStatement(
          'INSERT INTO outbox (event_id,plan_id,device_id,queued_at) VALUES (?,?,?,?)',
          [row[0], row[1], 'same-device', '2026-10-14'],
        );
      }
      for (final plan in ['shared']) {
        await db.customStatement(
          '''
          INSERT INTO sync_state (device_id,plan_id,device_monotonic,
            last_pushed_server_ts,last_pulled_server_ts)
          VALUES (? ,?,9007199254740991,123,456)
        ''',
          ['same-device', plan],
        );
      }
    } finally {
      await db.close();
    }
  }

  final stageKeyCache = <String, String>{};
  sqlite.Database openStage(AccountStoreLocation location) {
    final stage = File(
      '${location.file.parent.parent.path}/.stage-${location.storeId}/kasaran.sqlite',
    );
    final db = sqlite.sqlite3.open(stage.path, mode: sqlite.OpenMode.readOnly);
    db.execute("PRAGMA key = '${stageKeyCache[location.storeId]}'");
    db.execute('PRAGMA query_only = ON');
    return db;
  }

  test(
    'encrypted A and B stages route pending authors and retain raw history',
    () async {
      await seedShared();
      final original = await legacy.readAsBytes();
      final legacyKey = key.value;
      final b = await registry.resolveVerified(
        const VerifiedSessionSnapshot('verified-B', Object()),
      );
      for (final (user, location, plans, queued) in [
        ('verified-A', destination, ['shared'], ['a-event']),
        ('verified-B', b, ['shared'], ['b-event']),
      ]) {
        await expectLater(
          LegacyStoreMigrator(
            legacy,
            key,
            registry,
            security,
          ).ensurePromoted(user, location),
          throwsA(
            isA<LocalStoreUnavailable>().having(
              (e) => e.reason,
              'publication gate',
              'durabilityUnverified',
            ),
          ),
        );
        stageKeyCache[location.storeId] = (await location.keys.read())!;
        expect(stageKeyCache[location.storeId], isNot(legacyKey));
        expect(location.file.parent.existsSync(), isFalse);
        final stage = openStage(location);
        try {
          expect(
            stage
                .select('SELECT id FROM plans ORDER BY id')
                .map((r) => r['id']),
            plans,
          );
          expect(
            stage
                .select('SELECT event_id FROM outbox ORDER BY event_id')
                .map((r) => r['event_id']),
            queued,
          );
          expect(
            stage.select('SELECT id FROM change_log ORDER BY id').length,
            2,
          );
          expect(
            stage.select('SELECT old_value FROM change_log WHERE id = ?', [
              'b-event',
            ]).single['old_value'],
            '{"raw": [1, 2]}',
          );
          expect(
            stage.select('SELECT new_value FROM change_log WHERE id = ?', [
              'b-event',
            ]).single['new_value'],
            '{"unknown":9007199254740991}',
          );
          expect(
            stage
                .select('SELECT estimated_cents FROM ledger_entries')
                .single['estimated_cents'],
            9007199254740991,
          );
          expect(
            stage.select(
              'SELECT last_pulled_server_ts,device_monotonic FROM sync_state WHERE plan_id = ?',
              ['shared'],
            ).single['device_monotonic'],
            9007199254740991,
          );
          expect(stage.select('PRAGMA foreign_key_check'), isEmpty);
        } finally {
          stage.close();
        }
        expect(await legacy.readAsBytes(), original);
        expect(key.value, legacyKey);
      }
      final stage = openStage(destination);
      try {
        expect(stage.select('SELECT COUNT(*) AS n FROM outbox').single['n'], 1);
      } finally {
        stage.close();
      }
    },
  );

  test('missing live membership blocks before creating a stage', () async {
    final db = await openCanonicalV2(legacy, key);
    await db.customStatement("DELETE FROM plan_members WHERE plan_id='solo'");
    await db.close();
    final before = await legacy.readAsBytes();
    await expectLater(
      LegacyStoreMigrator(
        legacy,
        key,
        registry,
        security,
      ).ensurePromoted('verified-A', destination),
      throwsA(isA<LocalStoreUnavailable>()),
    );
    expect(
      Directory(
        '${destination.file.parent.parent.path}/.stage-${destination.storeId}',
      ).existsSync(),
      isFalse,
    );
    expect(await legacy.readAsBytes(), before);
  });

  test('unattributable pending alias blocks entire shared stage', () async {
    await seedShared();
    final db = await openCanonicalV2(legacy, key);
    await db.customStatement('''
      INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id)
      VALUES ('unknown','shared',NULL)
    ''');
    await db.customStatement('''
      INSERT INTO change_log (id,plan_id,entity_type,entity_id,field_name,
        schema_version,device_monotonic,device_id,plan_member_id,created_at)
      VALUES ('unknown-event','shared','future','x','x',87,10,
        'same-device','unknown','2026-10-14')
    ''');
    await db.customStatement('''
      INSERT INTO outbox (event_id,plan_id,device_id,queued_at)
      VALUES ('unknown-event','shared','same-device','2026-10-14')
    ''');
    await db.close();
    final before = await legacy.readAsBytes();
    await expectLater(
      LegacyStoreMigrator(
        legacy,
        key,
        registry,
        security,
      ).ensurePromoted('verified-A', destination),
      throwsA(
        isA<LocalStoreUnavailable>().having(
          (e) => e.reason,
          'pending attribution',
          'ambiguousPendingAuthor',
        ),
      ),
    );
    expect(
      Directory(
        '${destination.file.parent.parent.path}/.stage-${destination.storeId}',
      ).existsSync(),
      isFalse,
    );
    expect(await destination.keys.read(), isNull);
    expect(await legacy.readAsBytes(), before);
  });

  Future<void> expectRejectedBeforeStage(String reason) async {
    final before = await legacy.readAsBytes();
    final originalKey = key.value;
    await expectLater(
      LegacyStoreMigrator(
        legacy,
        key,
        registry,
        security,
      ).ensurePromoted('verified-A', destination),
      throwsA(
        isA<LocalStoreUnavailable>().having(
          (error) => error.reason,
          'source authorization',
          reason,
        ),
      ),
    );
    expect(await legacy.readAsBytes(), before);
    expect(key.value, originalKey);
    expect(await destination.keys.read(), isNull);
    expect(destination.file.parent.existsSync(), isFalse);
    expect(
      Directory(
        '${destination.file.parent.parent.path}/.stage-${destination.storeId}',
      ).existsSync(),
      isFalse,
    );
  }

  test('extra sqliteX table fails authorization before stage or key', () async {
    final db = sqlite.sqlite3.open(legacy.path);
    try {
      db.execute("PRAGMA key = '${key.value}'");
      db.execute('CREATE TABLE sqliteXextra (id TEXT PRIMARY KEY)');
    } finally {
      db.close();
    }
    await expectRejectedBeforeStage('unsupportedSourceLayout');
  });

  test('generated column fails authorization before stage or key', () async {
    final db = sqlite.sqlite3.open(legacy.path);
    try {
      db.execute("PRAGMA key = '${key.value}'");
      db.execute(
        'ALTER TABLE plans ADD COLUMN surprise TEXT GENERATED ALWAYS AS (id) VIRTUAL',
      );
    } finally {
      db.close();
    }
    await expectRejectedBeforeStage('unsupportedSourceLayout');
  });

  test('removed CHECK fails authorization before stage or key', () async {
    final db = sqlite.sqlite3.open(legacy.path);
    try {
      db.execute("PRAGMA key = '${key.value}'");
      db.execute('PRAGMA writable_schema = ON');
      db.execute(
        "UPDATE sqlite_master SET sql=replace(sql, 'CHECK (guest_cap >= 0)', '') WHERE type='table' AND name='plans'",
      );
      db.execute('PRAGMA writable_schema = OFF');
      db.execute('PRAGMA schema_version = 50');
    } finally {
      db.close();
    }
    await expectRejectedBeforeStage('unsupportedSourceLayout');
  });

  test(
    'changed column collation fails authorization before stage or key',
    () async {
      final db = sqlite.sqlite3.open(legacy.path);
      try {
        db.execute("PRAGMA key = '${key.value}'");
        db.execute('PRAGMA writable_schema = ON');
        db.execute(
          '''UPDATE sqlite_master SET sql=replace(sql, 'region_code TEXT NOT NULL', 'region_code TEXT COLLATE NOCASE NOT NULL') WHERE type='table' AND name='plans' ''',
        );
        expect(db.select("SELECT sql FROM sqlite_master WHERE name='plans'").single['sql'], contains('COLLATE NOCASE'));
        db.execute('PRAGMA writable_schema = OFF');
        db.execute('PRAGMA schema_version = 51');
      } finally {
        db.close();
      }
      await expectRejectedBeforeStage('unsupportedSourceLayout');
    },
  );

  test('deferred foreign key fails authorization before stage or key', () async {
    final db = sqlite.sqlite3.open(legacy.path);
    try {
      db.execute("PRAGMA key = '${key.value}'");
      db.execute('PRAGMA writable_schema = ON');
      db.execute(
        "UPDATE sqlite_master SET sql=replace(sql, 'REFERENCES plans(id)', 'REFERENCES plans(id) DEFERRABLE INITIALLY DEFERRED') WHERE type='table' AND name='sync_state'",
      );
      db.execute('PRAGMA writable_schema = OFF');
      db.execute('PRAGMA schema_version = 52');
    } finally {
      db.close();
    }
    await expectRejectedBeforeStage('unsupportedSourceLayout');
  });

  test('extra v2 column fails authorization before stage or key', () async {
    final db = sqlite.sqlite3.open(legacy.path);
    try {
      db.execute("PRAGMA key = '${key.value}'");
      db.execute('ALTER TABLE plans ADD COLUMN unexpected TEXT');
    } finally {
      db.close();
    }
    await expectRejectedBeforeStage('unsupportedSourceLayout');
  });

  test(
    'dropped partial unique index fails authorization before stage or key',
    () async {
      final db = sqlite.sqlite3.open(legacy.path);
      try {
        db.execute("PRAGMA key = '${key.value}'");
        db.execute('DROP INDEX one_active_created_plan');
      } finally {
        db.close();
      }
      await expectRejectedBeforeStage('unsupportedSourceLayout');
    },
  );

  test('pre-constraint v2 missing parity index fails closed', () async {
    final db = sqlite.sqlite3.open(legacy.path);
    try {
      db.execute("PRAGMA key = '${key.value}'");
      db.execute('DROP INDEX one_membership_user');
    } finally {
      db.close();
    }
    await expectRejectedBeforeStage('unsupportedSourceLayout');
  });

  test('altered v2 default fails before stage or key', () async {
    final db = sqlite.sqlite3.open(legacy.path);
    try {
      db.execute("PRAGMA key = '${key.value}'");
      db.execute('PRAGMA foreign_keys = OFF');
      db.execute('BEGIN');
      db.execute('ALTER TABLE sync_state RENAME TO old_sync_state');
      db.execute('''
          CREATE TABLE sync_state (
            device_id TEXT NOT NULL, plan_id TEXT NOT NULL REFERENCES plans(id),
            last_pushed_server_ts INTEGER, last_pulled_server_ts INTEGER,
            device_monotonic INTEGER NOT NULL DEFAULT 1 CHECK(device_monotonic>=0),
            PRIMARY KEY(device_id,plan_id)
          )
        ''');
      db.execute('INSERT INTO sync_state SELECT * FROM old_sync_state');
      db.execute('DROP TABLE old_sync_state');
      db.execute('COMMIT');
    } finally {
      db.close();
    }
    await expectRejectedBeforeStage('unsupportedSourceLayout');
  });

  test(
    'dropped alias membership FK fails authorization before stage or key',
    () async {
      final db = sqlite.sqlite3.open(legacy.path);
      try {
        db.execute("PRAGMA key = '${key.value}'");
        db.execute('PRAGMA foreign_keys = OFF');
        db.execute('BEGIN');
        db.execute('ALTER TABLE plan_members RENAME TO old_plan_members');
        db.execute('''
        CREATE TABLE plan_members (
          plan_id TEXT NOT NULL REFERENCES plans(id), user_id TEXT NOT NULL UNIQUE,
          plan_member_id TEXT NOT NULL UNIQUE,
          role TEXT NOT NULL CHECK (role IN ('creator','partner')),
          joined_at TEXT NOT NULL, PRIMARY KEY(plan_id,user_id)
        )
      ''');
        db.execute('INSERT INTO plan_members SELECT * FROM old_plan_members');
        db.execute('DROP TABLE old_plan_members');
        db.execute('COMMIT');
      } finally {
        db.close();
      }
      await expectRejectedBeforeStage('unsupportedSourceLayout');
    },
  );

  test('mismatched pending device fails before stage or key', () async {
    await seedShared();
    final db = sqlite.sqlite3.open(legacy.path);
    try {
      db.execute("PRAGMA key = '${key.value}'");
      db.execute(
        "UPDATE outbox SET device_id='wrong-device' WHERE event_id='a-event'",
      );
    } finally {
      db.close();
    }
    await expectRejectedBeforeStage('ambiguousPendingAuthor');
  });

  test('existing stage and missing retained key are never reset', () async {
    await seedShared();
    final migrator = LegacyStoreMigrator(legacy, key, registry, security);
    await expectLater(
      migrator.ensurePromoted('verified-A', destination),
      throwsA(isA<LocalStoreUnavailable>()),
    );
    final stage = File(
      '${destination.file.parent.parent.path}/.stage-${destination.storeId}/kasaran.sqlite',
    );
    final before = await stage.readAsBytes();
    final retained = await destination.keys.read();
    await expectLater(
      migrator.ensurePromoted('verified-A', destination),
      throwsA(isA<LocalStoreUnavailable>()),
    );
    expect(await stage.readAsBytes(), before);
    expect(await destination.keys.read(), retained);
    await destination.keys.write('f' * 64);
    await expectLater(
      migrator.ensurePromoted('verified-A', destination),
      throwsA(isA<LocalStoreUnavailable>()),
    );
    expect(await stage.readAsBytes(), before);
    await destination.keys.write('');
    await expectLater(
      migrator.ensurePromoted('verified-A', destination),
      throwsA(isA<LocalStoreUnavailable>()),
    );
    expect(await stage.readAsBytes(), before);
  });

  for (final fault in [
    'manifest-version',
    'manifest-float-version',
    'manifest-store',
    'manifest-source',
    'manifest-malformed',
    'missing-manifest',
    'extra-sidecar',
    'linked-file',
    'changed-content',
    'changed-schema',
    'missing-key',
    'changed-source',
  ]) {
    test('retained stage $fault blocks without repair or publication', () async {
      final migrator = LegacyStoreMigrator(legacy, key, registry, security);
      await expectLater(
        migrator.ensurePromoted('verified-A', destination),
        throwsA(isA<LocalStoreUnavailable>()),
      );
      final stage = Directory(
        '${destination.file.parent.parent.path}/.stage-${destination.storeId}',
      );
      final stageFile = File('${stage.path}/kasaran.sqlite');
      final manifest = File('${stage.path}/migration-manifest.json');
      var reason = 'stageManifestMismatch';
      if (fault.startsWith('manifest-') && fault != 'manifest-malformed') {
        final data =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        data[switch (fault) {
          'manifest-version' => 'copy_format_version',
          'manifest-float-version' => 'copy_format_version',
          'manifest-store' => 'store_id',
          _ => 'source_fingerprint',
        }] = fault == 'manifest-float-version'
            ? 1.0
            : 'invalid';
        await manifest.writeAsString(jsonEncode(data));
      } else if (fault == 'manifest-malformed') {
        await manifest.writeAsString('{');
      } else if (fault == 'missing-manifest') {
        await manifest.delete();
        reason = 'invalidRetainedStage';
      } else if (fault == 'extra-sidecar') {
        await File('${stageFile.path}-wal').writeAsBytes([1, 2, 3]);
        reason = 'invalidRetainedStage';
      } else if (fault == 'linked-file') {
        final target = File('${root.path}/retained-copy.sqlite');
        await stageFile.rename(target.path);
        await Link(stageFile.path).create(target.path);
        reason = 'invalidRetainedStage';
      } else if (fault == 'changed-content' || fault == 'changed-schema') {
        final stageDb = sqlite.sqlite3.open(stageFile.path);
        try {
          stageDb.execute("PRAGMA key = '${await destination.keys.read()}'");
          stageDb.execute(
            fault == 'changed-content'
                ? 'UPDATE plans SET guest_cap=3'
                : 'CREATE TABLE unexpected (id TEXT)',
          );
        } finally {
          stageDb.close();
        }
        reason = fault == 'changed-content'
            ? 'stageContentMismatch'
            : 'unsupportedSourceLayout';
      } else if (fault == 'missing-key') {
        await metadata.delete('kasaran.account_db.v1.${destination.storeId}');
        reason = 'stageKeyUnavailable';
      } else if (fault == 'changed-source') {
        final sourceDb = sqlite.sqlite3.open(legacy.path);
        try {
          sourceDb.execute("PRAGMA key = '${key.value}'");
          sourceDb.execute('UPDATE plans SET guest_cap=3');
        } finally {
          sourceDb.close();
        }
      }
      final sourceBefore = await legacy.readAsBytes();
      final stageBefore = await stageFile.readAsBytes();
      final manifestBefore = manifest.existsSync()
          ? await manifest.readAsBytes()
          : null;
      final keyBefore = await destination.keys.read();
      await expectLater(
        migrator.ensurePromoted('verified-A', destination),
        throwsA(
          isA<LocalStoreUnavailable>().having(
            (error) => error.reason,
            'recovery rejection',
            reason,
          ),
        ),
      );
      expect(await legacy.readAsBytes(), sourceBefore);
      expect(await stageFile.readAsBytes(), stageBefore);
      expect(
        manifest.existsSync() ? await manifest.readAsBytes() : null,
        manifestBefore,
      );
      expect(await destination.keys.read(), keyBefore);
      expect(destination.file.parent.existsSync(), isFalse);
    });
  }

  test('verified A cannot stage into B mapped destination', () async {
    final b = await registry.resolveVerified(
      const VerifiedSessionSnapshot('verified-B', Object()),
    );
    final before = await legacy.readAsBytes();
    final originalKey = key.value;
    await expectLater(
      LegacyStoreMigrator(
        legacy,
        key,
        registry,
        security,
      ).ensurePromoted('verified-A', b),
      throwsA(isA<LocalStoreUnavailable>()),
    );
    expect(await b.keys.read(), isNull);
    expect(
      Directory(
        '${b.file.parent.parent.path}/.stage-${b.storeId}',
      ).existsSync(),
      isFalse,
    );
    expect(b.file.parent.existsSync(), isFalse);
    expect(await legacy.readAsBytes(), before);
    expect(key.value, originalKey);
  });

  test(
    'competing migrators retain exactly one immutable stage and key',
    () async {
      final before = await legacy.readAsBytes();
      final originalKey = key.value;
      final firstRegistry = AccountStoreRegistry(
        root,
        _DelayedMetadata(metadata),
        security,
      );
      final otherRegistry = AccountStoreRegistry(
        root,
        _DelayedMetadata(metadata),
        security,
      );
      final first = await firstRegistry.resolveVerified(
        const VerifiedSessionSnapshot('verified-A', Object()),
      );
      final other = await otherRegistry.resolveVerified(
        const VerifiedSessionSnapshot('verified-A', Object()),
      );
      expect(other.storeId, destination.storeId);
      final results = await Future.wait(
        [
          LegacyStoreMigrator(
            legacy,
            key,
            firstRegistry,
            security,
          ).ensurePromoted('verified-A', first),
          LegacyStoreMigrator(
            legacy,
            key,
            otherRegistry,
            security,
          ).ensurePromoted('verified-A', other),
        ].map((future) async {
          try {
            await future;
            return 'published';
          } on LocalStoreUnavailable catch (error) {
            return error.reason;
          }
        }),
      );
      expect(results, contains('durabilityUnverified'));
      expect(results, everyElement('durabilityUnverified'));
      expect(results, isNot(contains('published')));
      final stage = Directory(
        '${destination.file.parent.parent.path}/.stage-${destination.storeId}',
      );
      final files = stage.listSync().whereType<File>().toList();
      expect(files.map((file) => file.uri.pathSegments.last).toSet(), {
        'kasaran.sqlite',
        'migration-manifest.json',
      });
      final retained = await destination.keys.read();
      expect(retained, matches(RegExp(r'^[0-9a-f]{64}$')));
      stageKeyCache[destination.storeId] = retained!;
      final opened = openStage(destination);
      try {
        expect(opened.select('SELECT id FROM plans').single['id'], 'solo');
      } finally {
        opened.close();
      }
      final stageBytes = await File(
        '${stage.path}/kasaran.sqlite',
      ).readAsBytes();
      final manifestBytes = await File(
        '${stage.path}/migration-manifest.json',
      ).readAsBytes();
      await expectLater(
        LegacyStoreMigrator(
          legacy,
          key,
          otherRegistry,
          security,
        ).ensurePromoted('verified-A', other),
        throwsA(isA<LocalStoreUnavailable>()),
      );
      expect(await destination.keys.read(), retained);
      expect(
        await File('${stage.path}/kasaran.sqlite').readAsBytes(),
        stageBytes,
      );
      expect(
        await File('${stage.path}/migration-manifest.json').readAsBytes(),
        manifestBytes,
      );
      expect(destination.file.parent.existsSync(), isFalse);
      expect(await legacy.readAsBytes(), before);
      expect(key.value, originalKey);
    },
  );

  test('account bootstrap cannot bypass sealed legacy migration', () async {
    final before = await legacy.readAsBytes();
    await expectLater(
      LocalStoreBootstrap(root, key, security).openAccount(destination),
      throwsA(isA<StateError>()),
    );
    expect(destination.file.existsSync(), isFalse);
    expect(await legacy.readAsBytes(), before);
  });

  test('dangling legacy symlink cannot bypass account bootstrap', () async {
    await legacy.delete();
    await Link(legacy.path).create('${root.path}/missing-target');
    await expectLater(
      LocalStoreBootstrap(root, key, security).openAccount(destination),
      throwsA(isA<StateError>()),
    );
    expect(destination.file.existsSync(), isFalse);
  });

  test(
    'missing original key fails closed without creating destination',
    () async {
      key.value = null;
      final migrator = LegacyStoreMigrator(legacy, key, registry, security);
      await expectLater(
        migrator.ensurePromoted('verified-A', destination),
        throwsA(isA<LocalStoreUnavailable>()),
      );
      expect(destination.file.existsSync(), isFalse);
      expect(key.value, isNull);
    },
  );

  test('sidecars fail closed without touching encrypted source', () async {
    final before = await legacy.readAsBytes();
    final sidecar = File('${legacy.path}-wal');
    await sidecar.writeAsBytes([1, 2, 3]);
    await expectLater(
      LegacyStoreMigrator(
        legacy,
        key,
        registry,
        security,
      ).ensurePromoted('verified-A', destination),
      throwsA(isA<LocalStoreUnavailable>()),
    );
    expect(await legacy.readAsBytes(), before);
    expect(await sidecar.readAsBytes(), [1, 2, 3]);
    expect(destination.file.existsSync(), isFalse);
  });
}
