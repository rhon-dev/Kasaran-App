import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Preserve the router's synchronous Provider of AuthState override contract.
enum AuthState { unauthenticated, unverified, authenticated }

/// Null only when a test embeds KasaranApp without calling main(); production
/// initializes Supabase before mounting the router.
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  try {
    final client = Supabase.instance.client;
    return SupabaseAuthRepository(SupabaseAuthGateway(client.auth));
    // Widget-only smoke tests mount KasaranApp directly without calling main.
    // ignore: avoid_catching_errors
  } on AssertionError {
    return null;
  }
});

final _authUpdatesProvider = StreamProvider<AuthSessionStatus>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository?.onStatusChanged ?? const Stream<AuthSessionStatus>.empty();
});

final authStateProvider = Provider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final status =
      ref.watch(_authUpdatesProvider).value ?? repository?.currentStatus;
  return switch (status) {
    AuthSessionStatus.verified => AuthState.authenticated,
    AuthSessionStatus.emailUnverified => AuthState.unverified,
    _ => AuthState.unauthenticated,
  };
});

/// Verification status alone cannot distinguish two verified accounts.
abstract interface class AuthIdentitySource {
  String? get currentUserId;
  Stream<String?> get onUserChanged;
}

final class SupabaseAuthIdentitySource implements AuthIdentitySource {
  const SupabaseAuthIdentitySource(this.auth);
  final GoTrueClient auth;

  @override
  String? get currentUserId => auth.currentUser?.id;

  @override
  Stream<String?> get onUserChanged =>
      auth.onAuthStateChange.map((event) => event.session?.user.id);
}

final authIdentitySourceProvider = Provider<AuthIdentitySource?>((ref) {
  try {
    return SupabaseAuthIdentitySource(Supabase.instance.client.auth);
    // Widget-only tests mount without calling main.
    // ignore: avoid_catching_errors
  } on AssertionError {
    return null;
  }
});

final authIdentityStateProvider = StreamProvider<String?>((ref) async* {
  final source = ref.watch(authIdentitySourceProvider);
  if (source == null) return;
  yield source.currentUserId;
  yield* source.onUserChanged;
});

/// Null when identity is unknown or the Auth stream fails.
final authUserIdProvider = Provider<String?>((ref) {
  final identity = ref.watch(authIdentityStateProvider);
  if (identity.isLoading || identity.hasError || !identity.hasValue) {
    return null;
  }
  return identity.requireValue;
});
