import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/ui/local_store_gate.dart';
import 'package:kasaran/ui/router/app_router.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final security = PlatformLocalDeviceSecurity();
  runApp(
    LocalStoreGate(
      open: () async => LocalStoreBootstrap(
        await getApplicationSupportDirectory(),
        PlatformDatabaseKeyStore(),
        security,
      ).open(),
      markWarningShown: security.markLockWarningShown,
      // ProviderScope is the Riverpod root of the application router.
      child: const ProviderScope(child: KasaranApp()),
    ),
  );
}

/// Root widget for the Kasaran application.
///
/// Reads the [appRouterProvider] so the GoRouter is created once and cached
/// for the lifetime of the app. Auth state changes cause the router's redirect
/// logic to re-evaluate without recreating the router object.
class KasaranApp extends ConsumerWidget {
  const KasaranApp({super.key});

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
