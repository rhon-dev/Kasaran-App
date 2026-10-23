import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';

/// The only capability granted to account-bound financial operations. A lease
/// never exposes a database except within a counted [run] invocation.
final class AccountLease {
  AccountLease._(this._owner, this.userId, this.generation);

  final AccountStoreCoordinator _owner;
  final String userId;
  final int generation;

  /// Rejects a revoked generation before invoking work; counts the complete
  /// returned future (including Drift's asynchronous transaction COMMIT).
  Future<T> run<T>(Future<T> Function(AppDatabase db) work) {
    final db = _owner._admit(this); // synchronous rejection, before any await
    return _owner._execute(this, db, work);
  }
}

/// Serializes account open/close/Auth transitions while allowing admitted
/// transactions to complete in their original encrypted account store.
final class AccountStoreCoordinator extends ChangeNotifier {
  AccountStoreCoordinator(this._identity, this._openAccount);

  final VerifiedLocalIdentity _identity;
  final Future<AppDatabase> Function(VerifiedSessionSnapshot) _openAccount;
  Future<void> _serial = Future.value();
  AppDatabase? _db;
  VerifiedSessionSnapshot? _session;
  VerifiedSessionSnapshot? _observed;
  VerifiedSessionSnapshot? _failedOpen;
  VerifiedSessionSnapshot? _failedAuthSession;
  bool _failedAuth = false;
  bool _failedClose = false;
  bool _blocked = true;
  bool _started = false;
  bool _closed = false;
  bool _disposed = false;
  int _pendingTransitions = 0;
  int _generation = 0;
  int _active = 0;
  Completer<void>? _drained;

  VerifiedLocalIdentity get identity => _identity;
  int get generation => _generation;
  bool get hasFailure => _failedOpen != null || _failedAuth || _failedClose;

  bool get isReady {
    if (_closed ||
        _blocked ||
        _db == null ||
        !_matches(_session, _identity.capture())) {
      if (!_blocked) _observeDetached();
      return false;
    }
    return true;
  }

  bool _matches(VerifiedSessionSnapshot? a, VerifiedSessionSnapshot? b) =>
      a != null &&
      b != null &&
      a.userId == b.userId &&
      identical(a.marker, b.marker);

