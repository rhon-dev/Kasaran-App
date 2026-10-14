import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';

class _KeyStore implements DatabaseKeyStore {
  String? key;
  int writes = 0;
  @override
  Future<String?> read() async => key;
  @override
  Future<void> write(String value) async {
    key = value;
    writes++;
  }
}

Future<void> _plan(AppDatabase db, String id, String member) async {
  await db.customStatement(
    '''
INSERT INTO plans (id,creator_user_id,wedding_date,total_budget_cents,
guest_cap,region_code,ruleset_version,driving_rsvp_status,created_at)
VALUES (?,?,?,?,?,?,?,?,?)''',
    [
      id,
      member,
      '2027-01-01',
      10000,
      2,
      'TEST',
      'fixture-only',
      'pending',
      '2026-10-01T00:00:00Z',
    ],
  );
  await db.customStatement(
    'INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id) VALUES (?,?,?)',
    ['$id-alias', id, member],
  );
}

void main() {
  test(
    'encrypted local core round-trips exact cents, raw log and pending outbox',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasaran-v2-core-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/local.sqlite');
      final keys = _KeyStore();
      final db = await EncryptedDatabaseOpener(file, keys).open();
      await _plan(db, 'plan-a', 'member-a');
      const cents = 9007199254740991;
      await db.customStatement(
        '''
INSERT INTO ledger_entries (id,plan_id,category_code,entry_type,supplier_name,
estimated_cents,pricing_mode,created_at) VALUES (?,?,?,?,?,?,?,?)''',
        [
          'ledger-a',
          'plan-a',
          'catering_venue',
          'standard',
          'Fixture supplier',
          cents,
          'flat',
          '2026-10-01T00:00:00Z',
        ],
      );
      const rawJson =
          '{"unknown":{"unicode":"ñ","veryLarge":9007199254740991}}';
      await db.customStatement(
        '''
INSERT INTO change_log (id,plan_id,entity_type,entity_id,field_name,
schema_version,new_value,device_monotonic,device_id,plan_member_id,created_at)
VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
        [
          'event-a',
          'plan-a',
          'ledger',
          'ledger-a',
          'estimated_cents',
          2,
          rawJson,
          1,
          'device-a',
          'plan-a-alias',
          '2026-10-01T00:00:00Z',
        ],
      );
      await db.customStatement(
        'INSERT INTO outbox (event_id,plan_id,device_id,queued_at) VALUES (?,?,?,?)',
        ['event-a', 'plan-a', 'device-a', '2026-10-01T00:00:00Z'],
      );
      await db.close();
      expect(keys.writes, 1);

      final reopened = await EncryptedDatabaseOpener(file, keys).open();
      addTearDown(reopened.close);
      final ledger = await reopened
          .customSelect('SELECT estimated_cents FROM ledger_entries')
          .get();
      expect(ledger.single.read<int>('estimated_cents'), cents);
      final log = await reopened
          .customSelect('SELECT new_value FROM change_log')
          .get();
      expect(log.single.read<String>('new_value'), rawJson);
      final queue = await reopened
          .customSelect('SELECT event_id,plan_id FROM outbox')
          .get();
      expect(queue.single.read<String>('event_id'), 'event-a');
      expect(queue.single.read<String>('plan_id'), 'plan-a');
    },
  );

  test(
    'local constraints reject foreign alias, invalid mode and negative amounts',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _plan(db, 'plan-a', 'member-a');
      await _plan(db, 'plan-b', 'member-b');
      final fk = await db.customSelect('PRAGMA foreign_keys').get();
      expect(fk.single.read<int>('foreign_keys'), 1);
      await expectLater(
        db.customStatement(
          '''
INSERT INTO change_log (id,plan_id,entity_type,entity_id,field_name,
schema_version,device_monotonic,device_id,plan_member_id,created_at)
VALUES (?,?,?,?,?,?,?,?,?,?)''',
          [
            'bad-event',
            'plan-a',
            'ledger',
            'ledger-a',
            'amount',
            2,
            1,
            'device-a',
            'plan-b-alias',
            '2026-10-01T00:00:00Z',
          ],
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        db.customStatement(
          '''
INSERT INTO ledger_entries (id,plan_id,category_code,entry_type,
supplier_name,estimated_cents,pricing_mode,per_head_rate_cents,created_at)
VALUES (?,?,?,?,?,?,?,?,?)''',
          [
            'bad-mode',
            'plan-a',
            'buffer',
            'standard',
            'Fixture',
            1,
            'flat',
            2,
            '2026-10-01T00:00:00Z',
          ],
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        db.customStatement(
          '''
INSERT INTO ledger_entries (id,plan_id,category_code,entry_type,
supplier_name,estimated_cents,pricing_mode,created_at)
VALUES (?,?,?,?,?,?,?,?)''',
          [
            'bad-negative',
            'plan-a',
            'buffer',
            'standard',
            'Fixture',
            -1,
            'flat',
            '2026-10-01T00:00:00Z',
          ],
        ),
        throwsA(isA<Exception>()),
      );
      final count = await db
          .customSelect('SELECT count(*) AS n FROM ledger_entries')
          .get();
      expect(count.single.read<int>('n'), 0);
    },
  );

  test('local membership rejects a user joining two plans', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _plan(db, 'plan-a', 'member-a');
    await _plan(db, 'plan-b', 'member-b');
    await db.customStatement(
      'INSERT INTO plan_members (plan_id,user_id,plan_member_id,role,joined_at) '
      'VALUES (?,?,?,?,?)',
      ['plan-a', 'member-a', 'plan-a-alias', 'creator', '2026-10-01T00:00:00Z'],
    );
    await db.customStatement(
      'INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id) '
      'VALUES (?,?,?)',
      ['plan-b-alias-a', 'plan-b', 'member-a'],
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO plan_members (plan_id,user_id,plan_member_id,role,joined_at) '
        'VALUES (?,?,?,?,?)',
        [
          'plan-b',
          'member-a',
          'plan-b-alias-a',
          'partner',
          '2026-10-01T00:00:00Z',
        ],
      ),
      throwsA(isA<Exception>()),
    );
    final memberships = await db
        .customSelect('SELECT plan_id FROM plan_members')
        .get();
    expect(memberships.map((row) => row.read<String>('plan_id')), ['plan-a']);
  });

  test('local creator has at most one active plan', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _plan(db, 'plan-a', 'member-a');
    await expectLater(
      _plan(db, 'plan-b', 'member-a'),
      throwsA(isA<Exception>()),
    );
    await db.customStatement(
      "UPDATE plans SET is_active = 0 WHERE id = 'plan-a'",
    );
    await _plan(db, 'plan-c', 'member-a');
    final active = await db
        .customSelect('SELECT id FROM plans WHERE is_active = 1')
        .get();
    expect(active.single.read<String>('id'), 'plan-c');
  });
}
