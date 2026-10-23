// Actual production Dart transport -> disposable Edge -> authenticated RPC.
// No mocks, fake HTTP server, SQLite queue, cursor persistence or projection.
@Tags(['local_supabase'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';
import 'package:test/test.dart';

String _uuid() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (var i = 0; i < 6; i++) {
    bytes[i] = (millis >> ((5 - i) * 8)) & 255;
  }
  bytes[6] = (bytes[6] & 15) | 0x70;
  bytes[8] = (bytes[8] & 63) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final class _IssuedSession implements SyncSessionSource {
  _IssuedSession(this.session);
  final SyncAuthSession session;
  @override
  SyncAuthSession capture() => session;
}

void main() {
  test(
    'Dart HttpSyncTransport round trips real Edge stamps retries and pages',
    _exerciseRoundTrip,
  );
  test(
    'Dart reader accepts zero counter committed by direct Edge caller',
    () => _exerciseRoundTrip(boundaryCounter: '0'),
  );
  test(
    'Dart reader accepts canonical non-v7 group committed by direct Edge caller',
    () => _exerciseRoundTrip(
      boundaryGroup: '00000000-0000-4000-8000-000000000000',
    ),
  );
}

Future<void> _exerciseRoundTrip({
  String? boundaryCounter,
  String? boundaryGroup,
}) async {
  final workdir = Platform.environment['SUPABASE_WORKDIR'];
  expect(workdir, isNotNull, reason: 'Disposable workdir required');
  final config = await File('$workdir/supabase/config.toml').readAsString();
  expect(
    RegExp(
      r'^project_id\s*=\s*"kasaran_p08_disposable"\s*$',
      multiLine: true,
    ).hasMatch(config),
    isTrue,
    reason: 'Exact disposable guard required before fixture writes',
  );
  final status = await Process.run('supabase', [
    'status',
    '-o',
    'json',
  ], workingDirectory: workdir);
  expect(status.exitCode, 0, reason: 'Disposable services must be running');
  final settings = jsonDecode(status.stdout as String) as Map<String, dynamic>;
  final base = Uri.parse(settings['API_URL'] as String);
  expect(base.host, '127.0.0.1', reason: 'Literal loopback only');
  final anon = settings['ANON_KEY'] as String;
  final service = settings['SERVICE_ROLE_KEY'] as String;
  final client = http.Client();
  addTearDown(client.close);
  Future<Map<String, dynamic>> post(
    String path,
    Object body, {
    String? token,
  }) async {
    final response = await client.post(
      base.resolve(path),
      headers: {
        'apikey': anon,
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    expect(
      response.statusCode,
      anyOf(200, 201),
      reason: 'Synthetic fixture request',
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  final email = 'dart-sync-${_uuid()}@example.test';
  final password = '${_uuid()}Aa1!';
  final user = await post('/auth/v1/admin/users', {
    'email': email,
    'password': password,
    'email_confirm': true,
  }, token: service);
  final login = await post('/auth/v1/token?grant_type=password', {
    'email': email,
    'password': password,
  });
  final token = login['access_token'] as String;
  final planId = _uuid();
  await post('/rest/v1/rpc/create_plan', {
    'p_id': planId,
    'p_wedding_date': '2027-06-01',
    'p_total_budget_cents': 100000,
    'p_guest_cap': 20,
    'p_region_code': 'PH-NCR',
    'p_ruleset_version': 'synthetic',
    'p_driving_rsvp_status': 'unknown',
  }, token: token);
  final aliases = await client.get(
    base.resolve(
      '/rest/v1/plan_member_aliases?select=plan_member_id&plan_id=eq.$planId',
    ),
    headers: {'apikey': anon, 'Authorization': 'Bearer $token'},
  );
  expect(aliases.statusCode, 200);
  final aliasRows = jsonDecode(aliases.body) as List<dynamic>;
  expect(aliasRows, hasLength(1));
  final alias =
      (aliasRows.single as Map<String, dynamic>)['plan_member_id'] as String;
  final transport = HttpSyncTransport(
    baseUrl: base,
    anonKey: anon,
    sessions: _IssuedSession(
      SyncAuthSession(
        userId: user['id'] as String,
        marker: Object(),
        accessToken: token,
      ),
    ),
  );
  addTearDown(transport.close);
  final events = List<SyncEvent>.generate(
    2,
    (index) => SyncEvent.fromJson({
      'id': _uuid(),
      'plan_id': planId,
      'entity_type': 'ledger_entries',
      'entity_id': _uuid(),
      'field_name': 'estimated_cents',
      'change_group_id': null,
      'schema_version': 1,
      'old_value': null,
      'new_value': {
        'value': 9007199254740993,
        'nested': [9223372036854775807, -9223372036854775808],
      },
      'device_monotonic': '9223372036854775807',
      'device_id': _uuid(),
      'plan_member_id': alias,
      'created_at': '2026-10-20T00:00:00.000Z',
    }),
  );
  final first = await transport.push(planId, events);
  expect(first.accepted, {events[0].id: 1, events[1].id: 2});
  expect(first.highWater, 2);
  final retry = await transport.push(planId, events);
  expect(retry.accepted, first.accepted);
  expect(retry.highWater, first.highWater);
  final page1 = await transport.pull(planId, cursor: 0, limit: 1);
  expect(page1.rows.single.id, events[0].id);
  expect(page1.rows.single.data['new_value'], events[0].data['new_value']);
  expect(page1.rows.single.deviceMonotonic, 9223372036854775807);
  expect(page1.rows.single.serverTimestamp, 1);
  expect(page1.nextCursor, 1);
  expect(page1.hasMore, isTrue);
  final page2 = await transport.pull(
    planId,
    cursor: page1.nextCursor,
    limit: 1,
  );
  expect(page2.rows.single.id, events[1].id);
  expect(page2.rows.single.data['new_value'], events[1].data['new_value']);
  expect(page2.nextCursor, 2);
  expect(page2.hasMore, isFalse);
  final empty = await transport.pull(
    planId,
    cursor: page2.nextCursor,
    limit: 1,
  );
  expect(empty.rows, isEmpty);
  expect(empty.nextCursor, 2);
  expect(empty.hasMore, isFalse);
  await expectLater(
    transport.pull(_uuid(), cursor: 0),
    throwsA(
      isA<SyncTransportException>().having((e) => e.statusCode, 'status', 403),
    ),
  );
  if (boundaryCounter != null || boundaryGroup != null) {
    // Commit through a direct authorized Edge call first, bypassing the Dart
    // decoder, then exercise the production transport reader over that row.
    final wire = <String, Object?>{
      ...events.first.toPushJson(),
      'id': _uuid(),
      'device_monotonic': ?boundaryCounter,
      'change_group_id': ?boundaryGroup,
    };
    final accepted = await post('/functions/v1/sync_push', {
      'protocol_version': {'major': 1, 'minor': 0},
      'plan_id': planId,
      'rows': [wire],
    }, token: token);
    expect(accepted['server_ts_high'], '3');
    final boundaryPage = await transport.pull(planId, cursor: 2, limit: 1);
    expect(boundaryPage.rows.single.id, wire['id']);
    expect(
      boundaryPage.rows.single.data['device_monotonic'],
      wire['device_monotonic'],
    );
    expect(
      boundaryPage.rows.single.data['change_group_id'],
      wire['change_group_id'],
    );
    expect(boundaryPage.nextCursor, 3);
    expect(boundaryPage.hasMore, isFalse);
    // Outbound decoding/push also follows the same approved contract.
    final source = SyncEvent.fromJson(wire);
    expect((await transport.push(planId, [source])).accepted[source.id], 3);
  }
}
