import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/ui/providers/setup_draft_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';
import 'package:kasaran/ui/validation/setup_budget_date.dart';

/// SCR-03 only captures a session draft. Plan creation needs SCR-04's inputs.
class Scr03SetupBudgetDate extends ConsumerStatefulWidget {
  const Scr03SetupBudgetDate({super.key});

  @override
  ConsumerState<Scr03SetupBudgetDate> createState() =>
      _Scr03SetupBudgetDateState();
}

class _Scr03SetupBudgetDateState extends ConsumerState<Scr03SetupBudgetDate> {
  late final TextEditingController _budget;
  late final TextEditingController _date;
  String? _budgetError;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(setupDraftProvider);
    _budget = TextEditingController(text: draft.budgetInput);
    _date = TextEditingController(text: draft.dateInput);
  }

  @override
  void dispose() {
    _budget.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final draft = ref.read(setupDraftProvider);
    if (draft.ownerId == null) return;
    int? cents;
    DateTime? date;
    String? budgetError;
    String? dateError;
    try {
      cents = parseBudgetInput(_budget.text);
    } on FormatException catch (error) {
      budgetError = error.message;
    }
    try {
      date = parseWeddingDate(_date.text);
    } on FormatException catch (error) {
      dateError = error.message;
    }
    setState(() {
      _budgetError = budgetError;
      _dateError = dateError;
    });
    if (budgetError != null ||
        dateError != null ||
        cents == null ||
        date == null) {
      return;
    }
    if (isPastWeddingDate(date, ref.read(setupTodayProvider))) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Past wedding date'),
          content: Text(
            'Your wedding date is ${_date.text}. Continue with this date?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      // A->B->A may have the same account ID but a different draft instance.
      if (!mounted || !identical(ref.read(setupDraftProvider), draft)) return;
      if (accepted != true) {
        ref.read(setupDraftProvider.notifier).restoreDate();
        return;
      }
    }
    if (!mounted || !identical(ref.read(setupDraftProvider), draft)) return;
    ref.read(setupDraftProvider.notifier).acceptDate(_date.text);
    context.go(Routes.onboardingGuestRegion);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(setupDraftProvider, (_, next) {
      if (_budget.text != next.budgetInput) _budget.text = next.budgetInput;
      if (_date.text != next.dateInput) _date.text = next.dateInput;
    });
    final draft = ref.watch(setupDraftProvider);
    if (draft.ownerId == null) {
      return const Scaffold(
        body: Center(child: Text('Checking account identity…')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Setup · Budget & Date')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Step 1 of 3',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Budget and wedding date',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Draft for this session only. No plan has been created.',
                  key: Key('setup-notice'),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('setup-budget'),
                  controller: _budget,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Total budget',
                    hintText: '₱350,000.00',
                    errorText: _budgetError,
                  ),
                  onChanged: (value) {
                    ref.read(setupDraftProvider.notifier).setBudget(value);
                    if (_budgetError != null) {
                      setState(() => _budgetError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('setup-date'),
                  controller: _date,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Wedding date',
                    hintText: 'YYYY-MM-DD',
                    errorText: _dateError,
                  ),
                  onChanged: (value) {
                    ref.read(setupDraftProvider.notifier).setDate(value);
                    if (_dateError != null) setState(() => _dateError = null);
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('setup-next'),
                  onPressed: _next,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
