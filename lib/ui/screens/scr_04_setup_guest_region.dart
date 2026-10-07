import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/ui/router/app_router.dart';

/// SCR-04 remains unfinished until the complete Phase 09 setup workflow.
class Scr04SetupGuestRegion extends StatelessWidget {
  const Scr04SetupGuestRegion({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Setup · Guest Cap & Region')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Step 2 of 3',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Guest cap and region are not available yet. '
                'Your budget and date are a session draft; '
                'no plan has been created.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(Routes.onboardingBudgetDate),
                child: const Text('Back to budget & date'),
              ),
              TextButton(
                onPressed: () => context.go(Routes.signIn),
                child: const Text('Start/Join'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
