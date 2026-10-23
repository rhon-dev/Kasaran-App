import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, TransactionExecutor;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/auth_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/secure_storage/sync_device_identity.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';
import 'package:kasaran/sync/queue/sync_runtime_owner.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';
import 'package:kasaran/ui/providers/account_store_provider.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/providers/sync_runtime_provider.dart';
import 'package:kasaran/ui/sync_runtime_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/queue/account_sync_host_test.dart'
    show Metadata, TrackedClient, fixtureActor;
import '../sync/queue/account_sync_worker_test.dart' show TestTimers;
import '../sync/queue/durable_outbox_pusher_test.dart' as fixture;
import '../sync/transport/bootstrap_transport_test.dart' as wire;
import 'production_sync_runtime_test.dart' show session;

class _LoopbackHttp extends HttpOverrides {}

void main() {
  for (final boundary in [
    'ledger SELECT',
    'plan SELECT',
    'ledger read COMMIT',
    'plan read COMMIT',
    'mutation COMMIT',
  ]) {
    for (final transition in ['signout', 'same-user', 'A-B-A']) {
      testWidgets('mounted root $transition revokes held native $boundary', (
        tester,
      ) async {
        final harness = (await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(_PinnedRoot.open, _LoopbackHttp())))!;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: SyncRuntimeGate(
              owner: harness.owner,
              child: const SizedBox(),
            ),
          ),
        );
        try {
          await tester.runAsync(() async {
            await harness.owner.settled;
            final container = harness.container;
            final subscriptions = [
              container.listen(ledgerEntriesProvider, (_, _) {}),
              container.listen(currentPlanIdProvider, (_, _) {}),
              container.listen(syncHostStatusProvider, (_, _) {}),
            ];
            try {
              expect(await container.read(ledgerEntriesFutureProvider), hasLength(1));
              expect(await container.read(currentPlanIdFutureProvider), wire.planId);
              final old = harness.owner.host!;
              final ledger = container.read(boundLedgerProvider)!;
              final clients = List.of(harness.clients);
              final requests = harness.requests;
              harness.hook.arm(boundary);
              final Future<Object?> operation;
              if (boundary == 'mutation COMMIT') {
                operation = ledger.create(fixture.draft);
              } else if (boundary.startsWith('ledger')) {
                container.invalidate(ledgerEntriesFutureProvider);
                // Invalidate the finite query through the existing host revision.
                old.notifyLocalWrite();
                operation = container.read(ledgerEntriesFutureProvider);
              } else {
                container.invalidate(localPlanLookupProvider);
                operation = container.read(currentPlanIdFutureProvider);
              }
              final rejected = expectLater(operation, throwsStateError);
              await harness.hook.entered!.future.timeout(const Duration(seconds: 5));
              if (transition == 'signout') {
                await harness.client.auth.signOut();
              } else {
                await harness.client.auth.recoverSession(
                  session(transition == 'A-B-A' ? 'synthetic-b' : wire.userId),
                );
              }
              final observations = [harness.coordinator.observeSession()];
              if (transition == 'A-B-A') {
                await harness.client.auth.recoverSession(session(wire.userId));
                observations.add(harness.coordinator.observeSession());
              }
              expect(old.actor, isNull);
              expect(container.read(boundLedgerProvider), isNull);
              expect(container.read(ledgerEntriesProvider).value, isNull);
              expect(container.read(currentPlanIdProvider).value, isNull);
              expect(clients.map((c) => c.closes), everyElement(0));
              expect(harness.opens, 1);
              expect(harness.requests, requests);
              await expectLater(ledger.listLive(), throwsStateError);
              harness.hook.release!.complete();
              await rejected;
              await Future.wait(observations);
              await harness.owner.settled;
              expect(clients.map((c) => c.closes), everyElement(1));
              if (transition == 'signout') {
                expect(harness.owner.host, isNull);
                expect(container.read(ledgerEntriesProvider).value, isNull);
                expect(container.read(currentPlanIdProvider).value, isNull);
                await harness.client.auth.recoverSession(session(wire.userId));
                await harness.coordinator.observeSession();
                await harness.owner.settled;
              }
              expect(harness.owner.host, isNot(same(old)));
              expect(harness.owner.host?.actor?.userId, wire.userId);
              expect(harness.opens, 2, reason: 'no intermediate B store/host');
              expect(await container.read(currentPlanIdFutureProvider), wire.planId);
              expect(
                await container.read(ledgerEntriesFutureProvider),
                hasLength(boundary == 'mutation COMMIT' ? 2 : 1),
                reason: 'native COMMIT drains durably but stale result never escapes',
              );
              expect(harness.discoveries, 0);
            } finally {
              if (!(harness.hook.release?.isCompleted ?? true)) {
                harness.hook.release!.complete();
              }
              for (final subscription in subscriptions) {
                subscription.close();
              }
            }
          });
        } finally {
          await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
          await tester.runAsync(harness.close);
        }
      });
    }
  }

  testWidgets('root uncertain native close retains handle and owned clients fail closed', (tester) async {
    final harness = (await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(_PinnedRoot.open, _LoopbackHttp())))!;
    await tester.pumpWidget(SyncRuntimeGate(owner: harness.owner, child: const SizedBox()));
    await tester.runAsync(() async {
      await harness.owner.settled;
      final container = harness.container;
      final subscription = container.listen(ledgerEntriesProvider, (_, _) {});
      final planSubscription = container.listen(currentPlanIdProvider, (_, _) {});
      try {
        expect(await container.read(ledgerEntriesFutureProvider), hasLength(1));
        expect(await container.read(currentPlanIdFutureProvider), wire.planId);
        final old = container.read(boundLedgerProvider)!;
        harness.hook.failClose = true;
        final closing = harness.owner.close();
        final failed = expectLater(closing, throwsStateError);
        expect(harness.owner.close(), same(closing));
        expect(container.read(syncHostStatusProvider), AccountSyncHostStatus.stopped);
        expect(container.read(boundLedgerProvider), isNull);
        expect(container.read(ledgerEntriesProvider).value, isNull);
        expect(container.read(currentPlanIdProvider).value, isNull);
        await failed;
        expect(harness.hook.closeCalls, 1);
        expect(harness.coordinator.hasFailure, isTrue);
        expect(harness.clients.map((c) => c.closes), everyElement(0));
        expect(await harness.hook.retained!.runSelect('SELECT count(*) AS n FROM ledger_entries', []), [{'n': 1}]);
        await expectLater(old.listLive(), throwsStateError);
        await expectLater(harness.coordinator.withAccount((_) async {}), throwsStateError);
        await harness.client.auth.recoverSession(session(wire.userId));
        await expectLater(harness.coordinator.observeSession(), throwsStateError);
        await expectLater(harness.coordinator.retryCurrent(), throwsStateError);
        await expectLater(harness.owner.close(), throwsStateError);
        harness.owner.notifyForeground();
        expect(harness.owner.host, isNull);
        expect(harness.opens, 1);
        expect(harness.hook.closeCalls, 1);
        expect(container.read(ledgerEntriesProvider).value, isNull);
        expect(container.read(currentPlanIdProvider).value, isNull);
      } finally {
        subscription.close();
        planSubscription.close();
      }
    });
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() => harness.close(repairFault: true));
  });
}

