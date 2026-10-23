import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show QueryInterceptor, TransactionExecutor, ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/sync/queue/durable_outbox_pusher.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

const actor = LedgerActor(
  planId: '00000000-0000-4000-8000-000000000001',
  userId: 'synthetic-a',
  planMemberId: '00000000-0000-4000-8000-000000000002',
  deviceId: '00000000-0000-4000-8000-000000000003',
);
const actorB = LedgerActor(
  planId: '00000000-0000-4000-8000-000000000011',
  userId: 'synthetic-b',
  planMemberId: '00000000-0000-4000-8000-000000000012',
  deviceId: '00000000-0000-4000-8000-000000000013',
);
const draft = LedgerDraft(
  categoryCode: 'buffer',
  entryType: 'standard',
  supplierName: 'Synthetic',
  pricingMode: 'flat',
  estimatedCents: 9007199254740993,
);

class Identity implements SyncSessionSource {
  String user = actor.userId;
  Object marker = Object();
  @override
  SyncAuthSession capture() => SyncAuthSession(
    userId: user,
    marker: marker,
    accessToken: 'synthetic-token',
  );
}

class FrozenSession implements SyncSessionSource {
  FrozenSession(this.session);
  final SyncAuthSession session;
  @override
  SyncAuthSession capture() => session;
}

class LocalIdentity implements VerifiedLocalIdentity {
  LocalIdentity(this.source);
  final Identity source;
  @override
  VerifiedSessionSnapshot capture() =>
      VerifiedSessionSnapshot(source.user, source.marker);
}

class Keys implements DatabaseKeyStore {
  String? key;
  @override
  Future<String?> read() async => key;
  @override
  Future<void> write(String value) async => key = value;
}

class CommitHook extends QueryInterceptor {
  Future<void> Function()? action;
  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    final next = action;
    action = null;
    await next?.call();
    await inner.send();
  }
}

Future<void> seed(AppDatabase db, LedgerActor a) async {
  await db.customStatement(
    '''
INSERT INTO plans
(id,creator_user_id,wedding_date,total_budget_cents,guest_cap,region_code,
 ruleset_version,driving_rsvp_status,created_at) VALUES (?,?,?,?,?,?,?,?,?)''',
    [
      a.planId,
      a.userId,
      '2027-01-01',
      10000,
      2,
      'TEST',
      'fixture',
      'pending',
      '2026-10-20T00:00:00Z',
    ],
  );
  await db.customStatement(
    'INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id) VALUES (?,?,?)',
    [a.planMemberId, a.planId, a.userId],
  );
  await db.customStatement(
    'INSERT INTO plan_members (plan_id,user_id,plan_member_id,role,joined_at) VALUES (?,?,?,?,?)',
    [a.planId, a.userId, a.planMemberId, 'creator', '2026-10-20T00:00:00Z'],
  );
}

