import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/data/repositories/plan_membership_repository.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';

/// The custom-scheme link and pasted link enter the same server acceptance path.
/// No unowned HTTPS host is treated as an invitation (OQ-09).
String? parseInviteLink(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      uri.scheme != 'kasaran' ||
      uri.host != 'accept' ||
      uri.pathSegments.length != 1) {
    return null;
  }
  final token = uri.pathSegments.single;
  return RegExp(r'^[0-9a-f]{32}$').hasMatch(token) ? token : null;
}

class Scr02InviteAcceptance extends ConsumerStatefulWidget {
  const Scr02InviteAcceptance({required this.token, super.key});

  /// Raw token is held transiently for RPC only, never shown or logged.
  final String token;

  @override
  ConsumerState<Scr02InviteAcceptance> createState() =>
      _InviteAcceptanceState();
}

class _InviteAcceptanceState extends ConsumerState<Scr02InviteAcceptance> {
  final _pastedLink = TextEditingController();
  bool _submitting = false;
  bool _joined = false;
  String? _error;

  @override
  void dispose() {
    _pastedLink.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_submitting || _joined) return;
    final token = widget.token.isNotEmpty
        ? parseInviteLink('kasaran://accept/${widget.token}')
        : parseInviteLink(_pastedLink.text);
    if (token == null) {
      setState(() => _error = 'Enter a valid Kasaran invitation link.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(planMembershipRepositoryProvider).acceptInvite(token);
      _pastedLink.clear();
      ref.invalidate(currentPlanIdProvider);
      if (mounted) setState(() => _joined = true);
    } on InviteAcceptanceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not join. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SCR-02')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Join my partner’s plan'),
            if (auth != AuthState.authenticated)
              Text(
                auth == AuthState.unverified
                    ? 'Verify your email before accepting this invitation.'
                    : 'Sign in before accepting this invitation. Reopen the link after sign-in.',
              ),
            if (auth == AuthState.authenticated && !_joined) ...[
              if (widget.token.isEmpty)
                TextField(
                  controller: _pastedLink,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Invitation link',
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: _submitting ? null : _accept,
                child: const Text('Accept invitation'),
              ),
            ],
            if (_joined) const Text('You joined your partner’s plan.'),
          ],
        ),
      ),
    );
  }
}
