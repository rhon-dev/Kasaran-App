// SCR-02 Invite Acceptance — phase 03 placeholder.
// Receives [token] from the deep-link route parameter.
// Phase 06 replaces this with the real invite acceptance flow.
import 'package:flutter/material.dart';
import 'package:kasaran/ui/screens/placeholder_screen.dart';

class Scr02InviteAcceptance extends StatelessWidget {
  const Scr02InviteAcceptance({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        screenId: 'SCR-02',
        screenName: 'Invite Acceptance (token: $token)',
      );
}