void main() {
  late Directory dir;
  late File file, bFile;
  late Keys keys, bKeys;
  late List<String> opened;
  late Identity identity;
  late LocalIdentity local;
  late AccountStoreCoordinator coordinator;
  late AppDatabase db;
  late CommitHook commit;
  late HttpServer server;
  late HttpSyncTransport transport;
  late DurableOutboxPusher pusher;
  late List<Map<String, dynamic>> requests;
  late Future<void> Function(HttpRequest, Map<String, dynamic>) respond;

  Future<List<Map<String, dynamic>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table').get())
          .map((r) => r.data)
          .toList();
  Future<void> enqueue() async {
    await LocalLedgerWriter(db, identity: local).create(actor, draft);
  }

  Future<void> reply(HttpRequest req, Object body, {int status = 200}) async {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Map<String, Object?> accepted(Map<String, dynamic> body, {int? take}) {
    final events = body['rows'] as List;
    return {
      'protocol_version': {'major': 1, 'minor': 0},
      'accepted': events
          .take(take ?? events.length)
          .map(
            (dynamic r) => {
              'id': (r as Map)['id'],
              'server_ts': '${events.indexOf(r) + 1}',
            },
          )
          .toList(),
      'server_ts_high': '999',
    };
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kasaran-outbox-');
    file = File('${dir.path}/a.sqlite');
    keys = Keys();
    identity = Identity();
    local = LocalIdentity(identity);
    final initial = await EncryptedDatabaseOpener(file, keys).open();
    await seed(initial, actor);
    await initial.close();
    bFile = File('${dir.path}/b.sqlite');
    bKeys = Keys();
    final initialB = await EncryptedDatabaseOpener(bFile, bKeys).open();
    await seed(initialB, actorB);
    await initialB.close();
    expect(bKeys.key, isNot(keys.key));
    commit = CommitHook();
    opened = [];
    coordinator = AccountStoreCoordinator(local, (session) async {
      opened.add(session.userId);
      final isA = session.userId == actor.userId;
      return db = AppDatabase(
        NativeDatabase(
          isA ? file : bFile,
          setup: (raw) {
            if (raw.select('PRAGMA cipher').isEmpty) {
              throw StateError('Cipher required');
            }
            raw.execute("PRAGMA key = '${isA ? keys.key! : bKeys.key!}'");
          },
        ).interceptWith(commit),
      );
    });
    await coordinator.observeSession();
    await enqueue();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = [];
    respond = (req, body) => reply(req, accepted(body));
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
    pusher = DurableOutboxPusher(coordinator, transport);
  });
  tearDown(() async {
    transport.close();
    await server.close(force: true);
    await coordinator.close();
    await dir.delete(recursive: true);
  });

  for (final mode in ['external observation', 'app transition']) {
    test(
      '$mode drains actual acknowledgment COMMIT into only original encrypted file',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        respond = (req, body) async {
          commit.action = () async {
            entered.complete();
            await release.future;
          };
          await reply(req, accepted(body));
        };
        final pushing = pusher.pushOnce(actor);
        await entered.future.timeout(const Duration(seconds: 5));
        var authCalled = false;
        final Future<void> transition;
        if (mode == 'external observation') {
          identity.user = actorB.userId;
          identity.marker = Object();
          transition = coordinator.observeSession();
        } else {
          transition = coordinator.transition(() async {
            authCalled = true;
            identity.user = actorB.userId;
            identity.marker = Object();
          });
        }
        expect(coordinator.isReady, isFalse);
        expect(opened, [actor.userId]);
        expect(authCalled, isFalse);
        await expectLater(pusher.pushOnce(actorB), throwsA(anything));
        release.complete();
        await expectLater(pushing, throwsA(anything));
        await transition;
        expect(opened, [actor.userId, actorB.userId]);
        expect(await rows('change_log'), isEmpty);
        expect(await rows('outbox'), isEmpty);
        await coordinator.close();
        final original = await EncryptedDatabaseOpener(file, keys).open();
        try {
          expect(
            await original.customSelect('SELECT * FROM outbox').get(),
            isEmpty,
          );
          expect(
            (await original
                    .customSelect('SELECT server_ts FROM change_log')
                    .get())
                .single
                .data['server_ts'],
            1,
          );
          expect(
            (await original
                    .customSelect(
                      'SELECT last_pushed_server_ts FROM sync_state',
                    )
                    .get())
                .single
                .data['last_pushed_server_ts'],
            1,
          );
        } finally {
          await original.close();
        }
      },
    );
  }

  for (final change in ['member removed', 'plan inactive', 'alias unlinked']) {
    test('$change during HTTP refuses whole acknowledgment', () async {
      respond = (req, body) async {
        switch (change) {
          case 'member removed':
            await db.customStatement('DELETE FROM plan_members');
          case 'plan inactive':
            await db.customStatement('UPDATE plans SET is_active=0');
          case 'alias unlinked':
            await db.customStatement('PRAGMA foreign_keys=OFF');
            await db.customStatement(
              'UPDATE plan_member_aliases SET user_id=NULL',
            );
            await db.customStatement('PRAGMA foreign_keys=ON');
        }
        await reply(req, accepted(body));
      };
      await expectLater(pusher.pushOnce(actor), throwsA(anything));
      expect(await rows('outbox'), hasLength(1));
      expect((await rows('change_log')).single['server_ts'], isNull);
    });
  }

  for (final changed in ['user', 'plan', 'alias', 'invalid device']) {
    test('forged actor $changed is denied before HTTP', () async {
      final forged = LedgerActor(
        planId: changed == 'plan' ? actorB.planId : actor.planId,
        userId: changed == 'user' ? actorB.userId : actor.userId,
        planMemberId: changed == 'alias'
            ? actorB.planMemberId
            : actor.planMemberId,
        deviceId: changed == 'invalid device' ? 'forged' : actor.deviceId,
      );
      await expectLater(pusher.pushOnce(forged), throwsA(anything));
      expect(requests, isEmpty);
      expect(await rows('outbox'), hasLength(1));
    });
  }

  for (final original in [
    'other user',
    'retired same-user alias',
    'null alias',
  ]) {
    test(
      'queued original author $original is never retagged to current member',
      () async {
        const alias = '00000000-0000-4000-8000-000000000090';
        await db.customStatement(
          'INSERT INTO plan_member_aliases (plan_id,plan_member_id,user_id) VALUES (?,?,?)',
          [
            actor.planId,
            alias,
            original == 'other user'
                ? actorB.userId
                : original == 'null alias'
                ? null
                : actor.userId,
          ],
        );
        await db.customStatement('UPDATE change_log SET plan_member_id=?', [
          alias,
        ]);
        final before = await rows('change_log');
        final queue = await rows('outbox');
        expect((await pusher.pushOnce(actor)).attempted, 0);
        expect(requests, isEmpty);
        expect(await rows('change_log'), before);
        expect(await rows('outbox'), queue);
      },
    );
  }

  for (final mismatch in ['user', 'marker']) {
    test(
      'coordinator and transport $mismatch mismatch sends no queued event',
      () async {
        final other = HttpSyncTransport(
          baseUrl: transport.baseUrl,
          anonKey: 'synthetic-anon',
          sessions: FrozenSession(
            SyncAuthSession(
              userId: mismatch == 'user' ? actorB.userId : actor.userId,
              marker: mismatch == 'marker' ? Object() : identity.marker,
              accessToken: 'synthetic-token',
            ),
          ),
          maxAttempts: 1,
        );
        addTearDown(other.close);
        await expectLater(
          DurableOutboxPusher(coordinator, other).pushOnce(actor),
          throwsA(isA<SyncTransportException>()),
        );
        expect(requests, isEmpty);
        expect(await rows('outbox'), hasLength(1));
      },
    );
  }

  test(
    'malformed matching JSON is rejected before any HTTP with sanitized error',
    () async {
      await db.customStatement('UPDATE change_log SET new_value=?', [
        'private-invalid-json',
      ]);
      Object? error;
      try {
        await pusher.pushOnce(actor);
      } catch (e) {
        error = e;
      }
      expect(error, isA<DurableOutboxException>());
      expect('$error', isNot(contains('private')));
      expect(requests, isEmpty);
      expect(await rows('outbox'), hasLength(1));
    },
  );

  test('stable ordering sends at most 100 and retains overflow', () async {
    for (var i = 0; i < 100; i++) {
      await enqueue();
    }
    await db.customStatement('UPDATE change_log SET device_monotonic=1');
    final expected = (await rows(
      'change_log',
    )).map((e) => e['id'] as String).toList()..sort();
    final result = await pusher.pushOnce(actor);
    expect(result.attempted, 100);
    expect(result.acknowledged, 100);
    final sent = (requests.single['rows'] as List)
        .map((dynamic e) => (e as Map)['id'])
        .toList();
    expect(sent, expected.take(100).toList());
    expect((await rows('outbox')).single['event_id'], expected.last);
  });

  test(
    'sync state disappearing in-flight rolls back stamps and queue deletion',
    () async {
      respond = (req, body) async {
        await db.customStatement('DELETE FROM sync_state');
        await reply(req, accepted(body));
      };
      await expectLater(pusher.pushOnce(actor), throwsA(anything));
      expect(await rows('outbox'), hasLength(1));
      expect((await rows('change_log')).single['server_ts'], isNull);
    },
  );

  for (final amount in [0, 1]) {
    test(
      '$amount accepted rows retain every unacknowledged row despite high water',
      () async {
        await enqueue();
        final before = await rows('change_log');
        respond = (req, body) => reply(req, accepted(body, take: amount));
        final result = await pusher.pushOnce(actor);
        expect(result.attempted, 2);
        expect(result.acknowledged, amount);
        expect(await rows('outbox'), hasLength(2 - amount));
        final events = await rows('change_log');
        expect(events.last, before.last);
        expect(
          (await rows('sync_state')).single['last_pushed_server_ts'],
          amount == 0 ? null : 1,
        );
      },
    );
  }

  test('empty batch sends no HTTP', () async {
    await db.customStatement('DELETE FROM outbox');
    final result = await pusher.pushOnce(actor);
    expect(result.attempted, 0);
    expect(result.acknowledged, 0);
    expect(requests, isEmpty);
  });

  test(
    'new writer event during HTTP is not included in acknowledgment and no SQL transaction spans HTTP',
    () async {
      respond = (req, body) async {
        await enqueue();
        await reply(req, accepted(body));
      };
      expect((await pusher.pushOnce(actor)).acknowledged, 1);
      final queue = await rows('outbox');
      final events = await rows('change_log');
      expect(queue, hasLength(1));
      expect(queue.single['event_id'], events.last['id']);
      expect(events.last['server_ts'], isNull);
      expect((await rows('sync_state')).single['device_monotonic'], 2);
    },
  );

  test(
    'watermark is monotonic and preserves pull counter and unrelated device state',
    () async {
      await db.customStatement(
        'UPDATE sync_state SET last_pushed_server_ts=44,last_pulled_server_ts=77',
      );
      await db.customStatement(
        'INSERT INTO sync_state (device_id,plan_id,device_monotonic,last_pushed_server_ts,last_pulled_server_ts) VALUES (?,?,10,99,88)',
        ['other-device', actor.planId],
      );
      final before = await rows('sync_state');
      await pusher.pushOnce(actor);
      expect(await rows('sync_state'), before);
    },
  );

  for (final fault in [
    'unexpected id',
    'duplicate id',
    'zero stamp',
    'stamp above high',
    'missing accepted',
    'unsupported version',
    'invalid JSON',
    'HTTP refusal',
    'update required',
    'lost response',
  ]) {
    test('$fault preserves exact pending events', () async {
      final before = await rows('change_log');
      final queue = await rows('outbox');
      final state = await rows('sync_state');
      respond = (req, body) async {
        final ack = accepted(body);
        switch (fault) {
          case 'unexpected id':
            ack['accepted'] = [
              {'id': 'unexpected', 'server_ts': '1'},
            ];
          case 'duplicate id':
            ack['accepted'] = [
              (ack['accepted']! as List).first,
              (ack['accepted']! as List).first,
            ];
          case 'zero stamp':
            ack['accepted'] = [
              {'id': before.single['id'], 'server_ts': '0'},
            ];
          case 'stamp above high':
            ack['server_ts_high'] = '0';
          case 'missing accepted':
            ack.remove('accepted');
          case 'unsupported version':
            ack['protocol_version'] = {'major': 2, 'minor': 0};
          case 'invalid JSON':
            req.response.write('invalid private payload');
            await req.response.close();
            return;
          case 'HTTP refusal':
            await reply(req, {'private': 'payload'}, status: 403);
            return;
          case 'update required':
            await reply(req, {
              'error': 'unsupported_protocol',
              'min_supported_build': 999,
            }, status: 426);
            return;
          case 'lost response':
            (await req.response.detachSocket(writeHeaders: false)).destroy();
            return;
        }
        await reply(req, ack);
      };
      await expectLater(pusher.pushOnce(actor), throwsA(anything));
      expect(await rows('outbox'), queue);
      expect(await rows('change_log'), before);
      expect(await rows('sync_state'), state);
    });
  }

  test(
    'actual failing COMMIT rolls back both queue and assigned stamps then exact retry succeeds',
    () async {
      await enqueue();
      final before = await rows('change_log');
      final queue = await rows('outbox');
      final state = await rows('sync_state');
      respond = (req, body) async {
        commit.action = () async =>
            throw StateError('private synthetic commit failure');
        await reply(req, accepted(body));
      };
      Object? error;
      try {
        await pusher.pushOnce(actor);
      } catch (e) {
        error = e;
      }
      expect(error, isA<DurableOutboxException>());
      expect('$error', isNot(contains('private')));
      expect(await rows('outbox'), queue);
      expect(await rows('change_log'), before);
      expect(await rows('sync_state'), state);
      respond = (req, body) => reply(req, accepted(body));
      expect((await pusher.pushOnce(actor)).acknowledged, 2);
      expect(requests[1], requests[0]);
      expect(await rows('outbox'), isEmpty);
    },
  );

  for (final missing in ['identical', 'changed payload', 'different stamp']) {
    test(
      'concurrent acknowledgment $missing requires complete matching event and stamp',
      () async {
        final arrived = Completer<void>();
        final release = Completer<void>();
        respond = (req, body) async {
          if (requests.length == 1) {
            arrived.complete();
            await release.future;
          }
          await reply(req, accepted(body));
        };
        final first = pusher.pushOnce(actor);
        await arrived.future;
        expect((await pusher.pushOnce(actor)).acknowledged, 1);
        if (missing == 'changed payload') {
          await db.customStatement('UPDATE change_log SET new_value=?', [
            '"changed"',
          ]);
        }
        if (missing == 'different stamp') {
          await db.customStatement('UPDATE change_log SET server_ts=2');
        }
        release.complete();
        if (missing == 'identical') {
          expect((await first).acknowledged, 1);
        } else {
          await expectLater(first, throwsA(anything));
        }
        expect(await rows('outbox'), isEmpty);
        expect((await rows('sync_state')).single['last_pushed_server_ts'], 1);
      },
    );
  }

  for (final stamp in [0, -1]) {
    test(
      'invalid persisted server stamp $stamp is refused before HTTP',
      () async {
        await db.customStatement('UPDATE change_log SET server_ts=?', [stamp]);
        await expectLater(pusher.pushOnce(actor), throwsA(anything));
        expect(requests, isEmpty);
        expect(await rows('outbox'), hasLength(1));
      },
    );
  }

  test(
    'absent device sync state fails closed instead of losing durable watermark',
    () async {
      await db.customStatement('DELETE FROM sync_state');
      await expectLater(pusher.pushOnce(actor), throwsA(anything));
      expect(requests, isEmpty);
      expect(await rows('outbox'), hasLength(1));
    },
  );

  test('dangling matching queue entry fails closed before HTTP', () async {
    await db.customStatement('PRAGMA foreign_keys=OFF');
    await db.customStatement(
      'INSERT INTO outbox (event_id,plan_id,device_id,queued_at) VALUES (?,?,?,?)',
      [
        '00000000-0000-7000-8000-000000000099',
        actor.planId,
        actor.deviceId,
        '2026-10-20T00:00:00Z',
      ],
    );
    await db.customStatement('PRAGMA foreign_keys=ON');
    await expectLater(pusher.pushOnce(actor), throwsA(anything));
    expect(requests, isEmpty);
    expect(await rows('outbox'), hasLength(2));
  });

  test(
    'queue resolving to another device stays untouched and is not sent',
    () async {
      await db.customStatement('UPDATE change_log SET device_id=?', [
        '00000000-0000-4000-8000-000000000099',
      ]);
      final result = await pusher.pushOnce(actor);
      expect(result.attempted, 0);
      expect(requests, isEmpty);
      expect(await rows('outbox'), hasLength(1));
    },
  );

  for (final race in [
    'same-user replacement',
    'A-B-A',
    'transition revocation',
  ]) {
    test(
      '$race after HTTP rejects acknowledgment with independently pinned transport source',
      () async {
        final captured = identity.capture();
        final pinned = HttpSyncTransport(
          baseUrl: transport.baseUrl,
          anonKey: 'synthetic-anon',
          sessions: FrozenSession(captured),
          maxAttempts: 1,
        );
        addTearDown(pinned.close);
        Future<void>? transition;
        respond = (req, body) async {
          if (race == 'transition revocation') {
            transition = coordinator.transition(() async {});
          } else {
            if (race == 'A-B-A') {
              identity.user = 'synthetic-b';
              identity.marker = Object();
              unawaited(coordinator.observeSession());
              identity.user = actor.userId;
            }
            identity.marker = Object();
          }
          await reply(req, accepted(body));
        };
        await expectLater(
          DurableOutboxPusher(coordinator, pinned).pushOnce(actor),
          throwsA(anything),
        );
        if (transition != null) await transition;
        // A revoked coordinator may reopen the same encrypted fixture.
        await coordinator.observeSession();
        expect(await rows('outbox'), hasLength(1));
        expect((await rows('change_log')).single['server_ts'], isNull);
      },
    );
  }

  for (final mutation in <String, Object?>{
    'old_value': '"changed"',
    'new_value': '"changed"',
    'server_ts': 55,
    'created_at': '2026-10-21T00:00:00Z',
    'device_monotonic': 77,
    'entity_id': '00000000-0000-7000-8000-000000000009',
    'field_name': 'notes',
    'schema_version': 2,
  }.entries) {
    test(
      'in-flight ${mutation.key} change rolls back the whole acknowledgment',
      () async {
        await enqueue();
        final original = await rows('change_log');
        final secondId = original.last['id'];
        respond = (req, body) async {
          await db.customStatement(
            'UPDATE change_log SET ${mutation.key}=? WHERE id=?',
            [mutation.value, secondId],
          );
          await reply(req, accepted(body));
        };
        await expectLater(pusher.pushOnce(actor), throwsA(anything));
        expect(await rows('outbox'), hasLength(2));
        final current = await rows('change_log');
        expect(current.first['server_ts'], isNull);
        expect(
          current.last['server_ts'],
          mutation.key == 'server_ts' ? 55 : isNull,
        );
        expect(
          (await rows('sync_state')).single['last_pushed_server_ts'],
          isNull,
        );
      },
    );
  }

  test(
    'in-flight queue timestamp change rolls back all accepted stamps',
    () async {
      await enqueue();
      respond = (req, body) async {
        final events = body['rows'] as List;
        await db.customStatement(
          'UPDATE outbox SET queued_at=? WHERE event_id=?',
          ['changed', (events.last as Map)['id']],
        );
        await reply(req, accepted(body));
      };
      await expectLater(pusher.pushOnce(actor), throwsA(anything));
      expect(await rows('outbox'), hasLength(2));
      expect(
        (await rows('change_log')).every((r) => r['server_ts'] == null),
        isTrue,
      );
    },
  );

  test('missing queue row alone is not proof of acceptance', () async {
    respond = (req, body) async {
      await db.customStatement('DELETE FROM outbox');
      await reply(req, accepted(body));
    };
    await expectLater(pusher.pushOnce(actor), throwsA(anything));
    expect((await rows('change_log')).single['server_ts'], isNull);
    expect((await rows('sync_state')).single['last_pushed_server_ts'], isNull);
  });

  test(
    'atomic acknowledgment survives encrypted reopen without changing financial values',
    () async {
      final before = await rows('change_log');
      final result = await pusher.pushOnce(actor);
      expect(result.attempted, 1);
      expect(result.acknowledged, 1);
      expect(
        (requests.single['rows'] as List).single,
        containsPair(
          'new_value',
          jsonDecode(before.single['new_value'] as String),
        ),
      );
      await coordinator.close();
      final reopened = await EncryptedDatabaseOpener(file, keys).open();
      try {
        expect(
          await reopened.customSelect('SELECT * FROM outbox').get(),
          isEmpty,
        );
        final event =
            (await reopened.customSelect('SELECT * FROM change_log').get())
                .single
                .data;
        expect(event, {...before.single, 'server_ts': 1});
        final state =
            (await reopened.customSelect('SELECT * FROM sync_state').get())
                .single
                .data;
        expect(state['last_pushed_server_ts'], 1);
        expect(state['device_monotonic'], 1);
        expect(
          (await reopened.select(reopened.ledgerEntries).get())
              .single
              .estimatedCents,
          9007199254740993,
        );
        expect(
          (await file.readAsBytes()).take(16).toList(),
          isNot(utf8.encode('SQLite format 3\u0000')),
        );
      } finally {
        await reopened.close();
      }
    },
  );
}
