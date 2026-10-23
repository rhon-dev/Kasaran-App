import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/sync/queue/account_sync_worker.dart';
import 'package:kasaran/sync/queue/durable_inbox_puller.dart';
import 'package:kasaran/sync/queue/durable_outbox_pusher.dart';
import 'package:kasaran/sync/replay/durable_projection_rebuilder.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

import 'durable_outbox_pusher_test.dart' as fixture;

class TestTimers {
  final alarms = <TestAlarm>[];
  Timer schedule(Duration delay, void Function() callback) {
    final alarm = TestAlarm(delay, callback);
    alarms.add(alarm);
    return alarm;
  }

  List<TestAlarm> get active => alarms.where((a) => a.isActive).toList();
  void fire() => active.first.fire();
}

class TestAlarm implements Timer {
  TestAlarm(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  @override
  void cancel() => isActive = false;
  void fire() {
    if (!isActive) return;
    isActive = false;
    tick++;
    callback();
  }
}

void main() {
  late Directory dir;
  late File file;
  late fixture.Keys keys;
  late fixture.Identity identity;
  late fixture.LocalIdentity local;
  late AccountStoreCoordinator coordinator;
  late AppDatabase db;
  late fixture.CommitHook commit;
  late HttpServer server;
  late HttpSyncTransport transport;
  late AccountSyncWorker worker;
  late TestTimers timers;
  late List<String> requests;
  late List<Map<String, dynamic>> accepted;
  late Future<void> Function(HttpRequest, Map<String, dynamic>) respond;

  Future<void> reply(HttpRequest req, Object body, {int status = 200}) async {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> normal(HttpRequest req, Map<String, dynamic> body) async {
    if (req.uri.path.endsWith('sync_push')) {
      for (final dynamic row in body['rows'] as List) {
        final event = Map<String, dynamic>.from(row as Map);
        if (!accepted.any((e) => e['id'] == event['id'])) {
          accepted.add({...event, 'server_ts': '${accepted.length + 1}'});
        }
      }
      await reply(req, {
        'protocol_version': {'major': 1, 'minor': 0},
        'accepted': [
          for (final dynamic row in body['rows'] as List)
            {
              'id': (row as Map)['id'],
              'server_ts': accepted.firstWhere(
                (e) => e['id'] == row['id'],
              )['server_ts'],
            },
        ],
        'server_ts_high': '${accepted.length}',
      });
    } else {
      final cursor = int.parse(body['cursor'] as String);
      final rows = accepted
          .where((e) => int.parse(e['server_ts'] as String) > cursor)
          .take(body['limit'] as int)
          .toList();
      await reply(req, {
        'protocol_version': {'major': 1, 'minor': 0},
        'rows': rows,
        'next_cursor': rows.isEmpty ? '$cursor' : rows.last['server_ts'],
        'has_more':
            rows.isNotEmpty &&
            int.parse(rows.last['server_ts'] as String) < accepted.length,
      });
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kasaran-worker-');
    file = File('${dir.path}/account.sqlite');
    keys = fixture.Keys();
    identity = fixture.Identity();
    local = fixture.LocalIdentity(identity);
    final initial = await EncryptedDatabaseOpener(file, keys).open();
    await fixture.seed(initial, fixture.actor);
    await initial.close();
    commit = fixture.CommitHook();
    coordinator = AccountStoreCoordinator(local, (_) async {
      db = AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            if (raw.select('PRAGMA cipher').isEmpty) {
              throw StateError('Cipher required');
            }
            raw.execute("PRAGMA key = '${keys.key!}'");
          },
        ).interceptWith(commit),
      );
      if ((await db.customSelect('SELECT * FROM plans').get()).isEmpty) {
        await fixture.seed(db, fixture.actor);
      }
      return db;
    });
    await coordinator.observeSession();
    requests = [];
    accepted = [];
    respond = normal;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body =
          jsonDecode(await utf8.decoder.bind(req).join())
              as Map<String, dynamic>;
      requests.add(req.uri.path.split('/').last);
      await respond(req, body);
    });
    transport = HttpSyncTransport(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      anonKey: 'synthetic-anon',
      sessions: identity,
      maxAttempts: 1,
    );
    timers = TestTimers();
    worker = AccountSyncWorker(
      schedule: timers.schedule,
      coordinator: coordinator,
      actor: fixture.actor,
      pusher: DurableOutboxPusher(coordinator, transport),
      puller: DurableInboxPuller(coordinator, transport),
      rebuilder: DurableProjectionRebuilder(coordinator),
    );
  });

  tearDown(() async {
    await worker.dispose();
    transport.close();
    await server.close(force: true);
    await coordinator.close();
    await dir.delete(recursive: true);
  });

  test(
    'same-status listener writes do not recursively redeliver pending',
    () async {
      await worker.start();
      var deliveries = 0;
      final subscription = worker.statuses.listen((state) {
        if (state == AccountSyncStatus.pending && ++deliveries < 20) {
          worker.notifyLocalWrite();
        }
      });
      addTearDown(subscription.cancel);
      worker.notifyLocalWrite();
      expect(deliveries, 1);
      expect(worker.status, AccountSyncStatus.pending);
      expect(timers.active, hasLength(1));
    },
  );

  for (final action in ['local write', 'foreground', 'dispose', 'revoke']) {
    test(
      'status delivery guards later listeners after $action callback',
      () async {
        await worker.start();
        requests.clear();
        final first = <AccountSyncStatus>[];
        final later = <AccountSyncStatus>[];
        Future<void>? disposing;
        var acted = false;
        final subscription = worker.statuses.listen((state) {
          first.add(state);
          if (acted) return;
          acted = true;
          switch (action) {
            case 'local write':
              worker.notifyLocalWrite();
            case 'foreground':
              worker.notifyForeground();
            case 'dispose':
              disposing = worker.dispose();
            case 'revoke':
              identity.marker = Object();
          }
        });
        final second = worker.statuses.listen(later.add);
        addTearDown(subscription.cancel);
        addTearDown(second.cancel);
        worker.notifyLocalWrite();
        if (action == 'foreground') {
          await worker.settled;
          expect(later, [AccountSyncStatus.syncing, AccountSyncStatus.idle]);
          expect(requests, ['sync_pull']);
        } else if (action == 'local write') {
          expect(first, [AccountSyncStatus.pending]);
          expect(later, [AccountSyncStatus.pending]);
          expect(timers.active, hasLength(1));
        } else {
          if (disposing != null) await disposing;
          expect(later, isEmpty);
          expect(worker.status, AccountSyncStatus.stopped);
          expect(timers.active, isEmpty);
          expect(requests, isEmpty);
        }
      },
    );
  }

  for (final action in ['stop', 'revoke', 'new status']) {
    test('paused status delivery drops buffered events after $action', () async {
      await worker.start();
      final statuses = <AccountSyncStatus>[];
      final done = Completer<void>();
      final subscription = worker.statuses.listen(
        statuses.add,
        onDone: done.complete,
      );
      addTearDown(subscription.cancel);
      subscription.pause();
      worker.notifyLocalWrite();
      if (action == 'stop') {
        await worker.stop();
        worker.notifyLocalWrite();
        worker.notifyForeground();
        await worker.start();
      } else if (action == 'revoke') {
        identity.marker = Object();
      } else {
        worker.notifyForeground();
        await worker.settled;
      }
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(
        statuses,
        action == 'new status' ? [AccountSyncStatus.idle] : isEmpty,
      );
      await worker.dispose();
      await done.future;
      // A listener attached after disposal observes termination, never replay.
      expect(await worker.statuses.toList(), isEmpty);
    });
  }

  test(
    'paused status observer does not hold durable disposal barrier',
    () async {
      await worker.start();
      final subscription = worker.statuses.listen((_) {});
      subscription.pause();
      var disposed = false;
      final disposing = worker.dispose().then((_) => disposed = true);
      // Flush the event queue without resuming or cancelling the observer.
      await Future<void>.delayed(Duration.zero);
      final completedBeforeCancellation = disposed;
      await subscription.cancel();
      await disposing;
      expect(completedBeforeCancellation, isTrue);
      expect(coordinator.isReady, isTrue);
    },
  );

  test(
    'status listener local-write reentrancy preserves pending delivery',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      final errors = <Object>[];
      final statuses = <AccountSyncStatus>[];
      var notified = false;
      final subscription = worker.statuses.listen((state) {
        statuses.add(state);
        if (state == AccountSyncStatus.syncing && !notified) {
          notified = true;
          try {
            worker.notifyLocalWrite();
          } catch (error) {
            errors.add(error);
          }
        }
      });
      addTearDown(subscription.cancel);
      await worker.start();
      expect(errors, isEmpty);
      expect(statuses, [
        AccountSyncStatus.syncing,
        AccountSyncStatus.pending,
        AccountSyncStatus.pending,
      ]);
      expect(worker.status, AccountSyncStatus.pending);
      expect(timers.active.single.delay, const Duration(milliseconds: 250));
      timers.fire();
      await worker.settled;
      expect(statuses.last, AccountSyncStatus.idle);
      expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
    },
  );

  test(
    'retained queue survives encrypted close and recreated worker retries automatically',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      respond = (req, body) => reply(req, {'error': 'transient'}, status: 503);
      final before =
          (await db.customSelect('SELECT * FROM outbox').get()).single.data;
      await worker.start();
      expect(worker.status, AccountSyncStatus.pending);
      await worker.dispose();
      expect(timers.active, isEmpty);
      await coordinator.close();
      coordinator = AccountStoreCoordinator(
        local,
        (_) async => db = await EncryptedDatabaseOpener(file, keys).open(),
      );
      await coordinator.observeSession();
      expect(
        (await db.customSelect('SELECT * FROM outbox').get()).single.data,
        before,
      );
      worker = AccountSyncWorker(
        coordinator: coordinator,
        actor: fixture.actor,
        schedule: timers.schedule,
        pusher: DurableOutboxPusher(coordinator, transport),
        puller: DurableInboxPuller(coordinator, transport),
        rebuilder: DurableProjectionRebuilder(coordinator),
      );
      respond = normal;
      await worker.start();
      expect(worker.status, AccountSyncStatus.idle);
      expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(1),
      );
    },
  );

  test(
    'timer admission detects silent marker replacement without stale status',
    () async {
      await worker.start();
      final statuses = <AccountSyncStatus>[];
      final subscription = worker.statuses.listen(statuses.add);
      addTearDown(subscription.cancel);
      worker.notifyLocalWrite();
      final before = requests.length;
      identity.marker = Object();
      timers.fire();
      await worker.settled;
      expect(requests, hasLength(before));
      expect(statuses, [AccountSyncStatus.pending]);
      expect(worker.status, AccountSyncStatus.stopped);
      expect(timers.active, isEmpty);
      await coordinator.observeSession();
      worker.notifyReconnect();
      expect(requests, hasLength(before));
    },
  );

  test(
    'dispose drains actual projection COMMIT without publishing success',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      final entered = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final statuses = <AccountSyncStatus>[];
      final subscription = worker.statuses.listen(statuses.add);
      addTearDown(subscription.cancel);
      respond = (req, body) async {
        if (req.uri.path.endsWith('sync_pull')) {
          // Inbox retention COMMIT arms the subsequent projection COMMIT gate.
          commit.action = () async {
            commit.action = () async {
              entered.complete();
              await release.future;
            };
          };
        }
        await normal(req, body);
      };
      final running = worker.start();
      await entered.future.timeout(const Duration(seconds: 5));
      var disposed = false;
      final disposing = worker.dispose().then((_) => disposed = true);
      expect(disposed, isFalse);
      release.complete();
      await Future.wait([running, disposing]);
      expect(statuses, [AccountSyncStatus.syncing]);
      expect(coordinator.isReady, isTrue);
      await coordinator.close();
      final reopened = await EncryptedDatabaseOpener(file, keys).open();
      try {
        expect(
          await reopened.customSelect('SELECT * FROM sync_inbox').get(),
          hasLength(1),
        );
        expect(
          await reopened.customSelect('SELECT * FROM ledger_entries').get(),
          hasLength(1),
        );
      } finally {
        await reopened.close();
      }
    },
  );

  test(
    'orphan first page preserves old projection until later create completes history',
    () async {
      await worker.dispose();
      worker = AccountSyncWorker(
        coordinator: coordinator,
        actor: fixture.actor,
        schedule: timers.schedule,
        pusher: DurableOutboxPusher(coordinator, transport),
        puller: DurableInboxPuller(coordinator, transport),
        rebuilder: DurableProjectionRebuilder(coordinator),
        maxPullPages: 1,
        pullLimit: 1,
      );
      final row = await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      final log =
          (await db.customSelect('SELECT * FROM change_log').get()).single.data;
      final create = <String, dynamic>{
        ...log,
        'server_ts': '2',
        'device_monotonic': '${log['device_monotonic']}',
        'old_value': jsonDecode(log['old_value']! as String),
        'new_value': jsonDecode(log['new_value']! as String),
      };
      accepted.addAll([
        {
          ...create,
          'id': '00000000-0000-7000-8000-000000000099',
          'server_ts': '1',
          'field_name': 'notes',
          'old_value': null,
          'new_value': 'remote note',
        },
        create,
      ]);
      await db.customStatement('DELETE FROM outbox');
      await db.customStatement('DELETE FROM change_log');
      await worker.start();
      expect(worker.status, AccountSyncStatus.pending);
      expect(
        (await db.customSelect('SELECT * FROM ledger_entries').get())
            .single
            .data,
        row.toJson(),
      );
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(1),
      );
      timers.fire();
      await worker.settled;
      expect(worker.status, AccountSyncStatus.idle);
      expect(
        (await db.customSelect('SELECT * FROM ledger_entries').get())
            .single
            .data['notes'],
        'remote note',
      );
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(2),
      );
      expect(timers.active, isEmpty);
    },
  );

  test(
    'configuration rejects zero unbounded or foreign-owner passes before HTTP',
    () async {
      final foreign = AccountStoreCoordinator(
        local,
        (_) async => throw StateError('must not open'),
      );
      addTearDown(foreign.close);
      for (final bound in [0, -1, 17]) {
        expect(
          () => AccountSyncWorker(
            coordinator: coordinator,
            actor: fixture.actor,
            pusher: DurableOutboxPusher(coordinator, transport),
            puller: DurableInboxPuller(coordinator, transport),
            rebuilder: DurableProjectionRebuilder(coordinator),
            maxPullPages: bound,
          ),
          throwsArgumentError,
        );
      }
      for (final limit in [0, 1001]) {
        expect(
          () => AccountSyncWorker(
            coordinator: coordinator,
            actor: fixture.actor,
            pusher: DurableOutboxPusher(coordinator, transport),
            puller: DurableInboxPuller(coordinator, transport),
            rebuilder: DurableProjectionRebuilder(coordinator),
            pullLimit: limit,
          ),
          throwsArgumentError,
        );
      }
      for (final stage in ['push', 'pull', 'rebuild']) {
        expect(
          () => AccountSyncWorker(
            coordinator: coordinator,
            actor: fixture.actor,
            pusher: DurableOutboxPusher(
              stage == 'push' ? foreign : coordinator,
              transport,
            ),
            puller: DurableInboxPuller(
              stage == 'pull' ? foreign : coordinator,
              transport,
            ),
            rebuilder: DurableProjectionRebuilder(
              stage == 'rebuild' ? foreign : coordinator,
            ),
          ),
          throwsArgumentError,
        );
      }
      expect(requests, isEmpty);
    },
  );

  test(
    'partial acknowledgment schedules bounded retry rather than falsely reporting idle',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      respond = (req, body) async {
        if (req.uri.path.endsWith('sync_push')) {
          await reply(req, {
            'protocol_version': {'major': 1, 'minor': 0},
            'accepted': <Object?>[],
            'server_ts_high': '0',
          });
        } else {
          await normal(req, body);
        }
      };
      await worker.start();
      expect(worker.status, AccountSyncStatus.pending);
      expect(timers.active.single.delay, const Duration(seconds: 1));
      final originalAlarm = timers.active.single;
      for (var i = 0; i < 10; i++) {
        worker.notifyLocalWrite();
      }
      expect(timers.active.single, same(originalAlarm));
      respond = normal;
      timers.fire();
      await worker.settled;
      expect(worker.status, AccountSyncStatus.idle);
      expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
    },
  );

  test(
    'compatible unknown accepted event is retained and classified attention not idle',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      final log =
          (await db.customSelect('SELECT * FROM change_log').get()).single.data;
      accepted.add({
        ...log,
        'server_ts': '1',
        'schema_version': 99,
        'device_monotonic': '${log['device_monotonic']}',
        'old_value': jsonDecode(log['old_value']! as String),
        'new_value': jsonDecode(log['new_value']! as String),
      });
      await db.customStatement('DELETE FROM outbox');
      await db.customStatement('DELETE FROM change_log');
      await db.customStatement('DELETE FROM ledger_entries');
      await worker.start();
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(1),
      );
      expect(
        await db.customSelect('SELECT * FROM ledger_entries').get(),
        isEmpty,
      );
      expect(worker.status, AccountSyncStatus.attention);
    },
  );

  test(
    'status stream exposes only classifications for actual projection success',
    () async {
      final statuses = <AccountSyncStatus>[];
      final subscription = worker.statuses.listen(statuses.add);
      addTearDown(subscription.cancel);
      await worker.start();
      expect(statuses, [AccountSyncStatus.syncing, AccountSyncStatus.idle]);
      await worker.dispose();
      worker.notifyForeground();
      worker.notifyLocalWrite();
      await worker.start();
      expect(statuses, [AccountSyncStatus.syncing, AccountSyncStatus.idle]);
      expect(timers.active, isEmpty);
    },
  );

  for (final change in ['same-user', 'A-B-A', 'member removed']) {
    test(
      '$change during HTTP admits no later stage or stale success status',
      () async {
        await LocalLedgerWriter(
          db,
          identity: local,
        ).create(fixture.actor, fixture.draft);
        final statuses = <AccountSyncStatus>[];
        final subscription = worker.statuses.listen(statuses.add);
        addTearDown(subscription.cancel);
        respond = (req, body) async {
          if (change == 'member removed') {
            await db.customStatement('DELETE FROM plan_members');
          } else if (change == 'same-user') {
            identity.marker = Object();
          } else {
            identity.user = fixture.actorB.userId;
            identity.marker = Object();
            final observing = coordinator.observeSession();
            identity.user = fixture.actor.userId;
            identity.marker = Object();
            unawaited(observing);
          }
          await normal(req, body);
        };
        await worker.start();
        expect(requests, ['sync_push']);
        expect(
          statuses,
          change == 'member removed'
              ? [AccountSyncStatus.syncing, AccountSyncStatus.error]
              : [AccountSyncStatus.syncing],
        );
        worker.notifyReconnect();
        await worker.settled;
        expect(requests, ['sync_push']);
        expect(timers.active, isEmpty);
        if (change != 'A-B-A') {
          // A-B-A reconciliation owns close/reopen; don't use its stale DB handle.
          if (change == 'member removed') {
            expect(
              await db.customSelect('SELECT * FROM outbox').get(),
              hasLength(1),
            );
          }
        } else {
          await coordinator.observeSession();
        }
      },
    );
  }

  for (final fault in [
    'update required',
    'authorization',
    'corrupt local queue',
    'incomplete history',
  ]) {
    test(
      '$fault publishes safe terminal status and ignores later triggers',
      () async {
        await LocalLedgerWriter(
          db,
          identity: local,
        ).create(fixture.actor, fixture.draft);
        final expected = fault == 'update required'
            ? AccountSyncStatus.updateRequired
            : fault == 'incomplete history'
            ? AccountSyncStatus.attention
            : AccountSyncStatus.error;
        if (fault == 'corrupt local queue') {
          await db.customStatement(
            "UPDATE change_log SET new_value='private-invalid-json'",
          );
        } else if (fault == 'incomplete history') {
          await db.customStatement('DELETE FROM outbox');
          await db.customStatement('DELETE FROM change_log');
        } else {
          respond = (req, body) {
            worker.notifyLocalWrite();
            return reply(
              req,
              fault == 'update required'
                  ? {'error': 'unsupported_protocol', 'min_supported_build': 7}
                  : {'error': 'private'},
              status: fault == 'update required' ? 426 : 403,
            );
          };
        }
        await worker.start();
        expect(worker.status, expected);
        final before = requests.length;
        worker.notifyLocalWrite();
        worker.notifyForeground();
        worker.notifyReconnect();
        await worker.start();
        expect(timers.active, isEmpty);
        expect(requests, hasLength(before));
        expect(
          await db.customSelect('SELECT * FROM ledger_entries').get(),
          hasLength(1),
        );
        if (fault != 'incomplete history') {
          expect(
            await db.customSelect('SELECT * FROM outbox').get(),
            hasLength(1),
          );
        }
      },
    );
  }

  test(
    'transient failure retains pending work and recovers on scheduled capped backoff',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      var failures = 0;
      respond = (req, body) async {
        if (failures++ < 7) {
          await reply(req, {'error': 'private'}, status: 503);
        } else {
          await normal(req, body);
        }
      };
      await worker.start();
      for (final seconds in [1, 2, 4, 8, 16, 30, 30]) {
        expect(worker.status, AccountSyncStatus.pending);
        expect(
          await db.customSelect('SELECT * FROM outbox').get(),
          hasLength(1),
        );
        expect(timers.active, hasLength(1));
        expect(timers.active.single.delay, Duration(seconds: seconds));
        timers.fire();
        await worker.settled;
      }
      expect(worker.status, AccountSyncStatus.idle);
      expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(1),
      );
      expect(timers.active, isEmpty);
    },
  );

  for (final change in ['same-user', 'A-B-A', 'storage unavailable']) {
    test(
      '$change replacement before start cannot reuse admitted actor',
      () async {
        if (change == 'storage unavailable') {
          await coordinator.close();
        } else if (change == 'same-user') {
          identity.marker =
              Object(); // Deliberately no coordinator notification.
        } else {
          identity.user = fixture.actorB.userId;
          identity.marker = Object();
          final b = coordinator.observeSession();
          identity.user = fixture.actor.userId;
          identity.marker = Object();
          await b;
          await coordinator.observeSession();
        }
        await worker.start();
        expect(requests, isEmpty);
        expect(timers.active, isEmpty);
      },
    );
  }

  test(
    'dispose during HTTP drains admitted operation but suppresses next stage',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      final entered = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      respond = (req, body) async {
        if (!entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        await normal(req, body);
      };
      final running = worker.start();
      await entered.future.timeout(const Duration(seconds: 5));
      var disposed = false;
      final disposing = worker.dispose().then((_) => disposed = true);
      expect(disposed, isFalse);
      release.complete();
      await Future.wait([running, disposing]);
      expect(requests, ['sync_push']);
      expect(coordinator.isReady, isTrue);
      expect(worker.status, AccountSyncStatus.stopped);
      expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
      expect(timers.active, isEmpty);
    },
  );

  test(
    'stop drains actual native acknowledgment COMMIT and admits no pull',
    () async {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      final entered = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      respond = (req, body) async {
        commit.action = () async {
          entered.complete();
          await release.future;
        };
        await normal(req, body);
      };
      final pausedStatuses = <AccountSyncStatus>[];
      final done = Completer<void>();
      final observer = worker.statuses.listen(
        pausedStatuses.add,
        onDone: done.complete,
      );
      addTearDown(observer.cancel);
      observer.pause();
      final running = worker.start();
      await entered.future.timeout(const Duration(seconds: 5));
      var stopped = false;
      final stopping = worker.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      release.complete();
      await Future.wait([
        running,
        stopping,
      ]).timeout(const Duration(seconds: 5));
      expect(stopped, isTrue);
      observer.resume();
      await done.future;
      expect(pausedStatuses, isEmpty);
      expect(await worker.statuses.toList(), isEmpty);
      expect(requests, ['sync_push']);
      expect(coordinator.isReady, isTrue);
      await coordinator.close();
      final reopened = await EncryptedDatabaseOpener(file, keys).open();
      try {
        expect(
          await reopened.customSelect('SELECT * FROM outbox').get(),
          isEmpty,
        );
        expect(
          (await reopened
                  .customSelect('SELECT server_ts FROM change_log')
                  .get())
              .single
              .data['server_ts'],
          1,
        );
      } finally {
        await reopened.close();
      }
    },
  );

  test('full push batch schedules asynchronous bounded continuation', () async {
    for (var i = 0; i < 101; i++) {
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
    }
    await worker.start();
    expect(await db.customSelect('SELECT * FROM outbox').get(), hasLength(1));
    expect(timers.active, hasLength(1));
    expect(timers.active.single.delay, Duration.zero);
    expect(worker.status, AccountSyncStatus.pending);
    timers.fire();
    await worker.settled;
    expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
    expect(accepted, hasLength(101));
    expect(worker.status, AccountSyncStatus.idle);
  });

  test(
    'bounded multi-page pull preserves projection until complete and continues automatically',
    () async {
      await worker.dispose();
      worker = AccountSyncWorker(
        coordinator: coordinator,
        actor: fixture.actor,
        schedule: timers.schedule,
        pusher: DurableOutboxPusher(coordinator, transport),
        puller: DurableInboxPuller(coordinator, transport),
        rebuilder: DurableProjectionRebuilder(coordinator),
        maxPullPages: 1,
        pullLimit: 1,
      );
      for (var i = 0; i < 2; i++) {
        await LocalLedgerWriter(
          db,
          identity: local,
        ).create(fixture.actor, fixture.draft);
      }
      await worker.start();
      expect(requests, ['sync_push', 'sync_pull']);
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(1),
      );
      expect(timers.active, hasLength(1));
      timers.fire();
      await worker.settled;
      expect(requests, ['sync_push', 'sync_pull', 'sync_pull']);
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(2),
      );
      expect(
        await db.customSelect('SELECT * FROM ledger_entries').get(),
        hasLength(2),
      );
      expect(worker.status, AccountSyncStatus.idle);
      expect(timers.active, isEmpty);
    },
  );

  test(
    'successful local write bursts debounce to one automatic cycle',
    () async {
      await worker.start();
      requests.clear();
      await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      for (var i = 0; i < 20; i++) {
        worker.notifyLocalWrite();
      }
      expect(requests, isEmpty);
      expect(timers.active, hasLength(1));
      expect(worker.status, AccountSyncStatus.pending);
      expect(timers.active.single.delay, const Duration(milliseconds: 250));
      timers.fire();
      await worker.settled;
      expect(requests, ['sync_push', 'sync_pull']);
      expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
    },
  );

  test(
    'foreground and reconnect notifications coalesce without overlapping HTTP',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      respond = (req, body) async {
        if (!entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        await normal(req, body);
      };
      final starting = worker.start();
      await entered.future.timeout(const Duration(seconds: 5));
      for (var i = 0; i < 20; i++) {
        worker.notifyForeground();
        worker.notifyReconnect();
      }
      expect(requests, ['sync_pull']);
      release.complete();
      await starting;
      expect(timers.active, hasLength(1));
      timers.fire();
      await worker.settled;
      expect(requests, ['sync_pull', 'sync_pull']);
      expect(timers.active, isEmpty);
    },
  );

  test('repeated start shares one serialized in-flight cycle', () async {
    await LocalLedgerWriter(
      db,
      identity: local,
    ).create(fixture.actor, fixture.draft);
    final entered = Completer<void>(), release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    respond = (req, body) async {
      if (req.uri.path.endsWith('sync_push') && !entered.isCompleted) {
        entered.complete();
        await release.future;
      }
      await normal(req, body);
    };
    final first = worker.start();
    await entered.future.timeout(const Duration(seconds: 5));
    final second = worker.start();
    release.complete();
    await Future.wait([first, second]);
    expect(requests, ['sync_push', 'sync_pull']);
  });

  test(
    'explicit start automatically pushes retains and rebuilds encrypted local create',
    () async {
      final row = await LocalLedgerWriter(
        db,
        identity: local,
      ).create(fixture.actor, fixture.draft);
      expect(requests, isEmpty);
      respond = (req, body) async {
        if (req.uri.path.endsWith('sync_pull')) {
          // Destroy only the derived projection after the real push: successful
          // acknowledgment alone cannot satisfy this reconstruction assertion.
          await db.customStatement('DELETE FROM ledger_entries');
        }
        await normal(req, body);
      };
      await worker.start();
      expect(requests, ['sync_push', 'sync_pull']);
      expect(await db.customSelect('SELECT * FROM outbox').get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM sync_inbox').get(),
        hasLength(1),
      );
      expect(
        (await db.customSelect('SELECT * FROM ledger_entries').get())
            .single
            .data,
        row.toJson(),
      );
      expect(worker.status, AccountSyncStatus.idle);
    },
  );
}
