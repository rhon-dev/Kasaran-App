// ui/router/app_router.dart
//
// go_router route tree for Kasaran.
//
// Route groups (from ux-spec §1.3 and design.md §1.3):
//
//   (auth)
//     /sign-in                         SCR-01
//
//   (invite)
//     /invite/accept/:token            SCR-02
//
//   (onboarding)                       distinct stack — NOT a tab
//     /onboarding/budget-date          SCR-03
//     /onboarding/guest-region         SCR-04
//     /onboarding/hidden-fees          SCR-05
//
//   (app) — StatefulShellRoute with 5 branches
//     /dashboard                       SCR-06   branch 0
//     /ledger                          SCR-07   branch 1
//       /ledger/entry/:id              SCR-08 (modal — full-screen)
//       /ledger/fee/:type              SCR-09
//     /guests                          SCR-12   branch 2
//       /guests/what-if                SCR-13
//     /pledges                         SCR-14   branch 3
//       /pledges/edit/:id              SCR-15
//       /pledges/new                   SCR-15 (new)
//     /more                            hub      branch 4
//       /more/change-log               SCR-16
//       /more/shared-access            SCR-17
//       /more/plan-settings            SCR-18
//       /more/sync-detail              SCR-19
//
//   modals (pushed over the shell from any tab):
//     /allocations                     SCR-10
//     /explain/:key                    SCR-11
//     /sync-detail                     SCR-19 (also reachable from /more)
//
// Redirect guards (phase 03 stubs — phase 06 replaces providers):
//   Unauthenticated → /sign-in
//   Authenticated, no active plan → /onboarding/budget-date
//   Authenticated, has plan → allow

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

// Route path constants — single source of truth used by push/go call sites.
// Named with 'Routes' prefix to avoid collisions with screen class names.
abstract final class Routes {
  static const signIn = '/sign-in';
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
  static const syncDetail = '/sync-detail';
}

