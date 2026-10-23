import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/main.dart';
import 'package:kasaran/data/repositories/bound_ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/account_store_runtime.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/sync_device_identity.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';
import 'package:kasaran/sync/queue/sync_runtime_owner.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/transport/bootstrap_transport_test.dart' as wire;

void main() {
  test(
    'root admits no host for signed out unverified or unavailable stores',
    () async {
      final client = SupabaseClient(
        'http://127.0.0.1:1',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      var factories = 0, opens = 0;
      final coordinator = AccountStoreCoordinator(
        SupabaseVerifiedLocalIdentity(client.auth),
        (_) async {
          opens++;
          throw StateError('Synthetic unavailable store');
        },
      );
      final owner = SyncRuntimeOwner(
        coordinator: coordinator,
        createHost: (_) {
          factories++;
          throw StateError('Must not create HTTP');
        },
      );
      try {
        await owner.settled;
        expect(owner.host, isNull);
        expect(opens, 0);
        await client.auth.recoverSession(session(wire.userId, verified: false));
        await coordinator.observeSession();
        await owner.settled;
        expect(owner.host, isNull);
        expect(opens, 0);
        await client.auth.recoverSession(session(wire.userId));
        await expectLater(coordinator.observeSession(), throwsStateError);
        await owner.settled;
        expect(coordinator.hasFailure, isTrue);
        expect(opens, 1);
        expect(factories, 0);
      } finally {
        await owner.close();
        await client.dispose();
      }
    },
  );
  test(
    'production factory bootstraps from actual pinned Auth and runtime registry proof',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'kasaran-production-binding-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final url = Uri.parse('http://127.0.0.1:${server.port}');
      final requests = <String>[];
      Completer<void>? pullEntered, pullRelease;
      server.listen((req) async {
        req.response.headers.contentType = ContentType.json;
        requests.add(req.uri.path);
        if (req.uri.path.endsWith('/logout')) {
          await req.drain<void>();
          req.response.write('{}');
          await req.response.close();
          return;
        }
        if (req.uri.path.endsWith('sync_pull') && pullEntered != null) {
          final entered = pullEntered!;
          pullEntered = null;
          entered.complete();
          await pullRelease!.future;
        }
        if (req.method == 'GET') {
          expect(req.uri.queryParameters['user_id'], 'eq.${wire.userId}');
          req.response.write(
            jsonEncode([
              {'plan_id': wire.planId},
            ]),
          );
        } else if (req.uri.path.endsWith('sync_bootstrap')) {
          req.response.write(jsonEncode(wire.snapshot()));
        } else {
          final body =
              jsonDecode(await utf8.decoder.bind(req).join())
                  as Map<String, dynamic>;
          req.response.write(
            jsonEncode({
              'protocol_version': {'major': 1, 'minor': 0},
              'rows': <Object>[],
              'next_cursor': body['cursor'],
              'has_more': false,
            }),
          );
        }
        await req.response.close();
      });
      final client = SupabaseClient(
        url.toString(),
        'synthetic-anon',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final metadata = MemoryMetadata();
      final runtime = await AccountStoreRuntime.initialize(
        initializeAuth: () => client.auth.recoverSession(session(wire.userId)),
        identity: () => SupabaseVerifiedLocalIdentity(client.auth),
        applicationSupportDirectory: () async => root,
        metadata: metadata,
        legacyKeys: NoLegacyKeys(),
        security: TestSecurity(),
      );
      await runtime.coordinator.observeSession();
      final owner = createAppSyncRuntimeOwner(
        runtime,
        client,
        baseUrl: url,
        anonKey: 'synthetic-anon',
        membership: SupabasePlanMembershipLookup(client),
      );
      try {
        await owner.settled;
        expect(owner.host?.actor?.planId, wire.planId);
        expect(
          owner.host?.actor?.deviceId,
          metadata.values[SyncDeviceIdentity.metadataKey],
        );
        expect(requests, [
          '/rest/v1/plan_members',
          '/functions/v1/sync_bootstrap',
          '/functions/v1/sync_pull',
        ]);
        final original = owner.host;
        await client.auth.recoverSession(session(wire.userId));
        expect(
          original?.actor,
          isNull,
        ); // identical user, different actual Session
        await runtime.coordinator.observeSession();
        await owner.settled;
        expect(owner.host, isNot(same(original)));
        expect(owner.host?.actor?.planId, wire.planId);
        expect(requests.where((p) => p.endsWith('plan_members')), hasLength(1));
        for (final transition in ['same-user', 'A-B-A', 'signout']) {
          final entered = pullEntered = Completer<void>();
          final release = pullRelease = Completer<void>();
          final old = owner.host!;
          final ledger = BoundLedgerRepository(old);
          owner.notifyForeground();
          await entered.future.timeout(const Duration(seconds: 3));
          final observations = <Future<void>>[];
          if (transition == 'signout') {
            // Real SDK local signout; any logout request is loopback only.
            await client.auth.signOut(scope: SignOutScope.local);
          } else {
            await client.auth.recoverSession(session(transition == 'A-B-A' ? 'synthetic-b' : wire.userId));
          }
          observations.add(runtime.coordinator.observeSession());
          if (transition == 'A-B-A') {
            await client.auth.recoverSession(session(wire.userId));
            observations.add(runtime.coordinator.observeSession());
          }
          expect(old.actor, isNull);
          await expectLater(ledger.listLive(), throwsStateError);
          release.complete();
          await Future.wait(observations);
          await owner.settled;
          if (transition == 'signout') {
            expect(owner.host, isNull);
            await client.auth.recoverSession(session(wire.userId));
            await runtime.coordinator.observeSession();
            await owner.settled;
          }
          expect(owner.host, isNot(same(old)));
          expect(owner.host?.actor?.planId, wire.planId);
        }
        expect(requests.where((p) => p.endsWith('plan_members')), hasLength(1));
        for (final transition in ['same-user', 'A-B-A', 'signout']) {
          final entered = Completer<void>(), release = Completer<void>();
          metadata.beforeRead = (key) async {
            if (key != SyncDeviceIdentity.metadataKey) return;
            metadata.beforeRead = null;
            entered.complete(); await release.future;
          };
          await client.auth.recoverSession(session(wire.userId));
          await runtime.coordinator.observeSession();
          await entered.future.timeout(const Duration(seconds: 3));
          final old = owner.host!;
          expect(old.actor, isNull);
          if (transition == 'signout') {
            await client.auth.signOut(scope: SignOutScope.local);
          } else {
            await client.auth.recoverSession(session(transition == 'A-B-A' ? 'synthetic-b' : wire.userId));
          }
          final observations = [runtime.coordinator.observeSession()];
          if (transition == 'A-B-A') {
            await client.auth.recoverSession(session(wire.userId));
            observations.add(runtime.coordinator.observeSession());
          }
          expect(old.actor, isNull);
          release.complete();
          await Future.wait(observations); await owner.settled;
          if (transition == 'signout') {
            expect(owner.host, isNull);
            await client.auth.recoverSession(session(wire.userId));
            await runtime.coordinator.observeSession(); await owner.settled;
          }
          expect(owner.host, isNot(same(old)));
          expect(owner.host?.actor?.planId, wire.planId);
        }
        expect(requests.where((p) => p.endsWith('plan_members')), hasLength(1));
      } finally {
        await owner.close();
        await client.dispose();
        await server.close(force: true);
        await root.delete(recursive: true);
      }
    },
  );
}

String session(String user, {bool verified = true}) => jsonEncode({
  'access_token': 'synthetic-not-a-credential',
  'refresh_token': 'synthetic',
  'token_type': 'bearer',
  'user': {
    'id': user,
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'email_confirmed_at': verified ? '2026-01-01T00:00:00Z' : null,
  },
});

class MemoryMetadata implements SecureKeyValueStore {
  final values = <String, String>{};
  Future<void> Function(String)? beforeRead;
  @override
  Future<String?> read(String key) async {
    await beforeRead?.call(key);
    return values[key];
  }
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class NoLegacyKeys implements DatabaseKeyStore {
  @override
  Future<String?> read() async => throw StateError('Legacy forbidden');
  @override
  Future<void> write(String value) async =>
      throw StateError('Legacy forbidden');
}

class TestSecurity implements LocalDeviceSecurity {
  @override
  Future<void> protectDirectory(String path) async {}
  @override
  Future<void> protectFile(String path) async {}
  @override
  Future<bool> hasDeviceLock() async => true;
  @override
  Future<bool> hasShownLockWarning() async => true;
  @override
  Future<void> markLockWarningShown() async {}
}
