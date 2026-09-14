import 'package:flutter/material.dart';

void main() {
  runApp(const KasaranApp());
}

/// Root widget for the Kasaran application.
///
/// Phase 01 — skeleton entry point only. Screens and navigation are
/// added from phase 03 onward (development-phases.md §03).
class KasaranApp extends StatelessWidget {
  const KasaranApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kasaran',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const _PlaceholderScreen(),
      );
}

/// Temporary placeholder screen — replaced in phase 03.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Text('Kasaran — coming soon'),
        ),
      );
}
