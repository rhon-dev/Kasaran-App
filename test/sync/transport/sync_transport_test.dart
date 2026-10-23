import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

class _Sessions implements SyncSessionSource {
  SyncAuthSession? current = const SyncAuthSession(
    userId: 'synthetic-user',
    marker: Object(),
    accessToken: 'synthetic-bearer-A',
  );
  int captures = 0;
  void Function(int)? afterCapture;
  @override
  SyncAuthSession? capture() {
    final result = current;
    afterCapture?.call(++captures);
    return result;
  }
}

SyncAuthSession _replacement(String userId, String token) =>
    SyncAuthSession(userId: userId, marker: Object(), accessToken: token);

Future<void> reply(HttpRequest request, Object body, {int status = 200}) async {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

class _LateClient implements HttpClient {
  final entered = Completer<void>();
  final pending = Completer<HttpClientRequest>();
  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    entered.complete();
    return pending.future;
  }

  @override
  set connectionTimeout(Duration? value) {}
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LateRequest implements HttpClientRequest {
  int aborted = 0;
  int headerReads = 0;
  @override
  set followRedirects(bool value) {}
  @override
  HttpHeaders get headers {
    headerReads++;
    throw StateError('Credentials must not be attached after timeout');
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late HttpServer server;
  late _Sessions sessions;
  late HttpSyncTransport transport;
  late List<Map<String, Object?>> requests;
  late Future<void> Function(HttpRequest) handler;

  setUp(() async {
    sessions = _Sessions();
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    transport = HttpSyncTransport(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      anonKey: 'synthetic-anon',
      sessions: sessions,
      maxAttempts: 1,
    );
    handler = (request) async {
      if (request.uri.path.endsWith('sync_push')) {
        await reply(request, {
          'protocol_version': {'major': 1, 'minor': 0},
          'accepted': [
            {'id': eventId, 'server_ts': '1'},
          ],
          'server_ts_high': '1',
        });
      } else {
        await reply(request, {
          'protocol_version': {'major': 1, 'minor': 0},
          'rows': [
            {...wireEvent(), 'server_ts': '1'},
          ],
          'next_cursor': '1',
          'has_more': false,
        });
      }
    };
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add({
        'method': request.method,
        'path': request.uri.path,
        'authorization': request.headers.value('Authorization'),
        'apikey': request.headers.value('apikey'),
        'body': body,
      });
      await handler(request);
    });
  });
  tearDown(() async {
    transport.close();
    await server.close(force: true);
  });

  test(
    'real HTTP uses versioned POST for both operations with exact integers',
    () async {
      final event = SyncEvent.fromJson(wireEvent());
      final pushed = await transport.push(planId, [event]);
      expect(pushed.accepted[eventId], 1);
      final pulled = await transport.pull(planId, cursor: 0, limit: 1);
      expect(pulled.rows.single.id, eventId);
      expect(requests.map((row) => row['method']), ['POST', 'POST']);
      expect(requests.map((row) => row['path']), [
        '/functions/v1/sync_push',
        '/functions/v1/sync_pull',
      ]);
      expect(requests.first['authorization'], 'Bearer synthetic-bearer-A');
      expect(requests.first['apikey'], 'synthetic-anon');
      final body =
          jsonDecode(requests.first['body']! as String) as Map<String, dynamic>;
      expect(body['protocol_version'], {'major': 1, 'minor': 0});
      final sent = (body['rows'] as List).single as Map<String, dynamic>;
      expect(sent.containsKey('server_ts'), isFalse);
      expect(sent['device_monotonic'], '9223372036854775807');
      expect(requests.first['body'], contains('9007199254740993'));
      final pullBody =
          jsonDecode(requests.last['body']! as String) as Map<String, dynamic>;
      expect(pullBody['cursor'], '0');
      expect(pullBody['limit'], 1);
    },
  );

  test('matching admitted account binding sends the original event', () async {
    final admitted = sessions.current!;
    final result = await transport.push(
      planId,
      [SyncEvent.fromJson(wireEvent())],
      requiredSession: SyncSessionBinding(
        userId: admitted.userId,
        marker: admitted.marker,
      ),
    );
    expect(result.accepted[eventId], 1);
    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single['body']! as String), {
      'protocol_version': {'major': 1, 'minor': 0},
      'plan_id': planId,
      'rows': [wireEvent()],
    });
  });

  test(
    'bound push rejects same-user replacement after HTTP admission',
    () async {
      final admitted = sessions.current!;
      handler = (request) async {
        sessions.current = _replacement(admitted.userId, 'synthetic-bearer-B');
        await reply(request, {
          'protocol_version': {'major': 1, 'minor': 0},
          'accepted': [
            {'id': eventId, 'server_ts': '1'},
          ],
          'server_ts_high': '1',
        });
      };
      await expectLater(
        transport.push(
          planId,
          [SyncEvent.fromJson(wireEvent())],
          requiredSession: SyncSessionBinding(
            userId: admitted.userId,
            marker: admitted.marker,
          ),
        ),
        throwsA(
          isA<SyncTransportException>().having(
            (error) => error.code,
            'code',
            'session_changed',
          ),
        ),
      );
      expect(requests, hasLength(1));
    },
  );

  test('different admitted account cannot use transport credentials', () async {
    await expectLater(
      transport.push(
        planId,
        [SyncEvent.fromJson(wireEvent())],
        requiredSession: SyncSessionBinding(
          userId: 'another-user',
          marker: sessions.current!.marker,
        ),
      ),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.code,
          'code',
          'session_changed',
        ),
      ),
    );
    expect(requests, isEmpty);
  });

  test('same-user different admitted marker cannot send queued data', () async {
    await expectLater(
      transport.push(
        planId,
        [SyncEvent.fromJson(wireEvent())],
        requiredSession: SyncSessionBinding(
          userId: sessions.current!.userId,
          marker: Object(),
        ),
      ),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.code,
          'code',
          'session_changed',
        ),
      ),
    );
    expect(requests, isEmpty);
  });

  test(
    'matching pull binding preserves the exact requested page envelope',
    () async {
      final admitted = sessions.current!;
      final page = await transport.pull(
        planId,
        cursor: 0,
        limit: 1,
        requiredSession: SyncSessionBinding(
          userId: admitted.userId,
          marker: admitted.marker,
        ),
      );
      expect(page.rows.single.id, eventId);
      expect(jsonDecode(requests.single['body']! as String), {
        'protocol_version': {'major': 1, 'minor': 0},
        'plan_id': planId,
        'cursor': '0',
        'limit': 1,
      });
    },
  );

  for (final mismatch in ['user', 'marker']) {
    test('pull binding $mismatch mismatch sends no HTTP request', () async {
      final admitted = sessions.current!;
      await expectLater(
        transport.pull(
          planId,
          cursor: 0,
          requiredSession: SyncSessionBinding(
            userId: mismatch == 'user' ? 'another-user' : admitted.userId,
            marker: mismatch == 'marker' ? Object() : admitted.marker,
          ),
        ),
        throwsA(
          isA<SyncTransportException>().having(
            (error) => error.code,
            'code',
            'session_changed',
          ),
        ),
      );
      expect(requests, isEmpty);
    });
  }

  test(
    'bound pull suppresses response after same-user session replacement',
    () async {
      final admitted = sessions.current!;
      handler = (request) async {
        sessions.current = _replacement(admitted.userId, 'synthetic-bearer-B');
        await reply(request, {
          'protocol_version': {'major': 1, 'minor': 0},
          'rows': [
            {...wireEvent(), 'server_ts': '1'},
          ],
          'next_cursor': '1',
          'has_more': false,
        });
      };
      await expectLater(
        transport.pull(
          planId,
          cursor: 0,
          requiredSession: SyncSessionBinding(
            userId: admitted.userId,
            marker: admitted.marker,
          ),
        ),
        throwsA(
          isA<SyncTransportException>().having(
            (error) => error.code,
            'code',
            'session_changed',
          ),
        ),
      );
      expect(requests, hasLength(1));
    },
  );

  test('missing verified session sends no HTTP request', () async {
    sessions.current = null;
    await expectLater(
      transport.pull(planId, cursor: 0),
      throwsA(isA<SyncTransportException>()),
    );
    expect(requests, isEmpty);
  });

  test(
    'same-user marker replacement during HTTP suppresses the response',
    () async {
      handler = (request) async {
        sessions.current = _replacement('synthetic-user', 'synthetic-bearer-B');
        await reply(request, {
          'protocol_version': {'major': 1, 'minor': 0},
          'rows': <Object?>[],
          'next_cursor': '0',
          'has_more': false,
        });
      };
      await expectLater(
        transport.pull(planId, cursor: 0),
        throwsA(
          isA<SyncTransportException>().having(
            (error) => error.code,
            'code',
            'session_changed',
          ),
        ),
      );
    },
  );

  test(
    'replacement after the final exchange check still suppresses the result',
    () async {
      var scheduled = false;
      sessions.afterCapture = (_) {
        if (requests.isNotEmpty && !scheduled) {
          scheduled = true;
          // Replace immediately after capture's snapshot, before public delivery.
          sessions.current = _replacement(
            'synthetic-user',
            'synthetic-bearer-B',
          );
        }
      };
      await expectLater(
        transport.push(planId, [SyncEvent.fromJson(wireEvent())]),
        throwsA(isA<SyncTransportException>()),
      );
    },
  );

  test(
    'transient retry keeps the exact request and stops after acceptance',
    () async {
      transport.close();
      final waits = <Duration>[];
      transport = HttpSyncTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic-anon',
        sessions: sessions,
        delay: (duration) async => waits.add(duration),
      );
      handler = (request) async {
        if (requests.length < 3) {
          await reply(request, {
            'private': 'never expose this payload',
          }, status: 503);
        } else {
          await reply(request, {
            'protocol_version': {'major': 1, 'minor': 0},
            'accepted': [
              {'id': eventId, 'server_ts': '4'},
            ],
            'server_ts_high': '4',
          });
        }
      };
      final result = await transport.push(planId, [
        SyncEvent.fromJson(wireEvent()),
      ]);
      expect(result.accepted[eventId], 4);
      expect(requests.length, 3);
      expect(requests.map((row) => row['body']).toSet(), hasLength(1));
      expect(waits, [
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 200),
      ]);
    },
  );

  test('A to B to A during retry wait cannot reuse the old request', () async {
    transport.close();
    transport = HttpSyncTransport(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      anonKey: 'synthetic-anon',
      sessions: sessions,
      delay: (_) async {
        sessions.current = _replacement('other-user', 'synthetic-bearer-B');
        sessions.current = _replacement(
          'synthetic-user',
          'synthetic-bearer-A2',
        );
      },
    );
    handler = (request) =>
        reply(request, {'private': 'not logged'}, status: 503);
    await expectLater(
      transport.pull(planId, cursor: 0),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.code,
          'code',
          'session_changed',
        ),
      ),
    );
    expect(requests, hasLength(1));
  });

  test(
    'retry exhaustion is bounded and never exposes raw response data',
    () async {
      transport.close();
      transport = HttpSyncTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic-anon',
        sessions: sessions,
        delay: (_) async {},
      );
      handler = (request) =>
          reply(request, {'private': 'sensitive-financial-body'}, status: 503);
      try {
        await transport.pull(planId, cursor: 0);
        fail('Unavailable server was accepted');
      } on SyncTransportException catch (error) {
        expect(error.code, 'temporarily_unavailable');
        expect(error.toString(), isNot(contains('sensitive-financial-body')));
        expect(error.toString(), isNot(contains('synthetic-bearer-A')));
      }
      expect(requests, hasLength(3));
    },
  );

  for (final status in [400, 401, 403]) {
    test('permanent HTTP $status is not retried', () async {
      handler = (request) =>
          reply(request, {'private': 'secret error'}, status: status);
      await expectLater(
        transport.pull(planId, cursor: 0),
        throwsA(
          isA<SyncTransportException>().having(
            (error) => error.statusCode,
            'status',
            status,
          ),
        ),
      );
      expect(requests, hasLength(1));
    });
  }

  test('unsupported major gives typed update-required without retry', () async {
    handler = (request) => reply(request, {
      'error': 'unsupported_protocol',
      'min_supported_build': 17,
    }, status: 426);
    await expectLater(
      transport.pull(planId, cursor: 0),
      throwsA(
        isA<SyncUpdateRequired>().having(
          (error) => error.minSupportedBuild,
          'minimum build',
          17,
        ),
      ),
    );
    expect(requests, hasLength(1));
  });

  test('redirect cannot forward the bearer to another origin', () async {
    var redirected = 0;
    final other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => other.close(force: true));
    other.listen((request) async {
      redirected++;
      await request.response.close();
    });
    handler = (request) async {
      request.response.statusCode = 303;
      request.response.headers.set(
        'Location',
        'http://127.0.0.1:${other.port}/stolen',
      );
      await request.response.close();
    };
    await expectLater(
      transport.pull(planId, cursor: 0),
      throwsA(isA<SyncTransportException>()),
    );
    expect(redirected, 0);
    expect(requests, hasLength(1));
  });

  test('finite request timeout aborts a stalled response', () async {
    transport.close();
    transport = HttpSyncTransport(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      anonKey: 'synthetic-anon',
      sessions: sessions,
      maxAttempts: 1,
      timeout: const Duration(milliseconds: 50),
    );
    handler = (_) async {};
    await expectLater(
      transport.pull(planId, cursor: 0),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.code,
          'code',
          'temporarily_unavailable',
        ),
      ),
    );
    expect(requests, hasLength(1));
  });

  test('oversize response is bounded before JSON parsing', () async {
    transport.close();
    transport = HttpSyncTransport(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      anonKey: 'synthetic-anon',
      sessions: sessions,
      maxResponseBytes: 32,
    );
    handler = (request) =>
        reply(request, {'private': List.filled(1000, 'x').join()});
    await expectLater(
      transport.pull(planId, cursor: 0),
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.code,
          'code',
          'response_too_large',
        ),
      ),
    );
    expect(requests, hasLength(1));
  });

  test(
    'invalid configuration and closed client cannot send credentials',
    () async {
      for (final url in [
        'http://remote.example',
        'https://example.test?secret=1',
        'https://user:secret@example.test',
        'https://example.test/path',
      ]) {
        expect(
          () => HttpSyncTransport(
            baseUrl: Uri.parse(url),
            anonKey: 'synthetic-anon',
            sessions: sessions,
          ),
          throwsA(isA<SyncTransportException>()),
        );
      }
      transport.close();
      await expectLater(
        transport.pull(planId, cursor: 0),
        throwsA(isA<SyncTransportException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'late socket setup is aborted without attaching credentials after timeout',
    () async {
      transport.close();
      final client = _LateClient();
      transport = HttpSyncTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic-anon',
        sessions: sessions,
        client: client,
        maxAttempts: 1,
        timeout: const Duration(milliseconds: 20),
      );
      final pulling = transport.pull(planId, cursor: 0);
      await client.entered.future;
      await expectLater(pulling, throwsA(isA<SyncTransportException>()));
      final late = _LateRequest();
      client.pending.complete(late);
      await Future<void>.delayed(Duration.zero);
      expect(late.aborted, 1);
      expect(late.headerReads, 0);
    },
  );

  test('unexpected HTTP implementation errors are sanitized', () async {
    transport.close();
    final client = _LateClient();
    transport = HttpSyncTransport(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      anonKey: 'synthetic-anon',
      sessions: sessions,
      client: client,
      maxAttempts: 1,
    );
    final pulling = transport.pull(planId, cursor: 0);
    await client.entered.future;
    client.pending.completeError(
      StateError('synthetic-bearer-A private-financial-payload'),
    );
    await expectLater(
      pulling,
      throwsA(
        isA<SyncTransportException>().having(
          (error) => error.toString(),
          'sanitized message',
          isNot(contains('private-financial-payload')),
        ),
      ),
    );
  });

  test(
    'session change during socket setup aborts before attaching credentials',
    () async {
      transport.close();
      final client = _LateClient();
      transport = HttpSyncTransport(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        anonKey: 'synthetic-anon',
        sessions: sessions,
        client: client,
        maxAttempts: 1,
      );
      final pulling = transport.pull(planId, cursor: 0);
      await client.entered.future;
      sessions.current = _replacement('synthetic-user', 'synthetic-bearer-B');
      final late = _LateRequest();
      client.pending.complete(late);
      await expectLater(pulling, throwsA(isA<SyncTransportException>()));
      expect(late.aborted, 1);
      expect(late.headerReads, 0);
    },
  );
}
