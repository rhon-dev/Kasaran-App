import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/ui/router/app_router.dart';

void main() {
  runApp(
    // ProviderScope is the Riverpod root — must wrap the entire widget tree.
    const ProviderScope(
      child: KasaranApp(),
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
