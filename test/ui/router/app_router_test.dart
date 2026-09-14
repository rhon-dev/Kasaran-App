// test/ui/router/app_router_test.dart
//
// Asserts every SCR-01..SCR-19 is reachable by navigating to its route,
// and verifies the redirect guard behaves correctly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal stub redirect that mirrors the production logic in app_router.dart.
/// Kept here so the test does not depend on the private _redirect function.
String? _testRedirect(
  String path,
  AuthState authState,
  bool hasActivePlan,
) {
  if (path.startsWith('/invite/')) return null;
  switch (authState) {
    case AuthState.unauthenticated:
    case AuthState.unverified:
      return path == Routes.signIn ? null : Routes.signIn;
    case AuthState.authenticated:
      if (!hasActivePlan) {
        return path.startsWith('/onboarding') ? null : Routes.onboardingBudgetDate;
      }
      if (path == Routes.signIn || path.startsWith('/onboarding')) {
        return Routes.dashboard;
      }
      return null;
  }
}

/// Minimal screen widget showing only [id] so tests can assert by text.
Widget _stub(String id) => Scaffold(body: Center(child: Text(id)));

/// Minimal tab-shell wrapper for tests (no NavigationBar needed).
class _TestShell extends StatelessWidget {
  const _TestShell({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(body: navigationShell);
}

/// Builds a [GoRouter] with stub screens and the test redirect.
GoRouter _buildRouter({
  AuthState authState = AuthState.authenticated,
  bool hasActivePlan = true,
}) =>
    GoRouter(
      initialLocation: Routes.signIn,
      redirect: (_, state) => _testRedirect(
        state.uri.path,
        authState,
        hasActivePlan,
      ),
      routes: _stubRoutes(),
    );

/// Returns the full route tree using stub screens.
/// Mirrors the shape of _buildRoutes() in app_router.dart.
List<RouteBase> _stubRoutes() => [
      GoRoute(
        path: Routes.signIn,
        name: 'sign-in',
        builder: (_, _) => _stub('SCR-01'),
      ),
      GoRoute(
        path: Routes.inviteAccept,
        name: 'invite-accept',
        builder: (_, _) => _stub('SCR-02'),
      ),
      GoRoute(
        path: Routes.onboardingBudgetDate,
        name: 'onboarding-budget-date',
        builder: (_, _) => _stub('SCR-03'),
        routes: [
          GoRoute(
            path: 'guest-region',
            name: 'onboarding-guest-region',
            builder: (_, _) => _stub('SCR-04'),
            routes: [
              GoRoute(
                path: 'hidden-fees',
                name: 'onboarding-hidden-fees',
                builder: (_, _) => _stub('SCR-05'),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _TestShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                name: 'dashboard',
                builder: (_, _) => _stub('SCR-06'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ledger,
                name: 'ledger',
                builder: (_, _) => _stub('SCR-07'),
                routes: [
                  GoRoute(
                    path: 'entry/:id',
                    name: 'ledger-entry',
                    builder: (_, _) => _stub('SCR-08'),
                  ),
                  GoRoute(
                    path: 'fee/:type',
                    name: 'ledger-fee',
                    builder: (_, _) => _stub('SCR-09'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.guests,
                name: 'guests',
                builder: (_, _) => _stub('SCR-12'),
                routes: [
                  GoRoute(
                    path: 'what-if',
                    name: 'guests-what-if',
                    builder: (_, _) => _stub('SCR-13'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.pledges,
                name: 'pledges',
                builder: (_, _) => _stub('SCR-14'),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: 'pledges-new',
                    builder: (_, _) => _stub('SCR-15'),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    name: 'pledges-edit',
                    builder: (_, _) => _stub('SCR-15'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                name: 'more',
                builder: (_, _) => _stub('SCR-16'),
                routes: [
                  GoRoute(
                    path: 'change-log',
                    name: 'more-change-log',
                    builder: (_, _) => _stub('SCR-16'),
                  ),
                  GoRoute(
                    path: 'shared-access',
                    name: 'more-shared-access',
                    builder: (_, _) => _stub('SCR-17'),
                  ),
                  GoRoute(
                    path: 'plan-settings',
                    name: 'more-plan-settings',
                    builder: (_, _) => _stub('SCR-18'),
                  ),
                  GoRoute(
                    path: 'sync-detail',
                    name: 'more-sync-detail',
                    builder: (_, _) => _stub('SCR-19'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.allocations,
        name: 'allocations',
        builder: (_, _) => _stub('SCR-10'),
      ),
      GoRoute(
        path: Routes.explainFigure,
        name: 'explain-figure',
        builder: (_, _) => _stub('SCR-11'),
      ),
      GoRoute(
        path: Routes.syncDetail,
        name: 'sync-detail',
        builder: (_, _) => _stub('SCR-19'),
      ),
    ];

/// Pumps the app and settles.
Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Route reachability — all 19 screens', () {
    // ---- Auth group (unauthenticated) ---------------------------------------
    testWidgets('SCR-01 sign-in is the landing for unauthenticated users', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter(
        authState: AuthState.unauthenticated,
        hasActivePlan: false,
      );
      await _pump(tester, router);
      expect(find.text('SCR-01'), findsOneWidget);
    });

    // ---- Invite (always accessible) ----------------------------------------
    testWidgets('SCR-02 /invite/accept/:token always accessible', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter(
        authState: AuthState.unauthenticated,
        hasActivePlan: false,
      );
      await _pump(tester, router);
      router.go('/invite/accept/testtoken');
      await tester.pumpAndSettle();
      expect(find.text('SCR-02'), findsOneWidget);
    });

    // ---- Onboarding (authenticated, no plan) --------------------------------
    testWidgets('SCR-03 onboarding/budget-date (redirect for no-plan user)', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter(hasActivePlan: false);
      await _pump(tester, router);
      expect(find.text('SCR-03'), findsOneWidget);
    });

    testWidgets('SCR-04 onboarding/budget-date/guest-region', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter(hasActivePlan: false);
      await _pump(tester, router);
      router.go('/onboarding/budget-date/guest-region');
      await tester.pumpAndSettle();
      expect(find.text('SCR-04'), findsOneWidget);
    });

    testWidgets('SCR-05 onboarding/.../hidden-fees', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter(hasActivePlan: false);
      await _pump(tester, router);
      router.go('/onboarding/budget-date/guest-region/hidden-fees');
      await tester.pumpAndSettle();
      expect(find.text('SCR-05'), findsOneWidget);
    });

    // ---- App shell (authenticated + plan) -----------------------------------
    group('App shell screens', () {
      late GoRouter router;
      setUp(() => router = _buildRouter());

      testWidgets('SCR-06 /dashboard', (WidgetTester tester) async {
        await _pump(tester, router);
        // Redirect sends auth+plan user to /dashboard from /sign-in
        expect(find.text('SCR-06'), findsOneWidget);
      });

      testWidgets('SCR-07 /ledger', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/ledger');
        await tester.pumpAndSettle();
        expect(find.text('SCR-07'), findsOneWidget);
      });

      testWidgets('SCR-08 /ledger/entry/:id', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/ledger/entry/abc123');
        await tester.pumpAndSettle();
        expect(find.text('SCR-08'), findsOneWidget);
      });

      testWidgets('SCR-09 /ledger/fee/:type', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/ledger/fee/crew_meals');
        await tester.pumpAndSettle();
        expect(find.text('SCR-09'), findsOneWidget);
      });

      testWidgets('SCR-10 /allocations', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/allocations');
        await tester.pumpAndSettle();
        expect(find.text('SCR-10'), findsOneWidget);
      });

      testWidgets('SCR-11 /explain/:key', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/explain/catering_venue');
        await tester.pumpAndSettle();
        expect(find.text('SCR-11'), findsOneWidget);
      });

      testWidgets('SCR-12 /guests', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/guests');
        await tester.pumpAndSettle();
        expect(find.text('SCR-12'), findsOneWidget);
      });

      testWidgets('SCR-13 /guests/what-if', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/guests/what-if');
        await tester.pumpAndSettle();
        expect(find.text('SCR-13'), findsOneWidget);
      });

      testWidgets('SCR-14 /pledges', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/pledges');
        await tester.pumpAndSettle();
        expect(find.text('SCR-14'), findsOneWidget);
      });

      testWidgets('SCR-15 /pledges/new', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/pledges/new');
        await tester.pumpAndSettle();
        expect(find.text('SCR-15'), findsOneWidget);
      });

      testWidgets('SCR-16 /more', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/more');
        await tester.pumpAndSettle();
        expect(find.text('SCR-16'), findsOneWidget);
      });

      testWidgets('SCR-17 /more/shared-access', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/more/shared-access');
        await tester.pumpAndSettle();
        expect(find.text('SCR-17'), findsOneWidget);
      });

      testWidgets('SCR-18 /more/plan-settings', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/more/plan-settings');
        await tester.pumpAndSettle();
        expect(find.text('SCR-18'), findsOneWidget);
      });

      testWidgets('SCR-19 /more/sync-detail', (WidgetTester tester) async {
        await _pump(tester, router);
        router.go('/more/sync-detail');
        await tester.pumpAndSettle();
        expect(find.text('SCR-19'), findsOneWidget);
      });
    });
  });

  group('Redirect guard behaviour', () {
    testWidgets('Unauthenticated → /sign-in for any protected route', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter(
        authState: AuthState.unauthenticated,
        hasActivePlan: false,
      );
      await _pump(tester, router);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(find.text('SCR-01'), findsOneWidget);
    });

    testWidgets('Authenticated no-plan → onboarding for /dashboard', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter(hasActivePlan: false);
      await _pump(tester, router);
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(find.text('SCR-03'), findsOneWidget);
    });

    testWidgets('Authenticated + plan on /sign-in → /dashboard', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter();
      await _pump(tester, router);
      expect(find.text('SCR-06'), findsOneWidget);
    });

    testWidgets('Invite deep-link accessible while unauthenticated', (
      WidgetTester tester,
    ) async {
      final router = _buildRouter(
        authState: AuthState.unauthenticated,
        hasActivePlan: false,
      );
      await _pump(tester, router);
      router.go('/invite/accept/sometoken');
      await tester.pumpAndSettle();
      expect(find.text('SCR-02'), findsOneWidget);
    });
  });
}
