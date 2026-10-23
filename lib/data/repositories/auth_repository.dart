import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// No plan may be opened for an unverified account.
enum AuthSessionStatus { signedOut, emailUnverified, verified }

final class AgeDeclarationRequired implements Exception {
  const AgeDeclarationRequired();
  @override
  String toString() => 'Confirm that you are 18 or older before signing up.';
}

abstract interface class AuthGateway {
  AuthSessionStatus get currentStatus;
  Stream<AuthSessionStatus> get onStatusChanged;
  Future<AuthSessionStatus> signUp(String email, String password, String name);
  Future<AuthSessionStatus> signIn(String email, String password);
  Future<void> signOut();
}

abstract interface class AuthRepository {
  AuthSessionStatus get currentStatus;
  Stream<AuthSessionStatus> get onStatusChanged;
  Future<AuthSessionStatus> signUp({
    required String email,
    required String password,
    required String displayName,
    required bool isAdult,
  });
  Future<AuthSessionStatus> signIn({
    required String email,
    required String password,
  });
  Future<void> signOut();
}

/// Separates policy from the SDK so tests never need a network or real tokens.
final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._gateway, {
    Future<void> Function(Future<void> Function())? transition,
  }) : _transition = transition;
  final AuthGateway _gateway;
  final Future<void> Function(Future<void> Function())? _transition;

  Future<T> _change<T>(Future<T> Function() action) async {
    final transition = _transition;
    if (transition == null) {
      return action(); // Standalone policy unit tests only.
    }
    late T result;
    await transition(() async {
      result = await action();
    });
    return result;
  }

  @override
  AuthSessionStatus get currentStatus => _gateway.currentStatus;
  @override
  Stream<AuthSessionStatus> get onStatusChanged => _gateway.onStatusChanged;
  @override
  Future<AuthSessionStatus> signUp({
    required String email,
    required String password,
    required String displayName,
    required bool isAdult,
  }) async {
    if (!isAdult) throw const AgeDeclarationRequired();
    return _change(
      () => _gateway.signUp(email.trim(), password, displayName.trim()),
    );
  }

  @override
  Future<AuthSessionStatus> signIn({
    required String email,
    required String password,
  }) => _change(() => _gateway.signIn(email.trim(), password));
  @override
  Future<void> signOut() => _change(_gateway.signOut);
}

/// Production adapter; Supabase Auth owns credentials, refresh rotation and
/// server-side session revocation. Never log exceptions containing credentials.
final class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._auth);
  final GoTrueClient _auth;
  AuthSessionStatus? _pendingVerification;

  static AuthSessionStatus _status(Session? session) {
    if (session == null) return AuthSessionStatus.signedOut;
    return session.user.emailConfirmedAt == null
        ? AuthSessionStatus.emailUnverified
        : AuthSessionStatus.verified;
  }

  @override
  AuthSessionStatus get currentStatus =>
      _status(_auth.currentSession) == AuthSessionStatus.signedOut
      ? _pendingVerification ?? AuthSessionStatus.signedOut
      : _status(_auth.currentSession);

  @override
  Stream<AuthSessionStatus> get onStatusChanged => _auth.onAuthStateChange.map((
    event,
  ) {
    if (event.event == AuthChangeEvent.signedOut) _pendingVerification = null;
    return _status(event.session);
  });

  @override
  Future<AuthSessionStatus> signUp(
    String email,
    String password,
    String name,
  ) async {
    final result = await _auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
    );
    final status =
        result.session == null || result.user?.emailConfirmedAt == null
        ? AuthSessionStatus.emailUnverified
        : AuthSessionStatus.verified;
    _pendingVerification = status == AuthSessionStatus.emailUnverified
        ? status
        : null;
    return status;
  }

  @override
  Future<AuthSessionStatus> signIn(String email, String password) async {
    final result = await _auth.signInWithPassword(
      email: email,
      password: password,
    );
    _pendingVerification = null;
    return _status(result.session);
  }

  @override
  Future<void> signOut() async {
    // GoTrue's local scope revokes only this device's refresh session on the
    // server. A remote error propagates; do not claim revocation succeeded.
    await _auth.signOut();
    _pendingVerification = null;
  }
}
