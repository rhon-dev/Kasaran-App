import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/config/app_config.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/account_store_runtime.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';
import 'package:kasaran/sync/queue/sync_runtime_owner.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';
import 'package:kasaran/ui/local_store_gate.dart';
import 'package:kasaran/ui/providers/account_store_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/providers/setup_draft_provider.dart';
import 'package:kasaran/ui/providers/sync_runtime_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';
import 'package:kasaran/ui/sync_runtime_gate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Auth adapter, membership adapter and both HTTP transports share exactly
/// the verified-local Auth client; configuration comes from app_config in main.
SyncRuntimeOwner createAppSyncRuntimeOwner(
  AccountStoreRuntime runtime,
  SupabaseClient client, {
  required Uri baseUrl,
  required String anonKey,
  required PlanMembershipLookup membership,
}) {
  final identity = runtime.coordinator.identity;
  if (identity is! SupabaseVerifiedLocalIdentity ||
      !identical(identity.auth, client.auth)) {
    throw StateError('Sync Auth client does not match local identity');
  }
  final sessions = SupabaseSyncSessionSource(client.auth);
  return SyncRuntimeOwner(
    coordinator: runtime.coordinator,
    createHost: (lifetime) => AccountSyncHost.ownedTransports(
      coordinator: runtime.coordinator,
      deviceIdentity: runtime.deviceIdentity,
      discoverMembership: (binding) async {
        final generation = runtime.coordinator.generation;
        void check() {
          final current = sessions.capture();
          if (!runtime.coordinator.isReady ||
              generation != runtime.coordinator.generation ||
              current?.userId != binding.userId ||
              !identical(current?.marker, binding.marker)) {
            throw const SyncTransportException('session_changed');
          }
        }

        check();
        final plan = await membership.currentPlanId();
        check();
        return plan;
      },
      syncTransport: HttpSyncTransport(
        baseUrl: baseUrl,
        anonKey: anonKey,
        sessions: sessions,
        client: lifetime.wrap(HttpClient()),
      ),
      bootstrapTransport: HttpBootstrapTransport(
        baseUrl: baseUrl,
        anonKey: anonKey,
        sessions: sessions,
        client: lifetime.wrap(HttpClient()),
      ),
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final security = PlatformLocalDeviceSecurity();
  late AccountStoreRuntime runtime;
  runApp(
    LocalStoreGate(
      prepare: () async {
        runtime = await AccountStoreRuntime.initialize(
          initializeAuth: () async {
            final secureStorage = SecureTokenStore(
              PlatformSecureKeyValueStore(),
            );
            await Supabase.initialize(
              url: supabaseUrl,
              publishableKey: supabaseAnonKey,
              authOptions: FlutterAuthClientOptions(
                localStorage: secureStorage,
                pkceAsyncStorage: secureStorage,
              ),
              debug: false,
            );
          },
          identity: () =>
              SupabaseVerifiedLocalIdentity(Supabase.instance.client.auth),
          applicationSupportDirectory: getApplicationSupportDirectory,
          metadata: PlatformSecureKeyValueStore(),
          legacyKeys: PlatformDatabaseKeyStore(),
          security: security,
        );
        return runtime.warningNeeded;
      },
      markWarningShown: security.markLockWarningShown,
      child: Builder(
        builder: (_) => ProviderScope(
          overrides: [
            accountStoreCoordinatorProvider.overrideWithValue(
              runtime.coordinator,
            ),
            syncRuntimeOwnerProvider.overrideWith((ref) {
              final owner = createAppSyncRuntimeOwner(
                runtime,
                Supabase.instance.client,
                baseUrl: Uri.parse(supabaseUrl),
                anonKey: supabaseAnonKey,
                membership: ref.read(planMembershipLookupProvider),
              );
              // Gate owns shutdown; provider teardown only initiates the same
              // retained barrier as a fallback, never a second coordinator owner.
              ref.onDispose(
                () => unawaited(owner.close().catchError((Object _) {})),
              );
              return owner;
            }),
          ],
          child: const KasaranApp(),
        ),
      ),
    ),
  );
}

/// Auth-only pages require no database. A new generation replaces the entire
/// navigator tree, including indexed-stack pages and dialogs.
class KasaranApp extends ConsumerWidget {
  const KasaranApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountStoreStateProvider);
    return SyncRuntimeGate(
      owner: ref.watch(syncRuntimeOwnerProvider),
      child: ProviderScope(
        key: ValueKey(account.scopeKey),
        overrides: [
          appRouterProvider.overrideWith(createAppRouter),
          setupDraftProvider.overrideWith(SetupDraftController.new),
        ],
        child: const _AccountApp(),
      ),
    );
  }
}

class _AccountApp extends ConsumerWidget {
  const _AccountApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Kasaran',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
