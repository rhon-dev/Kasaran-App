// SCR-11 Explain Figure — phase 03 placeholder.
// Receives [figureKey] identifying which allocation figure to explain.
import 'package:flutter/material.dart';
import 'package:kasaran/ui/screens/placeholder_screen.dart';

class Scr11ExplainFigure extends StatelessWidget {
  const Scr11ExplainFigure({required this.figureKey, super.key});

  final String figureKey;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        screenId: 'SCR-11',
        screenName: 'Explain Figure ($figureKey)',
      );
}
