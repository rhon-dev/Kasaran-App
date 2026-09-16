// test/api/contract/sync_contract_test.dart
//
// API contract tests for the sync_push and sync_pull Edge Function stubs.
//
// TC-API-01: Unauthenticated request → 401.
// TC-API-02: Well-formed authenticated request → 200 with correct shape.
// TC-API-04: Malformed push body rejected → 400.
// TC-API-05: Malformed pull query rejected → 400.
// SEC-03: Issued access token exp − iat ≤ 3600 s.
//
// Requires `supabase start`. Tests call `markTestSkipped` inside the body
// when the local instance is not reachable — this correctly terminates the
// test body on offline machines without counting the test as a failure.
// In CI the contract-tests job starts `supabase start` first.
//
// TC-API-03 (idempotency) is deferred to phase 08.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const String _baseUrl = 'http://127.0.0.1:54321';
const String _fnPath = '/functions/v1';

// ignore_for_file: do_not_use_environment
const String _anonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9'
      '.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
);

const String _srKey = String.fromEnvironment(
  'SUPABASE_SERVICE_ROLE_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0'
      '.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU',
);

const String _email = 'contract-test@kasaran-local.test';
const String _pass = 'ContractTest123!';

const String _planId   = '01938000-0000-7000-8000-000000000001';
const String _entityId = '01938000-0000-7000-8000-000000000002';
const String _deviceId = '01938000-0000-7000-8000-000000000003';
const String _actorId  = '01938000-0000-7000-8000-000000000004';
const String _rowId    = '01938000-0000-7000-8000-000000000005';

const String _offlineMsg =
    'Local Supabase not running — `supabase start` to execute';

// ---------------------------------------------------------------------------
// Module-level state set by setUpAll
// ---------------------------------------------------------------------------
bool _online = false;
String _tok = '';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Uri _fn(String name) => Uri.parse('$_baseUrl$_fnPath/$name');

Map<String, String> _anon() => <String, String>{
      'apikey': _anonKey,
      'Content-Type': 'application/json',
    };

Map<String, String> _auth() => <String, String>{
      'apikey': _anonKey,
      'Authorization': 'Bearer $_tok',
      'Content-Type': 'application/json',
    };

/// Returns true when the local Supabase Auth service responds within 10 s.
Future<bool> _isRunning() async {
  try {
    final r = await http
        .get(
          Uri.parse('$_baseUrl/auth/v1/health'),
          headers: <String, String>{'apikey': _anonKey},
        )
        .timeout(const Duration(seconds: 10));
    return r.statusCode < 500;
  } catch (_) {
    return false;
  }
}

/// Skips the current test if Supabase is not running.
/// `markTestSkipped` throws _SkipException, immediately terminating the body.
void skipIfOffline() {
  if (!_online) markTestSkipped(_offlineMsg);
}

/// Creates (or signs in as) the contract-test user and returns its JWT.
Future<String> _acquireToken() async {
  final signIn = await http.post(
    Uri.parse('$_baseUrl/auth/v1/token?grant_type=password'),
    headers: <String, String>{
      'apikey': _anonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, String>{'email': _email, 'password': _pass}),
  );

  if (signIn.statusCode == 200) {
    return (jsonDecode(signIn.body) as Map<String, dynamic>)['access_token']
        as String;
  }

  // User doesn't exist yet — create via admin endpoint.
  final create = await http.post(
    Uri.parse('$_baseUrl/auth/v1/admin/users'),
    headers: <String, String>{
      'apikey': _srKey,
      'Authorization': 'Bearer $_srKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, Object>{
      'email': _email,
      'password': _pass,
      'email_confirm': true,
    }),
  );
  expect(create.statusCode, anyOf(200, 201),
      reason: 'create user failed: ${create.body}');

  final signIn2 = await http.post(
    Uri.parse('$_baseUrl/auth/v1/token?grant_type=password'),
    headers: <String, String>{
      'apikey': _anonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, String>{'email': _email, 'password': _pass}),
  );
  expect(signIn2.statusCode, 200,
      reason: 'sign-in after create failed: ${signIn2.body}');
  return (jsonDecode(signIn2.body) as Map<String, dynamic>)['access_token']
      as String;
}

