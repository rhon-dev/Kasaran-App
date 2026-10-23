import 'package:supabase_flutter/supabase_flutter.dart';

/// Captures one verified local Auth session without persisting or logging tokens.
/// The marker is opaque and compared by object identity across awaits.
final class VerifiedSessionSnapshot {
  const VerifiedSessionSnapshot(this.userId, this.marker);
  final String userId;
  final Object marker;
}

/// A synchronous, last-known verified session identity. No network authority.
// Interface is required to separate the production Auth adapter from test fakes.
// ignore: one_member_abstracts
abstract interface class VerifiedLocalIdentity {
  VerifiedSessionSnapshot? capture();
}

/// Reads the current Auth session on each repository operation. A new session
/// object invalidates a pending operation, even across an A→B→A account switch.
/// Phase 08 must recheck live authorization on the server.
final class SupabaseVerifiedLocalIdentity implements VerifiedLocalIdentity {
  const SupabaseVerifiedLocalIdentity(this.auth);
  final GoTrueClient auth;

  @override
  VerifiedSessionSnapshot? capture() {
    final session = auth.currentSession;
    final user = session?.user;
    if (session == null || user?.emailConfirmedAt == null) return null;
    return VerifiedSessionSnapshot(user!.id, session);
  }
}
