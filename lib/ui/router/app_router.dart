// Production go_router route tree. SCR-19 lives only under More.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/screens/scr_01_sign_in.dart';
import 'package:kasaran/ui/screens/scr_02_invite_acceptance.dart';
import 'package:kasaran/ui/screens/scr_03_setup_budget_date.dart';
import 'package:kasaran/ui/screens/scr_04_setup_guest_region.dart';
import 'package:kasaran/ui/screens/scr_05_setup_hidden_fees.dart';
import 'package:kasaran/ui/screens/scr_06_dashboard.dart';
import 'package:kasaran/ui/screens/scr_07_ledger_list.dart';
import 'package:kasaran/ui/screens/scr_08_expense_editor.dart';
import 'package:kasaran/ui/screens/scr_09_hidden_fee_editor.dart';
import 'package:kasaran/ui/screens/scr_10_allocations.dart';
import 'package:kasaran/ui/screens/scr_11_explain_figure.dart';
import 'package:kasaran/ui/screens/scr_12_guests_list.dart';
import 'package:kasaran/ui/screens/scr_13_guest_what_if.dart';
import 'package:kasaran/ui/screens/scr_14_pledges_list.dart';
import 'package:kasaran/ui/screens/scr_15_pledge_editor.dart';
import 'package:kasaran/ui/screens/scr_16_change_log.dart';
import 'package:kasaran/ui/screens/scr_17_shared_access.dart';
import 'package:kasaran/ui/screens/scr_18_plan_settings.dart';
import 'package:kasaran/ui/screens/scr_19_sync_detail.dart';
import 'package:kasaran/ui/shell/app_tab_shell.dart';

