import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/sync/prototype/synthetic_sync_protocol.dart';

void main() {
  SyntheticEvent event(
    String id, {
    String plan = 'plan-A',
    String device = 'device-A',
    int counter = 1,
    String entity = 'ledger_entries',
    int schema = 2,
    String field = 'estimated_cents',
    String? oldValue,
    String? newValue = '{"cents":9007199254740991}',
  }) => SyntheticEvent(
    id: id,
    planId: plan,
    deviceId: device,
    deviceMonotonic: counter,
    schemaVersion: schema,
    entityType: entity,
    fieldName: field,
    oldValue: oldValue,
    newValue: newValue,
  );

  SyntheticSyncServer server() => SyntheticSyncServer(
    memberships: {
      'plan-A': {'account-A', 'account-B'},
      'plan-B': {'account-C'},
    },
    maxBatchSize: 2,
    supportedMajor: 1,
  );

  test('retry retains first assigned sequence and no duplicate row', () {
    final sync = server();
    final first = event('event-1');
    final pushed = sync.push(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      rows: [first],
    );
    final retried = sync.push(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      rows: [first],
    );
    expect(pushed.single.sequence, 1);
    expect(retried.single.sequence, 1);
    final page = sync.pull(
      actor: 'account-B',
      planId: 'plan-A',
      protocolMajor: 1,
      cursor: 0,
      limit: 1,
    );
    expect(page.rows.map((row) => row.event.id), ['event-1']);
    expect(page.nextCursor, 1);
    expect(page.hasMore, isFalse);
  });

  test('foreign and absent plans have identical denial with existing rows', () {
    final sync = server();
    sync.push(
      actor: 'account-C',
      planId: 'plan-B',
      protocolMajor: 1,
      rows: [event('foreign', plan: 'plan-B')],
    );
    String denied(String plan) {
      try {
        sync.pull(
          actor: 'account-A',
          planId: plan,
          protocolMajor: 1,
          cursor: 0,
          limit: 1,
        );
        return 'allowed';
      } on SyntheticSyncError catch (error) {
        return error.reason;
      }
    }

    expect(denied('plan-B'), 'planUnavailable');
    expect(denied('missing-plan'), 'planUnavailable');
  });

  test('conflicting duplicate and mixed-plan batch never mutate log', () {
    final sync = server();
    sync.push(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      rows: [event('first')],
    );
    expect(
      () => sync.push(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 1,
        rows: [
          event('second'),
          event('first', newValue: '2'),
        ],
      ),
      throwsA(
        isA<SyntheticSyncError>().having(
          (e) => e.reason,
          'reason',
          'conflictingDuplicate',
        ),
      ),
    );
    expect(
      () => sync.push(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 1,
        rows: [
          event('second'),
          event('other', plan: 'plan-B'),
        ],
      ),
      throwsA(
        isA<SyntheticSyncError>().having(
          (e) => e.reason,
          'reason',
          'invalidEvent',
        ),
      ),
    );
    final next = sync.push(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      rows: [event('second')],
    );
    expect(next.single.sequence, 2);
  });

  test('version, invalid counter and oversize reject before acceptance', () {
    final sync = server();
    expect(
      () => sync.push(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 2,
        rows: [event('first')],
      ),
      throwsA(
        isA<SyntheticSyncError>().having(
          (e) => e.reason,
          'reason',
          'unsupportedVersion',
        ),
      ),
    );
    expect(
      () => sync.push(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 1,
        rows: [event('bad', counter: 0)],
      ),
      throwsA(
        isA<SyntheticSyncError>().having(
          (e) => e.reason,
          'reason',
          'invalidEvent',
        ),
      ),
    );
    expect(
      () => sync.push(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 1,
        rows: [event('a'), event('b'), event('c')],
      ),
      throwsA(
        isA<SyntheticSyncError>().having(
          (e) => e.reason,
          'reason',
          'invalidBatch',
        ),
      ),
    );
    expect(
      sync
          .push(
            actor: 'account-A',
            planId: 'plan-A',
            protocolMajor: 1,
            rows: [event('first')],
          )
          .single
          .sequence,
      1,
    );
  });

  test('limit-one pages, invalid cursor, and empty cursor retention', () {
    final sync = server();
    sync.push(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      rows: [event('a'), event('b')],
    );
    final first = sync.pull(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      cursor: 0,
      limit: 1,
    );
    expect([first.nextCursor, first.hasMore], [1, true]);
    final second = sync.pull(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      cursor: first.nextCursor,
      limit: 1,
    );
    expect(
      [second.rows.single.event.id, second.nextCursor, second.hasMore],
      ['b', 2, false],
    );
    final empty = sync.pull(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      cursor: 2,
      limit: 1,
    );
    expect([empty.rows.length, empty.nextCursor, empty.hasMore], [0, 2, false]);
    for (final invalid in [0, 1001]) {
      expect(
        () => sync.pull(
          actor: 'account-A',
          planId: 'plan-A',
          protocolMajor: 1,
          cursor: 0,
          limit: invalid,
        ),
        throwsA(isA<SyntheticSyncError>()),
      );
    }
    expect(
      () => sync.pull(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 1,
        cursor: -1,
        limit: 1,
      ),
      throwsA(isA<SyntheticSyncError>()),
    );
  });

  test('pre-commit fault leaves no row and no sequence gap', () {
    final sync = server();
    expect(
      () => sync.push(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 1,
        rows: [event('failed')],
        failBeforeCommit: true,
      ),
      throwsA(isA<SyntheticSyncError>()),
    );
    expect(
      sync
          .push(
            actor: 'account-A',
            planId: 'plan-A',
            protocolMajor: 1,
            rows: [event('next')],
          )
          .single
          .sequence,
      1,
    );
  });

  test('same-batch duplicate identity compares every raw payload field', () {
    final mutations = [
      event('same', device: 'device-B'),
      event('same', counter: 2),
      event('same', schema: 3),
      event('same', entity: 'future_rows'),
      event('same', field: 'label'),
      event('same', oldValue: 'null'),
      event('same', newValue: ' {"cents":9007199254740991} '),
    ];
    for (final mutated in mutations) {
      final sync = server();
      expect(
        () => sync.push(
          actor: 'account-A',
          planId: 'plan-A',
          protocolMajor: 1,
          rows: [event('same'), mutated],
        ),
        throwsA(isA<SyntheticSyncError>()),
      );
      final accepted = sync.push(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 1,
        rows: [event('same'), event('same')],
      );
      expect(accepted.map((row) => row.sequence), [1, 1]);
      expect(
        sync
            .pull(
              actor: 'account-A',
              planId: 'plan-A',
              protocolMajor: 1,
              cursor: 0,
              limit: 1000,
            )
            .rows
            .length,
        1,
      );
    }
  });

  test('malformed row rejects the whole batch before sequence allocation', () {
    for (final invalid in [
      event(''),
      event('invalid', device: ' '),
      event('invalid', entity: ''),
      event('invalid', field: ''),
      event('invalid', schema: 0),
      event('invalid', counter: -1),
      event('invalid', oldValue: '{broken'),
      event('invalid', newValue: 'NaN'),
    ]) {
      final sync = server();
      expect(
        () => sync.push(
          actor: 'account-A',
          planId: 'plan-A',
          protocolMajor: 1,
          rows: [event('valid'), invalid],
        ),
        throwsA(isA<SyntheticSyncError>()),
      );
      expect(
        sync
            .push(
              actor: 'account-A',
              planId: 'plan-A',
              protocolMajor: 1,
              rows: [event('valid')],
            )
            .single
            .sequence,
        1,
      );
    }
  });

  test('foreign push cannot append and plan sequences stay independent', () {
    final sync = server();
    for (final plan in ['plan-B', 'missing-plan']) {
      expect(
        () => sync.push(
          actor: 'account-A',
          planId: plan,
          protocolMajor: 1,
          rows: [event('foreign', plan: plan)],
        ),
        throwsA(
          isA<SyntheticSyncError>().having(
            (error) => error.reason,
            'reason',
            'planUnavailable',
          ),
        ),
      );
    }
    for (final pair in [('plan-A', 'account-A'), ('plan-B', 'account-C')]) {
      expect(
        sync
            .push(
              actor: pair.$2,
              planId: pair.$1,
              protocolMajor: 1,
              rows: [event(pair.$1, plan: pair.$1)],
            )
            .single
            .sequence,
        1,
      );
    }
  });
}
