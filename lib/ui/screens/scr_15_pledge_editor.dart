// SCR-15 Pledge Editor — phase 03 placeholder.
// Receives optional [pledgeId] for edit mode (null = new pledge).
import 'package:flutter/material.dart';
import 'package:kasaran/ui/screens/placeholder_screen.dart';

class Scr15PledgeEditor extends StatelessWidget {
  const Scr15PledgeEditor({this.pledgeId, super.key});

  final String? pledgeId;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        screenId: 'SCR-15',
        screenName: pledgeId != null
            ? 'Pledge Editor (edit: $pledgeId)'
            : 'Pledge Editor (new)',
      );
}
