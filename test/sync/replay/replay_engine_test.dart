import 'dart:convert';

import 'package:kasaran/sync/replay/replay_engine.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:test/test.dart';

const plan = '10000000-0000-4000-8000-000000000001';
const device = '20000000-0000-4000-8000-000000000001';
const member = '30000000-0000-4000-8000-000000000001';
const entry = '40000000-0000-7000-8000-000000000001';
const now = '2026-10-20T00:00:00.000Z';

Map<String, Object?> snapshot() => {
  'id': entry,
  'plan_id': plan,
  'category_code': 'catering_venue',
  'entry_type': 'standard',
  'supplier_name': 'Synthetic supplier',
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

SyncEvent event(
  int n,
  String field,
  Object? oldValue,
  Object? newValue, {
  int? stamp,
  int? counter,
  String deviceId = device,
  String entityType = 'ledger_entries',
  int schema = 1,
  String? group,
  String created = now,
}) => SyncEvent.fromJson({
  'id': '50000000-0000-7000-8000-${n.toString().padLeft(12, '0')}',
  'plan_id': plan,
  'entity_type': entityType,
  'entity_id': entry,
  'field_name': field,
  'change_group_id': group,
  'schema_version': schema,
  'old_value': oldValue,
  'new_value': newValue,
  'device_monotonic': (counter ?? n).toString(),
  'device_id': deviceId,
  'plan_member_id': member,
  'created_at': created,
  if (stamp != null) 'server_ts': stamp.toString(),
}, requireServerTimestamp: stamp != null);

void main() {
  test(
    'legacy padding exception keeps all other source and stamp identity strict',
    () {
      final pending = event(1, r'$create', null, snapshot());
      final local = event(1, r'$create', null, snapshot(), stamp: 42);
      const normalized = '2026-10-20T00:00:00.000000Z';
      for (final difference in <Map<String, Object?>>[
        {'created_at': '2026-10-20T00:00:00.000001Z'},
        {'created_at': '2026-10-20T00:00:00.001000Z'},
        {'created_at': '2026-10-20T00:00:01.000000Z'},
        {'created_at': '2026-10-20T00:00:00.00Z'},
        {
          'new_value': {...snapshot(), 'notes': 'changed'},
        },
        {'old_value': 'changed'},
        {'future_source': true},
        {'device_monotonic': '2'},
      ]) {
        final changed = SyncEvent.fromJson({
          ...local.data,
          'created_at': normalized,
          ...difference,
        }, requireServerTimestamp: true);
        for (final order in [
          [local, changed],
          [changed, local],
        ]) {
          expect(
            () => ReplayEngine.rebuild(order),
            throwsA(isA<ReplayException>()),
          );
        }
        expect(
          () => ReplayEngine.rebuild([changed], provisional: [pending]),
          throwsA(isA<ReplayException>()),
        );
      }
      for (final difference in <Map<String, Object?>>[
        {'server_ts': '43'},
        {'actor_user_id': member},
      ]) {
        final changed = SyncEvent.fromJson({
          ...local.data,
          'created_at': normalized,
          ...difference,
        }, requireServerTimestamp: true);
        expect(
          () => ReplayEngine.rebuild([local, changed]),
          throwsA(isA<ReplayException>()),
        );
      }
      final paddedPending = SyncEvent.fromJson({
        ...pending.data,
        'created_at': normalized,
      });
      expect(
        () => ReplayEngine.rebuild([], provisional: [pending, paddedPending]),
        throwsA(isA<ReplayException>()),
      );
    },
  );

  test(
    'legacy reconciliation retains every raw envelope in deterministic order',
    () {
      final pending = event(1, r'$create', null, snapshot());
      final local = event(1, r'$create', null, snapshot(), stamp: 42);
      final pulled = SyncEvent.fromJson({
        ...local.data,
        'created_at': '2026-10-20T00:00:00.000000Z',
      }, requireServerTimestamp: true);
      final a = ReplayEngine.rebuild([local, pulled], provisional: [pending]);
      final b = ReplayEngine.rebuild(
        [pulled, local, pulled],
        provisional: [pending, pending],
      );
      expect(
        a.retainedEnvelopes.map((row) => row.data),
        unorderedEquals([pending.data, local.data, pulled.data]),
      );
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
      expect(
        a.retainedEnvelopes.map((row) => row.data).toList(),
        b.retainedEnvelopes.map((row) => row.data).toList(),
      );
      expect(a.retainedEnvelopes.clear, throwsUnsupportedError);
      expect(pulled.data['created_at'], '2026-10-20T00:00:00.000000Z');
      expect(pending.data.containsKey('server_ts'), isFalse);
    },
  );

  test(
    'legacy SQL pull reconciles still-pending source without inventing stamp',
    () {
      final pending = event(1, r'$create', null, snapshot());
      final pulled = SyncEvent.fromJson({
        ...pending.data,
        'server_ts': '42',
        'created_at': '2026-10-20T00:00:00.000000Z',
      }, requireServerTimestamp: true);
      final result = ReplayEngine.rebuild([pulled], provisional: [pending]);
      expect(result.records.single, same(pulled));
      expect(result.provisionalEventIds, isEmpty);
      expect(result.ledgerEntries[entry]!.toJson(), snapshot());
    },
  );

  test('legacy SQL six-digit pull reconciles acknowledged local source', () {
    final local = event(1, r'$create', null, snapshot(), stamp: 1);
    final pulled = SyncEvent.fromJson({
      ...local.data,
      'created_at': '2026-10-20T00:00:00.000000Z',
    }, requireServerTimestamp: true);
    final forward = ReplayEngine.rebuild([local, pulled]);
    final reverse = ReplayEngine.rebuild([pulled, local]);
    expect(forward.records.single.data, local.data);
    expect(jsonEncode(forward.toJson()), jsonEncode(reverse.toJson()));
  });

  test(
    'alternate arrival permutations and 100 rebuilds are byte-equivalent',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final notes = event(2, 'notes', null, 'later null', stamp: 2);
      final clear = event(3, 'notes', 'later null', null, stamp: 3);
      final unknown = event(4, 'future_field', null, {
        'raw': [null, 9007199254740993],
      }, stamp: 4);
      final rows = [create, notes, clear, unknown];
      final expected = jsonEncode(ReplayEngine.rebuild(rows).toJson());
      Iterable<List<SyncEvent>> permutations(List<SyncEvent> source) sync* {
        if (source.isEmpty) {
          yield [];
          return;
        }
        for (var i = 0; i < source.length; i++) {
          final rest = [...source]..removeAt(i);
          for (final tail in permutations(rest)) {
            yield [source[i], ...tail];
          }
        }
      }

      final arrivals = permutations(rows).toList();
      expect(arrivals, hasLength(24));
      for (var run = 0; run < 100; run++) {
        final arrival = arrivals[run % arrivals.length];
        final result = ReplayEngine.rebuild([...arrival, ...arrival]);
        expect(jsonEncode(result.toJson()), expected);
        expect(result.ledgerEntries[entry]!.notes, isNull);
        expect(result.conflicts, isEmpty);
        expect(result.unknownRecords.single.data, unknown.data);
        expect(result.records.clear, throwsUnsupportedError);
        expect(result.issues.clear, throwsUnsupportedError);
        expect(result.conflicts.clear, throwsUnsupportedError);
        expect(result.unknownRecords.clear, throwsUnsupportedError);
        expect(
          result.ledgerEntries[entry]!.sourceConstraints.clear,
          throwsUnsupportedError,
        );
      }
    },
  );

  test(
    'server envelope is excluded only for accepted-to-provisional identity matching',
    () {
      final pending = event(1, r'$create', null, snapshot());
      final accepted = SyncEvent.fromJson({
        ...pending.data,
        'server_ts': '99',
        'actor_user_id': member,
      }, requireServerTimestamp: true);
      final result = ReplayEngine.rebuild([accepted], provisional: [pending]);
      expect(result.records.single, same(accepted));
      expect(result.provisionalEventIds, isEmpty);
      final changedStamp = SyncEvent.fromJson({
        ...accepted.data,
        'server_ts': '100',
      }, requireServerTimestamp: true);
      expect(
        () => ReplayEngine.rebuild([accepted, changedStamp]),
        throwsA(isA<ReplayException>()),
      );
      final changedExtra = SyncEvent.fromJson({
        ...accepted.data,
        'future_envelope': true,
      }, requireServerTimestamp: true);
      expect(
        () => ReplayEngine.rebuild([changedExtra], provisional: [pending]),
        throwsA(isA<ReplayException>()),
      );
      expect(ReplayEngine.rebuild([]).needsAttention, isFalse);
      expect(
        ReplayEngine.rebuild(
          [],
          provisional: [pending],
        ).ledgerEntries[entry]!.toJson(),
        snapshot(),
      );
    },
  );

  test(
    'per-head actual requires explicit manual flag without fabricating a derived estimate',
    () {
      final head = {
        ...snapshot(),
        'pricing_mode': 'per_head',
        'estimated_cents': null,
        'per_head_rate_cents': 100,
      };
      final create = event(1, r'$create', null, head, stamp: 1);
      final setActual = event(2, 'actual_cents', null, 900, stamp: 2);
      final incomplete = ReplayEngine.rebuild([create, setActual]);
      expect(incomplete.ledgerEntries[entry]!.isSourceValid, isFalse);
      expect(incomplete.ledgerEntries[entry]!.actualCents, 900);
      expect(incomplete.ledgerEntries[entry]!.estimatedCents, isNull);
      expect(
        incomplete.ledgerEntries[entry]!.sourceConstraints.map((c) => c.name),
        ['manualActualCoherence'],
      );
      final markManual = event(3, 'manually_valued', 0, 1, stamp: 3);
      final valid = ReplayEngine.rebuild([markManual, create, setActual]);
      expect(valid.ledgerEntries[entry]!.isSourceValid, isTrue);
      expect(valid.issues, isEmpty);
    },
  );

  test(
    'unknown group members are retained as unknown, never partly applied',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final unknown = event(
        2,
        'pricing_mode',
        {'pricing_mode': 'flat', 'per_head_rate_cents': null},
        {
          'pricing_mode': 'flat',
          'per_head_rate_cents': null,
          'future_rate': 10,
        },
        stamp: 2,
        group: plan,
      );
      final result = ReplayEngine.rebuild([unknown, create]);
      expect(result.issues.single.kind, ReplayIssueKind.unknownField);
      expect(result.unknownRecords.single, same(unknown));
      expect(result.ledgerEntries[entry]!.toJson(), snapshot());
    },
  );

  test(
    'source API exposes all writer fields and exact max int without totals',
    () {
      final source = {
        ...snapshot(),
        'actual_cents': 9223372036854775807,
        'notes': 'explicit',
        'manually_valued': 1,
      };
      final row = ReplayEngine.rebuild([
        event(1, r'$create', null, source, stamp: 1),
      ]).ledgerEntries[entry]!;
      expect(row.id, entry);
      expect(row.planId, plan);
      expect(row.categoryCode, 'catering_venue');
      expect(row.entryType, 'standard');
      expect(row.supplierName, 'Synthetic supplier');
      expect(row.actualCents, 9223372036854775807);
      expect(row.manuallyValued, 1);
      expect(row.templateSuggestionId, isNull);
      expect(row.checklistItemId, isNull);
      expect(row.createdAt, now);
      expect(row.deletedAt, isNull);
      expect(row.toJson(), source);
      expect(row.sourceConstraints, isEmpty);
    },
  );

  test(
    'Restore retains invalid pre-delete source with named constraint and no repair',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final invalid = event(2, 'actual_cents', null, -1, stamp: 2);
      final delete = event(3, 'deleted_at', null, now, stamp: 3);
      final suppressed = event(4, 'actual_cents', -1, 0, stamp: 4);
      final restore = event(5, 'deleted_at', now, null, stamp: 5);
      final result = ReplayEngine.rebuild([
        restore,
        suppressed,
        delete,
        invalid,
        create,
      ]);
      expect(result.ledgerEntries[entry]!.actualCents, -1);
      expect(result.ledgerEntries[entry]!.isDeleted, isFalse);
      expect(result.ledgerEntries[entry]!.isSourceValid, isFalse);
      expect(result.ledgerEntries[entry]!.sourceConstraints, [
        LedgerSourceConstraint.nonnegativeMoney,
      ]);
      expect(result.issues.last.constraints, [
        LedgerSourceConstraint.nonnegativeMoney,
      ]);
      expect(result.issues.last.eventId, restore.id);
      expect(result.records, hasLength(5));
    },
  );

  test(
    'all accepted ordering tie breakers are authoritative and deterministic',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final a = event(2, 'actual_cents', null, 10, stamp: 2, counter: 7);
      final b = event(3, 'actual_cents', 10, 20, stamp: 2, counter: 8);
      final c = event(
        4,
        'actual_cents',
        20,
        30,
        stamp: 2,
        counter: 8,
        deviceId: '20000000-0000-4000-8000-000000000002',
      );
      for (final arrivals in [
        [c, a, create, b],
        [b, create, c, a],
        [a, b, c, create],
      ]) {
        final result = ReplayEngine.rebuild(arrivals);
        expect(result.ledgerEntries[entry]!.actualCents, 30);
        expect(result.conflicts, isEmpty);
        expect(result.records.map((row) => row.id), [
          create.id,
          a.id,
          b.id,
          c.id,
        ]);
      }
      expect(
        () => ReplayEngine.rebuild([
          create,
          a,
          event(9, 'notes', null, 'ambiguous', stamp: 2, counter: 7),
        ]),
        throwsA(
          isA<ReplayException>().having(
            (e) => e.code,
            'code',
            'ambiguous_order',
          ),
        ),
      );
    },
  );

  test(
    'replay input is one plan and provisional source is one selected device',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final foreign = SyncEvent.fromJson({
        ...create.data,
        'plan_id': device,
      }, requireServerTimestamp: true);
      expect(
        () => ReplayEngine.rebuild([create, foreign]),
        throwsA(isA<ReplayException>()),
      );
      expect(
        () => ReplayEngine.rebuild(
          [create],
          provisional: [
            event(2, 'notes', null, 'one'),
            event(3, 'actual_cents', null, 1, deviceId: member),
          ],
        ),
        throwsA(
          isA<ReplayException>().having(
            (e) => e.code,
            'code',
            'multiple_provisional_devices',
          ),
        ),
      );
      expect(
        () => ReplayEngine.rebuild(
          [create],
          provisional: [
            event(2, 'notes', null, 'one', counter: 2),
            event(3, 'actual_cents', null, 1, counter: 2),
          ],
        ),
        throwsA(
          isA<ReplayException>().having(
            (e) => e.code,
            'code',
            'ambiguous_order',
          ),
        ),
      );
    },
  );

  test('second create never resets fields or resurrects a deleted entity', () {
    final create = event(1, r'$create', null, snapshot(), stamp: 1);
    final delete = event(2, 'deleted_at', null, now, stamp: 2);
    final duplicate = event(3, r'$create', null, {
      ...snapshot(),
      'supplier_name': 'Do not reset',
    }, stamp: 3);
    final result = ReplayEngine.rebuild([duplicate, delete, create]);
    expect(result.ledgerEntries[entry]!.isDeleted, isTrue);
    expect(
      result.ledgerEntries[entry]!.toJson()['supplier_name'],
      'Synthetic supplier',
    );
    expect(result.issues.single.kind.name, 'duplicateCreate');
    expect(result.records, hasLength(3));
    final pendingCreate = event(4, r'$create', null, snapshot());
    expect(
      ReplayEngine.rebuild(
        [create, delete],
        provisional: [pendingCreate],
      ).ledgerEntries[entry]!.isDeleted,
      isTrue,
    );
  });

  test(
    'provisional overlays authoritative replay by device counter without fake stamps',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 100);
      final accepted = event(2, 'actual_cents', null, 100, stamp: 999);
      final first = event(
        3,
        'actual_cents',
        100,
        200,
        counter: 3,
        created: '2099-01-01T00:00:00Z',
      );
      final second = event(
        4,
        'actual_cents',
        200,
        300,
        counter: 4,
        created: '2000-01-01T00:00:00Z',
      );
      final acceptedPending = event(2, 'actual_cents', null, 100);
      final result = ReplayEngine.rebuild(
        [accepted, create],
        provisional: [second, acceptedPending, first, first],
      );
      expect(result.ledgerEntries[entry]!.actualCents, 300);
      expect(result.records.map((e) => e.id), [
        create.id,
        accepted.id,
        first.id,
        second.id,
      ]);
      expect(result.provisionalEventIds, {first.id, second.id});
      expect(result.records.last.serverTimestamp, isNull);
      expect(result.conflicts, isEmpty);
      expect(
        jsonEncode(result.toJson()),
        jsonEncode(
          ReplayEngine.rebuild(
            [create, accepted],
            provisional: [first, second],
          ).toJson(),
        ),
      );
      expect(result.provisionalEventIds.clear, throwsUnsupportedError);
      expect(
        () => ReplayEngine.rebuild(
          [create, accepted],
          provisional: [event(2, 'actual_cents', null, 999)],
        ),
        throwsA(
          isA<ReplayException>().having(
            (e) => e.code,
            'code',
            'conflicting_event_id',
          ),
        ),
      );
      expect(
        () => ReplayEngine.rebuild([create], provisional: [accepted]),
        throwsA(
          isA<ReplayException>().having(
            (e) => e.code,
            'code',
            'provisional_stamp_forbidden',
          ),
        ),
      );
      expect(
        () => ReplayEngine.rebuild([first]),
        throwsA(
          isA<ReplayException>().having(
            (e) => e.code,
            'code',
            'accepted_stamp_required',
          ),
        ),
      );
    },
  );

  test(
    'tombstone suppresses history permanently; Restore reopens pre-delete fields',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final before = event(2, 'actual_cents', null, 100, stamp: 2);
      final delete = event(3, 'deleted_at', null, now, stamp: 3);
      final suppressed = event(4, 'actual_cents', 100, 999, stamp: 4);
      final dead = ReplayEngine.rebuild([suppressed, create, delete, before]);
      expect(dead.ledgerEntries[entry]!.isDeleted, isTrue);
      expect(dead.ledgerEntries[entry]!.actualCents, 100);
      expect(dead.issues.single.kind, ReplayIssueKind.tombstoneSuppressed);
      expect(dead.needsAttention, isTrue);
      final restore = event(5, 'deleted_at', now, null, stamp: 5);
      final live = ReplayEngine.rebuild([
        restore,
        suppressed,
        create,
        delete,
        before,
      ]);
      expect(live.ledgerEntries[entry]!.isDeleted, isFalse);
      expect(live.ledgerEntries[entry]!.actualCents, 100);
      expect(live.issues.single.kind, ReplayIssueKind.tombstoneSuppressed);
      expect(live.records, hasLength(5));
      final edit = event(6, 'actual_cents', 100, 200, stamp: 6);
      final again = ReplayEngine.rebuild([
        edit,
        restore,
        suppressed,
        create,
        delete,
        before,
      ]);
      expect(again.ledgerEntries[entry]!.actualCents, 200);
      expect(again.conflicts, isEmpty);
      expect(
        jsonEncode(again.toJson()),
        jsonEncode(
          ReplayEngine.rebuild([
            create,
            before,
            delete,
            suppressed,
            restore,
            edit,
          ]).toJson(),
        ),
      );
    },
  );

  test(
    'pricing group is one complete typed unit with separate flat estimate',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final clearEstimate = event(
        2,
        'estimated_cents',
        9007199254740993,
        null,
        stamp: 2,
      );
      const flat = {'pricing_mode': 'flat', 'per_head_rate_cents': null};
      const head = {'pricing_mode': 'per_head', 'per_head_rate_cents': 50000};
      final group = event(3, 'pricing_mode', flat, head, stamp: 3, group: plan);
      final stale = event(
        4,
        'pricing_mode',
        flat,
        {...head, 'per_head_rate_cents': 9007199254740993},
        stamp: 4,
        group: device,
      );
      final result = ReplayEngine.rebuild([
        stale,
        group,
        create,
        clearEstimate,
      ]);
      final row = result.ledgerEntries[entry]!;
      expect(row.pricingMode, 'per_head');
      expect(row.perHeadRateCents, 9007199254740993);
      expect(row.estimatedCents, isNull);
      expect(row.isSourceValid, isTrue);
      expect(result.issues, isEmpty);
      expect(result.conflicts.single.actualPriorValue, head);
      expect(
        () => (result.conflicts.single.actualPriorValue! as Map).clear(),
        throwsUnsupportedError,
      );
      for (final bad in [
        event(
          5,
          'pricing_mode',
          head,
          {'pricing_mode': 'flat'},
          stamp: 5,
          group: plan,
        ),
        event(5, 'pricing_mode', head, flat, stamp: 5),
        event(
          5,
          'pricing_mode',
          head,
          {...flat, 'extra': 1},
          stamp: 5,
          group: plan,
        ),
        event(5, 'per_head_rate_cents', 50000, 100, stamp: 5),
      ]) {
        final replay = ReplayEngine.rebuild([
          create,
          clearEstimate,
          group,
          bad,
        ]);
        expect(replay.ledgerEntries[entry]!.perHeadRateCents, 50000);
        expect(replay.issues, hasLength(1));
        expect(replay.needsAttention, isTrue);
      }
    },
  );

  test(
    'invalid merged source remains inspectable, typed malformed values do not apply',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final clear = event(
        2,
        'estimated_cents',
        9007199254740993,
        null,
        stamp: 2,
      );
      final result = ReplayEngine.rebuild([clear, create]);
      expect(result.ledgerEntries[entry]!.estimatedCents, isNull);
      expect(result.ledgerEntries[entry]!.isSourceValid, isFalse);
      expect(result.issues.single.kind, ReplayIssueKind.invalidSource);
      for (final value in ['123', 1.0, true, <Object?>[]]) {
        final replay = ReplayEngine.rebuild([
          create,
          event(3, 'actual_cents', null, value, stamp: 3),
        ]);
        expect(replay.ledgerEntries[entry]!.actualCents, isNull);
        expect(replay.issues.single.kind, ReplayIssueKind.invalidValue);
      }
      final negative = ReplayEngine.rebuild([
        create,
        event(3, 'actual_cents', null, -1, stamp: 3),
      ]);
      expect(negative.ledgerEntries[entry]!.actualCents, -1);
      expect(negative.ledgerEntries[entry]!.isSourceValid, isFalse);
      expect(negative.issues.single.kind, ReplayIssueKind.invalidSource);
    },
  );

  test('updates before create wait and replay once full snapshot arrives', () {
    final update = event(1, 'notes', null, 'waiting', stamp: 1);
    final partial = ReplayEngine.rebuild([update]);
    expect(partial.ledgerEntries, isEmpty);
    expect(partial.issues.single.kind, ReplayIssueKind.missingCreate);
    final create = event(2, r'$create', null, snapshot(), stamp: 2);
    final complete = ReplayEngine.rebuild([create, update]);
    expect(complete.ledgerEntries[entry]!.notes, 'waiting');
    expect(complete.issues, isEmpty);
    expect(complete.conflicts, isEmpty);
  });

  test('unknown schema, entity, field and snapshot keys stay raw only', () {
    final rows = [
      event(1, r'$create', null, snapshot(), stamp: 1, schema: 2),
      event(2, r'$create', null, snapshot(), stamp: 2, entityType: 'payments'),
      event(3, 'paid_on', null, '2026-01-01', stamp: 3),
      event(4, r'$create', null, {...snapshot(), 'derived_total': 1}, stamp: 4),
    ];
    final result = ReplayEngine.rebuild(rows.reversed);
    expect(result.ledgerEntries, isEmpty);
    expect(result.unknownRecords.map((e) => e.id), rows.map((e) => e.id));
    expect(result.issues.map((i) => i.kind), [
      ReplayIssueKind.unknownSchema,
      ReplayIssueKind.unsupportedEntity,
      ReplayIssueKind.unknownField,
      ReplayIssueKind.unknownField,
    ]);
    expect(result.needsAttention, isTrue);
    expect(result.records, hasLength(4));
  });

  test(
    'full create validates all fields atomically, never partial projection',
    () {
      final malformed = <Map<String, Object?>>[
        {...snapshot()}..remove('notes'),
        {...snapshot(), 'id': '60000000-0000-7000-8000-000000000001'},
        {...snapshot(), 'plan_id': device},
        {...snapshot(), 'supplier_name': '  '},
        {...snapshot(), 'supplier_name': 'x' * 201},
        {...snapshot(), 'category_code': 'unknown'},
        {...snapshot(), 'entry_type': 'oot_fees'},
        {...snapshot(), 'estimated_cents': -1},
        {...snapshot(), 'actual_cents': 1.5},
        {...snapshot(), 'actual_cents': '9007199254740993'},
        {...snapshot(), 'pricing_mode': 'per_head'},
        {...snapshot(), 'per_head_rate_cents': 100},
        {...snapshot(), 'manually_valued': true},
        {...snapshot(), 'notes': 'x' * 2001},
        {...snapshot(), 'created_at': '2026-02-30T00:00:00Z'},
        {...snapshot(), 'deleted_at': 'bad'},
        {...snapshot(), 'template_suggestion_id': 'not-validated'},
        {...snapshot(), 'checklist_item_id': 'not-validated'},
      ];
      for (final source in malformed) {
        final result = ReplayEngine.rebuild([
          event(1, r'$create', null, source, stamp: 1),
        ]);
        expect(result.ledgerEntries, isEmpty, reason: '$source');
        expect(result.issues.single.kind, ReplayIssueKind.invalidSnapshot);
        expect(result.needsAttention, isTrue);
        expect(result.records, hasLength(1));
      }
    },
  );

  test(
    'server order wins over clocks, stale old values compare actual prior',
    () {
      final create = event(1, r'$create', null, snapshot(), stamp: 1);
      final first = event(
        2,
        'actual_cents',
        null,
        5800000,
        stamp: 2,
        created: '2026-10-21T00:00:00Z',
      );
      final staleWinner = event(
        3,
        'actual_cents',
        null,
        6200000,
        stamp: 3,
        created: '2020-01-01T00:00:00Z',
      );
      final result = ReplayEngine.rebuild([staleWinner, create, first]);
      expect(result.ledgerEntries[entry]!.actualCents, 6200000);
      expect(result.conflicts, hasLength(1));
      final conflict = result.conflicts.single;
      expect(conflict.eventId, staleWinner.id);
      expect(conflict.fieldName, 'actual_cents');
      expect(conflict.recordedOldValue, isNull);
      expect(conflict.actualPriorValue, 5800000);
      expect(conflict.replacingValue, 6200000);
      expect(result.records.map((row) => row.id), [
        create.id,
        first.id,
        staleWinner.id,
      ]);
      expect(
        jsonEncode(result.toJson()),
        jsonEncode(
          ReplayEngine.rebuild([first, staleWinner, first, create]).toJson(),
        ),
      );
    },
  );

  test(
    'conflicting duplicate IDs fail closed without exposing source data',
    () {
      final a = event(1, r'$create', null, snapshot(), stamp: 1);
      final b = event(1, r'$create', null, {
        ...snapshot(),
        'supplier_name': 'Private value',
      }, stamp: 1);
      expect(
        () => ReplayEngine.rebuild([a, b]),
        throwsA(
          isA<ReplayException>()
              .having((e) => e.code, 'code', 'conflicting_event_id')
              .having(
                (e) => e.toString(),
                'safe message',
                isNot(contains('Private')),
              ),
        ),
      );
    },
  );

  test('full source create is exact, immutable and replay canonical', () {
    final create = event(1, r'$create', null, snapshot(), stamp: 1);
    final result = ReplayEngine.rebuild([create, create]);
    expect(result.ledgerEntries[entry]!.estimatedCents, 9007199254740993);
    expect(result.ledgerEntries[entry]!.toJson(), snapshot());
    expect(result.records, hasLength(1));
    expect(result.needsAttention, isFalse);
    expect(result.ledgerEntries.clear, throwsUnsupportedError);
    expect(
      () => result.ledgerEntries[entry]!.toJson().clear(),
      throwsUnsupportedError,
    );
    expect(
      jsonEncode(result.toJson()),
      jsonEncode(ReplayEngine.rebuild([create]).toJson()),
    );
  });
}
