import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';

class _Keys implements DatabaseKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async => value = key;
}

const actor = LedgerActor(
  planId: 'plan-a',
  userId: 'user-a',
  planMemberId: 'alias-a',
  deviceId: 'device-a',
);
const draft = LedgerDraft(
  categoryCode: 'buffer',
  entryType: 'standard',
  supplierName: 'Supplier',
  pricingMode: 'flat',
  estimatedCents: 9007199254740991,
);

Future<void> seed(AppDatabase db) async {
  await db.customStatement(
    '''
INSERT INTO plans
(id,creator_user_id,wedding_date,total_budget_cents,guest_cap,region_code,
 ruleset_version,driving_rsvp_status,created_at)
VALUES (?,?,?,?,?,?,?,?,?)''',
    [
      'plan-a',
      'user-a',
      '2027-01-01',
      10000,
      2,
      'TEST',
      'fixture',
      'pending',
      '2026-10-01T00:00:00Z',
    ],
  );
  await db.customStatement(
    'INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id) VALUES (?,?,?)',
    ['alias-a', 'plan-a', 'user-a'],
  );
  await db.customStatement(
    'INSERT INTO plan_members (plan_id,user_id,plan_member_id,role,joined_at) VALUES (?,?,?,?,?)',
    ['plan-a', 'user-a', 'alias-a', 'creator', '2026-10-01T00:00:00Z'],
  );
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Unexpected HTTP client');
}

