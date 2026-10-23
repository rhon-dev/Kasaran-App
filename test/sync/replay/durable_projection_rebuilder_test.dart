import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor, Value, QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/sync/replay/durable_projection_rebuilder.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../queue/durable_outbox_pusher_test.dart' as fixture;

const entryId = '10000000-0000-7000-8000-000000000001';
const now = '2026-10-20T00:00:00.000Z';
Map<String, Object?> source() => {
  'id': entryId,
  'plan_id': fixture.actor.planId,
  'category_code': 'buffer',
  'entry_type': 'standard',
  'supplier_name': 'Remote',
  'estimated_cents': 9007199254740993,
  'actual_cents': null,
  'pricing_mode': 'flat',
  'per_head_rate_cents': null,
  'manually_valued': 0,
  'notes': null,
  'template_suggestion_id': null,
  'checklist_item_id': null,
  'created_at': now,
  'deleted_at': null,
};
Map<String, Object?> event(int n, String field, Object? old, Object? value) => {
  'id': '20000000-0000-7000-8000-${n.toString().padLeft(12, '0')}',
  'plan_id': fixture.actor.planId,
  'entity_id': entryId,
  'entity_type': 'ledger_entries',
  'field_name': field,
  'change_group_id': null,
  'schema_version': 1,
  'old_value': old,
  'new_value': value,
  'device_id': fixture.actorB.deviceId,
  'device_monotonic': '$n',
  'plan_member_id': fixture.actorB.planMemberId,
  'created_at': now,
  'server_ts': '$n',
};

class ReadCommitHook extends fixture.CommitHook {
  String? afterSql;
  void Function()? afterRead;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (afterSql != null && statement.contains(afterSql!)) {
      afterSql = null;
      afterRead?.call();
    }
    return result;
  }
}

class CaptureIdentity extends fixture.LocalIdentity {
  CaptureIdentity(super.source);
  void Function()? onCapture;
  @override
  VerifiedSessionSnapshot capture() {
    final snapshot = super.capture();
    onCapture?.call();
    return snapshot;
  }
}

