// Tests the production router with auth/plan overrides, not a copied route tree.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';
import 'package:kasaran/ui/screens/placeholder_screen.dart';
import 'package:kasaran/ui/screens/scr_01_sign_in.dart';
import 'package:kasaran/ui/screens/scr_02_invite_acceptance.dart';

final _auth = NotifierProvider<_AuthController, AuthState>(_AuthController.new);
final _plan = NotifierProvider<_PlanController, PlanAccess>(
  _PlanController.new,
);

class _AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.unauthenticated;

  set value(AuthState next) => state = next;
}

class _PlanController extends Notifier<PlanAccess> {
  @override
  PlanAccess build() => PlanAccess.none;

  set value(PlanAccess next) => state = next;
}

Future<(ProviderContainer, GoRouter)> _pump(
  WidgetTester tester, {
  AuthState auth = AuthState.authenticated,
  bool plan = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => ref.watch(_auth)),
      planAccessProvider.overrideWith((ref) => ref.watch(_plan)),
    ],
  );
  addTearDown(container.dispose);
  container.read(_auth.notifier).value = auth;
  container.read(_plan.notifier).value = plan
      ? PlanAccess.member
      : PlanAccess.none;
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (container, router);
}

void _expectScreen(String id) {
  expect(
    find.byWidgetPredicate(
      (widget) => widget is PlaceholderScreen && widget.screenId == id,
    ),
    findsWidgets,
  );
}

void main() {
  testWidgets(
    'custom-scheme invite opens SCR-02 with original token unauthenticated',
    (tester) async {
      final (_, router) = await _pump(
        tester,
        auth: AuthState.unauthenticated,
        plan: false,
      );
      router.go('kasaran://accept/token-123');
      await tester.pumpAndSettle();
      expect(find.byType(Scr02InviteAcceptance), findsOneWidget);
      expect(
        tester
            .widget<Scr02InviteAcceptance>(find.byType(Scr02InviteAcceptance))
            .token,
        'token-123',
      );
      expect(find.text('Join my partner’s plan'), findsOneWidget);
    },
  );

  testWidgets(
    'invite bypass also holds for authenticated user without a plan',
    (tester) async {
      final (_, router) = await _pump(tester, plan: false);
      router.go('kasaran://accept/planless');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Scr02InviteAcceptance>(find.byType(Scr02InviteAcceptance))
            .token,
        'planless',
      );
    },
  );

  testWidgets('member cannot open another plan invitation', (tester) async {
    final (_, router) = await _pump(tester);
    router.go('kasaran://accept/token-123');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.dashboard);
    expect(find.byType(Scr02InviteAcceptance), findsNothing);
  });

  testWidgets('unknown membership cannot open invitation', (tester) async {
    final (container, router) = await _pump(tester, plan: false);
    container.read(_plan.notifier).value = PlanAccess.error;
    router.go('kasaran://accept/token-123');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.planCheck);
    expect(find.byType(Scr02InviteAcceptance), findsNothing);
  });

  testWidgets('unauthenticated protected route redirects to sign-in', (
    tester,
  ) async {
    final (_, router) = await _pump(
      tester,
      auth: AuthState.unauthenticated,
      plan: false,
    );
    router.go(Routes.dashboard);
    await tester.pumpAndSettle();
    expect(find.byType(Scr01SignIn), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, Routes.signIn);
  });

  testWidgets('unverified user cannot open a protected route', (tester) async {
    final (_, router) = await _pump(
      tester,
      auth: AuthState.unverified,
      plan: false,
    );
    router.go(Routes.dashboard);
    await tester.pumpAndSettle();
    expect(find.byType(Scr01SignIn), findsOneWidget);
  });

  testWidgets(
    'verified planless account sees Start or Join before onboarding',
    (tester) async {
      final (_, router) = await _pump(tester, plan: false);
      router.go(Routes.dashboard);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, Routes.signIn);
      expect(find.text('Start our plan'), findsOneWidget);
      expect(find.text("Join my partner's plan"), findsOneWidget);
    },
  );

  testWidgets('auth change refreshes the same router without losing location', (
    tester,
  ) async {
    final (container, router) = await _pump(
      tester,
      auth: AuthState.unauthenticated,
      plan: false,
    );
    container.read(_auth.notifier).value = AuthState.authenticated;
    expect(container.read(authStateProvider), AuthState.authenticated);
    await tester.pumpAndSettle();
    expect(find.text('Start our plan'), findsOneWidget);
    expect(identical(container.read(appRouterProvider), router), isTrue);
    container.read(_plan.notifier).value = PlanAccess.member;
    expect(container.read(planAccessProvider), PlanAccess.member);
    await tester.pumpAndSettle();
    _expectScreen('SCR-06');
    expect(identical(container.read(appRouterProvider), router), isTrue);
  });

  testWidgets(
    'unknown plan membership blocks protected routes and Start/Join',
    (tester) async {
      final (container, router) = await _pump(tester, plan: false);
      container.read(_plan.notifier).value = PlanAccess.loading;
      router.go(Routes.dashboard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.routeInformationProvider.value.uri.path, Routes.planCheck);
      expect(find.text('Start our plan'), findsNothing);
      container.read(_plan.notifier).value = PlanAccess.error;
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be checked'), findsOneWidget);
      expect(find.text('Start our plan'), findsNothing);
    },
  );

  testWidgets('all production SCR routes resolve to their screens', (
    tester,
  ) async {
    final (_, router) = await _pump(tester);
    const screens = <String, String>{
      Routes.dashboard: 'SCR-06',
      Routes.ledger: 'SCR-07',
      '/ledger/entry/abc123': 'SCR-08',
      '/ledger/fee/crew_meals': 'SCR-09',
      Routes.allocations: 'SCR-10',
      '/explain/catering_venue': 'SCR-11',
      Routes.guests: 'SCR-12',
      Routes.guestsWhatIf: 'SCR-13',
      Routes.pledges: 'SCR-14',
      Routes.pledgesNew: 'SCR-15',
      '/pledges/edit/abc123': 'SCR-15',
      Routes.more: 'SCR-16',
      Routes.moreChangeLog: 'SCR-16',
      Routes.moreSharedAccess: 'SCR-17',
      Routes.morePlanSettings: 'SCR-18',
      Routes.moreSyncDetail: 'SCR-19',
    };
    for (final entry in screens.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      _expectScreen(entry.value);
      expect(router.routeInformationProvider.value.uri.path, entry.key);
    }
  });

  testWidgets('onboarding screens remain reachable without a plan', (
    tester,
  ) async {
    final (_, router) = await _pump(tester, plan: false);
    for (final entry in <String, String>{
      Routes.onboardingBudgetDate: 'SCR-03',
      '/onboarding/budget-date/guest-region': 'SCR-04',
      '/onboarding/budget-date/guest-region/hidden-fees': 'SCR-05',
    }.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      _expectScreen(entry.value);
      expect(router.routeInformationProvider.value.uri.path, entry.key);
    }
  });

  testWidgets('SCR-19 has only its More destination', (tester) async {
    final (_, router) = await _pump(tester);
    router.go(Routes.moreSyncDetail);
    await tester.pumpAndSettle();
    _expectScreen('SCR-19');
    router.go('/sync-detail');
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PlaceholderScreen && widget.screenId == 'SCR-19',
      ),
      findsNothing,
    );
  });
}
