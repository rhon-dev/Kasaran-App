import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kasaran/data/repositories/invitation_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Gateway implements InvitationGateway {
  String? lastRpc;
  Map<String, Object?>? lastParams;
  Object? response;
  bool verified = true;
  final rows = <String, List<Map<String, Object?>>>{};
  final columns = <String, String>{};

  @override
  bool get emailVerified => verified;

  @override
  Future<Object?> rpc(String name, Map<String, Object?> params) async {
    lastRpc = name;
    lastParams = params;
    return response;
  }

  @override
  Future<List<Map<String, Object?>>> select(
    String table,
    String fields,
    String planId,
  ) async {
    columns[table] = fields;
    return rows[table] ?? [];
  }
}

class _FakeRepository implements InvitationRepository {
  @override
  Future<PairingEligibility> pairingEligibility(String planId) async =>
      const PairingEligibility(isActive: true, memberCount: 1);

  @override
  Future<List<InviteMetadata>> listInvites(String planId) async => [];

  @override
  Future<IssuedInvite> issueInvite(String planId) async => IssuedInvite(
    id: 'invite-1',
    expiresAt: DateTime.utc(2026, 10, 11),
    token: List.filled(32, 'a').join(),
  );

  @override
  Future<void> revokeInvite(String inviteId) async {}
}

void main() {
  test('widget scope can inject invitation repository', () {
    final fake = _FakeRepository();
    final container = ProviderContainer(
      overrides: [invitationRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    expect(container.read(invitationRepositoryProvider), same(fake));
  });

  test('issue parses a one-time server response', () async {
    final gateway = _Gateway()
      ..response = {
        'id': 'synthetic-invite',
        'expires_at': '2026-10-11T00:00:00Z',
        'token': List.filled(32, 'a').join(),
      };
    final repository = SupabaseInvitationRepository(gateway);
    final result = await repository.issueInvite('synthetic-plan');
    expect(result.id, 'synthetic-invite');
    expect(result.expiresAt, DateTime.utc(2026, 10, 11));
    expect(result.token, List.filled(32, 'a').join());
    expect(gateway.lastRpc, 'issue_invite');
    expect(gateway.lastParams, {'p_plan_id': 'synthetic-plan'});
  });

  test(
    'metadata list excludes token hash and parses server timestamps',
    () async {
      final gateway = _Gateway()
        ..rows['invites'] = [
          {
            'id': 'invite-1',
            'expires_at': '2026-10-11T00:00:00Z',
            'accepted_at': null,
            'revoked_at': null,
          },
        ];
      final invites = await SupabaseInvitationRepository(
        gateway,
      ).listInvites('synthetic-plan');
      expect(invites.single.id, 'invite-1');
      expect(invites.single.expiresAt, DateTime.utc(2026, 10, 11));
      expect(invites.single.acceptedAt, isNull);
      expect(gateway.columns['invites'], isNot(contains('token_hash')));
      expect(gateway.columns['invites'], contains('expires_at'));
    },
  );

  test('eligibility reads active plan and member count', () async {
    final gateway = _Gateway()
      ..rows['plans'] = [
        {'is_active': true},
      ]
      ..rows['plan_members'] = [
        {'user_id': 'creator'},
      ];
    final eligibility = await SupabaseInvitationRepository(
      gateway,
    ).pairingEligibility('synthetic-plan');
    expect(eligibility.isActive, isTrue);
    expect(eligibility.memberCount, 1);
    expect(gateway.columns['plans'], contains('is_active'));
    expect(gateway.columns['plan_members'], contains('user_id'));
  });

  test('revoke forwards only invitation ID to server', () async {
    final gateway = _Gateway()..response = {'id': 'invite-1', 'revoked': true};
    await SupabaseInvitationRepository(gateway).revokeInvite('invite-1');
    expect(gateway.lastRpc, 'revoke_invite');
    expect(gateway.lastParams, {'p_invite_id': 'invite-1'});
  });

  test('issue rejects missing token without exposing response', () async {
    final gateway = _Gateway()
      ..response = {'id': 'invite-1', 'expires_at': '2026-10-11T00:00:00Z'};
    await expectLater(
      SupabaseInvitationRepository(gateway).issueInvite('synthetic-plan'),
      throwsA(isA<FormatException>()),
    );
  });

  test('unverified account never invokes issue RPC', () async {
    final gateway = _Gateway()..verified = false;
    await expectLater(
      SupabaseInvitationRepository(gateway).issueInvite('synthetic-plan'),
      throwsStateError,
    );
    expect(gateway.lastRpc, isNull);
  });

  test('missing plan is not treated as eligible', () async {
    final gateway = _Gateway();
    await expectLater(
      SupabaseInvitationRepository(
        gateway,
      ).pairingEligibility('synthetic-plan'),
      throwsA(isA<FormatException>()),
    );
  });

  test('revoke rejects unconfirmed server response', () async {
    final gateway = _Gateway()..response = {'revoked': false};
    await expectLater(
      SupabaseInvitationRepository(gateway).revokeInvite('invite-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('plan eligibility query filters plans by primary key', () async {
    Uri? requestUri;
    final client = SupabaseClient(
      'http://localhost:54321',
      'synthetic-anon-key',
      httpClient: MockClient((request) async {
        requestUri = request.url;
        return http.Response(
          '[{"is_active":true}]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final rows = await SupabaseInvitationGateway(
      client,
    ).select('plans', 'is_active', 'synthetic-plan');
    expect(rows.single['is_active'], isTrue);
    expect(requestUri?.queryParameters['id'], 'eq.synthetic-plan');
    expect(requestUri?.queryParameters.containsKey('plan_id'), isFalse);
  });
}