void main() {
  test(
    'create persists typed full snapshot, event, queue and counter across encrypted reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasaran-ledger-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/local.sqlite');
      final keys = _Keys();
      final db = await EncryptedDatabaseOpener(file, keys).open();
      await seed(db);
      var next = 0;
      String id() =>
          '01938000-0000-7000-8000-${(++next).toRadixString(16).padLeft(12, '0')}';
      final repository = LedgerRepository(
        db,
        writer: LocalLedgerWriter(
          db,
          newId: id,
          utcNow: () => DateTime.utc(2026, 10, 14),
        ),
      );
      final entry = await repository.create(actor, draft);
      expect(entry.estimatedCents, 9007199254740991);
      expect(entry.id, startsWith('01938000-0000-7000-8000-'));
      expect((await repository.listLive('plan-a')).single.id, entry.id);
      await db.close();

      final reopened = await EncryptedDatabaseOpener(file, keys).open();
      addTearDown(reopened.close);
      expect(
        (await LedgerRepository(
          reopened,
        ).listLive('plan-a')).single.estimatedCents,
        9007199254740991,
      );
      final events = await reopened
          .customSelect('SELECT * FROM change_log')
          .get();
      expect(events, hasLength(1));
      expect(events.single.read<String>('field_name'), r'$create');
      expect(events.single.read<int>('schema_version'), 1);
      expect(events.single.read<int>('device_monotonic'), 1);
      expect(events.single.readNullable<int>('server_ts'), isNull);
      expect(jsonDecode(events.single.read<String>('old_value')), isNull);
      final snapshot =
          jsonDecode(events.single.read<String>('new_value'))
              as Map<String, dynamic>;
      expect(snapshot['estimated_cents'], 9007199254740991);
      expect(snapshot['per_head_rate_cents'], isNull);
      expect(snapshot['id'], entry.id);
      final queued = await reopened
          .customSelect('SELECT event_id FROM outbox')
          .get();
      expect(
        queued.single.read<String>('event_id'),
        events.single.read<String>('id'),
      );
      final counter = await reopened
          .customSelect('SELECT device_monotonic FROM sync_state')
          .get();
      expect(counter.single.read<int>('device_monotonic'), 1);
    },
  );

  test(
    'independent edits, grouped pricing and tombstone persist without no-op events',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);
      var serial = 0;
      String id() =>
          '01938000-0000-7000-8000-${(++serial).toRadixString(16).padLeft(12, '0')}';
      final repo = LedgerRepository(
        db,
        writer: LocalLedgerWriter(
          db,
          newId: id,
          utcNow: () => DateTime.utc(2026, 10, 14),
        ),
      );
      final created = await repo.create(actor, draft);
      await repo.edit(
        actor,
        created.id,
        const LedgerEntriesCompanion(
          supplierName: Value('Another'),
          notes: Value('typed note'),
          actualCents: Value(42),
        ),
      );
      await repo.edit(
        actor,
        created.id,
        const LedgerEntriesCompanion(supplierName: Value('Another')),
      );
      await repo.edit(
        actor,
        created.id,
        const LedgerEntriesCompanion(
          pricingMode: Value('per_head'),
          estimatedCents: Value(null),
          perHeadRateCents: Value(17),
          notes: Value(null),
        ),
      );
      final current = (await repo.listLive('plan-a')).single;
      expect(current.pricingMode, 'per_head');
      expect(current.perHeadRateCents, 17);
      expect(current.estimatedCents, isNull);
      expect(current.notes, isNull);
      final events = await db
          .customSelect('SELECT * FROM change_log ORDER BY device_monotonic')
          .get();
      expect(events.map((e) => e.read<String>('field_name')), [
        r'$create',
        'supplier_name',
        'actual_cents',
        'notes',
        'estimated_cents',
        'notes',
        'pricing_mode',
      ]);
      final group = events.last;
      expect(group.read<String>('change_group_id'), isNotEmpty);
      expect(jsonDecode(group.read<String>('old_value')), {
        'pricing_mode': 'flat',
        'per_head_rate_cents': null,
      });
      expect(jsonDecode(group.read<String>('new_value')), {
        'pricing_mode': 'per_head',
        'per_head_rate_cents': 17,
      });
      expect(jsonDecode(events[5].read<String>('new_value')), isNull);
      expect(events.map((e) => e.read<int>('device_monotonic')), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
      await repo.delete(actor, created.id);
      await repo.delete(actor, created.id);
      expect(await repo.listLive('plan-a'), isEmpty);
      expect(
        (await db.select(db.ledgerEntries).get()).single.deletedAt,
        isNotNull,
      );
      final remaining = await db
          .customSelect('SELECT * FROM change_log ORDER BY device_monotonic')
          .get();
      expect(remaining, hasLength(8));
      expect(remaining.last.read<String>('field_name'), 'deleted_at');
      expect(jsonDecode(remaining.last.read<String>('old_value')), isNull);
      expect(
        jsonDecode(remaining.last.read<String>('new_value')),
        '2026-10-14T00:00:00.000Z',
      );
      await expectLater(
        repo.edit(
          actor,
          created.id,
          const LedgerEntriesCompanion(notes: Value('resurrect')),
        ),
        throwsStateError,
      );
    },
  );

  test('late duplicate event ID rolls back projection and counter', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seed(db);
    final ids = [1, 2, 3, 2].iterator;
    String id() {
      ids.moveNext();
      return '01938000-0000-7000-8000-${ids.current.toRadixString(16).padLeft(12, '0')}';
    }

    final repo = LedgerRepository(db, writer: LocalLedgerWriter(db, newId: id));
    await repo.create(actor, draft);
    await expectLater(repo.create(actor, draft), throwsA(isA<Exception>()));
    expect(await repo.listLive('plan-a'), hasLength(1));
    expect(
      await db.customSelect('SELECT * FROM change_log').get(),
      hasLength(1),
    );
    expect(await db.customSelect('SELECT * FROM outbox').get(), hasLength(1));
    final counter = await db
        .customSelect('SELECT device_monotonic FROM sync_state')
        .get();
    expect(counter.single.read<int>('device_monotonic'), 1);
  });

  test(
    'late collision in a multi-field edit rolls back earlier event and projection',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);
      final ids = [1, 2, 3, 2].iterator;
      String id() {
        ids.moveNext();
        return '01938000-0000-7000-8000-${ids.current.toRadixString(16).padLeft(12, '0')}';
      }

      final repo = LedgerRepository(
        db,
        writer: LocalLedgerWriter(db, newId: id),
      );
      final before = await repo.create(actor, draft);
      await expectLater(
        repo.edit(
          actor,
          before.id,
          const LedgerEntriesCompanion(
            supplierName: Value('Changed'),
            notes: Value('also changed'),
          ),
        ),
        throwsA(isA<Exception>()),
      );
      expect((await repo.listLive('plan-a')).single, before);
      expect(
        await db.customSelect('SELECT * FROM change_log').get(),
        hasLength(1),
      );
      expect(await db.customSelect('SELECT * FROM outbox').get(), hasLength(1));
      expect(
        (await db.customSelect('SELECT device_monotonic FROM sync_state').get())
            .single
            .read<int>('device_monotonic'),
        1,
      );
    },
  );

  test(
    'foreign plan, revoked membership and invalid source reject without writes',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);
      final repo = LedgerRepository(db);
      await expectLater(
        repo.create(
          const LedgerActor(
            planId: 'other',
            userId: 'user-a',
            planMemberId: 'alias-a',
            deviceId: 'device-a',
          ),
          draft,
        ),
        throwsStateError,
      );
      await expectLater(
        repo.create(
          actor,
          const LedgerDraft(
            categoryCode: 'invalid',
            entryType: 'standard',
            supplierName: 'Supplier',
            pricingMode: 'flat',
            estimatedCents: 1,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.create(
          actor,
          const LedgerDraft(
            categoryCode: 'buffer',
            entryType: 'standard',
            supplierName: ' ',
            pricingMode: 'per_head',
            estimatedCents: 1,
          ),
        ),
        throwsArgumentError,
      );
      await db.customStatement(
        "DELETE FROM plan_members WHERE user_id='user-a'",
      );
      await expectLater(repo.create(actor, draft), throwsStateError);
      expect(await db.select(db.ledgerEntries).get(), isEmpty);
      expect(await db.customSelect('SELECT * FROM sync_state').get(), isEmpty);
    },
  );

  test(
    'offline encrypted reopen and write never construct an HTTP client',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasaran-ledger-offline-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/local.sqlite');
      final keys = _Keys();
      await HttpOverrides.runZoned(() async {
        final db = await EncryptedDatabaseOpener(file, keys).open();
        await seed(db);
        final created = await LedgerRepository(db).create(actor, draft);
        await db.close();
        final reopened = await EncryptedDatabaseOpener(file, keys).open();
        expect(
          (await LedgerRepository(reopened).listLive('plan-a')).single.id,
          created.id,
        );
        await LedgerRepository(reopened).delete(actor, created.id);
        await reopened.close();
      }, createHttpClient: _NoNetwork().createHttpClient);
    },
  );

  test(
    'cross-plan edit/delete, invalid patch and exhausted counter leave state intact',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);
      await db.customStatement(
        '''
INSERT INTO plans
      (id,creator_user_id,wedding_date,total_budget_cents,guest_cap,region_code,
       ruleset_version,driving_rsvp_status,created_at)
      VALUES (?,?,?,?,?,?,?,?,?)''',
        [
          'plan-b',
          'user-b',
          '2027-01-01',
          10000,
          2,
          'TEST',
          'fixture',
          'pending',
          '2026-10-01T00:00:00Z',
        ],
      );
      await db.customStatement(
        '''
INSERT INTO plan_member_aliases
      (plan_member_id,plan_id,user_id) VALUES (?,?,?)''',
        ['alias-b', 'plan-b', 'user-b'],
      );
      await db.customStatement(
        '''
INSERT INTO plan_members
      (plan_id,user_id,plan_member_id,role,joined_at) VALUES (?,?,?,?,?)''',
        ['plan-b', 'user-b', 'alias-b', 'creator', '2026-10-01T00:00:00Z'],
      );
      final repo = LedgerRepository(db);
      final row = await repo.create(actor, draft);
      const foreign = LedgerActor(
        planId: 'plan-b',
        userId: 'user-b',
        planMemberId: 'alias-b',
        deviceId: 'device-b',
      );
      await expectLater(
        repo.edit(
          foreign,
          row.id,
          const LedgerEntriesCompanion(notes: Value('wrong')),
        ),
        throwsStateError,
      );
      await expectLater(repo.delete(foreign, row.id), throwsStateError);
      await expectLater(
        repo.edit(
          actor,
          row.id,
          const LedgerEntriesCompanion(manuallyValued: Value(2)),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.edit(
          actor,
          row.id,
          const LedgerEntriesCompanion(supplierName: Value(' ')),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.edit(
          actor,
          row.id,
          const LedgerEntriesCompanion(planId: Value('plan-b')),
        ),
        throwsArgumentError,
      );
      await db.customStatement(
        '''UPDATE sync_state SET device_monotonic=?''',
        [9223372036854775807],
      );
      await expectLater(
        repo.edit(
          actor,
          row.id,
          const LedgerEntriesCompanion(notes: Value('too late')),
        ),
        throwsStateError,
      );
      expect((await repo.listLive('plan-a')).single, row);
      expect(
        await db.customSelect('SELECT * FROM change_log').get(),
        hasLength(1),
      );
      expect(await db.customSelect('SELECT * FROM outbox').get(), hasLength(1));
      expect(
        (await db.customSelect('SELECT device_monotonic FROM sync_state').get())
            .single
            .read<int>('device_monotonic'),
        9223372036854775807,
      );
    },
  );
}
