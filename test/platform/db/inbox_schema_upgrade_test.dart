import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class Keys implements DatabaseKeyStore {
  String key = '1234567890abcdef' * 4;
  @override
  Future<String?> read() async => key;
  @override
  Future<void> write(String value) async => key = value;
}

void main() {
  late Directory dir;
  late File file;
  late Keys keys;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('inbox-upgrade-');
    file = File('${dir.path}/db.sqlite');
    keys = Keys();
    final raw = sqlite.sqlite3.open(file.path);
    expect(raw.select('PRAGMA cipher'), isNotEmpty);
    raw.execute("PRAGMA key = '${keys.key}'");
    raw.execute(await File('test/fixtures/local_schema_v2.sql').readAsString());
    raw.execute(
      "INSERT INTO plans(id,creator_user_id,wedding_date,total_budget_cents,guest_cap,region_code,ruleset_version,driving_rsvp_status,created_at) VALUES('p','u','2027-01-01',9007199254740993,2,'PH','v1','pending','now')",
    );
    raw.execute("INSERT INTO plan_member_aliases VALUES('m','p','u')");
    raw.execute(
      "INSERT INTO change_log(id,plan_id,entity_type,entity_id,field_name,schema_version,new_value,device_monotonic,device_id,plan_member_id,created_at) VALUES('e','p','future','x','full',99,'{\"amount\":9007199254740993}',8,'d','m','now')",
    );
    raw.execute("INSERT INTO outbox VALUES('e','p','d','now')");
    raw.execute("INSERT INTO sync_state VALUES('d','p',40,77,8)");
    raw.execute('CREATE TABLE sentinel(value TEXT)');
    raw.execute("INSERT INTO sentinel VALUES('retained')");
    raw.close();
  });
  tearDown(() async => dir.delete(recursive: true));
  test(
    'failed upgrade actual COMMIT preserves v2 schema history and allows retry',
    () async {
      final original = sqlite.sqlite3.open(file.path);
      original.execute("PRAGMA key = '${keys.key}'");
      const preservedTables = [
        'plans',
        'plan_member_aliases',
        'plan_members',
        'ledger_entries',
        'change_log',
        'outbox',
        'sync_state',
        'sentinel',
      ];
      final before = {
        for (final table in preservedTables)
          table: original
              .select('SELECT * FROM $table')
              .map(Map<String, Object?>.from)
              .toList(),
      };
      original.close();
      final db = AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            raw.execute("PRAGMA key = '${keys.key}'");
            raw.commitFilter = () => false;
          },
        ),
      );
      await expectLater(
        db.customSelect('PRAGMA user_version').get(),
        throwsA(anything),
      );
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute("PRAGMA key = '${keys.key}'");
      expect(raw.select('PRAGMA user_version').single.columnAt(0), 2);
      expect(
        raw.select("SELECT * FROM sqlite_master WHERE name='sync_inbox'"),
        isEmpty,
      );
      expect(raw.select('SELECT * FROM sentinel').single['value'], 'retained');
      expect(raw.select('SELECT * FROM outbox'), hasLength(1));
      for (final table in preservedTables) {
        expect(
          raw
              .select('SELECT * FROM $table')
              .map(Map<String, Object?>.from)
              .toList(),
          before[table],
          reason: 'Native rejected upgrade preserves $table rows',
        );
      }
      raw.close();
      final retry = await EncryptedDatabaseOpener(file, keys).open();
      expect(
        (await retry.customSelect('PRAGMA user_version').get())
            .single
            .data
            .values
            .single,
        3,
      );
      await retry.close();
    },
  );
  test(
    'read-only v2 refuses upgrade without modifying bytes or version',
    () async {
      final before = await file.readAsBytes();
      final raw = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      raw.execute("PRAGMA key = '${keys.key}'");
      final db = AppDatabase(NativeDatabase.opened(raw));
      await expectLater(
        db.customSelect('PRAGMA user_version').get(),
        throwsA(anything),
      );
      await db.close();
      expect(await file.readAsBytes(), before);
      final check = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      check.execute("PRAGMA key = '${keys.key}'");
      expect(check.select('PRAGMA user_version').single.columnAt(0), 2);
      check.close();
    },
  );
  test(
    'newer encrypted version rejected before Drift and preserves file bytes',
    () async {
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute("PRAGMA key = '${keys.key}'");
      raw.execute('PRAGMA user_version=4');
      raw.close();
      final before = await file.readAsBytes();
      await expectLater(
        EncryptedDatabaseOpener(file, keys).open(),
        throwsA(isA<StateError>()),
      );
      expect(await file.readAsBytes(), before);
    },
  );
  test(
    'v3 inbox SQL enforces plan stamp and event identity without author alias FK',
    () async {
      final db = await EncryptedDatabaseOpener(file, keys).open();
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO sync_inbox VALUES('unknown','p',1,'{\"future\":9007199254740993}')",
      );
      for (final sql in [
        "INSERT INTO sync_inbox VALUES('zero','p',0,'{}')",
        "INSERT INTO sync_inbox VALUES('negative','p',-1,'{}')",
        "INSERT INTO sync_inbox VALUES('other','p',1,'{}')",
        "INSERT INTO sync_inbox VALUES('unknown','p',2,'{}')",
        "INSERT INTO sync_inbox VALUES('foreign','missing',3,'{}')",
      ]) {
        await expectLater(db.customStatement(sql), throwsA(anything));
      }
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(1),
      );
    },
  );
  test(
    'real encrypted v2 upgrades to v3 and retains all original rows across reopen',
    () async {
      final originalKey = keys.key;
      for (var i = 0; i < 2; i++) {
        final db = await EncryptedDatabaseOpener(file, keys).open();
        try {
          expect(
            (await db.customSelect('PRAGMA user_version').get())
                .single
                .data
                .values
                .single,
            3,
          );
          expect(
            await db.customSelect('SELECT * FROM sync_inbox').get(),
            isEmpty,
          );
          expect(
            (await db.customSelect('SELECT * FROM sentinel').get())
                .single
                .data['value'],
            'retained',
          );
          expect(
            (await db.customSelect('SELECT * FROM plans').get())
                .single
                .data['total_budget_cents'],
            9007199254740993,
          );
          expect(
            (await db.customSelect('SELECT * FROM outbox').get())
                .single
                .data['event_id'],
            'e',
          );
          expect(
            (await db.customSelect('SELECT * FROM change_log').get())
                .single
                .data['new_value'],
            '{"amount":9007199254740993}',
          );
          expect(
            (await db.customSelect('SELECT * FROM sync_state').get())
                .single
                .data,
            {
              'device_id': 'd',
              'plan_id': 'p',
              'last_pushed_server_ts': 40,
              'last_pulled_server_ts': 77,
              'device_monotonic': 8,
            },
          );
        } finally {
          await db.close();
        }
      }
      expect(keys.key, originalKey);
    },
  );
}