Map<String, dynamic> _jwtPayload(String token) {
  final parts = token.split('.');
  final padded = parts[1].padRight(
    parts[1].length + (4 - parts[1].length % 4) % 4,
    '=',
  );
  return jsonDecode(utf8.decode(base64Url.decode(padded)))
      as Map<String, dynamic>;
}

Map<String, Object> _pushBody({int rows = 1}) => <String, Object>{
      'plan_id': _planId,
      'rows': List<Map<String, Object?>>.generate(
        rows,
        (i) => <String, Object?>{
          'id': '01938000-0000-7000-8000-${(i + 10).toString().padLeft(12, '0')}',
          'plan_id': _planId,
          'entity_type': 'ledger_entry',
          'entity_id': _entityId,
          'field_name': 'estimated_cents',
          'old_value': null,
          'new_value': 100000,
          'device_monotonic': i,
          'device_id': _deviceId,
          'actor_user_id': _actorId,
          'created_at': '2026-09-14T00:00:00.000Z',
        },
      ),
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  setUpAll(() async {
    _online = await _isRunning();
    if (!_online) return;
    _tok = await _acquireToken();
  });

  // ─── TC-API-01: Auth enforcement ─────────────────────────────────────────
  group('TC-API-01 — Auth enforcement', () {
    test('sync_push: no Authorization → 401', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: _anon(), body: jsonEncode(_pushBody()));
      expect(r.statusCode, 401);
    });

    test('sync_push: invalid bearer → 401', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: <String, String>{
            'apikey': _anonKey,
            'Authorization': 'Bearer not.a.real.token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(_pushBody()));
      expect(r.statusCode, 401);
    });

    test('sync_pull: no Authorization → 401', () async {
      skipIfOffline();
      final r = await http.get(
        _fn('sync_pull').replace(queryParameters: <String, String>{
          'plan_id': _planId,
          'since_server_ts': '0',
        }),
        headers: _anon(),
      );
      expect(r.statusCode, 401);
    });

    test('sync_pull: invalid bearer → 401', () async {
      skipIfOffline();
      final r = await http.get(
        _fn('sync_pull').replace(queryParameters: <String, String>{
          'plan_id': _planId,
          'since_server_ts': '0',
        }),
        headers: <String, String>{
          'apikey': _anonKey,
          'Authorization': 'Bearer invalid.token.here',
          'Content-Type': 'application/json',
        },
      );
      expect(r.statusCode, 401);
    });
  });

  // ─── TC-API-02: Authenticated success ────────────────────────────────────
  group('TC-API-02 — Authenticated success', () {
    test('sync_push: 200 with accepted + server_ts_high', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: _auth(), body: jsonEncode(_pushBody()));
      expect(r.statusCode, 200);
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      expect(b['accepted'], isA<List<dynamic>>());
      expect(b.containsKey('server_ts_high'), isTrue);
    });

    test('sync_push: empty rows → 200', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: _auth(),
          body: jsonEncode(<String, Object>{
            'plan_id': _planId,
            'rows': <Map<String, dynamic>>[],
          }));
      expect(r.statusCode, 200);
    });

    test('sync_pull: 200 with rows + next_cursor + has_more', () async {
      skipIfOffline();
      final r = await http.get(
        _fn('sync_pull').replace(queryParameters: <String, String>{
          'plan_id': _planId,
          'since_server_ts': '0',
        }),
        headers: _auth(),
      );
      expect(r.statusCode, 200);
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      expect(b['rows'], isA<List<dynamic>>());
      expect(b.containsKey('next_cursor'), isTrue);
      expect(b.containsKey('has_more'), isTrue);
    });

    test('sync_pull: phase-04 stub returns empty rows', () async {
      skipIfOffline();
      final r = await http.get(
        _fn('sync_pull').replace(queryParameters: <String, String>{
          'plan_id': _planId,
          'since_server_ts': '0',
        }),
        headers: _auth(),
      );
      expect(r.statusCode, 200);
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      expect((b['rows'] as List<dynamic>).isEmpty, isTrue,
          reason: 'Phase-04 stub must return empty rows');
      expect(b['has_more'], isFalse);
    });
  });

  // ─── TC-API-04: Malformed push rejected ──────────────────────────────────
  group('TC-API-04 — Malformed push rejected', () {
    test('invalid JSON → 400', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: _auth(), body: 'not json');
      expect(r.statusCode, 400);
    });

    test('missing plan_id → 400', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: _auth(),
          body: jsonEncode(<String, Object>{
            'rows': <Map<String, dynamic>>[],
          }));
      expect(r.statusCode, 400);
    });

    test('non-UUID plan_id → 400', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: _auth(),
          body: jsonEncode(<String, Object>{
            'plan_id': 'not-a-uuid',
            'rows': <Map<String, dynamic>>[],
          }));
      expect(r.statusCode, 400);
    });

    test('row with client server_ts (D1 violation) → 400', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: _auth(),
          body: jsonEncode(<String, Object>{
            'plan_id': _planId,
            'rows': <Map<String, Object?>>[
              <String, Object?>{
                'id': _rowId,
                'plan_id': _planId,
                'entity_type': 'ledger_entry',
                'entity_id': _entityId,
                'field_name': 'estimated_cents',
                'old_value': null,
                'new_value': 100000,
                'device_monotonic': 1,
                'device_id': _deviceId,
                'actor_user_id': _actorId,
                'created_at': '2026-09-14T00:00:00.000Z',
                'server_ts': 999, // MUST be rejected — D1
              },
            ],
          }));
      expect(r.statusCode, 400);
    });

    test('row plan_id mismatch → 400', () async {
      skipIfOffline();
      final r = await http.post(_fn('sync_push'),
          headers: _auth(),
          body: jsonEncode(<String, Object>{
            'plan_id': _planId,
            'rows': <Map<String, Object?>>[
              <String, Object?>{
                'id': _rowId,
                'plan_id': '01938000-0000-7000-8000-999999999999',
                'entity_type': 'ledger_entry',
                'entity_id': _entityId,
                'field_name': 'estimated_cents',
                'old_value': null,
                'new_value': 100000,
                'device_monotonic': 1,
                'device_id': _deviceId,
                'actor_user_id': _actorId,
                'created_at': '2026-09-14T00:00:00.000Z',
              },
            ],
          }));
      expect(r.statusCode, 400);
    });

    test('GET to sync_push → 405', () async {
      skipIfOffline();
      final r = await http.get(_fn('sync_push'), headers: _auth());
      expect(r.statusCode, 405);
    });
  });

  // ─── TC-API-05: Malformed pull query rejected ─────────────────────────────
  group('TC-API-05 — Malformed pull query rejected', () {
    test('missing plan_id → 400', () async {
      skipIfOffline();
      final r = await http.get(
        _fn('sync_pull').replace(
          queryParameters: <String, String>{'since_server_ts': '0'},
        ),
        headers: _auth(),
      );
      expect(r.statusCode, 400);
    });

    test('non-UUID plan_id → 400', () async {
      skipIfOffline();
      final r = await http.get(
        _fn('sync_pull').replace(queryParameters: <String, String>{
          'plan_id': 'not-a-uuid',
          'since_server_ts': '0',
        }),
        headers: _auth(),
      );
      expect(r.statusCode, 400);
    });

    test('missing since_server_ts → 400', () async {
      skipIfOffline();
      final r = await http.get(
        _fn('sync_pull').replace(
          queryParameters: <String, String>{'plan_id': _planId},
        ),
        headers: _auth(),
      );
      expect(r.statusCode, 400);
    });

    test('non-integer since_server_ts → 400', () async {
      skipIfOffline();
      final r = await http.get(
        _fn('sync_pull').replace(queryParameters: <String, String>{
          'plan_id': _planId,
          'since_server_ts': 'not-a-number',
        }),
        headers: _auth(),
      );
      expect(r.statusCode, 400);
    });

    test('POST to sync_pull → 405', () async {
      skipIfOffline();
      final r = await http.post(
        _fn('sync_pull').replace(queryParameters: <String, String>{
          'plan_id': _planId,
          'since_server_ts': '0',
        }),
        headers: _auth(),
        body: '{}',
      );
      expect(r.statusCode, 405);
    });
  });

  // ─── SEC-03: Token TTL ────────────────────────────────────────────────────
  group('SEC-03 — Token TTL ≤ 3600 s', () {
    test('exp − iat ≤ 3600 (config.toml jwt_expiry = 3600)', () {
      skipIfOffline();
      final claims = _jwtPayload(_tok);
      final ttl = (claims['exp'] as int) - (claims['iat'] as int);
      expect(ttl, lessThanOrEqualTo(3600),
          reason: 'SEC-03: TTL must be ≤ 3600 s, got ${ttl}s');
    });
  });
}
