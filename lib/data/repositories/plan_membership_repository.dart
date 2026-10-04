import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// No membership is granted by client code: the authenticated, verified RPC
/// validates the invite and performs the server transaction.
// ignore: one_member_abstracts
abstract interface class PlanMembershipRepository {
  Future<void> acceptInvite(String token);
}

final class SupabasePlanMembershipRepository
    implements PlanMembershipRepository {
  const SupabasePlanMembershipRepository(this.client);
  final SupabaseClient client;

  @override
  Future<void> acceptInvite(String token) async {
    if (client.auth.currentUser?.emailConfirmedAt == null) {
      throw const InviteAcceptanceException(
        'Verify your email before joining.',
      );
    }
    try {
      await client.rpc<Object?>('accept_invite', params: {'p_token': token});
    } on PostgrestException catch (error) {
      final description = error.message.toLowerCase();
      if (description.contains('expired')) {
        throw const InviteAcceptanceException('This invitation has expired.');
      }
      if (description.contains('revoked')) {
        throw const InviteAcceptanceException('This invitation was revoked.');
      }
      if (description.contains('used') || description.contains('accepted')) {
        throw const InviteAcceptanceException(
          'This invitation was already used.',
        );
      }
      throw const InviteAcceptanceException(
        'This invitation could not be accepted.',
      );
    }
  }
}

final class InviteAcceptanceException implements Exception {
  const InviteAcceptanceException(this.message);
  final String message;
}

final planMembershipRepositoryProvider = Provider<PlanMembershipRepository>(
  (ref) => SupabasePlanMembershipRepository(Supabase.instance.client),
);
