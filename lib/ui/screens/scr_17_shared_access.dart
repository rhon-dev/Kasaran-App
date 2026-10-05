import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/data/repositories/invitation_repository.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';

final class _InvitationOverview {
  const _InvitationOverview(this.eligibility, this.invites);
  final PairingEligibility eligibility;
  final List<InviteMetadata> invites;
}

final _invitationOverviewProvider = FutureProvider.autoDispose
    .family<_InvitationOverview, String>((ref, planId) async {
      final repository = ref.watch(invitationRepositoryProvider);
      final eligibility = await repository.pairingEligibility(planId);
      final invites = await repository.listInvites(planId);
      return _InvitationOverview(eligibility, invites);
    });

/// Phase 06 invitation controls only; lifecycle actions arrive in Phase 16.
class Scr17SharedAccess extends ConsumerStatefulWidget {
  const Scr17SharedAccess({super.key});

  @override
  ConsumerState<Scr17SharedAccess> createState() => _Scr17SharedAccessState();
}

class _Scr17SharedAccessState extends ConsumerState<Scr17SharedAccess> {
  bool _busy = false;
  int _authEpoch = 0;
  int _planEpoch = 0;
  String? _issuedLink;
  String? _issuedId;
  String? _issuedPlanId;
  String? _error;

  Future<void> _issue(String planId) async {
    if (_busy) return;
    final userId = ref.read(authUserIdProvider);
    if (userId == null) return;
    final authEpoch = _authEpoch;
    final planEpoch = _planEpoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final issued = await ref
          .read(invitationRepositoryProvider)
          .issueInvite(planId);
      if (!mounted) return;
      final currentPlan = ref.read(currentPlanIdProvider);
      if (authEpoch != _authEpoch ||
          planEpoch != _planEpoch ||
          ref.read(authStateProvider) != AuthState.authenticated ||
          ref.read(authUserIdProvider) != userId ||
          !currentPlan.hasValue ||
          currentPlan.requireValue != planId) {
        return;
      }
      setState(() {
        _issuedId = issued.id;
        _issuedPlanId = planId;
        _issuedLink = 'kasaran://accept/${issued.token}';
      });
      ref.invalidate(_invitationOverviewProvider(planId));
    } catch (_) {
      if (mounted &&
          authEpoch == _authEpoch &&
          planEpoch == _planEpoch &&
          ref.read(authUserIdProvider) == userId) {
        setState(
          () => _error = 'Could not issue invitation. Reconnect and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(String planId, String inviteId) async {
    if (_busy) return;
    final userId = ref.read(authUserIdProvider);
    if (userId == null) return;
    final authEpoch = _authEpoch;
    final planEpoch = _planEpoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(invitationRepositoryProvider).revokeInvite(inviteId);
      if (!mounted ||
          authEpoch != _authEpoch ||
          planEpoch != _planEpoch ||
          ref.read(authUserIdProvider) != userId ||
          ref.read(authStateProvider) != AuthState.authenticated) {
        return;
      }
      setState(() {
        if (_issuedId == inviteId) {
          _issuedId = null;
          _issuedPlanId = null;
          _issuedLink = null;
        }
      });
      ref.invalidate(_invitationOverviewProvider(planId));
    } catch (_) {
      if (mounted &&
          authEpoch == _authEpoch &&
          planEpoch == _planEpoch &&
          ref.read(authUserIdProvider) == userId) {
        setState(
          () => _error = 'Could not revoke invitation. Reconnect and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authUserIdProvider, (previous, next) {
      if (previous != next && mounted) {
        _authEpoch++;
        setState(() {
          _issuedId = null;
          _issuedPlanId = null;
          _issuedLink = null;
          _error = null;
        });
      }
    });
    ref.listen(authStateProvider, (_, next) {
      if (next != AuthState.authenticated && mounted) {
        _authEpoch++;
        setState(() {
          _issuedId = null;
          _issuedPlanId = null;
          _issuedLink = null;
        });
      }
    });
    ref.listen(currentPlanIdProvider, (_, next) {
      _planEpoch++;
      if (_issuedPlanId != null &&
          (!next.hasValue || next.requireValue != _issuedPlanId) &&
          mounted) {
        setState(() {
          _issuedId = null;
          _issuedPlanId = null;
          _issuedLink = null;
        });
      }
    });
    final auth = ref.watch(authStateProvider);
    final userId = ref.watch(authUserIdProvider);
    final plan = ref.watch(currentPlanIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SCR-17 · Shared Access')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (plan) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError() => _retryPlan(),
          AsyncData(value: final planId) =>
            planId == null || auth != AuthState.authenticated || userId == null
                ? const Text('No active plan is available for invitations.')
                : _invitationBlock(planId),
        },
      ),
    );
  }

  Widget _retryPlan() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Your plan could not be checked. Reconnect and retry.'),
      TextButton(
        onPressed: () => ref.invalidate(currentPlanIdProvider),
        child: const Text('Retry'),
      ),
    ],
  );

  Widget _invitationBlock(String planId) {
    final overview = ref.watch(_invitationOverviewProvider(planId));
    final issuedLink = _issuedLink;
    final issuedId = _issuedId;
    return ListView(
      children: [
        if (issuedLink != null) ...[
          const Text(
            'Copy this invitation link now. It will not be shown after you leave. Copied text may remain in OS clipboard history.',
          ),
          SelectableText(issuedLink),
          if (issuedId != null)
            TextButton(
              onPressed: _busy ? null : () => _revoke(planId, issuedId),
              child: const Text('Revoke invitation'),
            ),
        ],
        if (_error != null) Text(_error!),
        ...switch (overview) {
          AsyncLoading() => [const Center(child: CircularProgressIndicator())],
          AsyncError() => [
            const Text(
              'Invitations could not be checked. Reconnect and retry.',
            ),
            TextButton(
              onPressed: () =>
                  ref.invalidate(_invitationOverviewProvider(planId)),
              child: const Text('Retry'),
            ),
          ],
          AsyncData(value: final data) => [
            const Text('Invite your partner'),
            if (data.eligibility.isActive && data.eligibility.memberCount == 1)
              FilledButton(
                onPressed: _busy ? null : () => _issue(planId),
                child: const Text('Issue invitation'),
              )
            else
              const Text('Invitations are unavailable for this plan.'),
            for (final invite in data.invites)
              if (invite.id != issuedId)
                ListTile(
                  title: Text('Invitation ${invite.id}'),
                  subtitle: Text(
                    invite.acceptedAt != null
                        ? 'Accepted'
                        : invite.revokedAt != null
                        ? 'Revoked'
                        : invite.expiresAt.isBefore(DateTime.now().toUtc())
                        ? 'Expired'
                        : 'Expires ${invite.expiresAt.toUtc().toIso8601String().substring(0, 10)}',
                  ),
                  trailing:
                      invite.acceptedAt == null &&
                          invite.revokedAt == null &&
                          invite.expiresAt.isAfter(DateTime.now().toUtc())
                      ? TextButton(
                          key: Key('revoke-${invite.id}'),
                          onPressed: _busy
                              ? null
                              : () => _revoke(planId, invite.id),
                          child: const Text('Revoke'),
                        )
                      : null,
                ),
          ],
        },
        const Text(
          'Partner removal, transfer, and plan deletion are not available yet.',
        ),
      ],
    );
  }
}
