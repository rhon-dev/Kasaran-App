// Tests the production router with auth/plan overrides, not a copied route tree.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/providers/setup_draft_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';
import 'package:kasaran/ui/screens/placeholder_screen.dart';
import 'package:kasaran/ui/screens/scr_01_sign_in.dart';
import 'package:kasaran/ui/screens/scr_02_invite_acceptance.dart';
import 'package:kasaran/ui/screens/scr_03_setup_budget_date.dart';
import 'package:kasaran/ui/screens/scr_04_setup_guest_region.dart';
import 'package:kasaran/ui/screens/scr_17_shared_access.dart';

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

final _user = NotifierProvider<_UserController, String>(_UserController.new);

class _UserController extends Notifier<String> {
  @override
  String build() => 'user-1';

  set value(String next) => state = next;
}

class _PendingMembershipLookup implements PlanMembershipLookup {
  final requests = <Completer<String?>>[];

  @override
  Future<String?> currentPlanId() {
    final request = Completer<String?>();
    requests.add(request);
    return request.future;
  }
}

class _RetryIdentitySource implements AuthIdentitySource {
  final changes = StreamController<String?>.broadcast();
  String? userId;

  @override
  String? get currentUserId => userId;

  @override
  Stream<String?> get onUserChanged => changes.stream;

  Future<void> dispose() => changes.close();
}

