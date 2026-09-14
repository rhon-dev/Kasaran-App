// SCR-08 Expense Editor — phase 03 placeholder.
// Receives an optional [entryId] for edit mode (null = new entry).
import 'package:flutter/material.dart';
import 'package:kasaran/ui/screens/placeholder_screen.dart';

class Scr08ExpenseEditor extends StatelessWidget {
  const Scr08ExpenseEditor({this.entryId, super.key});

  final String? entryId;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        screenId: 'SCR-08',
        screenName: entryId != null
            ? 'Expense Editor (edit: $entryId)'
            : 'Expense Editor (new)',
      );
}
