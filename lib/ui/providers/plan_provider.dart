import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  if (ref.watch(authStateProvider) != AuthState.authenticated) return null;
  return ref.watch(planMembershipLookupProvider).currentPlanId();
});

final planAccessProvider = Provider<PlanAccess>((ref) {
  if (ref.watch(authStateProvider) != AuthState.authenticated) {
    return PlanAccess.none;
  }
  final lookup = ref.watch(currentPlanIdProvider);
  if (lookup.hasError) return PlanAccess.error;
  if (!lookup.hasValue) return PlanAccess.loading;
  return lookup.requireValue == null ? PlanAccess.none : PlanAccess.member;
});
