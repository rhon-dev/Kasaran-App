import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

const planId = '00000000-0000-4000-8000-000000000001';
const userId = '00000000-0000-4000-8000-000000000002';
const aliasId = '00000000-0000-4000-8000-000000000003';
const deviceId = '00000000-0000-4000-8000-000000000004';
Map<String, Object?> snapshot() => {
  'protocol_version': {'major': 1, 'minor': 0},
  'plan': {
    'id': planId,
    'creator_user_id': userId,
    'wedding_date': '2027-06-01',
    'total_budget_cents': '9223372036854775807',
    'guest_cap': 20,
    'region_code': 'PH-NCR',
    'ceremony_type': null,
    'venue_type': null,
    'reminder_enabled': true,
    'reminder_window_days': 7,
    'reminder_days_before': [7, 1],
    'reminder_overdue': true,
    'ruleset_version': 'synthetic',
    'driving_rsvp_status': 'unknown',
    'is_active': true,
    'setup_completed_at': null,
    'created_at': '2026-10-20T00:00:00.000000Z',
    'deleted_at': null,
  },
  'aliases': [
    {'plan_id': planId, 'plan_member_id': aliasId, 'user_id': userId},
  ],
  'member': {
    'plan_id': planId,
    'user_id': userId,
    'plan_member_id': aliasId,
    'role': 'creator',
    'joined_at': '2026-10-20T00:00:00.000000Z',
  },
};

class Sessions implements SyncSessionSource {
  Sessions() {
    final marker = Object();
    session = SyncAuthSession(
      userId: userId,
      marker: marker,
      accessToken: 'synthetic-secret',
    );
  }

  SyncAuthSession? session;
  @override
  SyncAuthSession? capture() => session;
}

