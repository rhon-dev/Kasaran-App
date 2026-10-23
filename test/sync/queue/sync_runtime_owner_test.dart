import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/bound_ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/secure_storage/sync_device_identity.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';
import 'package:kasaran/sync/queue/sync_runtime_owner.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

import '../transport/bootstrap_transport_test.dart' as wire;
import 'account_metadata_bootstrapper_test.dart' show AfterCommitHook;
import 'account_sync_host_test.dart' show Metadata, TrackedClient, fixtureActor;
import 'durable_outbox_pusher_test.dart' as fixture;

void main() {
  test(
    'host factory failure is sanitized and cannot restart on foreground',
    () async {
      final harness = await RuntimeHarness.open(failFactory: true);
      try {
        await harness.owner.settled;
        expect(harness.owner.status, AccountSyncHostStatus.error);
        expect(harness.owner.host, isNull);
        harness.owner.notifyForeground();
        await harness.owner.settled;
        expect(harness.created, 1);
      } finally {
        await harness.close();
      }
      expect(harness.clients.map((c) => c.closes), everyElement(1));
    },
  );

  test(
    'root shutdown defers owned transport closure through actual local mutation COMMIT',
    () async {
      final harness = await RuntimeHarness.open();
      await harness.owner.settled;
      final entered = Completer<void>(), release = Completer<void>();
      harness.commit.action = () async {
        entered.complete();
        await release.future;
      };
      final ledger = BoundLedgerRepository(harness.owner.host!);
      final writing = ledger.create(fixture.draft);
      final rejected = expectLater(writing, throwsA(anything));
      await entered.future;
      final closing = harness.owner.close();
      try {
        await Future<void>.delayed(Duration.zero);
        expect(harness.clients.map((c) => c.closes), everyElement(0));
        expect(harness.owner.host, isNull);
      } finally {
        release.complete();
      }
      await rejected;
      await closing;
      expect(harness.clients.map((c) => c.closes), everyElement(1));
      await harness.close();
    },
  );
  test(
    'ready root eagerly starts one host and retains it on repeated wakes',
    () async {
      final harness = await RuntimeHarness.open();
      try {
        await harness.owner.settled;
        expect(harness.created, 1);
        expect(harness.requests, ['sync_pull']);
        expect(harness.owner.host?.actor?.userId, wire.userId);
        final original = harness.owner.host;
        await harness.coordinator.observeSession();
        harness.owner.notifyBackground();
        expect(harness.owner.host, same(original));
        expect(harness.created, 1);
        final closing = harness.owner.close();
        expect(harness.owner.close(), same(closing));
        expect(harness.coordinator.isReady, isFalse);
        expect(harness.owner.host, isNull);
        await closing;
        expect(harness.clients.map((c) => c.closes), everyElement(1));
      } finally {
        await harness.close();
      }
    },
  );
}

class RuntimeHarness {
  RuntimeHarness(
    this.dir,
    this.identity,
    this.coordinator,
    this.db,
    this.server,
    this.commit,
  );
  final AfterCommitHook commit;
  final Directory dir;
  final fixture.Identity identity;
  final AccountStoreCoordinator coordinator;
  final AppDatabase db;
  final HttpServer server;
  late SyncRuntimeOwner owner;
  final clients = <TrackedClient>[];
  final requests = <String>[];
  int created = 0;
  int discoveries = 0;
  Future<void> Function(HttpRequest, Map<String, dynamic>)? respond;

  static Future<RuntimeHarness> open({
    bool seed = true,
    bool failFactory = false,
    Timer Function(Duration, void Function()) schedule = Timer.new,
    Future<String?> Function(SyncSessionBinding)? discovery,
  }) async {
    final dir = await Directory.systemTemp.createTemp(
      'kasaran-runtime-binding-',
    );
    final identity = fixture.Identity()..user = wire.userId;
    final file = File('${dir.path}/a.sqlite');
    final keys = fixture.Keys();
    final initial = await EncryptedDatabaseOpener(file, keys).open();
    await initial.close();
    final commit = AfterCommitHook();
    final db = AppDatabase(
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
    final coordinator = AccountStoreCoordinator(
      fixture.LocalIdentity(identity),
      (_) async => db,
    );
    await coordinator.observeSession();
    if (seed) await fixture.seed(db, fixtureActor);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = RuntimeHarness(
      dir,
      identity,
      coordinator,
      db,
      server,
      commit,
    );
    server.listen((req) async {
      final body =
          jsonDecode(await utf8.decoder.bind(req).join())
              as Map<String, dynamic>;
      harness.requests.add(req.uri.path.split('/').last);
      if (harness.respond != null) {
        await harness.respond!(req, body);
      } else {
        req.response.write(
          jsonEncode(
            req.uri.path.endsWith('sync_bootstrap')
                ? wire.snapshot()
                : {
                    'protocol_version': {'major': 1, 'minor': 0},
                    'rows': <Object>[],
                    'next_cursor': body['cursor'],
                    'has_more': false,
                  },
          ),
        );
        await req.response.close();
      }
    });
    harness.owner = SyncRuntimeOwner(
      coordinator: coordinator,
      createHost: (lifetime) {
        harness.created++;
        final syncClient = TrackedClient(), bootstrapClient = TrackedClient();
        harness.clients.addAll([syncClient, bootstrapClient]);
        if (failFactory) {
          lifetime.wrap(syncClient);
          lifetime.wrap(bootstrapClient);
          throw StateError('Synthetic private construction failure');
        }
        final url = Uri.parse('http://127.0.0.1:${server.port}');
        return AccountSyncHost.ownedTransports(
          coordinator: coordinator,
          schedule: schedule,
          deviceIdentity: SyncDeviceIdentity(Metadata()),
          discoverMembership: (binding) async {
            harness.discoveries++;
            return discovery == null ? null : discovery(binding);
          },
          syncTransport: HttpSyncTransport(
            baseUrl: url,
            anonKey: 'synthetic',
            sessions: identity,
            client: lifetime.wrap(syncClient),
            maxAttempts: 1,
          ),
          bootstrapTransport: HttpBootstrapTransport(
            baseUrl: url,
            anonKey: 'synthetic',
            sessions: identity,
            client: lifetime.wrap(bootstrapClient),
            maxAttempts: 1,
          ),
        );
      },
    );
    return harness;
  }

  Future<void> close() async {
    await owner.close();
    await server.close(force: true);
    await dir.delete(recursive: true);
  }
}
