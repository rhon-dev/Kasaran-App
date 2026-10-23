// Requires exclusive disposable service handoff; never starts/applies services.
@Tags(['local_supabase'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kasaran/sync/replay/replay_engine.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

String _uuid() {
  final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 0x70;
  bytes[8] = (bytes[8] & 63) | 0x80;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

final class _Sessions implements SyncSessionSource {
  _Sessions(this.session);
  final SyncAuthSession session;
  @override
  SyncAuthSession capture() => session;
}

void main() {
  test(
    'actual Edge preserves exact source envelopes and replays acknowledged or pending copies',
    () async {
      const disposable =
          '/Users/ahronjanl.rafaelahron.0804icloudcom/.hermes/cache/scratch/kasaran_p08_disposable';
      final workdir = Platform.environment['SUPABASE_WORKDIR'];
      expect(workdir, disposable);
      final config = await File('$workdir/supabase/config.toml').readAsString();
      expect(
        RegExp(
          r'^project_id\s*=\s*"kasaran_p08_disposable"\s*$',
          multiLine: true,
        ).hasMatch(config),
        isTrue,
      );
      final status = await Process.run('supabase', [
        'status',
        '-o',
        'json',
      ], workingDirectory: workdir);
      expect(
        status.exitCode,
        0,
        reason: 'Parent must hand off running disposable services',
      );
      final settings =
          jsonDecode(status.stdout as String) as Map<String, dynamic>;
      final base = Uri.parse(settings['API_URL'] as String);
      expect(base.scheme, 'http');
      expect(base.host, '127.0.0.1');
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

      final email = 'replay-wire-${_uuid()}@example.test';
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
      final plan = _uuid();
      await post('/rest/v1/rpc/create_plan', {
        'p_id': plan,
        'p_wedding_date': '2027-06-01',
        'p_total_budget_cents': 100000,
        'p_guest_cap': 20,
        'p_region_code': 'PH-NCR',
        'p_ruleset_version': 'synthetic',
        'p_driving_rsvp_status': 'unknown',
      }, token: token);
      final aliases = await client.get(
        base.resolve(
          '/rest/v1/plan_member_aliases?select=plan_member_id&plan_id=eq.$plan',
        ),
        headers: {'apikey': anon, 'Authorization': 'Bearer $token'},
      );
      expect(aliases.statusCode, 200);
      final alias =
          ((jsonDecode(aliases.body) as List).single as Map)['plan_member_id'];
      final transport = HttpSyncTransport(
        baseUrl: base,
        anonKey: anon,
        sessions: _Sessions(
          SyncAuthSession(
            userId: user['id'] as String,
            marker: Object(),
            accessToken: token,
          ),
        ),
      );
      addTearDown(transport.close);
      final device = _uuid();
      final pending = <SyncEvent>[];
      for (final created in [
        '2026-10-20T00:00:00.123Z',
        '2026-10-20T00:00:00.123456Z',
        '2026-10-20T00:00:00Z',
      ]) {
        pending.add(
          SyncEvent.fromJson({
            'id': _uuid(),
            'entity_id': _uuid(),
            'plan_id': plan,
            'entity_type': 'ledger_entries',
            'field_name': 'notes',
            'change_group_id': null,
            'schema_version': 1,
            'old_value': null,
            'new_value': 'synthetic source',
            'device_monotonic': '${pending.length + 1}',
            'device_id': device,
            'plan_member_id': alias,
            'created_at': created,
            'future_envelope': {'integer': 9007199254740993, 'null': null},
          }),
        );
      }
      final ack = await transport.push(plan, pending);
      final page = await transport.pull(plan, cursor: 0);
      expect(page.rows, hasLength(pending.length));
      expect(page.hasMore, isFalse);
      final acknowledged = <SyncEvent>[];
      for (var i = 0; i < pending.length; i++) {
        final source = pending[i];
        final actual = page.rows[i];
        final expected = {
          ...source.data,
          'server_ts': '${ack.accepted[source.id]}',
        };
        expect(
          actual.data,
          expected,
          reason: 'Original envelope must survive real SQL/Edge unchanged',
        );
        acknowledged.add(
          SyncEvent.fromJson(expected, requireServerTimestamp: true),
        );
      }
      final merged = ReplayEngine.rebuild([...acknowledged, ...page.rows]);
      final reversed = ReplayEngine.rebuild([
        ...page.rows.reversed,
        ...acknowledged.reversed,
      ]);
      expect(jsonEncode(merged.toJson()), jsonEncode(reversed.toJson()));
      final reconciled = ReplayEngine.rebuild(page.rows, provisional: pending);
      expect(reconciled.provisionalEventIds, isEmpty);
      expect(reconciled.records, hasLength(pending.length));
      expect(reconciled.retainedEnvelopes, hasLength(pending.length * 2));
      for (final difference in <Map<String, Object?>>[
        {'created_at': '2026-10-20T00:00:00.123001Z'},
        {'new_value': 'changed'},
        {'server_ts': '${page.rows.first.serverTimestamp! + 1}'},
      ]) {
        final changed = SyncEvent.fromJson({
          ...page.rows.first.data,
          ...difference,
        }, requireServerTimestamp: true);
        expect(
          () => ReplayEngine.rebuild([page.rows.first, changed]),
          throwsA(isA<ReplayException>()),
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