  Future<void> _queue(Future<void> Function() task) {
    final next = _serial.then((_) => task());
    _serial = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _revoke() {
    _blocked = true;
    _generation++;
    _publish();
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  /// Permanently revoke, drain complete operations and close the owned store.
  Future<void> close() {
    if (_failedClose) {
      return Future.error(StateError('Account store closure unconfirmed'));
    }
    if (_closed) return _serial;
    _closed = true;
    _revoke();
    return _queue(_drainAndClose);
  }

  @override
  void dispose() {
    unawaited(close().catchError((Object _) {}));
    _disposed = true;
    super.dispose();
  }

  Future<void> _drainAndClose() async {
    // Drift's native executor marks itself closed before delegate.close().
    // After a failure a repeated close may succeed as a no-op, not as proof
    // that the native handle closed. Keep ownership and fail permanently shut.
    if (_failedClose) throw StateError('Account store closure unconfirmed');
    if (_active > 0) {
      _drained ??= Completer<void>();
      await _drained!.future;
    }
    final old = _db;
    if (old != null) {
      try {
        await old.close();
      } catch (_) {
        _failedClose = true;
        _publish();
        rethrow;
      }
    }
    _db = null;
    _session = null;
  }

  Future<void> _openCurrent({VerifiedSessionSnapshot? only}) async {
    if (_failedClose) throw StateError('Account store closure unconfirmed');
    if (_closed) return;
    if (_pendingTransitions > 0) return;
    while (true) {
      if (_pendingTransitions > 0) return;
      final candidate = _identity.capture();
      if (only != null && !_matches(only, candidate)) {
        throw StateError('Retry session changed');
      }
      if (candidate == null) return;
      if (!_matches(_observed, candidate)) {
        _observed = candidate;
        _generation++;
      }
      late final AppDatabase db;
      try {
        db = await _openAccount(candidate);
      } catch (_) {
        if (_matches(candidate, _observed) &&
            _matches(candidate, _identity.capture())) {
          _failedOpen = candidate;
          _publish();
        }
        rethrow;
      }
      if (_closed ||
          _pendingTransitions > 0 ||
          !_matches(candidate, _identity.capture()) ||
          !_matches(candidate, _observed)) {
        // A rejected candidate is still owned until closure is confirmed.
        _db = db;
        _session = candidate;
        await _drainAndClose();
        if (_closed) return;
        if (only != null) throw StateError('Retry session changed');
        continue;
      }
      _db = db;
      _session = candidate;
      _failedOpen = null;
      _blocked = false;
      _publish();
      return;
    }
  }

  /// Auth SDK events must call this immediately, before publishing B routes.
  /// Revocation is synchronous even though COMMIT drain/close/open are async.
  Future<void> observeSession() {
    if (_closed) return Future.error(StateError('Account coordinator closed'));
    if (_failedClose) {
      return Future.error(StateError('Account store closure unconfirmed'));
    }
    final current = _identity.capture();
    if (_matches(_observed, current)) return _serial;
    _started = true;
    _observed = current;
    _failedOpen = null;
    _failedAuth = false;
    _failedAuthSession = null;
    _revoke();
    return _queue(() async {
      // A preceding observation may already have reconciled the newest marker
      // (or failed it). Queued SDK notifications must not reopen a ready store
      // or silently retry the same failed session after A->B->A.
      if (isReady || _matches(_failedOpen, _identity.capture())) return;
      await _drainAndClose();
      await _openCurrent();
    });
  }

  // Synchronous checks cannot await observation. Handle only their detached
  // future; callers awaiting observeSession still receive open failures.
  void _observeDetached() {
    unawaited(
      observeSession().then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }

  /// Explicit recovery from a failed account open, only for the same fresh
  /// verified session. No route or lease is admitted until reopening succeeds.
  Future<void> retryCurrent() {
    final requested = _identity.capture();
    if (!_blocked ||
        _failedClose ||
        _pendingTransitions > 0 ||
        !_matches(requested, _failedOpen) ||
        !_matches(requested, _observed)) {
      return Future.error(
        StateError('No failed current account open to retry'),
      );
    }
    return _queue(() async {
      if (!_blocked ||
          _failedClose ||
          _pendingTransitions > 0 ||
          !_matches(requested, _failedOpen) ||
          !_matches(requested, _observed) ||
          !_matches(requested, _identity.capture())) {
        throw StateError('Retry session changed');
      }
      _failedOpen =
          null; // One explicit attempt; another failure records it again.
      _publish();
      await _openCurrent(only: requested);
    });
  }

  /// Admission fails closed while a transition is draining or opening.
  Future<T> withAccount<T>(
    Future<T> Function(AccountLease lease) operation,
  ) async {
    if (!_started) {
      if (_identity.capture() == null) throw StateError('Account unavailable');
      await observeSession();
    }
    if (!isReady) throw StateError('Account unavailable');
    return operation(AccountLease._(this, _session!.userId, _generation));
  }

  AppDatabase _admit(AccountLease lease) {
    final current = _identity.capture();
    if (_blocked ||
        _db == null ||
        lease.generation != _generation ||
        lease.userId != _session?.userId ||
        !_matches(_session, current)) {
      if (!_blocked && !_matches(_session, current)) _observeDetached();
      throw StateError('Account lease revoked');
    }
    _active++;
    return _db!;
  }

  Future<T> _execute<T>(
    AccountLease lease,
    AppDatabase db,
    Future<T> Function(AppDatabase db) work,
  ) async {
    try {
      final result = await work(db);
      if (lease.generation != _generation || !isReady) {
        throw StateError('Account lease revoked');
      }
      return result;
    } finally {
      _active--;
      if (_active == 0 && _drained != null) {
        _drained!.complete();
        _drained = null;
      }
    }
  }

  /// Blocks first, drains all admitted `run` futures, closes A, then invokes
  /// the Auth mutation. No transition holds a lease while awaiting the drain.
  Future<void> transition(Future<void> Function() changeAuth) {
    if (_closed) return Future.error(StateError('Account coordinator closed'));
    if (_failedClose) {
      return Future.error(StateError('Account store closure unconfirmed'));
    }
    _started = true;
    _pendingTransitions++;
    _revoke();
    return _queue(() async {
      try {
        await _drainAndClose();
        try {
          await changeAuth();
        } catch (_) {
          _failedAuthSession = _identity.capture();
          _failedAuth = true;
          rethrow; // Auth failure leaves this scope blocked.
        }
      } finally {
        _pendingTransitions--;
        _publish();
      }
      final current = _identity.capture();
      // A successful callback with the same identity cannot recover a failed
      // Auth mutation, even when no account open failed.
      if (_failedAuth &&
          (current == null && _failedAuthSession == null ||
              _matches(current, _failedAuthSession))) {
        return;
      }
      _failedAuth = false;
      _failedAuthSession = null;
      // A no-op Auth callback is not permission to retry a failed open.
      if (_matches(current, _failedOpen)) return;
      _observed = current;
      _failedOpen = null;
      if (_pendingTransitions == 0) await _openCurrent();
    });
  }
}