class _RetryMembershipLookup implements PlanMembershipLookup {
  @override
  Future<String?> currentPlanId() async => 'plan-1';
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
      authUserIdProvider.overrideWithValue('user-1'),
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
    'account switches defer protected routes until membership reload',
    (tester) async {
      final lookup = _PendingMembershipLookup();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWithValue(AuthState.authenticated),
          authUserIdProvider.overrideWith((ref) => ref.watch(_user)),
          planMembershipLookupProvider.overrideWithValue(lookup),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final routerSubscription = container.listen(appRouterProvider, (_, _) {});
      addTearDown(routerSubscription.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(lookup.requests.length, 1);
      lookup.requests[0].complete('plan-1');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, Routes.dashboard);
      container.read(_user.notifier).value = 'user-2';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(planAccessProvider), PlanAccess.loading);
      expect(router.routeInformationProvider.value.uri.path, Routes.planCheck);
      expect(lookup.requests.length, 2);
      container.read(_user.notifier).value = 'user-1';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(planAccessProvider), PlanAccess.loading);
      expect(router.routeInformationProvider.value.uri.path, Routes.planCheck);
      expect(lookup.requests.length, 3);
      lookup.requests[1].complete('plan-1');
      await tester.pump();
      expect(container.read(planAccessProvider), PlanAccess.loading);
      lookup.requests[2].complete('plan-1');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, Routes.dashboard);
    },
  );

  testWidgets('sign-out hides an open past-date prompt and erases its draft', (
    tester,
  ) async {
    final (container, router) = await _pump(tester, plan: false);
    final keepRouterWatched = container.listen(appRouterProvider, (_, _) {});
    addTearDown(keepRouterWatched.close);
    await tester.tap(find.text('Start our plan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('setup-budget')), '123');
    await tester.enterText(find.byKey(const Key('setup-date')), '2020-01-01');
    await tester.tap(find.byKey(const Key('setup-next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2020-01-01'), findsWidgets);
    container.read(_auth.notifier).value = AuthState.unauthenticated;
    await tester.pumpAndSettle();
    expect(container.read(setupDraftProvider).ownerId, isNull);
    expect(find.textContaining('2020-01-01'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, Routes.signIn);
  });

  testWidgets(
    'identity reload hides and erases SCR-03 draft through production router',
    (tester) async {
      final lookup = _PendingMembershipLookup();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWithValue(AuthState.authenticated),
          authUserIdProvider.overrideWith((ref) => ref.watch(_user)),
          planMembershipLookupProvider.overrideWithValue(lookup),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final keepRouterWatched = container.listen(appRouterProvider, (_, _) {});
      addTearDown(keepRouterWatched.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      lookup.requests[0].complete(null);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start our plan'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('setup-budget')),
        '₱28,000.00',
      );
      await tester.enterText(find.byKey(const Key('setup-date')), '2028-02-29');
      expect(container.read(setupDraftProvider).budgetInput, '₱28,000.00');
      container.read(_user.notifier).value = 'user-2';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.routeInformationProvider.value.uri.path, Routes.planCheck);
      expect(container.read(setupDraftProvider).budgetInput, isEmpty);
      expect(find.text('₱28,000.00'), findsNothing);
      container.read(_user.notifier).value = 'user-1';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.routeInformationProvider.value.uri.path, Routes.planCheck);
      lookup.requests[1].complete(null);
      await tester.pump();
      lookup.requests[2].complete(null);
      await tester.pumpAndSettle();
      router.go(Routes.onboardingBudgetDate);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('setup-budget')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('plan-check retry refreshes failed account identity', (
    tester,
  ) async {
    final source = _RetryIdentitySource();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(AuthState.authenticated),
        authIdentitySourceProvider.overrideWithValue(source),
        planMembershipLookupProvider.overrideWithValue(
          _RetryMembershipLookup(),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await source.dispose();
    });
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    source.changes.addError(StateError('synthetic identity failure'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.planCheck);
    expect(find.text('Retry'), findsOneWidget);
    source.userId = 'user-1';
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.dashboard);
  });

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
      Routes.morePlanSettings: 'SCR-18',
      Routes.moreSyncDetail: 'SCR-19',
    };
    for (final entry in screens.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      _expectScreen(entry.value);
      expect(router.routeInformationProvider.value.uri.path, entry.key);
    }
    router.go(Routes.moreSharedAccess);
    await tester.pumpAndSettle();
    expect(find.byType(Scr17SharedAccess), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      Routes.moreSharedAccess,
    );
  });

  testWidgets('onboarding screens remain reachable without a plan', (
    tester,
  ) async {
    final (_, router) = await _pump(tester, plan: false);
    router.go(Routes.onboardingBudgetDate);
    await tester.pumpAndSettle();
    expect(find.byType(Scr03SetupBudgetDate), findsOneWidget);
    expect(find.textContaining('No plan has been created'), findsOneWidget);
    router.go(Routes.onboardingGuestRegion);
    await tester.pumpAndSettle();
    expect(find.byType(Scr04SetupGuestRegion), findsOneWidget);
    expect(find.textContaining('no plan has been created'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      Routes.onboardingGuestRegion,
    );
    router.go(Routes.onboardingHiddenFees);
    await tester.pumpAndSettle();
    _expectScreen('SCR-05');
  });

  testWidgets('Start advances SCR-03 draft to SCR-04 and Back restores it', (
    tester,
  ) async {
    final (container, router) = await _pump(tester, plan: false);
    await tester.tap(find.text('Start our plan'));
    await tester.pumpAndSettle();
    expect(find.byType(Scr03SetupBudgetDate), findsOneWidget);
    await tester.enterText(find.byKey(const Key('setup-budget')), '₱28,000.00');
    await tester.enterText(find.byKey(const Key('setup-date')), '2028-02-29');
    await tester.tap(find.byKey(const Key('setup-next')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      Routes.onboardingGuestRegion,
    );
    expect(find.byType(Scr04SetupGuestRegion), findsOneWidget);
    expect(container.read(setupDraftProvider).acceptedDate, '2028-02-29');
    await tester.tap(find.text('Back to budget & date'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('setup-budget')))
          .controller!
          .text,
      '₱28,000.00',
    );
  });

  testWidgets('member cannot open either onboarding draft route', (
    tester,
  ) async {
    final (_, router) = await _pump(tester);
    for (final path in [
      Routes.onboardingBudgetDate,
      Routes.onboardingGuestRegion,
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, Routes.dashboard);
      expect(find.byType(Scr03SetupBudgetDate), findsNothing);
      expect(find.byType(Scr04SetupGuestRegion), findsNothing);
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
