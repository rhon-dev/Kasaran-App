import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/data/repositories/local_plan_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';
import 'package:kasaran/ui/providers/account_store_provider.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/sync_runtime_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, Supabase;

enum PlanAccess { loading, none, member, error }

// ignore: one_member_abstracts
abstract interface class PlanMembershipLookup {
  Future<String?> currentPlanId();
}

final class SupabasePlanMembershipLookup implements PlanMembershipLookup {
  const SupabasePlanMembershipLookup(this.client);
  final SupabaseClient client;

  @override
  Future<String?> currentPlanId() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Signed-in account required');
    final row = await client
        .from('plan_members')
        .select('plan_id')
        .eq('user_id', uid)
        .maybeSingle();
    return row?['plan_id'] as String?;
  }
}

final planMembershipLookupProvider = Provider<PlanMembershipLookup>(
  (ref) => SupabasePlanMembershipLookup(Supabase.instance.client),
);

// Local-only injectable seam, deliberately separate from server discovery.
// ignore: one_member_abstracts
abstract interface class LocalPlanLookup {
  Future<String?> currentPlanId();
}

final class _EncryptedLocalPlanLookup implements LocalPlanLookup {
  const _EncryptedLocalPlanLookup(this.coordinator);
  final AccountStoreCoordinator coordinator;
  @override
  Future<String?> currentPlanId() async =>
      (await LocalPlanRepository(coordinator).currentActivePlan())?.plan.id;
}

final localPlanLookupProvider = Provider<LocalPlanLookup>((ref) {
  final coordinator = ref.watch(accountStoreCoordinatorProvider);
  if (coordinator == null) throw StateError('Account unavailable');
  return _EncryptedLocalPlanLookup(coordinator);
});

typedef _PlanReadKey = (AccountStoreCoordinator?, int, String);
_PlanReadKey? _planReadKey(Ref ref) {
  ref.watch(syncRuntimeRevisionProvider);
  final account = ref.watch(accountStoreStateProvider);
  if (!account.isReady) return null;
  final userId = ref.watch(authUserIdProvider);
  if (ref.watch(authStateProvider) != AuthState.authenticated ||
      userId == null) {
    return null;
  }
  final coordinator = ref.watch(accountStoreCoordinatorProvider);
  if (coordinator != null && !coordinator.isReady) return null;
  return (coordinator, account.generation, userId);
}

final _planReadsProvider = FutureProvider.autoDispose
    .family<String?, _PlanReadKey>((ref, key) async {
      ref.watch(syncRuntimeRevisionProvider);
      final coordinator = key.$1;
      final marker = coordinator?.identity.capture()?.marker;
      final result = await ref.watch(localPlanLookupProvider).currentPlanId();
      if (!ref.mounted) throw StateError('Account changed');
      final current = ref.read(accountStoreStateProvider);
      if (!current.isReady ||
          current.generation != key.$2 ||
          ref.read(authUserIdProvider) != key.$3 ||
          coordinator != null &&
              (!coordinator.isReady ||
                  !identical(coordinator.identity.capture()?.marker, marker))) {
        throw StateError('Account changed');
      }
      return result;
    });

/// Finite encrypted-local reads; generation-keyed to drop previous-account IDs.
/// The public AsyncValue never retains a previous generation during loading.
final currentPlanIdProvider = Provider<AsyncValue<String?>>((ref) {
  final key = _planReadKey(ref);
  return key == null
      ? const AsyncData(null)
      : ref.watch(_planReadsProvider(key));
});
final currentPlanIdFutureProvider = Provider<Future<String?>>((ref) {
  final key = _planReadKey(ref);
  return key == null
      ? Future.value()
      : ref.watch(_planReadsProvider(key).future);
});

final planAccessProvider = Provider<PlanAccess>((ref) {
  if (ref.watch(authStateProvider) != AuthState.authenticated) {
    return PlanAccess.none;
  }
  final account = ref.watch(accountStoreStateProvider);
  if (!account.isReady) {
    return account.status == AccountStoreStatus.loading
        ? PlanAccess.loading
        : PlanAccess.error;
  }
  if (ref.watch(authUserIdProvider) == null) {
    final identity = ref.watch(authIdentityStateProvider);
    return identity.hasError ? PlanAccess.error : PlanAccess.loading;
  }
  final lookup = ref.watch(currentPlanIdProvider);
  if (lookup.isLoading) return PlanAccess.loading;
  if (lookup.hasError) return PlanAccess.error;
  if (!lookup.hasValue) return PlanAccess.loading;
  final status = ref.watch(syncHostStatusProvider);
  if (status == AccountSyncHostStatus.error ||
      status == AccountSyncHostStatus.updateRequired) {
    return PlanAccess.error;
  }
  if (lookup.requireValue != null) return PlanAccess.member;
  // Fresh encrypted metadata has no persisted authoritative-empty marker.
  return status == AccountSyncHostStatus.none
      ? PlanAccess.none
      : PlanAccess.loading;
});
