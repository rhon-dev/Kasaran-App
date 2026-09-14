// ui/providers/plan_provider.dart
//
// Stub active-plan state provider.
//
// Phase 03: always returns false (no active plan) so the router redirects an
// authenticated-but-plan-less user to the onboarding wizard. Phase 07 wires
// this to the real repository once the data layer exists.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the authenticated user has an active wedding plan.
///
/// Stub for phase 03 — always false.
/// Phase 07 replaces this with a provider backed by the plan repository.
final hasActivePlanProvider = Provider<bool>((ref) =>
    // Phase 03 stub: no active plan. Override in widget tests that need the
    // authenticated + has-plan path (tab shell).
    false);
