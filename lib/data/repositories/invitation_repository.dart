import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Only server RPCs grant or revoke invitations. Raw tokens remain transient.
abstract interface class InvitationGateway {
  bool get emailVerified;
  Future<Object?> rpc(String name, Map<String, Object?> params);
  Future<List<Map<String, Object?>>> select(
    String table,
    String fields,
    String planId,
  );
}

final class IssuedInvite {
  const IssuedInvite({
    required this.id,
    required this.expiresAt,
    required this.token,
  });
  final String id;
  final DateTime expiresAt;
  final String token;
}

final class InviteMetadata {
  const InviteMetadata({
    required this.id,
    required this.expiresAt,
    required this.acceptedAt,
    required this.revokedAt,
  });
  final String id;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
}

final class PairingEligibility {
  const PairingEligibility({required this.isActive, required this.memberCount});
  final bool isActive;
  final int memberCount;
}

abstract interface class InvitationRepository {
  Future<PairingEligibility> pairingEligibility(String planId);
  Future<List<InviteMetadata>> listInvites(String planId);
  Future<IssuedInvite> issueInvite(String planId);
  Future<void> revokeInvite(String inviteId);
}

final class SupabaseInvitationRepository implements InvitationRepository {
  const SupabaseInvitationRepository(this.gateway);
  final InvitationGateway gateway;

  @override
  Future<PairingEligibility> pairingEligibility(String planId) async {
    final plans = await gateway.select('plans', 'is_active', planId);
    if (plans.length != 1 || plans.single['is_active'] is! bool) {
      throw const FormatException('Plan access unavailable');
    }
    final members = await gateway.select('plan_members', 'user_id', planId);
    return PairingEligibility(
      isActive: plans.single['is_active']! as bool,
      memberCount: members.length,
    );
  }

  @override
  Future<List<InviteMetadata>> listInvites(String planId) async {
    final rows = await gateway.select(
      'invites',
      'id,expires_at,accepted_at,revoked_at',
      planId,
    );
    return rows.map((row) {
      final id = row['id'];
      final expiry = _requiredDate(row['expires_at']);
      if (id is! String || id.isEmpty) {
        throw const FormatException('Invalid invitation metadata');
      }
      return InviteMetadata(
        id: id,
        expiresAt: expiry,
        acceptedAt: _optionalDate(row['accepted_at']),
        revokedAt: _optionalDate(row['revoked_at']),
      );
    }).toList();
  }

  static DateTime _requiredDate(Object? raw) {
    final date = raw is String ? DateTime.tryParse(raw) : null;
    if (date == null) {
      throw const FormatException('Invalid invitation metadata');
    }
    return date;
  }

  static DateTime? _optionalDate(Object? raw) =>
      raw == null ? null : _requiredDate(raw);

  @override
  Future<void> revokeInvite(String inviteId) async {
    final response = await gateway.rpc('revoke_invite', {
      'p_invite_id': inviteId,
    });
    if (response is! Map ||
        response['id'] != inviteId ||
        response['revoked'] != true) {
      throw const FormatException('Invalid revoke response');
    }
  }

  @override
  Future<IssuedInvite> issueInvite(String planId) async {
    if (!gateway.emailVerified) throw StateError('Verified email required');
    final response = await gateway.rpc('issue_invite', {'p_plan_id': planId});
    if (response is! Map) throw const FormatException('Invalid issue response');
    final id = response['id'];
    final rawExpiry = response['expires_at'];
    final token = response['token'];
    final expiry = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
    if (id is! String ||
        id.isEmpty ||
        expiry == null ||
        token is! String ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(token)) {
      throw const FormatException('Invalid issue response');
    }
    return IssuedInvite(id: id, expiresAt: expiry, token: token);
  }
}

final class SupabaseInvitationGateway implements InvitationGateway {
  const SupabaseInvitationGateway(this.client);
  final SupabaseClient client;

  @override
  bool get emailVerified => client.auth.currentUser?.emailConfirmedAt != null;

  @override
  Future<Object?> rpc(String name, Map<String, Object?> params) =>
      client.rpc<Object?>(name, params: params);

  @override
  Future<List<Map<String, Object?>>> select(
    String table,
    String fields,
    String planId,
  ) async {
    final filter = table == 'plans' ? 'id' : 'plan_id';
    final rows = await client.from(table).select(fields).eq(filter, planId);
    return rows.map(Map<String, Object?>.from).toList();
  }
}

final invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => SupabaseInvitationRepository(
    SupabaseInvitationGateway(Supabase.instance.client),
  ),
);
