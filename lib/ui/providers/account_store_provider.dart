import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

enum AccountStoreStatus { signedOut, unverified, loading, ready, unavailable }

/// Public readiness contains no raw database capability.
final class AccountStoreState {
  const AccountStoreState(this.status, this.generation);
  final AccountStoreStatus status;
  final int generation;
  bool get isReady => status == AccountStoreStatus.ready;
  // Auth-only forms hold no financial capability and must survive their own
  // drain-before-SDK call to show failures/email-verification instructions.
  // Entering/leaving any account-bound state still replaces the whole scope.
  (AccountStoreStatus, int) get scopeKey => (
    status,
    status == AccountStoreStatus.signedOut ||
            status == AccountStoreStatus.unverified
        ? 0
        : generation,
  );
}

/// Production must install its single root-owned coordinator. Absence is never
/// permission to display financial/onboarding UI (tests may override readiness).
final accountStoreCoordinatorProvider = Provider<AccountStoreCoordinator?>(
  (ref) => null,
);

final accountSessionEventsProvider = Provider<Stream<void>>((ref) {
  try {
    return Supabase.instance.client.auth.onAuthStateChange.map((_) {});
    // ignore: avoid_catching_errors
  } on AssertionError {
    return const Stream.empty();
  }
});

class _AccountUpdates extends ChangeNotifier {
  _AccountUpdates(this.coordinator, Stream<void> events) {
    coordinator?.addListener(_changed);
    _subscription = events.listen(
      (_) => observe(),
      onError: (Object _, StackTrace _) {
        // An untrustworthy event source must revoke even if the last SDK capture
        // still looks verified. An explicit successful Auth change is required.
        final owner = coordinator;
        if (owner != null) {
          unawaited(
            owner
                .transition(
                  () async => throw StateError('Auth observation unavailable'),
                )
                .catchError((Object _) {}),
          );
        }
      },
    );
    scheduleMicrotask(observe);
  }
  final AccountStoreCoordinator? coordinator;
  late final StreamSubscription<void> _subscription;
  bool _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void observe() {
    if (_disposed || coordinator == null) return;
    unawaited(coordinator!.observeSession().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _disposed = true;
    coordinator?.removeListener(_changed);
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final _accountUpdatesProvider = ChangeNotifierProvider<_AccountUpdates>(
  (ref) => _AccountUpdates(
    ref.watch(accountStoreCoordinatorProvider),
    ref.watch(accountSessionEventsProvider),
  ),
);

final accountStoreStateProvider = Provider<AccountStoreState>((ref) {
  final updates = ref.watch(_accountUpdatesProvider);
  final auth = ref.watch(authStateProvider);
  final coordinator = updates.coordinator;
  final generation = coordinator?.generation ?? 0;
  if (auth == AuthState.unauthenticated) {
    return AccountStoreState(AccountStoreStatus.signedOut, generation);
  }
  if (auth == AuthState.unverified) {
    return AccountStoreState(AccountStoreStatus.unverified, generation);
  }
  if (coordinator == null) {
    return AccountStoreState(AccountStoreStatus.unavailable, generation);
  }
  if (coordinator.isReady) {
    return AccountStoreState(AccountStoreStatus.ready, generation);
  }
  return AccountStoreState(
    coordinator.hasFailure
        ? AccountStoreStatus.unavailable
        : AccountStoreStatus.loading,
    generation,
  );
});