class _NativeBoundary extends QueryInterceptor {
  String? boundary;
  Completer<void>? entered, release;
  bool failClose = false;
  int closeCalls = 0;
  QueryExecutor? retained;

  void arm(String value) {
    boundary = value;
    entered = Completer<void>();
    release = Completer<void>();
  }

  Future<void> _hold() async {
    boundary = null;
    entered!.complete();
    await release!.future;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) async {
    final rows = await executor.runSelect(statement, args);
    if (boundary == 'ledger SELECT' && statement.contains('FROM "ledger_entries"') ||
        boundary == 'plan SELECT' && statement.contains('FROM "plans"')) {
      await _hold();
    }
    return rows;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (boundary?.endsWith('COMMIT') ?? false) await _hold();
    await inner.send();
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    closeCalls++;
    retained = inner;
    if (failClose) throw StateError('Synthetic uncertain native close');
    await inner.close();
  }
}

class _PinnedRoot {
  _PinnedRoot(this.dir, this.server, this.client, this.hook);
  final Directory dir;
  final HttpServer server;
  final SupabaseClient client;
  final _NativeBoundary hook;
  late AccountStoreCoordinator coordinator;
  late SyncRuntimeOwner owner;
  late ProviderContainer container;
  final clients = <TrackedClient>[];
  int opens = 0, discoveries = 0, requests = 0;

