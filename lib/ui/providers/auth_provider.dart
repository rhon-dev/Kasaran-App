// ui/providers/auth_provider.dart
//
// Stub authentication state provider.
//
// Phase 03: always returns [AuthState.unauthenticated] so the app starts on
// SCR-01 (sign-in) by default. Phase 06 replaces this with a real Supabase
// Auth session listener.
//
// The redirect guard in app_router.dart reads this provider; keeping it
// separate from the router means phase 06 only touches this file, not the
// router.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Authentication states relevant to routing decisions.
enum AuthState {
  /// No authenticated session. Router redirects to SCR-01.
  unauthenticated,

  /// Session present but email not yet verified (post-sign-up state).
  /// Router blocks navigation past auth screens until verified.
  /// Phase 06 activates this state.
  unverified,

  /// Fully authenticated and email-verified.
  authenticated,
}

/// Stub provider — always [AuthState.unauthenticated] in phase 03.
///
/// Phase 06 replaces this with a [StreamProvider] or [AsyncNotifierProvider]
/// backed by `supabase_flutter`'s `onAuthStateChange` stream.
final authStateProvider = Provider<AuthState>((ref) =>
    // Phase 03 stub: start unauthenticated so every test and cold launch lands
    // on the sign-in screen. Flip to [AuthState.authenticated] in widget tests
    // that need to reach the app shell.
    AuthState.unauthenticated);
