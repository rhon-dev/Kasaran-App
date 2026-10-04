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