void main() {
  late Directory dir;
  late File file, bFile;
  late fixture.Keys keys, bKeys;
  late fixture.Identity identity;
  late CaptureIdentity local;
  late AccountStoreCoordinator coordinator;
  late AppDatabase db;
  late sqlite.Database native;
  late ReadCommitHook commit;
  late DurableProjectionRebuilder rebuilder;
  late List<String> opened;

  Future<List<Map<String, Object?>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
          .map((r) => r.data)
          .toList();
  Future<Map<String, Object?>> snapshot() async => {
    for (final t in [
      'plans',
      'plan_members',
      'plan_member_aliases',
      'ledger_entries',
      'change_log',
      'outbox',
      'sync_state',
      'sync_inbox',
    ])
      t: await rows(t),
  };
  Future<void> retain(Map<String, Object?> e) => db.customStatement(
    'INSERT INTO sync_inbox(event_id,plan_id,server_ts,raw_event) VALUES(?,?,?,?)',
    [
      e['id'],
      e['plan_id'],
      int.parse(e['server_ts']! as String),
      jsonEncode(e),
    ],
  );
  Future<void> reopen() async {
    await coordinator.close();
    coordinator = AccountStoreCoordinator(
      local,
      (_) async => db = await EncryptedDatabaseOpener(file, keys).open(),
    );
    await coordinator.observeSession();
    rebuilder = DurableProjectionRebuilder(coordinator);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kasaran-projection-');
    file = File('${dir.path}/a.sqlite');
    bFile = File('${dir.path}/b.sqlite');
    keys = fixture.Keys();
    bKeys = fixture.Keys();
    identity = fixture.Identity();
    local = CaptureIdentity(identity);
    final a = await EncryptedDatabaseOpener(file, keys).open();
    await fixture.seed(a, fixture.actor);
    await a.close();
    final b = await EncryptedDatabaseOpener(bFile, bKeys).open();
    await fixture.seed(b, fixture.actorB);
    await b.close();
    commit = ReadCommitHook();
    opened = [];
    coordinator = AccountStoreCoordinator(local, (session) async {
      opened.add(session.userId);
      final isA = session.userId == fixture.actor.userId;
      return db = AppDatabase(
        NativeDatabase(
          isA ? file : bFile,
          setup: (raw) {
            native = raw;
            if (raw.select('PRAGMA cipher').isEmpty) {
              throw StateError('Cipher required');
            }
            raw.execute("PRAGMA key = '${isA ? keys.key! : bKeys.key!}'");
          },
        ).interceptWith(commit),
      );
    });
    await coordinator.observeSession();
    rebuilder = DurableProjectionRebuilder(coordinator);
  });
  tearDown(() async {
    await coordinator.close();
    await dir.delete(recursive: true);
  });

  test(
    'corrupt excluded device metadata cannot hide behind provisional ownership filter',
    () async {
      await retain(event(1, r'$create', null, source()));
      await rebuilder.rebuild(fixture.actor);
      await LocalLedgerWriter(db, identity: local).edit(
        fixture.actor,
        entryId,
        const LedgerEntriesCompanion(notes: Value('pending')),
      );
      await db.customStatement("UPDATE change_log SET device_id='invalid'");
      await db.customStatement("UPDATE outbox SET device_id='invalid'");
      final before = await snapshot();
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(isA<DurableProjectionException>()),
      );
      expect(await snapshot(), before);
    },
  );

  for (final boundary in [
    'FROM plans p',
    'FROM sync_state WHERE',
    'FROM sync_inbox WHERE',
    'FROM change_log WHERE',
    'FROM outbox q LEFT',
    'SELECT 1 FROM change_log',
    'SELECT c.* FROM outbox',
    'SELECT id FROM ledger_entries',
  ]) {
    test(
      'same-user replacement after awaited $boundary rolls back without disclosure',
      () async {
        await retain(event(1, r'$create', null, source()));
        final before = await snapshot();
        var triggered = false;
        commit.afterSql = boundary;
        commit.afterRead = () {
          triggered = true;
          identity.marker = Object();
        };
        await expectLater(
          rebuilder.rebuild(fixture.actor),
          throwsA(isA<DurableProjectionException>()),
        );
        expect(triggered, isTrue);
        expect(await snapshot(), before);
        await coordinator.observeSession();
        expect(await snapshot(), before);
      },
    );
  }

  test(
    'cross-plan primary key collision rolls back partial replacement without touching other plan',
    () async {
      await retain(event(1, r'$create', null, source()));
      await rebuilder.rebuild(fixture.actor);
      await fixture.seed(db, fixture.actorB);
      final otherIdentity = fixture.Identity()..user = fixture.actorB.userId;
      final other = await LocalLedgerWriter(
        db,
        identity: fixture.LocalIdentity(otherIdentity),
      ).create(fixture.actorB, fixture.draft);
      await retain({
        ...event(2, r'$create', null, {...source(), 'id': other.id}),
        'entity_id': other.id,
      });
      final before = await snapshot();
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(isA<DurableProjectionException>()),
      );
      expect(await snapshot(), before);
      await reopen();
      expect(await snapshot(), before);
    },
  );

  for (final difference in ['instant', 'value', 'assigned stamp']) {
    test(
      'acknowledged and inbox changed $difference fails immutable reconciliation',
      () async {
        await LocalLedgerWriter(
          db,
          identity: local,
          utcNow: () => DateTime.parse(now),
        ).create(fixture.actor, fixture.draft);
        final log = (await rows('change_log')).single;
        await db.customStatement('UPDATE change_log SET server_ts=1');
        await db.customStatement('DELETE FROM outbox');
        final wire = {
          ...log,
          'server_ts': difference == 'assigned stamp' ? '2' : '1',
          'device_monotonic': '${log['device_monotonic']}',
          'old_value': jsonDecode(log['old_value']! as String),
          'new_value': jsonDecode(log['new_value']! as String),
        };
        if (difference == 'instant') {
          wire['created_at'] = '2026-10-20T00:00:00.000001Z';
        }
        if (difference == 'value') {
          wire['new_value'] = {
            ...wire['new_value']! as Map<String, Object?>,
            'notes': 'changed',
          };
        }
        await retain(wire);
        final before = await snapshot();
        await expectLater(
          rebuilder.rebuild(fixture.actor),
          throwsA(isA<DurableProjectionException>()),
        );
        expect(await snapshot(), before);
      },
    );
  }

  test(
    'unknown creation cannot authorize deletion of a preexisting projection',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      await db.customStatement('DELETE FROM outbox');
      final log = (await rows('change_log')).single;
      await db.customStatement('DELETE FROM change_log');
      await retain({
        ...log,
        'server_ts': '1',
        'schema_version': 99,
        'device_monotonic': '${log['device_monotonic']}',
        'old_value': jsonDecode(log['old_value']! as String),
        'new_value': jsonDecode(log['new_value']! as String),
      });
      final before = await snapshot();
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(
          isA<DurableProjectionException>().having(
            (e) => e.code,
            'code',
            'incomplete_history',
          ),
        ),
      );
      expect(await snapshot(), before);
    },
  );

  test(
    'session replacement after counted lease completion cannot expose stale result',
    () async {
      await retain(event(1, r'$create', null, source()));
      var captures = 0;
      commit.action = () async {
        local.onCapture = () {
          captures++;
          // First capture checks the transaction result; second is the
          // coordinator readiness check completing its counted work future.
          if (captures == 2) {
            local.onCapture = null;
            identity.marker = Object();
          }
        };
      };
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(isA<DurableProjectionException>()),
      );
      expect(captures, greaterThanOrEqualTo(2));
      await coordinator.observeSession();
      expect((await rows('ledger_entries')).single, source());
    },
  );

  test(
    'accepted matching pending identity is applied once and leaves original queue intact',
    () async {
      final original = await LocalLedgerWriter(
        db,
        identity: local,
        utcNow: () => DateTime.parse(now),
      ).create(fixture.actor, fixture.draft);
      final log = (await rows('change_log')).single;
      await retain({
        ...log,
        'device_monotonic': '${log['device_monotonic']}',
        'server_ts': '1',
        'old_value': jsonDecode(log['old_value']! as String),
        'new_value': jsonDecode(log['new_value']! as String),
        'created_at': '2026-10-20T00:00:00.000000Z',
      });
      final before = await snapshot();
      final result = await rebuilder.rebuild(fixture.actor);
      expect(result.projected, 1);
      expect(
        result.needsAttention,
        isFalse,
      ); // duplicate create would classify attention
      expect((await rows('ledger_entries')).single, original.toJson());
      expect(await snapshot(), before);
    },
  );

  for (final foreign in ['device', 'author']) {
    test(
      'pending other $foreign is not adopted into this actor overlay',
      () async {
        await retain(event(1, r'$create', null, source()));
        await rebuilder.rebuild(fixture.actor);
        await LocalLedgerWriter(db, identity: local).edit(
          fixture.actor,
          entryId,
          const LedgerEntriesCompanion(notes: Value('foreign pending')),
        );
        if (foreign == 'device') {
          await db.customStatement('UPDATE change_log SET device_id=?', [
            fixture.actorB.deviceId,
          ]);
          await db.customStatement('UPDATE outbox SET device_id=?', [
            fixture.actorB.deviceId,
          ]);
        } else {
          await db.customStatement(
            'INSERT INTO plan_member_aliases(plan_member_id,plan_id,user_id) VALUES(?,?,?)',
            [
              fixture.actorB.planMemberId,
              fixture.actor.planId,
              fixture.actorB.userId,
            ],
          );
          await db.customStatement('UPDATE change_log SET plan_member_id=?', [
            fixture.actorB.planMemberId,
          ]);
        }
        final before = await snapshot();
        expect((await rebuilder.rebuild(fixture.actor)).projected, 1);
        expect((await rows('ledger_entries')).single, source());
        for (final t in before.keys.where((t) => t != 'ledger_entries')) {
          expect(await rows(t), before[t]);
        }
      },
    );
  }

  for (final history in ['empty projection', 'complete entity']) {
    test(
      'supported orphan update with $history refuses all publication across encrypted reopen',
      () async {
        if (history == 'complete entity') {
          await retain(event(1, r'$create', null, source()));
          await rebuilder.rebuild(fixture.actor);
          await retain(event(2, 'notes', null, 'must not publish'));
        } else {
          expect(await rows('ledger_entries'), isEmpty);
        }
        await retain({
          ...event(3, 'estimated_cents', 100, 200),
          'entity_id': '10000000-0000-7000-8000-000000000002',
        });
        final before = await snapshot();
        await expectLater(
          rebuilder.rebuild(fixture.actor),
          throwsA(
            isA<DurableProjectionException>().having(
              (e) => e.code,
              'code',
              'incomplete_history',
            ),
          ),
        );
        expect(await snapshot(), before);
        await reopen();
        expect(await snapshot(), before);
      },
    );
  }

  for (final order in [
    [1, 2, 3],
    [1, 3, 2],
    [2, 1, 3],
    [3, 1, 2],
    [2, 3, 1],
    [3, 2, 1],
  ]) {
    test(
      'two-device accepted arrival $order converges after each encrypted reopen',
      () async {
        final events = {
          1: event(1, r'$create', null, source()),
          2: {
            ...event(2, 'notes', null, 'device two'),
            'device_id': fixture.actor.deviceId,
          },
          3: event(3, 'estimated_cents', 9007199254740993, 9007199254740995),
        };
        final arrived = <int>{};
        for (final n in order) {
          await retain(events[n]!);
          arrived.add(n);
          final before = await snapshot();
          if (!arrived.contains(1)) {
            await expectLater(
              rebuilder.rebuild(fixture.actor),
              throwsA(
                isA<DurableProjectionException>().having(
                  (e) => e.code,
                  'code',
                  'incomplete_history',
                ),
              ),
            );
            expect(await snapshot(), before);
          } else {
            final result = await rebuilder.rebuild(fixture.actor);
            expect(result.projected, 1);
            expect(result.needsAttention, isFalse);
            expect((await rows('ledger_entries')).single, {
              ...source(),
              if (arrived.contains(2)) 'notes': 'device two',
              if (arrived.contains(3)) 'estimated_cents': 9007199254740995,
            });
            for (final t in before.keys.where((t) => t != 'ledger_entries')) {
              expect(await rows(t), before[t]);
            }
          }
          final published = await snapshot();
          await reopen();
          expect(await snapshot(), published);
        }
        expect((await rows('ledger_entries')).single, {
          ...source(),
          'notes': 'device two',
          'estimated_cents': 9007199254740995,
        });
        final before = await snapshot();
        await rebuilder.rebuild(fixture.actor);
        expect(await snapshot(), before);
      },
    );
  }

  test(
    'tombstone suppresses ordinary changes and Restore reopens predelete source',
    () async {
      await retain(event(1, r'$create', null, source()));
      await retain(event(2, 'deleted_at', null, now));
      await retain(event(3, 'supplier_name', 'Remote', 'suppressed'));
      final deleted = await rebuilder.rebuild(fixture.actor);
      expect(deleted.needsAttention, isTrue);
      expect((await rows('ledger_entries')).single, {
        ...source(),
        'deleted_at': now,
      });
      await reopen();
      await retain(event(4, 'deleted_at', now, null));
      await retain(event(5, 'notes', null, 'restored'));
      await rebuilder.rebuild(fixture.actor);
      expect((await rows('ledger_entries')).single, {
        ...source(),
        'notes': 'restored',
      });
    },
  );

  for (final unsupported in ['schema', 'entity', 'field']) {
    test(
      'unknown $unsupported orphan remains raw attention without blanket refusal',
      () async {
        await retain({
          ...event(1, 'estimated_cents', 100, 200),
          if (unsupported == 'schema') 'schema_version': 99,
          if (unsupported == 'entity') 'entity_type': 'future_entity',
          if (unsupported == 'field') 'field_name': 'future_field',
        });
        final before = await snapshot();
        final result = await rebuilder.rebuild(fixture.actor);
        expect(result.projected, 0);
        expect(result.needsAttention, isTrue);
        expect(await snapshot(), before);
        await reopen();
        expect(await snapshot(), before);
      },
    );
  }

  test(
    'compatible unknown history is retained exactly and never projected',
    () async {
      await retain({
        ...event(1, r'$create', null, source()),
        'future_envelope': {'exact': 9007199254740993},
      });
      await retain({
        ...event(2, 'future_field', null, {'exact': 9007199254740995}),
        'schema_version': 99,
      });
      final before = await snapshot();
      final result = await rebuilder.rebuild(fixture.actor);
      expect(result.projected, 1);
      expect(result.needsAttention, isTrue);
      expect((await rows('ledger_entries')).single, source());
      expect(await rows('sync_inbox'), before['sync_inbox']);
      await reopen();
      expect(await rows('sync_inbox'), before['sync_inbox']);
    },
  );

  test(
    'other plan projection and every source surface are preserved',
    () async {
      await fixture.seed(db, fixture.actorB);
      final otherIdentity = fixture.Identity()..user = fixture.actorB.userId;
      final other = await LocalLedgerWriter(
        db,
        identity: fixture.LocalIdentity(otherIdentity),
      ).create(fixture.actorB, fixture.draft);
      await retain(event(1, r'$create', null, source()));
      final before = await snapshot();
      await rebuilder.rebuild(fixture.actor);
      expect(await rows('ledger_entries'), contains(equals(other.toJson())));
      for (final t in before.keys.where((t) => t != 'ledger_entries')) {
        expect(await rows(t), before[t]);
      }
    },
  );

  for (final corruption in [
    'raw JSON',
    'inbox id',
    'stamp',
    'queue device',
    'local JSON',
    'local counter',
  ]) {
    test(
      '$corruption corruption rejects with safe metadata and all-surface rollback',
      () async {
        await retain(event(1, r'$create', null, source()));
        await rebuilder.rebuild(fixture.actor);
        await LocalLedgerWriter(db, identity: local).edit(
          fixture.actor,
          entryId,
          const LedgerEntriesCompanion(notes: Value('private source')),
        );
        switch (corruption) {
          case 'raw JSON':
            await db.customStatement(
              "UPDATE sync_inbox SET raw_event='private not JSON'",
            );
          case 'inbox id':
            await db.customStatement("UPDATE sync_inbox SET event_id='wrong'");
          case 'stamp':
            await db.customStatement('UPDATE sync_inbox SET server_ts=2');
          case 'queue device':
            await db.customStatement('UPDATE outbox SET device_id=?', [
              fixture.actorB.deviceId,
            ]);
          case 'local JSON':
            await db.customStatement(
              "UPDATE change_log SET new_value='private not JSON'",
            );
          case 'local counter':
            await db.customStatement(
              'UPDATE change_log SET device_monotonic=1.5',
            );
        }
        final before = await snapshot();
        Object? error;
        try {
          await rebuilder.rebuild(fixture.actor);
        } catch (e) {
          error = e;
        }
        expect(error, isA<DurableProjectionException>());
        expect('$error', isNot(contains('private')));
        expect(await snapshot(), before);
        await reopen();
        expect(await snapshot(), before);
      },
    );
  }

  for (final refusal in ['member', 'alias', 'plan', 'actor', 'device']) {
    test(
      '$refusal refusal preserves prior projection and raw history',
      () async {
        await retain(event(1, r'$create', null, source()));
        await rebuilder.rebuild(fixture.actor);
        if (refusal == 'member') {
          await db.customStatement('DELETE FROM plan_members');
        }
        if (refusal == 'plan') {
          await db.customStatement('UPDATE plans SET is_active=0');
        }
        if (refusal == 'alias') {
          await db.customStatement('PRAGMA foreign_keys=OFF');
          await db.customStatement(
            'UPDATE plan_member_aliases SET user_id=NULL',
          );
          await db.customStatement('PRAGMA foreign_keys=ON');
        }
        final before = await snapshot();
        const a = fixture.actor;
        final requested = LedgerActor(
          planId: a.planId,
          userId: refusal == 'actor' ? fixture.actorB.userId : a.userId,
          planMemberId: a.planMemberId,
          deviceId: refusal == 'device' ? 'invalid' : a.deviceId,
        );
        await expectLater(
          rebuilder.rebuild(requested),
          throwsA(isA<DurableProjectionException>()),
        );
        expect(await snapshot(), before);
      },
    );
  }

  test(
    'native COMMIT rejection preserves all surfaces after encrypted reopen',
    () async {
      await retain(event(1, r'$create', null, source()));
      await rebuilder.rebuild(fixture.actor);
      await retain(event(2, 'notes', null, 'not yet published'));
      final before = await snapshot();
      var rejected = 0;
      native.commitFilter = () {
        if (rejected == 0) {
          rejected++;
          return false;
        }
        return true;
      };
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(isA<DurableProjectionException>()),
      );
      expect(rejected, 1);
      await reopen();
      expect(await snapshot(), before);
      expect((await rebuilder.rebuild(fixture.actor)).projected, 1);
      expect(
        (await rows('ledger_entries')).single['notes'],
        'not yet published',
      );
    },
  );

  for (final mode in [
    'external observation',
    'app transition',
    'same-user replacement',
    'A-B-A',
  ]) {
    test(
      '$mode drains actual COMMIT in original account with no stale result',
      () async {
        await retain(event(1, r'$create', null, source()));
        final entered = Completer<void>(), release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        commit.action = () async {
          entered.complete();
          await release.future;
        };
        final rebuilding = rebuilder.rebuild(fixture.actor);
        await entered.future.timeout(const Duration(seconds: 5));
        var authCalled = false;
        final Future<void> transition;
        if (mode == 'app transition') {
          transition = coordinator.transition(() async {
            authCalled = true;
            identity.user = fixture.actorB.userId;
            identity.marker = Object();
          });
        } else if (mode == 'A-B-A') {
          identity.user = fixture.actorB.userId;
          identity.marker = Object();
          unawaited(coordinator.observeSession());
          identity.user = fixture.actor.userId;
          identity.marker = Object();
          transition = coordinator.observeSession();
        } else {
          if (mode != 'same-user replacement') {
            identity.user = fixture.actorB.userId;
          }
          identity.marker = Object();
          transition = coordinator.observeSession();
        }
        expect(coordinator.isReady, isFalse);
        expect(opened, [fixture.actor.userId]);
        expect(authCalled, isFalse);
        await expectLater(
          rebuilder.rebuild(fixture.actorB),
          throwsA(isA<DurableProjectionException>()),
        );
        release.complete();
        await expectLater(
          rebuilding,
          throwsA(isA<DurableProjectionException>()),
        );
        await transition;
        if (mode == 'same-user replacement' || mode == 'A-B-A') {
          expect((await rows('ledger_entries')).single, source());
        } else {
          expect(await rows('ledger_entries'), isEmpty);
          expect(await rows('sync_inbox'), isEmpty);
          await coordinator.close();
          final a = await EncryptedDatabaseOpener(file, keys).open();
          try {
            expect(
              (await a.customSelect('SELECT * FROM ledger_entries').get())
                  .single
                  .data,
              source(),
            );
            expect(
              await a.customSelect('SELECT * FROM sync_inbox').get(),
              hasLength(1),
            );
          } finally {
            await a.close();
          }
        }
      },
    );
  }

  test(
    'concurrent writer waits through rebuild COMMIT and its queued edit survives later replay',
    () async {
      await retain(event(1, r'$create', null, source()));
      final entered = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      commit.action = () async {
        entered.complete();
        await release.future;
      };
      final rebuilding = rebuilder.rebuild(fixture.actor);
      await entered.future.timeout(const Duration(seconds: 5));
      var completed = false;
      final writing = coordinator
          .withAccount(
            (lease) => lease.run(
              (leased) => LocalLedgerWriter(leased, identity: local).edit(
                fixture.actor,
                entryId,
                const LedgerEntriesCompanion(notes: Value('serialized')),
              ),
            ),
          )
          .then((r) {
            completed = true;
            return r;
          });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      release.complete();
      await rebuilding;
      await writing;
      expect((await rows('ledger_entries')).single['notes'], 'serialized');
      expect(await rows('outbox'), hasLength(1));
      final before = await snapshot();
      await rebuilder.rebuild(fixture.actor);
      expect(await snapshot(), before);
    },
  );

  test(
    'unacknowledged original missing its queue cannot silently disappear',
    () async {
      await retain(event(1, r'$create', null, source()));
      await rebuilder.rebuild(fixture.actor);
      await LocalLedgerWriter(db, identity: local).edit(
        fixture.actor,
        entryId,
        const LedgerEntriesCompanion(notes: Value('pending source')),
      );
      await db.customStatement('DELETE FROM outbox');
      final before = await snapshot();
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(
          isA<DurableProjectionException>().having(
            (e) => e.code,
            'code',
            'invalid_queue',
          ),
        ),
      );
      expect(await snapshot(), before);
    },
  );

  test('invalid persisted watermark refuses even an empty rebuild', () async {
    await db.customStatement(
      'INSERT INTO sync_state(device_id,plan_id,last_pulled_server_ts) VALUES(?,?,?)',
      [fixture.actor.deviceId, fixture.actor.planId, -1],
    );
    final before = await snapshot();
    await expectLater(
      rebuilder.rebuild(fixture.actor),
      throwsA(
        isA<DurableProjectionException>().having(
          (e) => e.code,
          'code',
          'invalid_sync_state',
        ),
      ),
    );
    expect(await snapshot(), before);
  });

  test('invalid queue time is refused without hiding its original', () async {
    await LocalLedgerWriter(
      db,
      identity: local,
    ).create(fixture.actor, fixture.draft);
    await db.customStatement(
      "UPDATE outbox SET queued_at='private-invalid-time'",
    );
    final before = await snapshot();
    await expectLater(
      rebuilder.rebuild(fixture.actor),
      throwsA(
        isA<DurableProjectionException>().having(
          (e) => e.code,
          'code',
          'invalid_queue',
        ),
      ),
    );
    expect(await snapshot(), before);
  });

  test(
    'pending counter state cannot be missing or behind its retained original',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      for (final mode in ['behind', 'missing']) {
        if (mode == 'behind') {
          await db.customStatement('UPDATE sync_state SET device_monotonic=0');
        } else {
          await db.customStatement('DELETE FROM sync_state');
        }
        final before = await snapshot();
        await expectLater(
          rebuilder.rebuild(fixture.actor),
          throwsA(
            isA<DurableProjectionException>().having(
              (e) => e.code,
              'code',
              'invalid_sync_state',
            ),
          ),
        );
        expect(await snapshot(), before);
      }
    },
  );

  test(
    'dangling queue fails safely rather than disappearing through a join',
    () async {
      await db.customStatement('PRAGMA foreign_keys=OFF');
      await db.customStatement(
        'INSERT INTO outbox(event_id,plan_id,device_id,queued_at) VALUES(?,?,?,?)',
        [
          '20000000-0000-7000-8000-000000000099',
          fixture.actor.planId,
          fixture.actor.deviceId,
          now,
        ],
      );
      await db.customStatement('PRAGMA foreign_keys=ON');
      final before = await snapshot();
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(
          isA<DurableProjectionException>().having(
            (e) => e.code,
            'code',
            'invalid_queue',
          ),
        ),
      );
      expect(await snapshot(), before);
    },
  );

  test(
    'invalid reduced source rejects publication with all-surface rollback and reopen',
    () async {
      await retain(event(1, r'$create', null, source()));
      await rebuilder.rebuild(fixture.actor);
      await retain(event(2, 'estimated_cents', 9007199254740993, -1));
      final before = await snapshot();
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(
          isA<DurableProjectionException>().having(
            (e) => e.code,
            'code',
            'invalid_projection',
          ),
        ),
      );
      expect(await snapshot(), before);
      await reopen();
      expect(await snapshot(), before);
    },
  );

  test(
    'uncovered existing projection fails closed instead of deleting retained state',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      await db.customStatement('DELETE FROM outbox');
      await db.customStatement('DELETE FROM change_log');
      final before = await snapshot();
      await expectLater(
        rebuilder.rebuild(fixture.actor),
        throwsA(
          isA<DurableProjectionException>().having(
            (e) => e.code,
            'code',
            'incomplete_history',
          ),
        ),
      );
      expect(await snapshot(), before);
    },
  );

  test(
    'acknowledged originals merge with padded inbox without duplicate application',
    () async {
      final original = await LocalLedgerWriter(
        db,
        identity: local,
        utcNow: () => DateTime.parse(now),
      ).create(fixture.actor, fixture.draft);
      final log = (await rows('change_log')).single;
      await db.customStatement('UPDATE change_log SET server_ts=7');
      await db.customStatement('DELETE FROM outbox');
      final before = await snapshot();
      expect((await rebuilder.rebuild(fixture.actor)).projected, 1);
      expect((await rows('ledger_entries')).single, original.toJson());
      expect(await snapshot(), before);
      final wire = {
        ...log,
        'server_ts': '7',
        'device_monotonic': '${log['device_monotonic']}',
        'old_value': jsonDecode(log['old_value']! as String),
        'new_value': jsonDecode(log['new_value']! as String),
      };
      final created = wire['created_at']! as String;
      wire['created_at'] = '${created.substring(0, created.length - 1)}000Z';
      await retain(wire);
      final retained = await snapshot();
      final result = await rebuilder.rebuild(fixture.actor);
      expect(result.projected, 1);
      expect(result.needsAttention, isFalse);
      expect(await snapshot(), retained);
    },
  );

  test(
    'matching pending original overlays without mutating queue or counter',
    () async {
      final original = await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      final before = await snapshot();
      final result = await rebuilder.rebuild(fixture.actor);
      expect(result.projected, 1);
      expect((await rows('ledger_entries')).single, original.toJson());
      expect(await snapshot(), before);
      await reopen();
      expect((await rebuilder.rebuild(fixture.actor)).projected, 1);
      expect(await snapshot(), before);
    },
  );

  test(
    'accepted remote create persists exact source without inventing aliases across reopen',
    () async {
      await retain(event(1, r'$create', null, source()));
      final before = await snapshot();
      final result = await rebuilder.rebuild(fixture.actor);
      expect(result.projected, 1);
      expect(result.needsAttention, isFalse);
      expect((await rows('ledger_entries')).single, source());
      for (final t in before.keys.where((t) => t != 'ledger_entries')) {
        expect(await rows(t), before[t]);
      }
      await reopen();
      expect((await rows('ledger_entries')).single, source());
      expect((await rebuilder.rebuild(fixture.actor)).projected, 1);
    },
  );
}
