// test/ui/golden/tab_shell_golden_test.dart
//
// Golden tests for the AppTabShell layout.
//
// Golden files are committed under test/ui/golden/goldens/ and must be
// regenerated (flutter test --update-goldens) whenever the shell's visual
// structure intentionally changes.
//
// These tests verify:
//   1. The shell renders the NavigationBar with five labelled tabs.
//   2. The selected tab (index 0 = Dashboard) is visually distinct.
//   3. The shell occupies full bounds without overflow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/ui/screens/placeholder_screen.dart';
import 'package:kasaran/ui/shell/app_tab_shell.dart';

// ---------------------------------------------------------------------------
// Helper: build an isolated tab shell with minimal go_router wiring
// ---------------------------------------------------------------------------

/// Builds a [MaterialApp.router] containing only the [AppTabShell] backed by
/// five stub branch routes so the golden captures the nav-bar and content area
/// without pulling in real screen dependencies.
Widget _buildShellApp({int initialIndex = 0}) {
  final router = GoRouter(
    initialLocation: _branchPaths[initialIndex],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppTabShell(navigationShell: navigationShell),
        branches: List.generate(
          _branchPaths.length,
          (i) => StatefulShellBranch(
            routes: [
              GoRoute(
                path: _branchPaths[i],
                builder: (context, state) => PlaceholderScreen(
                  screenId: _branchIds[i],
                  screenName: _branchNames[i],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    ),
  );
}

const _branchPaths = ['/dashboard', '/ledger', '/guests', '/pledges', '/more'];
const _branchIds = ['SCR-06', 'SCR-07', 'SCR-12', 'SCR-14', 'SCR-16'];
const _branchNames = ['Dashboard', 'Ledger', 'Guests', 'Pledges', 'More'];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AppTabShell golden tests', () {
    testWidgets('tab shell — dashboard selected (index 0)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildShellApp());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tab_shell_dashboard.png'),
      );
    });

    testWidgets('tab shell — ledger selected (index 1)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildShellApp());
      await tester.pumpAndSettle();

      // Tap the Ledger tab
      await tester.tap(find.text('Ledger'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tab_shell_ledger.png'),
      );
    });

    testWidgets('tab shell shows five navigation destinations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildShellApp());
      await tester.pumpAndSettle();

      // Each label appears at least once in the NavigationBar.
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Ledger'), findsWidgets);
      expect(find.text('Guests'), findsWidgets);
      expect(find.text('Pledges'), findsWidgets);
      expect(find.text('More'), findsWidgets);
    });

    testWidgets('tab shell displays current branch content', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildShellApp());
      await tester.pumpAndSettle();

      // Dashboard branch is active — SCR-06 screen id visible
      expect(find.text('SCR-06'), findsWidgets);

      // Tap Guests tab
      await tester.tap(find.text('Guests').last);
      await tester.pumpAndSettle();
      expect(find.text('SCR-12'), findsWidgets);
    });
  });
}
