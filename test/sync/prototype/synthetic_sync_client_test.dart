import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/sync/prototype/synthetic_sync_protocol.dart';

SyntheticEvent event(
  String id, {
  String plan = 'plan-A',
  String device = 'device-A',
  int counter = 1,
  String entity = 'ledger_entries',
  int schema = 2,
  String? value = '9007199254740991',
}) => SyntheticEvent(
  id: id,
  planId: plan,
  deviceId: device,
  deviceMonotonic: counter,
  schemaVersion: schema,
  entityType: entity,
  fieldName: 'estimated_cents',
  oldValue: null,
  newValue: value,
);

SyntheticSyncServer server() => SyntheticSyncServer(
  memberships: {
    'plan-A': {'account-A', 'account-B'},
  },
  maxBatchSize: 2,
  supportedMajor: 1,
);

void main() {
  test('version refusal preserves the queue and cursor', () {
    final sync = server();
    final client = SyntheticSyncClient(planId: 'plan-A', deviceId: 'device-A');
    final pending = event('pending');
    client.enqueue(pending);
    expect(
      () => client.pushQueue(sync, 'account-A', 2),
      throwsA(isA<SyntheticSyncError>()),
    );
    expect(client.pending, [pending]);
    expect(client.cursor, 0);
    expect(client.retained, isEmpty);
  });

  test('invalid or mixed-plan queue fails without losing pending rows', () {
    for (final invalid in [
      event('foreign', plan: 'plan-B'),
      event('other-device', device: 'device-B'),
      event('invalid', counter: 0),
    ]) {
      final sync = server();
      final client = SyntheticSyncClient(
        planId: 'plan-A',
        deviceId: 'device-A',
      );
      final first = event('first');
      client.enqueue(first);
      client.enqueue(invalid);
      expect(
        () => client.pushQueue(sync, 'account-A', 1),
        throwsA(isA<SyntheticSyncError>()),
      );
      expect(client.pending, [first, invalid]);
      expect(
        sync
            .pull(
              actor: 'account-A',
              planId: 'plan-A',
              protocolMajor: 1,
              cursor: 0,
              limit: 1000,
            )
            .rows,
        isEmpty,
      );
    }
  });

  test('successful push removes only the bounded accepted batch', () {
    final sync = server();
    final client = SyntheticSyncClient(planId: 'plan-A', deviceId: 'device-A');
    final rows = [event('a'), event('b', counter: 2), event('c', counter: 3)];
    for (final row in rows) {
      client.enqueue(row);
    }
    client.pushQueue(sync, 'account-A', 1);
    expect(client.pending, [rows.last]);
    expect(client.cursor, 0);
    client.pushQueue(sync, 'account-A', 1);
    expect(client.pending, isEmpty);
    client.pullPage(sync, 'account-A', 1, 1000);
    expect(client.retained.keys, ['a', 'b', 'c']);
    expect(client.retained.values.map((row) => row.sequence), [1, 2, 3]);
  });

  test('failed page swap preserves cursor and all raw rows until retry', () {
    final sync = server();
    final known = event('known');
    const rawUnknown = ' {"future": [9007199254740991, null]} ';
    final unknown = event('unknown', entity: 'future_rows', value: rawUnknown);
    sync.push(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      rows: [known, unknown],
    );
    final client = SyntheticSyncClient(planId: 'plan-A', deviceId: 'device-B');
    client.pullPage(sync, 'account-B', 1, 1);
    final before = client.retained;
    expect(
      () => client.pullPage(
        sync,
        'account-B',
        1,
        1,
        beforeCommit: () => throw StateError('injected page failure'),
      ),
      throwsStateError,
    );
    expect(client.cursor, 1);
    expect(client.retained, before);
    client.pullPage(sync, 'account-B', 1, 1);
    expect(client.cursor, 2);
    expect(client.retained.keys, ['known', 'unknown']);
    expect(client.retained['unknown']!.event.newValue, rawUnknown);
    expect(client.projectedRows.map((row) => row.event.id), ['known']);
    expect(client.retained['known']!.event.newValue, '9007199254740991');
    client.pullPage(sync, 'account-B', 1, 1);
    client.pullPage(sync, 'account-B', 1, 1);
    expect(client.cursor, 2);
    expect(client.retained.keys, ['known', 'unknown']);
    expect(before.keys, ['known']);
  });

  test(
    'recursive page application preserves the prior snapshot until retry',
    () {
      final sync = server();
      sync.push(
        actor: 'account-A',
        planId: 'plan-A',
        protocolMajor: 1,
        rows: [event('first'), event('second', counter: 2)],
      );
      final client = SyntheticSyncClient(
        planId: 'plan-A',
        deviceId: 'device-B',
      );
      client.pullPage(sync, 'account-B', 1, 1);
      final before = client.retained;
      expect(
        () => client.pullPage(
          sync,
          'account-B',
          1,
          1,
          beforeCommit: () => client.pullPage(sync, 'account-B', 1, 1),
        ),
        throwsA(
          isA<SyntheticSyncError>().having(
            (error) => error.reason,
            'reason',
            'pageInProgress',
          ),
        ),
      );
      expect(client.retained, before);
      expect(client.cursor, 1);
      client.pullPage(sync, 'account-B', 1, 1);
      expect(client.retained.keys, ['first', 'second']);
      expect(client.cursor, 2);
    },
  );

  test('unknown schema and untyped values remain raw without projection', () {
    final sync = server();
    sync.push(
      actor: 'account-A',
      planId: 'plan-A',
      protocolMajor: 1,
      rows: [
        event('future', schema: 3),
        event('untyped', value: '"10"'),
      ],
    );
    final client = SyntheticSyncClient(planId: 'plan-A', deviceId: 'device-B');
    client.pullPage(sync, 'account-B', 1, 1000);
    expect(client.retained.length, 2);
    expect(client.projectedRows, isEmpty);
    expect(client.cursor, 2);
    expect(() => client.retained.clear(), throwsUnsupportedError);
    expect(() => client.pending.clear(), throwsUnsupportedError);
  });

  test('devices keep independent queues and converge on the accepted log', () {
    final sync = server();
    final a = SyntheticSyncClient(planId: 'plan-A', deviceId: 'device-A');
    final b = SyntheticSyncClient(planId: 'plan-A', deviceId: 'device-B');
    a.enqueue(event('a'));
    b.enqueue(event('b', device: 'device-B', value: '120001'));
    a.pushQueue(sync, 'account-A', 1);
    expect(b.pending.single.id, 'b');
    b.pushQueue(sync, 'account-B', 1);
    a.pullPage(sync, 'account-A', 1, 1);
    a.pullPage(sync, 'account-A', 1, 1);
    b.pullPage(sync, 'account-B', 1, 1000);
    expect(a.retained, b.retained);
    expect(a.cursor, b.cursor);
    expect(a.pending, isEmpty);
    expect(b.pending, isEmpty);
  });
}
