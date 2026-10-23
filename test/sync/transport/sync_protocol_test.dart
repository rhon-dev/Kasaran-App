import 'dart:convert';

import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  test('zero event counter is valid for outbound and accepted events', () {
    final wire = wireEvent()..['device_monotonic'] = '0';
    expect(SyncEvent.fromJson(wire).deviceMonotonic, 0);
    expect(
      SyncEvent.fromJson({
        ...wire,
        'server_ts': '1',
      }, requireServerTimestamp: true).deviceMonotonic,
      0,
    );
  });
  test('canonical non-v7 group is valid for outbound and accepted events', () {
    const group = '00000000-0000-4000-8000-000000000000';
    final wire = wireEvent()..['change_group_id'] = group;
    expect(SyncEvent.fromJson(wire).data['change_group_id'], group);
    expect(
      SyncEvent.fromJson({
        ...wire,
        'server_ts': '1',
      }, requireServerTimestamp: true).data['change_group_id'],
      group,
    );
  });
  test('wire snapshot retains exact int64 JSON and additive values', () {
    final source = wireEvent()
      ..['future_extension'] = {
        'values': [null, 9007199254740993],
      };
    final event = SyncEvent.fromJson(source);
    source['new_value'] = 1;
    final encoded = jsonEncode(event.toPushJson());
    expect(encoded, contains('9007199254740993'));
    expect(event.deviceMonotonic, 9223372036854775807);
    expect(event.toPushJson()['server_ts'], isNull);
    final extension = event.data['future_extension']! as Map<String, Object?>;
    expect(extension['values'], [null, 9007199254740993]);
    expect(event.data.clear, throwsUnsupportedError);
    expect(
      (extension['values']! as List<Object?>).clear,
      throwsUnsupportedError,
    );
  });

  test('pull page retains unknown events and validates its exact cursor', () {
    final wire = wireEvent()
      ..['server_ts'] = '8'
      ..['entity_type'] = 'future_entities'
      ..['schema_version'] = 88;
    final body = <String, Object?>{
      'protocol_version': {'major': 1, 'minor': 2},
      'rows': [wire],
      'next_cursor': '8',
      'has_more': false,
    };
    final page = SyncPullPage.fromJson(
      body,
      planId: planId,
      cursor: 7,
      limit: 1,
    );
    expect(page.nextCursor, 8);
    expect(page.rows.single.data['entity_type'], 'future_entities');
    expect(page.rows.single.data['schema_version'], 88);
    expect(page.rows.single.serverTimestamp, 8);
    expect(
      () => page.rows.single.toPushJson(),
      throwsA(isA<SyncProtocolException>()),
    );
    expect(
      () => SyncPullPage.fromJson(
        {...body, 'next_cursor': '9'},
        planId: planId,
        cursor: 7,
        limit: 1,
      ),
      throwsA(isA<SyncProtocolException>()),
    );
  });

  test(
    'push acknowledgments are bounded to submitted unique IDs and high water',
    () {
      final body = <String, Object?>{
        'protocol_version': {'major': 1, 'minor': 0},
        'accepted': [
          {'id': eventId, 'server_ts': '9223372036854775807'},
        ],
        'server_ts_high': '9223372036854775807',
      };
      final result = SyncPushResult.fromJson(body, requestedIds: {eventId});
      expect(result.accepted[eventId], 9223372036854775807);
      expect(result.highWater, 9223372036854775807);
      expect(result.accepted.clear, throwsUnsupportedError);
      for (final invalid in [
        {...body, 'server_ts_high': '1'},
        {
          ...body,
          'accepted': [
            {'id': 'foreign', 'server_ts': '1'},
          ],
        },
        {
          ...body,
          'accepted': [
            {'id': eventId, 'server_ts': '1'},
            {'id': eventId, 'server_ts': '1'},
          ],
        },
        {
          ...body,
          'protocol_version': {'major': 2, 'minor': 0},
        },
      ]) {
        expect(
          () => SyncPushResult.fromJson(invalid, requestedIds: {eventId}),
          throwsA(isA<SyncProtocolException>()),
        );
      }
    },
  );

  test(
    'event metadata rejects invalid integers, identifiers and normalized dates',
    () {
      for (final patch in <Map<String, Object?>>[
        {'device_monotonic': '-1'},
        {'device_monotonic': '01'},
        {'device_monotonic': '9223372036854775808'},
        {'device_monotonic': 1},
        {'schema_version': 1.0},
        {'schema_version': 0},
        {'id': '019a0000-0000-4000-8000-000000000001'},
        {'plan_id': 'bad'},
        {'entity_id': 'bad'},
        {'plan_member_id': 'bad'},
        {'change_group_id': 'bad'},
        {'field_name': ' '},
        {'created_at': '2026-02-30T08:00:00Z'},
        {'created_at': '2026-10-20T08:00:00'},
        {'server_ts': null},
        {'actor_user_id': 'untrusted'},
        {'new_value': DateTime.utc(2026)},
      ]) {
        expect(
          () => SyncEvent.fromJson({...wireEvent(), ...patch}),
          throwsA(isA<SyncProtocolException>()),
        );
      }
      final missing = wireEvent()..remove('old_value');
      expect(
        () => SyncEvent.fromJson(missing),
        throwsA(isA<SyncProtocolException>()),
      );
    },
  );

  test(
    'out-of-range JSON integers cannot silently become imprecise doubles',
    () {
      final source =
          jsonDecode(
                jsonEncode(
                  wireEvent(),
                ).replaceFirst('9007199254740993', '9223372036854775808'),
              )
              as Map<String, Object?>;
      expect(
        () => SyncEvent.fromJson(source),
        throwsA(isA<SyncProtocolException>()),
      );
    },
  );

  test('foreign, repeated, unordered and over-limit pages are rejected', () {
    Map<String, Object?> page(
      List<Object?> rows, {
      String cursor = '2',
      bool more = false,
    }) => {
      'protocol_version': {'major': 1, 'minor': 0},
      'rows': rows,
      'next_cursor': cursor,
      'has_more': more,
    };
    final first = {...wireEvent(), 'server_ts': '1'};
    final second = {
      ...wireEvent(),
      'id': '019a0000-0000-7000-8000-000000000003',
      'server_ts': '2',
    };
    for (final invalid in [
      page([
        {...first, 'plan_id': '44444444-4444-4444-8444-444444444444'},
      ], cursor: '1'),
      page([
        first,
        {...first, 'server_ts': '2'},
      ]),
      page([second, first], cursor: '1'),
      page([first, second]),
      page([], cursor: '1'),
      page([], cursor: '0', more: true),
    ]) {
      expect(
        () =>
            SyncPullPage.fromJson(invalid, planId: planId, cursor: 0, limit: 1),
        throwsA(isA<SyncProtocolException>()),
      );
    }
    final repeated = page([
      first,
      {...first, 'server_ts': '2'},
    ]);
    expect(
      () =>
          SyncPullPage.fromJson(repeated, planId: planId, cursor: 0, limit: 2),
      throwsA(isA<SyncProtocolException>()),
    );
    final unordered = page([second, first], cursor: '1');
    expect(
      () =>
          SyncPullPage.fromJson(unordered, planId: planId, cursor: 0, limit: 2),
      throwsA(isA<SyncProtocolException>()),
    );
  });

  test(
    'empty pages retain cursor and partial acknowledgments remain explicit',
    () {
      final page = SyncPullPage.fromJson(
        {
          'protocol_version': {'major': 1, 'minor': 0},
          'rows': [],
          'next_cursor': '99',
          'has_more': false,
        },
        planId: planId,
        cursor: 99,
        limit: 100,
      );
      expect(page.nextCursor, 99);
      final ack = SyncPushResult.fromJson(
        {
          'protocol_version': {'major': 1, 'minor': 0},
          'accepted': [],
          'server_ts_high': '99',
        },
        requestedIds: {eventId},
      );
      expect(ack.accepted, isEmpty);
      expect(ack.highWater, 99);
    },
  );
}