void main() {
  final corruptions = <String, void Function(Map<String, dynamic>)>{
    'foreign plan': (s) => (s['plan'] as Map)['id'] = deviceId,
    'foreign member': (s) => (s['member'] as Map)['user_id'] = deviceId,
    'member different plan': (s) => (s['member'] as Map)['plan_id'] = deviceId,
    'missing alias': (s) => s['aliases'] = <Object?>[],
    'duplicate alias': (s) =>
        (s['aliases'] as List).add((s['aliases'] as List).first),
    'alias user mismatch': (s) =>
        ((s['aliases'] as List).first as Map)['user_id'] = deviceId,
    'alias plan mismatch': (s) =>
        ((s['aliases'] as List).first as Map)['plan_id'] = deviceId,
    'bad role': (s) => (s['member'] as Map)['role'] = 'admin',
    'role creator mismatch': (s) => (s['member'] as Map)['role'] = 'partner',
    'invalid joined date': (s) =>
        (s['member'] as Map)['joined_at'] = '2026-02-30T00:00:00Z',
    'invalid user UUID': (s) =>
        (s['plan'] as Map)['creator_user_id'] = 'private',
    'bad date': (s) => (s['plan'] as Map)['wedding_date'] = '2027-02-30',
    'bad created date': (s) => (s['plan'] as Map)['created_at'] = 'yesterday',
    'bad setup date': (s) => (s['plan'] as Map)['setup_completed_at'] = 2,
    'deleted active plan': (s) =>
        (s['plan'] as Map)['deleted_at'] = '2026-10-20T00:00:00Z',
    'inactive': (s) => (s['plan'] as Map)['is_active'] = false,
    'overflow guest': (s) => (s['plan'] as Map)['guest_cap'] = 2147483648,
    'negative guest': (s) => (s['plan'] as Map)['guest_cap'] = -1,
    'float guest': (s) => (s['plan'] as Map)['guest_cap'] = 2.0,
    'string boolean': (s) => (s['plan'] as Map)['reminder_enabled'] = 'true',
    'invalid window': (s) => (s['plan'] as Map)['reminder_window_days'] = -1,
    'duplicate reminder days': (s) =>
        (s['plan'] as Map)['reminder_days_before'] = [1, 1],
    'float reminder': (s) => (s['plan'] as Map)['reminder_days_before'] = [1.0],
    'invalid ceremony': (s) => (s['plan'] as Map)['ceremony_type'] = 'unknown',
    'invalid venue': (s) => (s['plan'] as Map)['venue_type'] = 'unknown',
    'empty ruleset': (s) => (s['plan'] as Map)['ruleset_version'] = '',
    'empty RSVP': (s) => (s['plan'] as Map)['driving_rsvp_status'] = '',
    'empty region': (s) => (s['plan'] as Map)['region_code'] = '',
  };
  for (final entry in corruptions.entries) {
    test('snapshot refuses ${entry.key}', () {
      final s = jsonDecode(jsonEncode(snapshot())) as Map<String, dynamic>;
      entry.value(s);
      expect(
        () => BootstrapSnapshot.fromJson(s, planId: planId, userId: userId),
        throwsA(anything),
      );
    });
  }
  test('missing any consumed plan column fails closed', () {
    final plan = snapshot()['plan']! as Map<String, Object?>;
    for (final key in plan.keys) {
      final s = jsonDecode(jsonEncode(snapshot())) as Map<String, dynamic>;
      (s['plan'] as Map).remove(key);
      expect(
        () => BootstrapSnapshot.fromJson(s, planId: planId, userId: userId),
        throwsA(anything),
        reason: key,
      );
    }
  });
  test(
    'additive fields ignored and immutable known columns normalized for SQLite',
    () {
      final s = snapshot();
      final plan = s['plan']! as Map<String, Object?>;
      plan['future_grant'] = 'admin';
      final result = BootstrapSnapshot.fromJson(
        s,
        planId: planId,
        userId: userId,
      );
      expect(result.plan.containsKey('future_grant'), isFalse);
      expect(result.plan['reminder_enabled'], 1);
      expect(result.plan['reminder_days_before'], '[7,1]');
      expect(() => result.plan['id'] = deviceId, throwsUnsupportedError);
    },
  );
  for (final mode in ['user mismatch', 'marker mismatch', 'no session']) {
    test('transport $mode refuses before HTTP', () async {
      final sessions = Sessions();
      final binding = SyncSessionBinding(
        userId: userId,
        marker: sessions.session!.marker,
      );
      if (mode == 'user mismatch') {
        sessions.session = SyncAuthSession(
          userId: deviceId,
          marker: binding.marker,
          accessToken: 'private',
        );
      }
      if (mode == 'marker mismatch') {
        final marker = Object();
        sessions.session = SyncAuthSession(
          userId: userId,
          marker: marker,
          accessToken: 'private',
        );
      }
      if (mode == 'no session') sessions.session = null;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      server.listen((r) {
        requests++;
        r.response.close();
      });
      final t = HttpBootstrapTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic',
        sessions: sessions,
        maxAttempts: 1,
      );
      addTearDown(() async {
        t.close();
        await server.close(force: true);
      });
      await expectLater(
        t.fetch(planId, requiredSession: binding),
        throwsA(isA<SyncTransportException>()),
      );
      expect(requests, 0);
    });
  }
  for (final mode in [
    'redirect',
    'overflow',
    'malformed',
    'invalid UTF-8',
    'timeout',
    'cancel',
    'replace during response',
    'refusal',
    'update required',
  ]) {
    test('bounded sanitized HTTP: $mode', () async {
      final sessions = Sessions();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final entered = Completer<void>();
      var requests = 0;
      final t = HttpBootstrapTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic',
        sessions: sessions,
        maxAttempts: 1,
        maxResponseBytes: mode == 'overflow' ? 8 : 20000,
        timeout: mode == 'timeout'
            ? const Duration(milliseconds: 40)
            : const Duration(seconds: 3),
      );
      addTearDown(() async {
        t.close();
        await server.close(force: true);
      });
      server.listen((r) async {
        requests++;
        await r.drain<void>();
        if (mode == 'timeout' || mode == 'cancel') {
          entered.complete();
          return;
        }
        if (mode == 'redirect') {
          r.response.statusCode = 302;
          r.response.headers.set(
            'location',
            'http://127.0.0.1:${server.port}/private',
          );
        }
        if (mode == 'refusal') r.response.statusCode = 403;
        if (mode == 'update required') {
          r.response.statusCode = 426;
          r.response.write(
            '{"error":"unsupported_protocol","min_supported_build":2}',
          );
        } else if (mode == 'malformed') {
          r.response.write('{private');
        } else if (mode == 'invalid UTF-8') {
          r.response.add([0xff]);
        } else {
          r.response.write(jsonEncode(snapshot()));
        }
        if (mode == 'replace during response') {
          final marker = Object();
          sessions.session = SyncAuthSession(
            userId: userId,
            marker: marker,
            accessToken: 'private',
          );
        }
        await r.response.close();
      });
      final pending = t.fetch(
        planId,
        requiredSession: SyncSessionBinding(
          userId: userId,
          marker: sessions.session!.marker,
        ),
      );
      if (mode == 'cancel') {
        await entered.future;
        t.close();
      }
      Object? failure;
      try {
        await pending;
      } catch (e) {
        failure = e;
      }
      expect(failure, isNotNull);
      expect('$failure', isNot(contains('private')));
      expect('$failure', isNot(contains('synthetic-secret')));
      if (mode == 'update required') expect(failure, isA<SyncUpdateRequired>());
      expect(requests, 1);
    });
  }
  for (final mode in ['accept', 'exhaust', 'replace', 'refresh', 'interrupt']) {
    test('bootstrap retry boundary: $mode', () async {
      final sessions = Sessions();
      final admitted = sessions.session!;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bodies = <String>[];
      final tokens = <String?>[];
      final waits = <Duration>[];
      final transport = HttpBootstrapTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic',
        sessions: sessions,
        delay: (duration) async {
          waits.add(duration);
          if (mode == 'interrupt') throw StateError('private');
          if (mode == 'replace' || mode == 'refresh') {
            sessions.session = SyncAuthSession(
              userId: userId,
              marker: mode == 'replace' ? Object() : admitted.marker,
              accessToken: 'synthetic-refreshed',
            );
          }
        },
      );
      addTearDown(() async {
        transport.close();
        await server.close(force: true);
      });
      server.listen((request) async {
        bodies.add(await utf8.decoder.bind(request).join());
        tokens.add(request.headers.value('authorization'));
        if (mode == 'exhaust' || bodies.length < 3) {
          request.response.statusCode = 503;
          request.response.write('private');
        } else {
          request.response.write(jsonEncode(snapshot()));
        }
        await request.response.close();
      });
      final pending = transport.fetch(
        planId,
        requiredSession: SyncSessionBinding(
          userId: userId,
          marker: admitted.marker,
        ),
      );
      if (mode == 'accept' || mode == 'refresh') {
        expect((await pending).member['user_id'], userId);
      } else {
        final code = switch (mode) {
          'replace' => 'session_changed',
          'interrupt' => 'retry_interrupted',
          _ => 'temporarily_unavailable',
        };
        await expectLater(
          pending,
          throwsA(
            isA<SyncTransportException>()
                .having((e) => e.code, 'code', code)
                .having((e) => '$e', 'sanitized', isNot(contains('private'))),
          ),
        );
      }
      final interrupted = mode == 'replace' || mode == 'interrupt';
      expect(bodies, hasLength(interrupted ? 1 : 3));
      expect(bodies.toSet(), hasLength(1));
      expect(waits, [
        const Duration(milliseconds: 100),
        if (!interrupted) const Duration(milliseconds: 200),
      ]);
      expect(tokens.first, 'Bearer synthetic-secret');
      if (mode == 'refresh') {
        expect(tokens.skip(1), everyElement('Bearer synthetic-refreshed'));
      }
    });
  }
  for (final status in [400, 401, 403]) {
    test('bootstrap permanent HTTP $status does not retry', () async {
      final sessions = Sessions();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      final transport = HttpBootstrapTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic',
        sessions: sessions,
        delay: (_) async => fail('Permanent refusal must not back off'),
      );
      addTearDown(() async {
        transport.close();
        await server.close(force: true);
      });
      server.listen((request) async {
        requests++;
        await request.drain<void>();
        request.response.statusCode = status;
        request.response.write('private');
        await request.response.close();
      });
      await expectLater(
        transport.fetch(
          planId,
          requiredSession: SyncSessionBinding(
            userId: userId,
            marker: sessions.session!.marker,
          ),
        ),
        throwsA(
          isA<SyncTransportException>()
              .having((e) => e.code, 'code', 'request_refused')
              .having((e) => e.statusCode, 'status', status),
        ),
      );
      expect(requests, 1);
    });
  }
  test(
    'bootstrap invalid configuration and closed client cannot send',
    () async {
      final sessions = Sessions();
      for (final url in [
        'http://remote.example',
        'https://example.test?private=1',
        'https://user:private@example.test',
        'https://example.test/path',
        'https://example.test/#private',
      ]) {
        expect(
          () => HttpBootstrapTransport(
            baseUrl: Uri.parse(url),
            anonKey: 'synthetic',
            sessions: sessions,
          ),
          throwsA(
            isA<SyncTransportException>().having(
              (e) => e.code,
              'code',
              'invalid_configuration',
            ),
          ),
        );
      }
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      server.listen((request) {
        requests++;
        request.response.close();
      });
      final transport = HttpBootstrapTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic',
        sessions: sessions,
      );
      addTearDown(() => server.close(force: true));
      transport.close();
      await expectLater(
        transport.fetch(
          planId,
          requiredSession: SyncSessionBinding(
            userId: userId,
            marker: sessions.session!.marker,
          ),
        ),
        throwsA(
          isA<SyncTransportException>().having((e) => e.code, 'code', 'closed'),
        ),
      );
      expect(requests, 0);
    },
  );
  test(
    'POST binds exact admitted session and preserves full signed-int64 metadata',
    () async {
      final sessions = Sessions();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final transport = HttpBootstrapTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic-anon',
        sessions: sessions,
      );
      addTearDown(() async {
        transport.close();
        await server.close(force: true);
      });
      server.listen((req) async {
        expect(req.uri.path, '/functions/v1/sync_bootstrap');
        expect(req.method, 'POST');
        expect(req.headers.value('authorization'), 'Bearer synthetic-secret');
        expect(jsonDecode(await utf8.decoder.bind(req).join()), {
          'protocol_version': {'major': 1, 'minor': 0},
          'plan_id': planId,
        });
        req.response.write(jsonEncode(snapshot()));
        await req.response.close();
      });
      final result = await transport.fetch(
        planId,
        requiredSession: SyncSessionBinding(
          userId: userId,
          marker: sessions.session!.marker,
        ),
      );
      expect(result.plan['total_budget_cents'], 9223372036854775807);
      expect(result.member['user_id'], userId);
    },
  );
}