/// Canonical in-app paths. The custom-scheme URL `kasaran://accept/{token}`
/// arrives with host `accept` and is redirected to [inviteAccept].
/// HTTPS App Links / Universal Links on the owned domain (OQ-09) are the
/// long-term replacement for the custom scheme.
abstract final class Routes {
  static const signIn = '/sign-in';
  static const planCheck = '/plan-check';
  static const invitePaste = '/invite/accept';
  static const inviteAccept = '/invite/accept/:token';
  static const onboardingBudgetDate = '/onboarding/budget-date';
  static const onboardingGuestRegion = '/onboarding/guest-region';
  static const onboardingHiddenFees = '/onboarding/hidden-fees';
  static const dashboard = '/dashboard';
  static const ledger = '/ledger';
  static const ledgerEntry = '/ledger/entry/:id';
  static const ledgerFee = '/ledger/fee/:type';
  static const guests = '/guests';
  static const guestsWhatIf = '/guests/what-if';
  static const pledges = '/pledges';
  static const pledgesNew = '/pledges/new';
  static const pledgesEdit = '/pledges/edit/:id';
  static const more = '/more';
  static const moreChangeLog = '/more/change-log';
  static const moreSharedAccess = '/more/shared-access';
  static const morePlanSettings = '/more/plan-settings';
  static const moreSyncDetail = '/more/sync-detail';
  static const allocations = '/allocations';
  static const explainFigure = '/explain/:key';
}

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Keep one router instance; refresh its redirect when auth/plan changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authStateProvider, (_, _) => refresh.refresh());
  ref.listen(planAccessProvider, (_, _) => refresh.refresh());
  final router = GoRouter(
    initialLocation: Routes.signIn,
    refreshListenable: refresh,
    redirect: (_, state) => _redirect(
      state,
      ref.read(authStateProvider),
      ref.read(planAccessProvider),
    ),
    routes: _buildRoutes(),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

String? _redirect(GoRouterState state, AuthState auth, PlanAccess planAccess) {
  final uri = state.uri;
  // Android/iOS deliver kasaran://accept/<token>, not /invite/accept/<token>.
  // Match the scheme and host explicitly rather than treating every /<token>
  // route as an invitation.
  if (uri.scheme == 'kasaran' &&
      uri.host == 'accept' &&
      uri.pathSegments.length == 1 &&
      uri.pathSegments.single.isNotEmpty) {
    return '/invite/accept/${Uri.encodeComponent(uri.pathSegments.single)}';
  }
  final path = uri.path;
  if (path == Routes.invitePaste || path.startsWith('${Routes.invitePaste}/')) {
    if (auth == AuthState.authenticated) {
      if (planAccess == PlanAccess.loading || planAccess == PlanAccess.error) {
        return Routes.planCheck;
      }
      if (planAccess == PlanAccess.member) return Routes.dashboard;
    }
    return null;
  }
  switch (auth) {
    case AuthState.unauthenticated:
    case AuthState.unverified:
      return path == Routes.signIn ? null : Routes.signIn;
    case AuthState.authenticated:
      if (planAccess == PlanAccess.loading || planAccess == PlanAccess.error) {
        return path == Routes.planCheck ? null : Routes.planCheck;
      }
      if (planAccess == PlanAccess.none) {
        return path == Routes.signIn || path.startsWith('/onboarding')
            ? null
            : Routes.signIn;
      }
      if (path == Routes.signIn ||
          path == Routes.planCheck ||
          path.startsWith('/onboarding')) {
        return Routes.dashboard;
      }
      return null;
  }
}

List<RouteBase> _buildRoutes() => [
  GoRoute(
    path: Routes.signIn,
    name: 'sign-in',
    builder: (_, _) => const Scr01SignIn(),
  ),
  GoRoute(
    path: Routes.planCheck,
    name: 'plan-check',
    builder: (_, _) => const _PlanCheckScreen(),
  ),
  GoRoute(
    path: Routes.invitePaste,
    name: 'invite-paste',
    builder: (_, _) => const Scr02InviteAcceptance(token: ''),
  ),
  GoRoute(
    path: Routes.inviteAccept,
    name: 'invite-accept',
    builder: (_, state) =>
        Scr02InviteAcceptance(token: state.pathParameters['token'] ?? ''),
  ),
  GoRoute(
    path: Routes.onboardingBudgetDate,
    name: 'onboarding-budget-date',
    builder: (_, _) => const Scr03SetupBudgetDate(),
    routes: [
      GoRoute(
        path: 'guest-region',
        name: 'onboarding-guest-region',
        builder: (_, _) => const Scr04SetupGuestRegion(),
        routes: [
          GoRoute(
            path: 'hidden-fees',
            name: 'onboarding-hidden-fees',
            builder: (_, _) => const Scr05SetupHiddenFees(),
          ),
        ],
      ),
    ],
  ),
  StatefulShellRoute.indexedStack(
    builder: (_, _, navigationShell) =>
        AppTabShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.dashboard,
            name: 'dashboard',
            builder: (_, _) => const Scr06Dashboard(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.ledger,
            name: 'ledger',
            builder: (_, _) => const Scr07LedgerList(),
            routes: [
              GoRoute(
                path: 'entry/:id',
                name: 'ledger-entry',
                builder: (_, state) =>
                    Scr08ExpenseEditor(entryId: state.pathParameters['id']),
              ),
              GoRoute(
                path: 'fee/:type',
                name: 'ledger-fee',
                builder: (_, state) =>
                    Scr09HiddenFeeEditor(feeType: state.pathParameters['type']),
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
            builder: (_, _) => const Scr12GuestsList(),
            routes: [
              GoRoute(
                path: 'what-if',
                name: 'guests-what-if',
                builder: (_, _) => const Scr13GuestWhatIf(),
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
            builder: (_, _) => const Scr14PledgesList(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'pledges-new',
                builder: (_, _) => const Scr15PledgeEditor(),
              ),
              GoRoute(
                path: 'edit/:id',
                name: 'pledges-edit',
                builder: (_, state) =>
                    Scr15PledgeEditor(pledgeId: state.pathParameters['id']),
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
            builder: (_, _) => const Scr16ChangeLog(),
            routes: [
              GoRoute(
                path: 'change-log',
                name: 'more-change-log',
                builder: (_, _) => const Scr16ChangeLog(),
              ),
              GoRoute(
                path: 'shared-access',
                name: 'more-shared-access',
                builder: (_, _) => const Scr17SharedAccess(),
              ),
              GoRoute(
                path: 'plan-settings',
                name: 'more-plan-settings',
                builder: (_, _) => const Scr18PlanSettings(),
              ),
              GoRoute(
                path: 'sync-detail',
                name: 'more-sync-detail',
                builder: (_, _) => const Scr19SyncDetail(),
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
    builder: (_, _) => const Scr10Allocations(),
  ),
  GoRoute(
    path: Routes.explainFigure,
    name: 'explain-figure',
    builder: (_, state) =>
        Scr11ExplainFigure(figureKey: state.pathParameters['key'] ?? ''),
  ),
];

class _PlanCheckScreen extends ConsumerWidget {
  const _PlanCheckScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(planAccessProvider);
    return Scaffold(
      body: Center(
        child: status == PlanAccess.loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your plan could not be checked. Reconnect and retry.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(currentPlanIdProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
      ),
    );
  }
}
