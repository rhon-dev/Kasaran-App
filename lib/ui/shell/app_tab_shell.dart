// ui/shell/app_tab_shell.dart
//
// The (app) tab shell — wraps the five main tabs with a BottomNavigationBar.
// Used by go_router's StatefulShellRoute so each branch preserves its own
// Navigator stack (back-stack is per-tab, not shared).
//
// ux-spec §1.3 tabs (in order):
//   0 Dashboard  — SCR-06
//   1 Ledger     — SCR-07
//   2 Guests     — SCR-12
//   3 Pledges    — SCR-14
//   4 More       — SCR-16, SCR-17, SCR-18, SCR-19 pushed from here

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The stateful bottom-tab shell for the main application.
///
/// [navigationShell] is provided by go_router's [StatefulShellRoute]; it
/// manages the per-branch Navigator stacks and exposes [goBranch] for tab
/// switching.
class AppTabShell extends StatelessWidget {
  const AppTabShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTabTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Ledger',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Guests',
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism),
              label: 'Pledges',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      );

  void _onTabTap(int index) {
    // initialLocation: true restores the branch to its root when the tab is
    // already selected (standard Material 3 behaviour).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
