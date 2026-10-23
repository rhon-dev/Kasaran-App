import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';
import 'package:kasaran/ui/providers/account_store_provider.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/providers/sync_runtime_provider.dart';

import '../../sync/queue/account_sync_host_test.dart' show fixtureActor;
import '../../sync/queue/account_sync_worker_test.dart' show TestTimers;
import '../../sync/queue/durable_outbox_pusher_test.dart' as fixture;
import '../../sync/queue/sync_runtime_owner_test.dart' show RuntimeHarness;
import '../../sync/transport/bootstrap_transport_test.dart' as wire;

ProviderContainer runtimeContainer(RuntimeHarness harness) => ProviderContainer(
  overrides: [
    syncRuntimeOwnerProvider.overrideWithValue(harness.owner),
    accountStoreCoordinatorProvider.overrideWithValue(harness.coordinator),
    authStateProvider.overrideWithValue(AuthState.authenticated),
    authUserIdProvider.overrideWithValue(wire.userId),
    accountSessionEventsProvider.overrideWithValue(const Stream.empty()),
  ],
);

void main() {
  test('close synchronously clears live provider authority and private values', () async {
    final harness = await RuntimeHarness.open();
    await harness.owner.settled;
    final container = runtimeContainer(harness);
    final subscriptions = [
      container.listen(ledgerEntriesProvider, (_, _) {}),
      container.listen(currentPlanIdProvider, (_, _) {}),
      container.listen(syncHostStatusProvider, (_, _) {}),
      container.listen(boundLedgerProvider, (_, _) {}),
    ];
    try {
      final ledger = container.read(boundLedgerProvider)!;
      await ledger.create(fixture.draft);
      expect(await container.read(ledgerEntriesFutureProvider), hasLength(1));
      expect(await container.read(currentPlanIdFutureProvider), wire.planId);
      expect(container.read(syncHostStatusProvider), AccountSyncHostStatus.ready);
      var notifications = 0;
      Future<void>? reentrant;
      harness.owner.addListener(() {
        notifications++;
        reentrant = harness.owner.close();
      });
      final closing = harness.owner.close();
      void expectRevoked() {
        expect(container.read(syncHostStatusProvider), AccountSyncHostStatus.stopped);
        expect(container.read(syncHostProvider), isNull);
        expect(container.read(boundLedgerProvider), isNull);
        expect(container.read(ledgerEntriesProvider).value, isNull);
        expect(container.read(currentPlanIdProvider).value, isNull);
      }
      expectRevoked();
      expect(reentrant, same(closing));
      expect(notifications, 1);
      await expectLater(ledger.listLive(), throwsStateError);
      await closing;
      expectRevoked();
      expect(harness.owner.close(), same(closing));
      expect(notifications, 1);
    } finally {
      for (final subscription in subscriptions) { subscription.close(); }
      container.dispose();
      await harness.close();
    }
  });
  test(
    'revoked provider snapshot never retains previous account rows',
    () async {
      final harness = await RuntimeHarness.open();
      await harness.owner.settled;
      final container = runtimeContainer(harness);
      final subscription = container.listen(ledgerEntriesProvider, (_, _) {});
      try {
        await container.read(boundLedgerProvider)!.create(fixture.draft);
        expect(await container.read(ledgerEntriesFutureProvider), hasLength(1));
        expect(await container.read(currentPlanIdFutureProvider), wire.planId);
        harness.identity.marker = Object();
        final transition = harness.coordinator.observeSession();
        expect(container.read(ledgerEntriesProvider).value, isNull);
        expect(container.read(currentPlanIdProvider).value, isNull);
        await transition;
      } finally {
        subscription.close();
        container.dispose();
        await harness.close();
      }
    },
  );

  test(
    'reentrant session revocation at commit notification suppresses result disclosure',
    () async {
      final harness = await RuntimeHarness.open();
      await harness.owner.settled;
      final container = runtimeContainer(harness);
      final ledger = container.read(boundLedgerProvider)!;
      harness.owner.host!.addListener(() {
        harness.identity.marker = Object();
      });
      try {
        await expectLater(ledger.create(fixture.draft), throwsStateError);
      } finally {
        container.dispose();
        await harness.close();
      }
    },
  );

  test(
    'raw replay invalidates retained local read provider without remount',
    () async {
      final harness = await RuntimeHarness.open();
      await harness.owner.settled;
      final row = await LocalLedgerWriter(
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
      final container = runtimeContainer(harness);
      final subscription = container.listen(ledgerEntriesProvider, (_, _) {});
      try {
        expect(await container.read(ledgerEntriesFutureProvider), isEmpty);
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
        harness.owner.notifyForeground();
        await harness.owner.settled;
        expect(
          (await container.read(ledgerEntriesFutureProvider)).single.id,
          row.id,
        );
        expect(harness.discoveries, 0);
      } finally {
        subscription.close();
        container.dispose();
        await harness.close();
      }
    },
  );
  test(
    'finite local plan and ledger providers remain usable with sync HTTP paused',
    () async {
      final harness = await RuntimeHarness.open();
      await harness.owner.settled;
      final entered = Completer<void>(), release = Completer<void>();
      harness.respond = (req, body) async {
        entered.complete();
        await release.future;
        req.response.write(
          jsonEncode({
            'protocol_version': {'major': 1, 'minor': 0},
            'rows': <Object>[],
            'next_cursor': body['cursor'],
            'has_more': false,
          }),
        );
        await req.response.close();
      };
      harness.owner.notifyForeground();
      await entered.future;
      final container = runtimeContainer(harness);
      try {
        final before = List.of(harness.requests);
        expect(
          await container
              .read(currentPlanIdFutureProvider)
              .timeout(const Duration(seconds: 2)),
          wire.planId,
        );
        expect(
          await container
              .read(ledgerEntriesFutureProvider)
              .timeout(const Duration(seconds: 2)),
          isEmpty,
        );
        expect(harness.requests, before);
        expect(harness.discoveries, 0);
      } finally {
        release.complete();
        await harness.owner.settled;
        container.dispose();
        await harness.close();
      }
    },
  );
  test(
    'write notifications wait for native COMMIT and observer exceptions cannot fail durable success',
    () async {
      final timers = TestTimers();
      final harness = await RuntimeHarness.open(schedule: timers.schedule);
      await harness.owner.settled;
      final container = runtimeContainer(harness);
      final subscription = container.listen(
        syncRuntimeRevisionProvider,
        (_, _) {},
      );
      try {
        final ledger = container.read(boundLedgerProvider)!;
        final before = container.read(syncRuntimeRevisionProvider);
        final entered = Completer<void>(), release = Completer<void>();
        harness.commit.action = () async {
          entered.complete();
          await release.future;
        };
        final writing = ledger.create(fixture.draft);
        await entered.future;
        expect(container.read(syncRuntimeRevisionProvider), before);
        expect(timers.active, isEmpty);
        harness.owner.host!.addListener(
          () => throw StateError('observer failure'),
        );
        release.complete();
        final row = await writing;
        expect(
          container.read(syncRuntimeRevisionProvider),
          greaterThan(before),
        );
        harness.commit.action = null;
        expect(
          (await container.read(ledgerEntriesFutureProvider)).single.id,
          row.id,
        );
      } finally {
        subscription.close();
        container.dispose();
        await harness.close();
      }
    },
  );
  test(
    'empty metadata and failed discovery are unknown until confirmed none',
    () async {
      var fail = true;
      final harness = await RuntimeHarness.open(
        seed: false,
        discovery: (_) async {
          if (fail) throw StateError('offline');
          return null;
        },
      );
      await harness.owner.settled;
      final container = ProviderContainer(
        overrides: [
          syncRuntimeOwnerProvider.overrideWithValue(harness.owner),
          accountStoreCoordinatorProvider.overrideWithValue(
            harness.coordinator,
          ),
          authStateProvider.overrideWithValue(AuthState.authenticated),
          authUserIdProvider.overrideWithValue(wire.userId),
          accountSessionEventsProvider.overrideWithValue(const Stream.empty()),
        ],
      );
      final subscription = container.listen(planAccessProvider, (_, _) {});
      try {
        expect(await container.read(currentPlanIdFutureProvider), isNull);
        expect(container.read(planAccessProvider), isNot(PlanAccess.none));
        fail = false;
        await harness.owner.host!.refreshMembership();
        await container.read(currentPlanIdFutureProvider);
        expect(container.read(planAccessProvider), PlanAccess.none);
      } finally {
        subscription.close();
        container.dispose();
        await harness.close();
      }
    },
  );
  test(
    'local plan and bound ledger reads never discover and committed mutations refresh reads',
    () async {
      final timers = TestTimers();
      final harness = await RuntimeHarness.open(schedule: timers.schedule);
      await harness.owner.settled;
      final container = ProviderContainer(
        overrides: [
          syncRuntimeOwnerProvider.overrideWithValue(harness.owner),
          accountStoreCoordinatorProvider.overrideWithValue(
            harness.coordinator,
          ),
          authStateProvider.overrideWithValue(AuthState.authenticated),
          authUserIdProvider.overrideWithValue(wire.userId),
          accountSessionEventsProvider.overrideWithValue(const Stream.empty()),
        ],
      );
      final subscription = container.listen(ledgerEntriesProvider, (_, _) {});
      try {
        final before = List.of(harness.requests);
        expect(await container.read(currentPlanIdFutureProvider), wire.planId);
        expect(await container.read(ledgerEntriesFutureProvider), isEmpty);
        expect(harness.discoveries, 0);
        expect(harness.requests, before);
        final ledger = container.read(boundLedgerProvider)!;
        final created = await ledger.create(fixture.draft);
        expect(
          (await container.read(ledgerEntriesFutureProvider)).single.id,
          created.id,
        );
        await ledger.edit(
          created.id,
          const LedgerEntriesCompanion(supplierName: Value('Changed')),
        );
        expect(
          (await container.read(
            ledgerEntriesFutureProvider,
          )).single.supplierName,
          'Changed',
        );
        await ledger.delete(created.id);
        expect(await container.read(ledgerEntriesFutureProvider), isEmpty);
        expect(harness.requests, before);
        expect(timers.active.single.delay, const Duration(milliseconds: 250));
        await expectLater(
          ledger.edit(
            'absent',
            const LedgerEntriesCompanion(supplierName: Value('No')),
          ),
          throwsA(anything),
        );
        expect(await container.read(ledgerEntriesFutureProvider), isEmpty);
      } finally {
        subscription.close();
        container.dispose();
        await harness.close();
      }
    },
  );
}
