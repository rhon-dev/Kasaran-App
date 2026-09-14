// ui/screens/placeholder_screen.dart
//
// Reusable placeholder widget used by every SCR-01..SCR-19 screen in phase 03.
// Each real screen replaces its call to this with its actual implementation
// in the relevant feature phase.

import 'package:flutter/material.dart';

/// A minimal scaffold that displays [screenId] and [screenName].
///
/// Used exclusively in phase 03 as a route target. Every feature phase that
/// implements a real screen replaces this widget in that screen's file.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.screenId,
    required this.screenName,
    super.key,
  });

  /// e.g. 'SCR-01'
  final String screenId;

  /// e.g. 'Sign In / Sign Up'
  final String screenName;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(screenId),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                screenId,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                screenName,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
