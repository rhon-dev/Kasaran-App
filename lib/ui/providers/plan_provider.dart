import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/ui/providers/account_store_provider.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
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

/// A failed network read is not proof that the account has no plan.
final currentPlanIdProvider = FutureProvider<String?>((ref) async {
  final account = ref.watch(accountStoreStateProvider);
  if (!account.isReady) return null;
  final userId = ref.watch(authUserIdProvider);
  if (ref.watch(authStateProvider) != AuthState.authenticated ||
      userId == null) {
    return null;
  }
  final coordinator = ref.read(accountStoreCoordinatorProvider);
  if (coordinator != null && !coordinator.isReady) return null;
  final result = await ref.watch(planMembershipLookupProvider).currentPlanId();
  // Dispose/invalidating a future is not enough: reject the stale result at
  // its source, including same-user session replacement and A->B->A.
  if (!ref.mounted) throw StateError('Account changed');
  final current = ref.read(accountStoreStateProvider);
  if (!current.isReady ||
      current.generation != account.generation ||
      coordinator != null && !coordinator.isReady ||
      ref.read(authUserIdProvider) != userId) {
    throw StateError('Account changed');
  }
  return result;
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
  return lookup.requireValue == null ? PlanAccess.none : PlanAccess.member;
});