  static Future<_PinnedRoot> open() async {
    final dir = await Directory.systemTemp.createTemp('kasaran-root-boundary-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final url = Uri.parse('http://127.0.0.1:${server.port}');
    final client = SupabaseClient(url.toString(), 'synthetic', authOptions: const AuthClientOptions(autoRefreshToken: false));
    await client.auth.recoverSession(session(wire.userId));
    final hook = _NativeBoundary();
    final harness = _PinnedRoot(dir, server, client, hook);
    server.listen((req) async {
      await req.drain<void>();
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path.endsWith('/logout')) {
        req.response.write('{}');
      } else {
        harness.requests++;
        // This boundary fixture deliberately keeps replication paused/offline.
        req.response.statusCode = 503;
        req.response.write(jsonEncode({'error': 'temporarily_unavailable'}));
      }
      await req.response.close();
    });
    final file = File('${dir.path}/a.sqlite');
    final keys = fixture.Keys();
    final initial = await EncryptedDatabaseOpener(file, keys).open();
    await fixture.seed(initial, fixtureActor);
    await LocalLedgerWriter(initial, identity: SupabaseVerifiedLocalIdentity(client.auth)).create(fixtureActor, fixture.draft);
    await initial.close();
    harness.coordinator = AccountStoreCoordinator(SupabaseVerifiedLocalIdentity(client.auth), (snapshot) async {
      expect(snapshot.userId, wire.userId);
      harness.opens++;
      return AppDatabase(NativeDatabase(file, setup: (raw) {
        if (raw.select('PRAGMA cipher').isEmpty) throw StateError('Cipher required');
        raw.execute("PRAGMA key = '${keys.key!}'");
      }).interceptWith(hook));
    });
    await harness.coordinator.observeSession();
    final sessions = SupabaseSyncSessionSource(client.auth);
    final timers = TestTimers();
    harness.owner = SyncRuntimeOwner(coordinator: harness.coordinator, createHost: (lifetime) {
      final sync = HttpOverrides.runWithHttpOverrides(TrackedClient.new, _LoopbackHttp());
      final bootstrap = HttpOverrides.runWithHttpOverrides(TrackedClient.new, _LoopbackHttp());
      harness.clients.addAll([sync, bootstrap]);
      return AccountSyncHost.ownedTransports(
        coordinator: harness.coordinator,
        deviceIdentity: SyncDeviceIdentity(Metadata()),
        discoverMembership: (_) async { harness.discoveries++; return null; },
        schedule: timers.schedule,
        syncTransport: HttpSyncTransport(baseUrl: url, anonKey: 'synthetic', sessions: sessions, client: lifetime.wrap(sync), maxAttempts: 1),
        bootstrapTransport: HttpBootstrapTransport(baseUrl: url, anonKey: 'synthetic', sessions: sessions, client: lifetime.wrap(bootstrap), maxAttempts: 1),
      );
    });
    harness.container = ProviderContainer(overrides: [
      syncRuntimeOwnerProvider.overrideWithValue(harness.owner),
      accountStoreCoordinatorProvider.overrideWithValue(harness.coordinator),
      authRepositoryProvider.overrideWithValue(SupabaseAuthRepository(SupabaseAuthGateway(client.auth), transition: harness.coordinator.transition)),
      authIdentitySourceProvider.overrideWithValue(SupabaseAuthIdentitySource(client.auth)),
      accountSessionEventsProvider.overrideWithValue(client.auth.onAuthStateChange.map((_) {})),
    ]);
    await harness.owner.settled;
    return harness;
  }

  Future<void> close({bool repairFault = false}) async {
    try {
      await owner.close();
    } catch (_) {
      if (!repairFault) rethrow;
    }
    container.dispose();
    if (repairFault) {
      // Only fixture cleanup repairs the still-open executor, not root recovery.
      hook.failClose = false;
      await hook.retained!.close();
      for (final client in clients) { client.close(force: true); }
      coordinator.dispose();
      owner.dispose();
    }
    await client.dispose();
    await server.close(force: true);
    await dir.delete(recursive: true);
  }
}
