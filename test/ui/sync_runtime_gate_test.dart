import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/repositories/bound_ledger_repository.dart';
import 'package:kasaran/main.dart';
import 'package:kasaran/ui/providers/account_store_provider.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/providers/sync_runtime_provider.dart';
import 'package:kasaran/ui/sync_runtime_gate.dart';

import '../sync/queue/account_sync_host_test.dart' show fixtureActor;
import '../sync/queue/account_sync_worker_test.dart' show TestTimers;
import '../sync/queue/durable_outbox_pusher_test.dart' as fixture;
import '../sync/queue/sync_runtime_owner_test.dart' show RuntimeHarness;
import '../sync/transport/bootstrap_transport_test.dart' as wire;
import 'providers/sync_runtime_provider_test.dart' show runtimeContainer;

class _LoopbackHttp extends HttpOverrides {}

class _VisibleLedger extends ConsumerWidget {
  const _VisibleLedger();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(
      ref
          .watch(ledgerEntriesProvider)
          .when(
            data: (rows) =>
                rows.isEmpty ? 'empty ledger' : rows.single.supplierName,
            error: (_, _) => 'unavailable',
            loading: () => 'loading',
          ),
    ),
  );
}

void main() {
  testWidgets(
    'mounted foreground periodic wake retries failed initial discovery and updates access',
    (tester) async {
      final timers = TestTimers();
      var attempts = 0;
      final harness = (await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(
          () => RuntimeHarness.open(
            seed: false,
            schedule: timers.schedule,
            discovery: (_) async {
              if (++attempts < 3) throw StateError('offline');
              return wire.planId;
            },
          ),
          _LoopbackHttp(),
        ),
      ))!;
      final container = runtimeContainer(harness);
      try {
        await tester.runAsync(() => harness.owner.settled);
        expect(attempts, 1);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: SyncRuntimeGate(
              owner: harness.owner,
              child: const SizedBox(),
            ),
          ),
        );
        await tester.runAsync(() async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await harness.owner.settled;
          expect(await container.read(currentPlanIdProvider.future), isNull);
        });
        expect(attempts, 2);
        expect(container.read(planAccessProvider), isNot(PlanAccess.none));
        await tester.runAsync(() async {
          timers.fire();
          await harness.owner.settled;
          expect(
            await container.read(currentPlanIdProvider.future),
            wire.planId,
          );
        });
        expect(container.read(planAccessProvider), PlanAccess.member);
        expect(harness.created, 1);
        await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
      } finally {
        container.dispose();
        await tester.runAsync(harness.close);
      }
    },
  );
  testWidgets(
    'terminal worker latch survives actual app rebuild and lifecycle wakes',
    (tester) async {
      final timers = TestTimers();
      final harness = (await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(
          () => RuntimeHarness.open(schedule: timers.schedule),
          _LoopbackHttp(),
        ),
      ))!;
      final container = runtimeContainer(harness);
      try {
        await tester.runAsync(() => harness.owner.settled);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const KasaranApp(),
          ),
        );
        harness.respond = (req, body) async {
          req.response.statusCode = 426;
          req.response.write(
            jsonEncode({
              'error': 'unsupported_protocol',
              'min_supported_build': 9,
            }),
          );
          await req.response.close();
        };
        await tester.runAsync(() async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await harness.owner.settled;
        });
        expect(
          harness.owner.host?.status.toString(),
          'AccountSyncHostStatus.updateRequired',
        );
        final original = harness.owner.host;
        final requests = List.of(harness.requests);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const KasaranApp(),
          ),
        );
        await tester.runAsync(() async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await harness.owner.settled;
        });
        expect(harness.owner.host, same(original));
        expect(harness.created, 1);
        expect(harness.requests, requests);
        expect(timers.active, isEmpty);
        await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
      } finally {
        container.dispose();
        await tester.runAsync(harness.close);
      }
    },
  );

  testWidgets(
    'actual root unmount retains native transports until held local COMMIT drains',
    (tester) async {
      final harness = (await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(
          RuntimeHarness.open,
          _LoopbackHttp(),
        ),
      ))!;
      final release = (await tester.runAsync(() async => Completer<void>()))!;
      try {
        await tester.runAsync(() => harness.owner.settled);
        await tester.runAsync(
          () => tester.pumpWidget(
            ProviderScope(
              overrides: [
                syncRuntimeOwnerProvider.overrideWithValue(harness.owner),
                accountStoreCoordinatorProvider.overrideWithValue(
                  harness.coordinator,
                ),
                accountSessionEventsProvider.overrideWithValue(
                  const Stream.empty(),
                ),
                authStateProvider.overrideWithValue(AuthState.authenticated),
                planAccessProvider.overrideWithValue(PlanAccess.member),
              ],
              child: const KasaranApp(),
            ),
          ),
        );
        await tester.runAsync(() => harness.owner.settled);
        final entered = (await tester.runAsync(() async => Completer<void>()))!;
        harness.commit.action = () async {
          harness.commit.action = null;
          entered.complete();
          await release.future;
        };
        late Future<void> rejected;
        await tester.runAsync(() async {
          final writing = BoundLedgerRepository(
            harness.owner.host!,
          ).create(fixture.draft);
          rejected = expectLater(writing, throwsA(anything));
          await entered.future;
        });
        await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
        expect(harness.owner.host, isNull);
        expect(harness.clients.map((c) => c.closes), everyElement(0));
        release.complete();
        await tester.runAsync(() async {
          await rejected;
          await harness.owner.close();
        });
        expect(harness.clients.map((c) => c.closes), everyElement(1));
      } finally {
        if (!release.isCompleted) release.complete();
        await tester.runAsync(harness.close);
      }
    },
  );

  testWidgets(
    'mounted finite ledger view updates after lifecycle-triggered raw replay without remount',
    (tester) async {
      final harness = (await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(
          RuntimeHarness.open,
          _LoopbackHttp(),
        ),
      ))!;
      final container = runtimeContainer(harness);
      try {
        await tester.runAsync(() async {
          await harness.owner.settled;
          await LocalLedgerWriter(
            harness.db,
            identity: harness.coordinator.identity,
          ).create(fixtureActor, fixture.draft);
          final log =
              (await harness.db.customSelect('SELECT * FROM change_log').get())
                  .single
                  .data;
          final event = <String, dynamic>{
            ...log,
            'server_ts': '1',
            'device_monotonic': '${log['device_monotonic']}',
            'old_value': jsonDecode(log['old_value']! as String),
            'new_value': jsonDecode(log['new_value']! as String),
          };
          for (final table in ['outbox', 'change_log', 'ledger_entries']) {
            await harness.db.customStatement('DELETE FROM $table');
          }
          harness.respond = (req, body) async {
            req.response.write(
              jsonEncode({
                'protocol_version': {'major': 1, 'minor': 0},
                'rows': [event],
                'next_cursor': '1',
                'has_more': false,
              }),
            );
            await req.response.close();
          };
          await container.read(ledgerEntriesProvider.future);
        });
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: SyncRuntimeGate(
              owner: harness.owner,
              child: const _VisibleLedger(),
            ),
          ),
        );
        expect(find.text('empty ledger'), findsOneWidget);
        final originalView = tester.element(find.byType(_VisibleLedger));
        await tester.runAsync(() async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await harness.owner.settled;
          await container.read(ledgerEntriesProvider.future);
        });
        await tester.pump();
        expect(find.text(fixture.draft.supplierName), findsOneWidget);
        expect(tester.element(find.byType(_VisibleLedger)), same(originalView));
        await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
      } finally {
        container.dispose();
        await tester.runAsync(harness.close);
      }
    },
  );
  testWidgets(
    'actual application mounts a single runtime gate outside account navigator',
    (tester) async {
      final harness = (await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(
          RuntimeHarness.open,
          _LoopbackHttp(),
        ),
      ))!;
      try {
        await tester.runAsync(() => harness.owner.settled);
        await tester.runAsync(
          () => tester.pumpWidget(
            ProviderScope(
              overrides: [
                syncRuntimeOwnerProvider.overrideWithValue(harness.owner),
                accountStoreCoordinatorProvider.overrideWithValue(
                  harness.coordinator,
                ),
                accountSessionEventsProvider.overrideWithValue(
                  const Stream.empty(),
                ),
                authStateProvider.overrideWithValue(AuthState.authenticated),
                planAccessProvider.overrideWithValue(PlanAccess.member),
              ],
              child: const KasaranApp(),
            ),
          ),
        );
        expect(find.byType(SyncRuntimeGate), findsOneWidget);
        await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
        await tester.runAsync(() => harness.owner.close());
        expect(harness.clients.map((c) => c.closes), everyElement(1));
      } finally {
        await tester.runAsync(harness.close);
      }
    },
  );
  testWidgets(
    'mounted lifecycle gate resumes polling and unmount drains its owner',
    (tester) async {
      final timers = TestTimers();
      final harness = (await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(
          () => RuntimeHarness.open(schedule: timers.schedule),
          _LoopbackHttp(),
        ),
      ))!;
      try {
        await tester.runAsync(() => harness.owner.settled);
        await tester.pumpWidget(
          SyncRuntimeGate(owner: harness.owner, child: const SizedBox()),
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(timers.active, isEmpty);
        await tester.runAsync(() async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await harness.owner.settled;
        });
        expect(
          harness.owner.host?.status.toString(),
          'AccountSyncHostStatus.ready',
        );
        expect(
          harness.owner.host?.syncStatus.toString(),
          'AccountSyncStatus.idle',
        );
        expect(timers.active.single.delay, const Duration(seconds: 30));
        final before = harness.requests.length;
        await tester.runAsync(() async {
          timers.fire();
          await harness.owner.settled;
        });
        expect(harness.requests.length, before + 1);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        expect(timers.active, isEmpty);
        await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
        await tester.runAsync(() => harness.owner.close());
        expect(harness.clients.map((c) => c.closes), everyElement(1));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        expect(timers.active, isEmpty);
      } finally {
        await tester.runAsync(harness.close);
      }
    },
  );
}
