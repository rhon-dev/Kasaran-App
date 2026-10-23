import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/sync/queue/durable_inbox_puller.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'durable_outbox_pusher_test.dart' as fixture;

Map<String, Object?> event({int stamp = 1, String suffix = '001'}) => {
  'id': '00000000-0000-7000-8000-000000000$suffix',
  'plan_id': fixture.actor.planId,
  'entity_id': '00000000-0000-7000-8000-000000000099',
  'entity_type': 'future_entity',
  'field_name': 'future_group',
  'schema_version': 99,
  'old_value': null,
  'new_value': {'amount': 9007199254740993, 'negative': -9007199254740993},
  'device_id': fixture.actorB.deviceId,
  'device_monotonic': '0',
  'plan_member_id': fixture.actorB.planMemberId,
  'created_at': '2026-10-20T00:00:00Z',
  'server_ts': '$stamp',
  'future': {
    'nested': [9007199254740993, true, null],
  },
};
void main() {
  late Directory dir;
  late File file, bFile;
  late fixture.Keys keys, bKeys;
  late fixture.Identity identity;
  late fixture.LocalIdentity local;
  late AccountStoreCoordinator coordinator;
  late AppDatabase db;
  late sqlite.Database native;
  late fixture.CommitHook commit;
  late HttpServer server;
  late HttpSyncTransport transport;
  late DurableInboxPuller puller;
  late List<Map<String, dynamic>> requests;
  late Future<void> Function(HttpRequest, Map<String, dynamic>) respond;
  late List<String> opened;
  Future<List<Map<String, Object?>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table').get())
          .map((r) => r.data)
          .toList();
  Future<Map<String, Object?>> snapshot() async => {
    for (final t in [
      'plans',
      'ledger_entries',
      'change_log',
      'outbox',
      'sync_state',
      'sync_inbox',
    ])
      t: await rows(t),
  };
  Future<void> reply(
    HttpRequest req,
    List<Map<String, Object?>> events, {
    int? cursor,
    bool more = false,
  }) async {
    req.response.headers.contentType = ContentType.json;
    req.response.write(
      jsonEncode({
        'protocol_version': {'major': 1, 'minor': 0},
        'rows': events,
        'next_cursor':
            '${cursor ?? (events.isEmpty ? 0 : int.parse(events.last['server_ts']! as String))}',
        'has_more': more,
      }),
    );
    await req.response.close();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kasaran-inbox-');
    file = File('${dir.path}/a.sqlite');
    bFile = File('${dir.path}/b.sqlite');
    keys = fixture.Keys();
    bKeys = fixture.Keys();
    identity = fixture.Identity();
    local = fixture.LocalIdentity(identity);
    final a = await EncryptedDatabaseOpener(file, keys).open();
    await fixture.seed(a, fixture.actor);
    await a.close();
    final b = await EncryptedDatabaseOpener(bFile, bKeys).open();
    await fixture.seed(b, fixture.actorB);
    await b.close();
    commit = fixture.CommitHook();
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
    await LocalLedgerWriter(
      db,
      identity: local,
    ).create(fixture.actor, fixture.draft);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = [];
    respond = (req, body) => reply(req, [event()]);
    server.listen((req) async {
      final body =
          jsonDecode(await utf8.decoder.bind(req).join())
              as Map<String, dynamic>;
      requests.add(body);
      await respond(req, body);
    });
    transport = HttpSyncTransport(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      anonKey: 'synthetic-anon',
      sessions: identity,
      maxAttempts: 1,
    );
    puller = DurableInboxPuller(coordinator, transport);
  });
  tearDown(() async {
    transport.close();
    await server.close(force: true);
    await coordinator.close();
    await dir.delete(recursive: true);
  });
  test(
    'accepted full unknown additive raw page and cursor survive encrypted reopen without touching originals',
    () async {
      final before = await snapshot();
      final result = await puller.pullOnce(fixture.actor, limit: 2);
      expect(result.received, 1);
      expect(result.cursor, 1);
      expect(result.hasMore, isFalse);
      expect(requests.single['cursor'], '0');
      expect(requests.single['limit'], 2);
      final retained = (await rows('sync_inbox')).single;
      expect(jsonDecode(retained['raw_event']! as String), event());
      for (final t in ['plans', 'ledger_entries', 'change_log', 'outbox']) {
        expect(await rows(t), before[t]);
      }
      expect((await rows('sync_state')).single, {
        ...(before['sync_state']! as List<Map<String, Object?>>).single,
        'last_pulled_server_ts': 1,
      });
      await coordinator.close();
      final reopened = await EncryptedDatabaseOpener(file, keys).open();
      try {
        expect(
          (await reopened.customSelect('SELECT * FROM sync_inbox').get())
              .single
              .data,
          retained,
        );
        expect(
          (await reopened.customSelect('SELECT * FROM sync_state').get())
              .single
              .data['last_pulled_server_ts'],
          1,
        );
      } finally {
        await reopened.close();
      }
    },
  );
  test(
    'empty accepted page preserves every persisted byte-value including unset cursor',
    () async {
      respond = (req, body) =>
          reply(req, [], cursor: int.parse(body['cursor'] as String));
      final before = await snapshot();
      final result = await puller.pullOnce(fixture.actor);
      expect(result.received, 0);
      expect(result.cursor, 0);
      expect(result.hasMore, isFalse);
      expect(await snapshot(), before);
    },
  );
  test(
    'absent device state starts at zero without overwriting other devices or push counters',
    () async {
      await db.customStatement(
        'UPDATE sync_state SET last_pushed_server_ts=55,device_monotonic=81',
      );
      final original = await rows('sync_state');
      final second = fixture.actorB.deviceId;
      const a = fixture.actor;
      final actor = LedgerActor(
        planId: a.planId,
        userId: a.userId,
        planMemberId: a.planMemberId,
        deviceId: second,
      );
      expect((await puller.pullOnce(actor)).cursor, 1);
      expect(requests.single['cursor'], '0');
      final states = await rows('sync_state');
      expect(states.first, original.single);
      expect(states.last, {
        'device_id': second,
        'plan_id': a.planId,
        'device_monotonic': 0,
        'last_pushed_server_ts': null,
        'last_pulled_server_ts': 1,
      });
    },
  );
  for (final mutation in [
    'raw content',
    'changed stamp',
    'stamp reused',
    'different plan',
  ]) {
    test('$mutation conflicts roll back entire page and cursor', () async {
      final row = event();
      if (mutation == 'raw content') row['future'] = {'changed': true};
      if (mutation == 'changed stamp') row['server_ts'] = '2';
      if (mutation == 'stamp reused') row['id'] = event(suffix: '098')['id'];
      if (mutation == 'different plan') {
        await fixture.seed(db, fixture.actorB);
        row['plan_id'] = fixture.actorB.planId;
      }
      await db.customStatement('INSERT INTO sync_inbox VALUES(?,?,?,?)', [
        row['id'],
        row['plan_id'],
        int.parse(row['server_ts']! as String),
        jsonEncode(row),
      ]);
      final before = await snapshot();
      respond = (req, body) =>
          reply(req, [event(), event(stamp: 3, suffix: '003')]);
      await expectLater(puller.pullOnce(fixture.actor), throwsA(anything));
      expect(await snapshot(), before);
    });
  }
  for (final mode in ['external observation', 'app transition']) {
    test(
      '$mode drains actual inbox COMMIT only to original account without disclosure',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        respond = (req, body) async {
          commit.action = () async {
            entered.complete();
            await release.future;
          };
          await reply(req, [event()]);
        };
        final pulling = puller.pullOnce(fixture.actor);
        await entered.future.timeout(const Duration(seconds: 5));
        var authCalled = false;
        final Future<void> transition;
        if (mode == 'external observation') {
          identity.user = fixture.actorB.userId;
          identity.marker = Object();
          transition = coordinator.observeSession();
        } else {
          transition = coordinator.transition(() async {
            authCalled = true;
            identity.user = fixture.actorB.userId;
            identity.marker = Object();
          });
        }
        expect(coordinator.isReady, isFalse);
        expect(opened, [fixture.actor.userId]);
        expect(authCalled, isFalse);
        await expectLater(puller.pullOnce(fixture.actorB), throwsA(anything));
        release.complete();
        await expectLater(pulling, throwsA(anything));
        await transition;
        expect(opened, [fixture.actor.userId, fixture.actorB.userId]);
        expect(await rows('sync_inbox'), isEmpty);
        expect(await rows('sync_state'), isEmpty);
        await coordinator.close();
        final a = await EncryptedDatabaseOpener(file, keys).open();
        try {
          expect(
            (await a.customSelect('SELECT * FROM sync_inbox').get())
                .single
                .data['server_ts'],
            1,
          );
          expect(
            (await a.customSelect('SELECT * FROM sync_state').get())
                .single
                .data['last_pulled_server_ts'],
            1,
          );
          expect(
            await a.customSelect('SELECT * FROM outbox').get(),
            hasLength(1),
          );
        } finally {
          await a.close();
        }
      },
    );
  }
  test(
    'actual failed inbox COMMIT rolls back rows cursor and leaves queue then retry succeeds',
    () async {
      final before = await snapshot();
      respond = (req, body) async {
        commit.action = () async => throw StateError('private failure');
        await reply(req, [event(), event(stamp: 2, suffix: '002')]);
      };
      Object? error;
      try {
        await puller.pullOnce(fixture.actor);
      } catch (e) {
        error = e;
      }
      expect(error, isA<DurableInboxException>());
      expect('$error', isNot(contains('private')));
      expect(await snapshot(), before);
      respond = (req, body) =>
          reply(req, [event(), event(stamp: 2, suffix: '002')]);
      expect((await puller.pullOnce(fixture.actor)).received, 2);
      expect(requests.last, requests.first);
      expect(await rows('outbox'), before['outbox']);
    },
  );
  test(
    'native inbox COMMIT rejection preserves every row across encrypted reopen and exact retry',
    () async {
      final before = await snapshot();
      var rejected = 0;
      respond = (req, body) async {
        native.commitFilter = () {
          if (rejected == 0) {
            rejected++;
            return false;
          }
          return true;
        };
        await reply(req, [event(), event(stamp: 2, suffix: '002')]);
      };
      await expectLater(
        puller.pullOnce(fixture.actor),
        throwsA(isA<DurableInboxException>()),
      );
      expect(rejected, 1);
      await coordinator.close();
      coordinator = AccountStoreCoordinator(
        local,
        (_) async => db = await EncryptedDatabaseOpener(file, keys).open(),
      );
      await coordinator.observeSession();
      expect(await snapshot(), before);
      puller = DurableInboxPuller(coordinator, transport);
      respond = (req, body) =>
          reply(req, [event(), event(stamp: 2, suffix: '002')]);
      expect((await puller.pullOnce(fixture.actor)).cursor, 2);
      expect(requests.last, requests.first);
      expect(await rows('outbox'), before['outbox']);
    },
  );

  for (final mismatch in ['user', 'marker']) {
    test(
      'bound coordinator and transport $mismatch mismatch denies before HTTP',
      () async {
        final other = HttpSyncTransport(
          baseUrl: transport.baseUrl,
          anonKey: 'synthetic-anon',
          sessions: fixture.FrozenSession(
            SyncAuthSession(
              userId: mismatch == 'user'
                  ? fixture.actorB.userId
                  : identity.user,
              marker: mismatch == 'marker' ? Object() : identity.marker,
              accessToken: 'synthetic-token',
            ),
          ),
          maxAttempts: 1,
        );
        addTearDown(other.close);
        final before = await snapshot();
        await expectLater(
          DurableInboxPuller(coordinator, other).pullOnce(fixture.actor),
          throwsA(isA<SyncTransportException>()),
        );
        expect(requests, isEmpty);
        expect(await snapshot(), before);
      },
    );
  }
  for (final mode in ['member removed', 'plan inactive', 'alias unlinked']) {
    test('$mode during HTTP denies inbox publication', () async {
      respond = (req, body) async {
        if (mode == 'member removed') {
          await db.customStatement('DELETE FROM plan_members');
        }
        if (mode == 'plan inactive') {
          await db.customStatement('UPDATE plans SET is_active=0');
        }
        if (mode == 'alias unlinked') {
          await db.customStatement('PRAGMA foreign_keys=OFF');
          await db.customStatement(
            'UPDATE plan_member_aliases SET user_id=NULL',
          );
          await db.customStatement('PRAGMA foreign_keys=ON');
        }
        await reply(req, [event()]);
      };
      final before = await rows('sync_state');
      await expectLater(puller.pullOnce(fixture.actor), throwsA(anything));
      expect(await rows('sync_inbox'), isEmpty);
      expect(await rows('sync_state'), before);
      expect(await rows('outbox'), hasLength(1));
    });
  }
  for (final mode in ['same-user replacement', 'A-B-A', 'revoked lease']) {
    test(
      '$mode after HTTP fails with independently pinned transport',
      () async {
        final pinned = HttpSyncTransport(
          baseUrl: transport.baseUrl,
          anonKey: 'synthetic-anon',
          sessions: fixture.FrozenSession(identity.capture()),
          maxAttempts: 1,
        );
        addTearDown(pinned.close);
        Future<void>? transition;
        respond = (req, body) async {
          if (mode == 'revoked lease') {
            transition = coordinator.transition(() async {});
          } else {
            if (mode == 'A-B-A') {
              identity.user = fixture.actorB.userId;
              identity.marker = Object();
              unawaited(coordinator.observeSession());
              identity.user = fixture.actor.userId;
            }
            identity.marker = Object();
          }
          await reply(req, [event()]);
        };
        await expectLater(
          DurableInboxPuller(coordinator, pinned).pullOnce(fixture.actor),
          throwsA(anything),
        );
        if (transition != null) await transition;
        await coordinator.observeSession();
        expect(await rows('sync_inbox'), isEmpty);
        expect(await rows('outbox'), hasLength(1));
        expect(
          (await rows('sync_state')).single['last_pulled_server_ts'],
          isNull,
        );
      },
    );
  }
  for (final mode in ['user', 'plan', 'alias', 'device']) {
    test('forged actor $mode denied without HTTP', () async {
      const a = fixture.actor, b = fixture.actorB;
      final forged = LedgerActor(
        planId: mode == 'plan' ? b.planId : a.planId,
        userId: mode == 'user' ? b.userId : a.userId,
        planMemberId: mode == 'alias' ? b.planMemberId : a.planMemberId,
        deviceId: mode == 'device' ? 'invalid' : a.deviceId,
      );
      final before = await snapshot();
      await expectLater(puller.pullOnce(forged), throwsA(anything));
      expect(requests, isEmpty);
      expect(await snapshot(), before);
    });
  }
  test(
    'concurrent identical committed page is accepted only after complete retained comparison',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      respond = (req, body) async {
        if (requests.length == 1) {
          entered.complete();
          await release.future;
        }
        await reply(req, [event()]);
      };
      final first = puller.pullOnce(fixture.actor);
      await entered.future;
      expect((await puller.pullOnce(fixture.actor)).cursor, 1);
      release.complete();
      expect((await first).cursor, 1);
      expect(await rows('sync_inbox'), hasLength(1));
    },
  );
  test(
    'exact retained full event is idempotent for a second device cursor',
    () async {
      await puller.pullOnce(fixture.actor);
      await db.customStatement('UPDATE sync_state SET last_pulled_server_ts=0');
      final original = await rows('sync_inbox');
      expect((await puller.pullOnce(fixture.actor)).cursor, 1);
      expect(await rows('sync_inbox'), original);
    },
  );
  test(
    'concurrent different page cannot move cursor backward or retain partial rows',
    () async {
      final arrived = Completer<void>(), release = Completer<void>();
      respond = (req, body) async {
        if (requests.length == 1) {
          arrived.complete();
          await release.future;
          await reply(req, [event()]);
        } else {
          await reply(req, [event(stamp: 2, suffix: '002')]);
        }
      };
      final first = puller.pullOnce(fixture.actor);
      await arrived.future;
      expect((await puller.pullOnce(fixture.actor)).cursor, 2);
      release.complete();
      await expectLater(first, throwsA(anything));
      expect((await rows('sync_state')).single['last_pulled_server_ts'], 2);
      expect((await rows('sync_inbox')).single['server_ts'], 2);
    },
  );
}
