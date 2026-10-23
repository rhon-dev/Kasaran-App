import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/config/app_config.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/account_store_runtime.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';
import 'package:kasaran/ui/local_store_gate.dart';
import 'package:kasaran/ui/providers/account_store_provider.dart';
import 'package:kasaran/ui/providers/setup_draft_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            accountStoreCoordinatorProvider.overrideWith((ref) {
              ref.onDispose(runtime.coordinator.dispose);
              return runtime.coordinator;
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
    return ProviderScope(
      key: ValueKey(account.scopeKey),
      overrides: [
        appRouterProvider.overrideWith(createAppRouter),
        setupDraftProvider.overrideWith(SetupDraftController.new),
      ],
      child: const _AccountApp(),
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
