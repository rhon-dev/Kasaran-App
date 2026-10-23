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
import 'package:kasaran/platform/secure_storage/sync_device_identity.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';
import 'package:kasaran/sync/queue/account_sync_worker.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

import '../transport/bootstrap_transport_test.dart' as wire;
import 'account_metadata_bootstrapper_test.dart' show AfterCommitHook;
import 'account_sync_worker_test.dart' show TestTimers;
import 'durable_outbox_pusher_test.dart' as fixture;

class TrackedClient implements HttpClient {
  final HttpClient inner = HttpClient();
  int closes = 0;
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  Future<HttpClientRequest> postUrl(Uri url) => inner.postUrl(url);
  @override
  void close({bool force = false}) {
    closes++;
    inner.close(force: force);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Metadata implements SecureKeyValueStore {
  // Existing identity only: absent-key creation needs separate independent review.
  String value = wire.deviceId;
  Future<void> Function()? beforeRead;
  @override
  Future<String?> read(String key) async {
    await beforeRead?.call();
    return value;
  }

  @override
  Future<void> write(String key, String value) async => this.value = value;
  @override
  Future<void> delete(String key) async => throw StateError('Not used');
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late fixture.Identity identity;
  late AccountStoreCoordinator coordinator;
  late HttpServer server;
  late AccountSyncHost host;
  late Metadata metadata;
  late AfterCommitHook commit;
  late TrackedClient syncClient, bootstrapClient;
  late TestTimers timers;
  late HttpSyncTransport sync;
  late HttpBootstrapTransport bootstrap;
  late Future<String?> Function(SyncSessionBinding) discovery;
  late Future<void> Function(HttpRequest, Map<String, dynamic>) respond;
  late List<String> requests;
  late int discoveries;
  Future<void> reply(HttpRequest req, Object body, {int status = 200}) async {
    req.response.statusCode = status;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> normal(HttpRequest req, Map<String, dynamic> body) async {
    if (req.uri.path.endsWith('sync_bootstrap')) {
      await reply(req, wire.snapshot());
    } else {
      await reply(req, {
        'protocol_version': {'major': 1, 'minor': 0},
        'rows': <Object>[],
        'next_cursor': body['cursor'],
        'has_more': false,
      });
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kasaran-host-');
    identity = fixture.Identity()..user = wire.userId;
    final keys = fixture.Keys();
    final file = File('${dir.path}/a.sqlite');
    final initial = await EncryptedDatabaseOpener(file, keys).open();
    await initial.close();
    commit = AfterCommitHook();
    coordinator = AccountStoreCoordinator(
      fixture.LocalIdentity(identity),
      (_) async => db = AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            if (raw.select('PRAGMA cipher').isEmpty) {
              throw StateError('Cipher required');
            }
            raw.execute("PRAGMA key = '${keys.key!}'");
          },
        ).interceptWith(commit),
      ),
    );

    await coordinator.observeSession();
    requests = [];
    discoveries = 0;
    discovery = (_) async {
      discoveries++;
      return wire.planId;
    };
    respond = normal;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body =
          jsonDecode(await utf8.decoder.bind(req).join())
              as Map<String, dynamic>;
      requests.add(req.uri.path.split('/').last);
      await respond(req, body);
    });
    final url = Uri.parse('http://127.0.0.1:${server.port}');
    syncClient = TrackedClient();
    bootstrapClient = TrackedClient();
    sync = HttpSyncTransport(
      client: syncClient,
      baseUrl: url,
      anonKey: 'synthetic',
      sessions: identity,
      maxAttempts: 1,
    );
    bootstrap = HttpBootstrapTransport(
      client: bootstrapClient,
      baseUrl: url,
      anonKey: 'synthetic',
      sessions: identity,
      maxAttempts: 1,
    );
    metadata = Metadata();
    timers = TestTimers();
    host = AccountSyncHost.ownedTransports(
      coordinator: coordinator,
      deviceIdentity: SyncDeviceIdentity(metadata),
      discoverMembership: (binding) => discovery(binding),
      syncTransport: sync,
      bootstrapTransport: bootstrap,
      schedule: timers.schedule,
    );
  });
  tearDown(() async {
    await host.dispose();
    await server.close(force: true);
    await coordinator.close();
    await dir.delete(recursive: true);
  });
  test(
    'committed local notification invalidates now and debounces worker HTTP',
    () async {
      await fixture.seed(db, fixtureActor);
      await host.start();
      await host.settled;
      var changes = 0;
      host.addListener(() => changes++);
      host.notifyLocalWrite();
      host.notifyLocalWrite();
      expect(changes, greaterThanOrEqualTo(2));
      expect(requests, ['sync_pull']);
      expect(timers.active.single.delay, const Duration(milliseconds: 250));
      timers.fire();
      await host.settled;
      expect(requests, ['sync_pull', 'sync_pull']);
      await host.dispose();
      final before = changes;
      host.notifyLocalWrite();
      expect(changes, before);
    },
  );

  test(
    'asynchronous invalidation observer cannot hold disposal or replay stale authority',
    () async {
      await fixture.seed(db, fixtureActor);
      final release = Completer<void>();
      final observed = <AccountSyncHostStatus>[];
      final callbacks = <Future<void>>[];
      host.addListener(() {
        callbacks.add(() async {
          await release.future;
          observed.add(host.status);
        }());
      });
      await host.start();
      await host.settled;
      await host.dispose().timeout(const Duration(seconds: 2));
      expect(syncClient.closes, 1);
      expect(observed, isEmpty);
      release.complete();
      await Future.wait(callbacks);
      expect(observed, everyElement(AccountSyncHostStatus.stopped));
    },
  );
  test(
    'dispose drains actual remote projection COMMIT without success invalidation',
    () async {
      await fixture.seed(db, fixtureActor);
      final row = await LocalLedgerWriter(
        db,
        identity: coordinator.identity,
      ).create(fixtureActor, fixture.draft);
      final log =
          (await db.customSelect('SELECT * FROM change_log').get()).single.data;
      final event = <String, dynamic>{
        ...log,
        'server_ts': '1',
        'device_monotonic': '${log['device_monotonic']}',
        'old_value': jsonDecode(log['old_value']! as String),
        'new_value': jsonDecode(log['new_value']! as String),
      };
      await db.customStatement('DELETE FROM outbox');
      await db.customStatement('DELETE FROM change_log');
      await db.customStatement('DELETE FROM ledger_entries');
      final entered = Completer<void>(), release = Completer<void>();
      respond = (req, body) async {
        commit.action = () async {
          commit.action = () async {
            entered.complete();
            await release.future;
          };
        };
        await reply(req, {
          'protocol_version': {'major': 1, 'minor': 0},
          'rows': [event],
          'next_cursor': '1',
          'has_more': false,
        });
      };
      final seen = <AccountSyncStatus>[];
      host.addListener(() => seen.add(host.syncStatus));
      await host.start();
      await entered.future.timeout(const Duration(seconds: 5));
      final before = List.of(seen);
      var closed = false;
      final closing = host.dispose().then((_) => closed = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(closed, isFalse);
        expect(syncClient.closes, 0);
        expect(bootstrapClient.closes, 0);
      } finally {
        release.complete();
      }
      await closing.timeout(const Duration(seconds: 5));
      expect(seen, before);
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
      expect(syncClient.closes, 1);
      expect(bootstrapClient.closes, 1);
    },
  );
  test(
    'discovered conflicting retained metadata is not overwritten by bootstrap',
    () async {
      discovery = (_) async {
        discoveries++;
        await fixture.seed(db, fixtureActor);
        return wire.planId;
      };
      await host.start();
      expect(host.status, AccountSyncHostStatus.error);
      expect(host.actor, isNull);
      expect(
        (await db.customSelect('SELECT total_budget_cents FROM plans').get())
            .single
            .data['total_budget_cents'],
        10000,
      );
      expect(requests, ['sync_bootstrap']);
      await host.refreshMembership();
      host.notifyForeground();
      expect(discoveries, 1);
    },
  );
  test(
    'construction requires an already-ready caller-owned coordinator',
    () async {
      await coordinator.close();
      expect(
        () => AccountSyncHost.ownedTransports(
          coordinator: coordinator,
          deviceIdentity: SyncDeviceIdentity(metadata),
          discoverMembership: discovery,
          syncTransport: sync,
          bootstrapTransport: bootstrap,
        ),
        throwsStateError,
      );
      expect(requests, isEmpty);
    },
  );
  test('periodic policy leaves pending worker backoff to the worker', () async {
    await fixture.seed(db, fixtureActor);
    respond = (req, body) => reply(req, {'error': 'transient'}, status: 503);
    host.notifyForeground();
    await host.settled;
    expect(host.syncStatus, AccountSyncStatus.pending);
    final retry = timers.active.singleWhere(
      (a) => a.delay == const Duration(seconds: 1),
    );
    final periodic = timers.active.singleWhere(
      (a) => a.delay == const Duration(seconds: 30),
    );
    final before = requests.length;
    periodic.fire();
    await host.settled;
    expect(requests, hasLength(before));
    expect(retry.isActive, isTrue);
    respond = normal;
    retry.fire();
    await host.settled;
    expect(host.syncStatus, AccountSyncStatus.idle);
  });
  for (final stage in [
    'local COMMIT',
    'device',
    'discovery',
    'bootstrap HTTP',
    'bootstrap COMMIT',
    'worker HTTP',
    'worker COMMIT',
  ]) {
    for (final change in ['same-user', 'A-B-A', 'generation']) {
      test(
        '$change during $stage never adopts a replacement session',
        () async {
          final entered = Completer<void>(), release = Completer<void>();
          Future<void> gate() async {
            entered.complete();
            await release.future;
          }

          if (stage.startsWith('worker')) await fixture.seed(db, fixtureActor);
          if (stage == 'local COMMIT') commit.action = gate;
          if (stage == 'device') metadata.beforeRead = gate;
          if (stage == 'discovery') {
            discovery = (_) async {
              await gate();
              return wire.planId;
            };
          }
          respond = (req, body) async {
            if (stage.endsWith('HTTP')) await gate();
            if (stage.endsWith('COMMIT') && stage != 'local COMMIT') {
              commit.action = gate;
            }
            await normal(req, body);
          };
          final starting = host.start();
          await entered.future.timeout(const Duration(seconds: 5));
          final Future<void> changing;
          if (change == 'generation') {
            changing = coordinator.transition(() async {});
          } else {
            if (change == 'A-B-A') identity.user = fixture.actorB.userId;
            identity.marker = Object();
            changing = coordinator.observeSession();
            if (change == 'A-B-A') {
              identity.user = wire.userId;
              identity.marker = Object();
            }
          }
          try {
            expect(host.status, AccountSyncHostStatus.stopped);
            expect(host.actor, isNull);
            expect(syncClient.closes, 0);
            expect(bootstrapClient.closes, 0);
          } finally {
            release.complete();
          }
          await Future.wait([
            starting,
            changing,
            host.dispose(),
          ]).timeout(const Duration(seconds: 5));
          metadata.beforeRead = null;
          await coordinator.observeSession();
          await host.start();
          host.notifyForeground();
          await host.refreshMembership();
          expect(host.actor, isNull);
          expect(host.status, AccountSyncHostStatus.stopped);
          expect(timers.active, isEmpty);
          expect(syncClient.closes, 1);
          expect(bootstrapClient.closes, 1);
          expect(
            requests.length,
            stage.startsWith('bootstrap') || stage.startsWith('worker') ? 1 : 0,
          );
        },
      );
    }
  }
  test(
    'guarded invalidation suppresses later callbacks after reentrant revocation',
    () async {
      final later = <AccountSyncHostStatus>[];
      host.addListener(() {
        identity.marker = Object();
      });
      host.addListener(() {
        later.add(host.status);
      });
      await host.start();
      expect(later, isEmpty);
      expect(host.status, AccountSyncHostStatus.stopped);
      expect(requests, isEmpty);
    },
  );
  test(
    'unsafe discovery protocol failure is terminal rather than retryable offline',
    () async {
      discovery = (_) async {
        discoveries++;
        throw const SyncProtocolException('invalid_response');
      };
      host.notifyForeground();
      await host.settled;
      expect(host.status, AccountSyncHostStatus.error);
      expect(timers.active, isEmpty);
      await host.start();
      await host.refreshMembership();
      host.notifyForeground();
      expect(discoveries, 1);
      expect(host.actor, isNull);
    },
  );
  test(
    'terminal bootstrap failure invalidates authority classification',
    () async {
      final seen = <AccountSyncHostStatus>[];
      host.addListener(() => seen.add(host.status));
      respond = (req, body) => reply(req, {'error': 'forbidden'}, status: 403);
      await host.start();
      expect(seen.last, AccountSyncHostStatus.error);
    },
  );
  test(
    'periodic foreground idle wake retains and rebuilds a real remote event',
    () async {
      await fixture.seed(db, fixtureActor);
      final row = await LocalLedgerWriter(
        db,
        identity: coordinator.identity,
      ).create(fixtureActor, fixture.draft);
      final log =
          (await db.customSelect('SELECT * FROM change_log').get()).single.data;
      final event = <String, dynamic>{
        ...log,
        'server_ts': '1',
        'device_monotonic': '${log['device_monotonic']}',
        'old_value': jsonDecode(log['old_value']! as String),
        'new_value': jsonDecode(log['new_value']! as String),
      };
      await db.customStatement('DELETE FROM outbox');
      await db.customStatement('DELETE FROM change_log');
      await db.customStatement('DELETE FROM ledger_entries');
      host.notifyForeground();
      await host.settled;
      expect(host.syncStatus, AccountSyncStatus.idle);
      expect(
        await db.customSelect('SELECT * FROM ledger_entries').get(),
        isEmpty,
      );
      respond = (req, body) => reply(req, {
        'protocol_version': {'major': 1, 'minor': 0},
        'rows': [event],
        'next_cursor': '1',
        'has_more': false,
      });
      timers
          .fire(); // No foreground/reconnect/button call after remote arrival.
      await host.settled;
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
      expect(discoveries, 0);
      expect(requests, ['sync_pull', 'sync_pull']);
      host.notifyBackground();
      expect(timers.active, isEmpty);
      for (final alarm in timers.alarms) {
        alarm.fire();
      }
      await host.settled;
      expect(requests, hasLength(2));
    },
  );
  test(
    'failed HTTP bootstrap retries automatically on foreground period',
    () async {
      var attempts = 0;
      respond = (req, body) async {
        if (req.uri.path.endsWith('sync_bootstrap') && attempts++ < 2) {
          await reply(req, {'error': 'transient'}, status: 503);
        } else {
          await normal(req, body);
        }
      };
      await host.start();
      expect(host.status, AccountSyncHostStatus.pending);
      expect(host.actor, isNull);
      expect(await db.customSelect('SELECT * FROM plans').get(), isEmpty);
      host.notifyForeground();
      await host.settled;
      expect(host.status, AccountSyncHostStatus.pending);
      timers.fire();
      await host.settled;
      expect(host.status, AccountSyncHostStatus.ready);
      expect(requests, [
        'sync_bootstrap',
        'sync_bootstrap',
        'sync_bootstrap',
        'sync_pull',
      ]);
      expect(host.actor, isNotNull);
    },
  );
  test(
    'repeated start refresh and foreground coalesce discovery without overlap',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      discovery = (_) async {
        discoveries++;
        entered.complete();
        await release.future;
        return wire.planId;
      };
      final first = host.start();
      await entered.future;
      final starts = <Future<void>>[first];
      for (var i = 0; i < 10; i++) {
        starts.add(host.start());
        starts.add(host.refreshMembership());
        host.notifyForeground();
      }
      expect(discoveries, 1);
      expect(requests, isEmpty);
      release.complete();
      await Future.wait(starts);
      await host.settled;
      expect(requests, ['sync_bootstrap', 'sync_pull']);
      expect(timers.active, hasLength(1));
    },
  );
  for (final stage in [
    'device',
    'discovery',
    'bootstrap HTTP',
    'bootstrap COMMIT',
    'worker HTTP',
    'worker COMMIT',
  ]) {
    test(
      'dispose drains $stage before closing either owned transport',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        Future<void> gate() async {
          entered.complete();
          await release.future;
        }

        if (stage.startsWith('worker')) await fixture.seed(db, fixtureActor);
        if (stage == 'device') metadata.beforeRead = gate;
        if (stage == 'discovery') {
          discovery = (_) async {
            await gate();
            return wire.planId;
          };
        }
        respond = (req, body) async {
          if (stage.endsWith('HTTP')) await gate();
          if (stage.endsWith('COMMIT')) commit.action = gate;
          await normal(req, body);
        };
        final starting = host.start();
        await entered.future.timeout(const Duration(seconds: 5));
        var closed = false;
        final barrier = host.dispose();
        expect(host.dispose(), same(barrier));
        final closing = barrier.then((_) => closed = true);
        try {
          expect(host.status, AccountSyncHostStatus.stopped);
          expect(host.actor, isNull);
          await host.start();
          host.notifyForeground();
          await host.refreshMembership();
          await expectLater(host.readLocalPlan(), throwsStateError);
          await Future<void>.delayed(Duration.zero);
          expect(closed, isFalse);
          expect(syncClient.closes, 0);
          expect(bootstrapClient.closes, 0);
        } finally {
          release.complete();
        }
        await Future.wait([
          starting,
          closing,
        ]).timeout(const Duration(seconds: 5));
        expect(syncClient.closes, 1);
        expect(bootstrapClient.closes, 1);
        expect(coordinator.isReady, isTrue);
        expect(timers.active, isEmpty);
        if (stage == 'bootstrap COMMIT') {
          expect(
            await db.customSelect('SELECT * FROM plans').get(),
            hasLength(1),
          );
          expect(requests, ['sync_bootstrap']);
        }
      },
    );
  }
  test(
    'local capability and finite reads do not wait for paused worker HTTP',
    () async {
      await fixture.seed(db, fixtureActor);
      final entered = Completer<void>(), release = Completer<void>();
      respond = (req, body) async {
        entered.complete();
        await release.future;
        await normal(req, body);
      };
      await host.start();
      await entered.future;
      try {
        expect(host.actor, isNotNull);
        expect(
          (await host.readLocalPlan().timeout(
            const Duration(seconds: 2),
          ))!.plan.id,
          wire.planId,
        );
        expect(discoveries, 0);
      } finally {
        release.complete();
      }
      await host.settled;
    },
  );
  test(
    'dispose drains admitted local read native COMMIT before transport close',
    () async {
      await fixture.seed(db, fixtureActor);
      final entered = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      commit.action = () async {
        entered.complete();
        await release.future;
      };
      final reading = host.readLocalPlan();
      final rejected = expectLater(reading, throwsStateError);
      await entered.future.timeout(const Duration(seconds: 5));
      var closed = false;
      final closing = host.dispose().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      expect(syncClient.closes, 0);
      expect(bootstrapClient.closes, 0);
      release.complete();
      await Future.wait([closing, rejected]);
      expect(syncClient.closes, 1);
      expect(bootstrapClient.closes, 1);
      expect(coordinator.isReady, isTrue);
    },
  );
  test(
    'worker completion and terminal authority changes invalidate fresh pull getters',
    () async {
      await fixture.seed(db, fixtureActor);
      final seen = <AccountSyncStatus>[];
      final classified = <AccountSyncHostStatus>[];
      host.addListener(() {
        seen.add(host.syncStatus);
        classified.add(host.status);
      });
      await host.start();
      await host.settled;
      expect(seen, contains(AccountSyncStatus.idle));
      respond = (req, body) => reply(req, {'error': 'forbidden'}, status: 403);
      host.notifyForeground();
      await host.settled;
      expect(classified.last, AccountSyncHostStatus.error);
      expect(host.actor, isNull);
    },
  );
  test(
    'reentrant classification invalidation may dispose before worker HTTP admission',
    () async {
      await fixture.seed(db, fixtureActor);
      Future<void>? closing;
      host.addListener(() {
        if (host.status == AccountSyncHostStatus.ready) {
          closing = host.dispose();
        }
      });
      await host.start();
      await closing;
      expect(host.status, AccountSyncHostStatus.stopped);
      expect(host.actor, isNull);
      expect(requests, isEmpty);
      expect(identical(host.dispose(), host.dispose()), isTrue);
      await expectLater(host.readLocalPlan(), throwsStateError);
    },
  );
  for (final phase in ['bootstrap', 'worker']) {
    for (final code in [403, 426]) {
      test(
        '$phase terminal $code revokes capability and cannot be reset by wakes',
        () async {
          if (phase == 'worker') await fixture.seed(db, fixtureActor);
          respond = (req, body) => reply(
            req,
            code == 426
                ? {'error': 'unsupported_protocol', 'min_supported_build': 9}
                : {'error': 'forbidden'},
            status: code,
          );
          await host.start();
          await host.settled;
          final expected = code == 426
              ? AccountSyncHostStatus.updateRequired
              : AccountSyncHostStatus.error;
          expect(host.status, expected);
          expect(host.actor, isNull);
          final before = requests.length;
          await host.start();
          await host.refreshMembership();
          host.notifyForeground();
          if (timers.active.isNotEmpty) timers.fire();
          await host.settled;
          expect(host.status, expected);
          expect(requests, hasLength(before));
          expect(timers.active, isEmpty);
          if (phase == 'worker') {
            expect(
              await db.customSelect('SELECT * FROM plans').get(),
              hasLength(1),
            );
          }
        },
      );
    }
  }
  test('explicit refresh trails older captured-none discovery on the same host', () async {
    final entered = Completer<void>(), release = Completer<void>();
    var accepted = false;
    discovery = (binding) async {
      expect(binding.marker, same(identity.marker));
      discoveries++;
      final captured = accepted ? wire.planId : null;
      if (discoveries == 1) {
        entered.complete();
        await release.future;
      }
      return captured;
    };
    final starting = host.start();
    await entered.future;
    accepted = true;
    final refresh = host.refreshMembership();
    final repeated = host.refreshMembership();
    expect(repeated, same(refresh));
    expect(host.start(), same(starting));
    host.notifyForeground();
    expect(discoveries, 1);
    release.complete();
    await Future.wait([starting, refresh, repeated]);
    await host.settled;
    expect(discoveries, 2);
    expect(host.status, AccountSyncHostStatus.ready);
    expect(host.actor?.planId, wire.planId);
    expect(requests.where((r) => r == 'sync_bootstrap'), hasLength(1));
  });
  test(
    'explicit post-invite refresh retries session-only none then bootstraps once',
    () async {
      discovery = (_) async {
        discoveries++;
        return null;
      };
      await host.start();
      expect(host.status, AccountSyncHostStatus.none);
      host.notifyForeground();
      timers.fire();
      await host.settled;
      expect(discoveries, 1);
      discovery = (_) async {
        discoveries++;
        return wire.planId;
      };
      await Future.wait([
        host.refreshMembership(),
        host.refreshMembership(),
        host.start(),
      ]);
      await host.settled;
      expect(discoveries, 2);
      expect(host.actor, isNotNull);
      expect(requests.where((r) => r == 'sync_bootstrap'), hasLength(1));
      await host.refreshMembership();
      expect(discoveries, 2);
      expect(requests.where((r) => r == 'sync_bootstrap'), hasLength(1));
    },
  );
  test(
    'foreground 30-second policy retries initial discovery without a button',
    () async {
      discovery = (_) async {
        discoveries++;
        if (discoveries < 3) throw const SocketException('offline synthetic');
        return wire.planId;
      };
      await host.start();
      expect(host.status, AccountSyncHostStatus.pending);
      expect(timers.active, isEmpty); // Explicitly background by default.
      host.notifyForeground();
      await host.settled;
      expect(discoveries, 2);
      expect(timers.active.single.delay, const Duration(seconds: 30));
      timers.fire();
      await host.settled;
      expect(discoveries, 3);
      expect(host.actor, isNotNull);
      expect(host.syncStatus, AccountSyncStatus.idle);
      host.notifyBackground();
      expect(timers.active, isEmpty);
    },
  );
  test(
    'same-user replacement during discovery permanently revokes this host',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      discovery = (_) async {
        entered.complete();
        await release.future;
        return wire.planId;
      };
      final start = host.start();
      await entered.future;
      identity.marker = Object();
      final changed = coordinator.observeSession();
      expect(host.status, AccountSyncHostStatus.stopped);
      expect(host.actor, isNull);
      release.complete();
      await start;
      await changed;
      await host.start();
      expect(host.status, AccountSyncHostStatus.stopped);
      expect(requests, isEmpty);
      expect(await db.customSelect('SELECT * FROM plans').get(), isEmpty);
    },
  );
  test(
    'empty is unknown until successful discovery explicitly confirms none',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      discovery = (_) async {
        entered.complete();
        await release.future;
        return null;
      };
      expect(host.status, AccountSyncHostStatus.unknown);
      final start = host.start();
      await entered.future;
      expect(host.status, AccountSyncHostStatus.initializing);
      expect(host.actor, isNull);
      release.complete();
      await start;
      expect(host.status, AccountSyncHostStatus.none);
      expect(requests, isEmpty);
      await host.start();
      expect(host.status, AccountSyncHostStatus.none);
    },
  );
  test(
    'empty encrypted account bootstraps actual metadata then auto-starts worker',
    () async {
      await host.start();
      await host.settled;
      expect(discoveries, 1);
      expect(host.actor!.planMemberId, wire.aliasId);
      expect(requests, ['sync_bootstrap', 'sync_pull']);
      expect(host.syncStatus, AccountSyncStatus.idle);
      expect(
        (await host.readLocalPlan())!.plan.totalBudgetCents,
        9223372036854775807,
      );
      expect(await db.customSelect('SELECT * FROM change_log').get(), isEmpty);
    },
  );
  test(
    'existing encrypted membership starts actual worker without discovery',
    () async {
      await fixture.seed(db, constFixtureActor);
      await host.start();
      await host.settled;
      expect(discoveries, 0);
      expect(host.actor!.planId, wire.planId);
      expect(host.syncStatus, AccountSyncStatus.idle);
      expect(requests, ['sync_pull']);
      expect((await host.readLocalPlan())!.member.userId, wire.userId);
    },
  );
}

const constFixtureActor = fixtureActor;
// Actor values match the independently validated bootstrap wire fixture.
const fixtureActor = LedgerActor(
  planId: wire.planId,
  userId: wire.userId,
  planMemberId: wire.aliasId,
  deviceId: wire.deviceId,
);