/// Builds the [GoRouter] wired to the Riverpod [ref].
///
/// Call this once inside a [ConsumerWidget] or [ConsumerStatefulWidget] and
/// cache the result in a [Provider]. The router listens to [authStateProvider]
/// and [hasActivePlanProvider] for redirect logic.
GoRouter buildAppRouter(WidgetRef ref) {
  final authState = ref.watch(authStateProvider);
  final hasActivePlan = ref.watch(hasActivePlanProvider);

  return GoRouter(
    initialLocation: Routes.signIn,
    redirect: (context, state) => _redirect(state, authState, hasActivePlan),
    routes: [
      // -----------------------------------------------------------------------
      // (auth) group
      // -----------------------------------------------------------------------
      GoRoute(
        path: Routes.signIn,
        name: 'sign-in',
        builder: (context, state) => const Scr01SignIn(),
      ),

      // -----------------------------------------------------------------------
      // (invite) group
      // -----------------------------------------------------------------------
      GoRoute(
        path: Routes.inviteAccept,
        name: 'invite-accept',
        builder: (context, state) => Scr02InviteAcceptance(
          token: state.pathParameters['token'] ?? '',
        ),
      ),

      // -----------------------------------------------------------------------
      // (onboarding) group — distinct stack, not a tab
      // ux-spec §1.3: "The setup wizard is a distinct stack rather than tabs
      // because REQ-HF-1 clause 6 requires it to gate completion."
      // -----------------------------------------------------------------------
      GoRoute(
        path: Routes.onboardingBudgetDate,
        name: 'onboarding-budget-date',
        builder: (context, state) => const Scr03SetupBudgetDate(),
        routes: [
          GoRoute(
            path: 'guest-region',
            name: 'onboarding-guest-region',
            builder: (context, state) => const Scr04SetupGuestRegion(),
            routes: [
              GoRoute(
                path: 'hidden-fees',
                name: 'onboarding-hidden-fees',
                builder: (context, state) => const Scr05SetupHiddenFees(),
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // (app) group — StatefulShellRoute with 5 independent tab stacks
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppTabShell(
          navigationShell: navigationShell,
        ),
        branches: [
          // Branch 0 — Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                name: 'dashboard',
                builder: (context, state) => const Scr06Dashboard(),
              ),
            ],
          ),

          // Branch 1 — Ledger
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ledger,
                name: 'ledger',
                builder: (context, state) => const Scr07LedgerList(),
                routes: [
                  GoRoute(
                    path: 'entry/:id',
                    name: 'ledger-entry',
                    builder: (context, state) => Scr08ExpenseEditor(
                      entryId: state.pathParameters['id'],
                    ),
                  ),
                  GoRoute(
                    path: 'fee/:type',
                    name: 'ledger-fee',
                    builder: (context, state) => Scr09HiddenFeeEditor(
                      feeType: state.pathParameters['type'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 2 — Guests
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.guests,
                name: 'guests',
                builder: (context, state) => const Scr12GuestsList(),
                routes: [
                  GoRoute(
                    path: 'what-if',
                    name: 'guests-what-if',
                    builder: (context, state) => const Scr13GuestWhatIf(),
                  ),
                ],
              ),
            ],
          ),

          // Branch 3 — Pledges
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.pledges,
                name: 'pledges',
                builder: (context, state) => const Scr14PledgesList(),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: 'pledges-new',
                    builder: (context, state) =>
                        const Scr15PledgeEditor(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    name: 'pledges-edit',
                    builder: (context, state) => Scr15PledgeEditor(
                      pledgeId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 4 — More
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                name: 'more',
                // The 'More' hub renders the change-log as its root per
                // ux-spec §1.3, with shared-access, settings, and sync pushed.
                builder: (context, state) => const Scr16ChangeLog(),
                routes: [
                  GoRoute(
                    path: 'change-log',
                    name: 'more-change-log',
                    builder: (context, state) => const Scr16ChangeLog(),
                  ),
                  GoRoute(
                    path: 'shared-access',
                    name: 'more-shared-access',
                    builder: (context, state) => const Scr17SharedAccess(),
                  ),
                  GoRoute(
                    path: 'plan-settings',
                    name: 'more-plan-settings',
                    builder: (context, state) => const Scr18PlanSettings(),
                  ),
                  GoRoute(
                    path: 'sync-detail',
                    name: 'more-sync-detail',
                    builder: (context, state) => const Scr19SyncDetail(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Modal routes — pushed over the shell from any context
      // -----------------------------------------------------------------------
      GoRoute(
        path: Routes.allocations,
        name: 'allocations',
        builder: (context, state) => const Scr10Allocations(),
      ),
      GoRoute(
        path: Routes.explainFigure,
        name: 'explain-figure',
        builder: (context, state) => Scr11ExplainFigure(
          figureKey: state.pathParameters['key'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.syncDetail,
        name: 'sync-detail',
        builder: (context, state) => const Scr19SyncDetail(),
      ),
    ],
  );
}

/// Route redirect logic.
///
/// Three rules, evaluated in order:
/// 1. Invite deep-link is always allowed regardless of auth state.
/// 2. Unauthenticated users may only visit auth/invite screens.
/// 3. Authenticated users without an active plan are sent to onboarding.
String? _redirect(
  GoRouterState state,
  AuthState authState,
  bool hasActivePlan,
) {
  final path = state.uri.path;

  // Deep-link invite is always accessible — the user may not be authenticated
  // yet when they tap the link.
  if (path.startsWith('/invite/')) return null;

  switch (authState) {
    case AuthState.unauthenticated:
    case AuthState.unverified:
      // Allow auth screens through; redirect everything else to sign-in.
      if (path == Routes.signIn) return null;
      return Routes.signIn;

    case AuthState.authenticated:
      // Authenticated but no plan → onboarding.
      if (!hasActivePlan) {
        if (path.startsWith('/onboarding')) return null;
        return Routes.onboardingBudgetDate;
      }
      // Has plan → if on auth/onboarding screen, send to dashboard.
      if (path == Routes.signIn || path.startsWith('/onboarding')) {
        return Routes.dashboard;
      }
      return null;
  }
}

// ---------------------------------------------------------------------------
// Router provider — cached so rebuild does not recreate the router object.
// ---------------------------------------------------------------------------

/// Provides a [GoRouter] instance wired to auth and plan state.
///
/// Use inside a [ConsumerWidget] via `ref.watch(appRouterProvider)`.
final appRouterProvider = Provider<GoRouter>((ref) {
  // ignore: avoid_dynamic_calls
  // This provider is read once by main.dart; the redirect closure captures
  // ref.watch calls, so the router rebuilds on auth/plan state changes
  // via go_router's refreshListenable integration.
  //
  // Phase 03: we build a router that watches stub providers. Phase 06 updates
  // those providers and the router's redirect logic re-runs automatically.
  //
  // A circular dependency is not possible here because the providers that
  // feed the redirect are leaf nodes (they do not depend on the router).
  final authState = ref.watch(authStateProvider);
  final hasActivePlan = ref.watch(hasActivePlanProvider);

  return GoRouter(
    initialLocation: Routes.signIn,
    redirect: (context, state) => _redirect(state, authState, hasActivePlan),
    routes: _buildRoutes(),
  );
});

List<RouteBase> _buildRoutes() => [
      GoRoute(
        path: Routes.signIn,
        name: 'sign-in',
        builder: (context, state) => const Scr01SignIn(),
      ),
      GoRoute(
        path: Routes.inviteAccept,
        name: 'invite-accept',
        builder: (context, state) => Scr02InviteAcceptance(
          token: state.pathParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.onboardingBudgetDate,
        name: 'onboarding-budget-date',
        builder: (context, state) => const Scr03SetupBudgetDate(),
        routes: [
          GoRoute(
            path: 'guest-region',
            name: 'onboarding-guest-region',
            builder: (context, state) => const Scr04SetupGuestRegion(),
            routes: [
              GoRoute(
                path: 'hidden-fees',
                name: 'onboarding-hidden-fees',
                builder: (context, state) => const Scr05SetupHiddenFees(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppTabShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                name: 'dashboard',
                builder: (context, state) => const Scr06Dashboard(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ledger,
                name: 'ledger',
                builder: (context, state) => const Scr07LedgerList(),
                routes: [
                  GoRoute(
                    path: 'entry/:id',
                    name: 'ledger-entry',
                    builder: (context, state) => Scr08ExpenseEditor(
                      entryId: state.pathParameters['id'],
                    ),
                  ),
                  GoRoute(
                    path: 'fee/:type',
                    name: 'ledger-fee',
                    builder: (context, state) => Scr09HiddenFeeEditor(
                      feeType: state.pathParameters['type'],
                    ),
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
                builder: (context, state) => const Scr12GuestsList(),
                routes: [
                  GoRoute(
                    path: 'what-if',
                    name: 'guests-what-if',
                    builder: (context, state) => const Scr13GuestWhatIf(),
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
                builder: (context, state) => const Scr14PledgesList(),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: 'pledges-new',
                    builder: (context, state) =>
                        const Scr15PledgeEditor(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    name: 'pledges-edit',
                    builder: (context, state) => Scr15PledgeEditor(
                      pledgeId: state.pathParameters['id'],
                    ),
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
                builder: (context, state) => const Scr16ChangeLog(),
                routes: [
                  GoRoute(
                    path: 'change-log',
                    name: 'more-change-log',
                    builder: (context, state) => const Scr16ChangeLog(),
                  ),
                  GoRoute(
                    path: 'shared-access',
                    name: 'more-shared-access',
                    builder: (context, state) => const Scr17SharedAccess(),
                  ),
                  GoRoute(
                    path: 'plan-settings',
                    name: 'more-plan-settings',
                    builder: (context, state) => const Scr18PlanSettings(),
                  ),
                  GoRoute(
                    path: 'sync-detail',
                    name: 'more-sync-detail',
                    builder: (context, state) => const Scr19SyncDetail(),
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
        builder: (context, state) => const Scr10Allocations(),
      ),
      GoRoute(
        path: Routes.explainFigure,
        name: 'explain-figure',
        builder: (context, state) => Scr11ExplainFigure(
          figureKey: state.pathParameters['key'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.syncDetail,
        name: 'sync-detail',
        builder: (context, state) => const Scr19SyncDetail(),
      ),
    ];
