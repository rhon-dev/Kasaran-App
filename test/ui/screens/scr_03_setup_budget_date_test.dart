import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/setup_draft_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';
import 'package:kasaran/ui/screens/scr_03_setup_budget_date.dart';
import 'package:kasaran/ui/screens/scr_04_setup_guest_region.dart';

final _user = NotifierProvider<_User, String>(_User.new);

class _User extends Notifier<String> {
  @override
  String build() => 'A';
  set value(String next) => state = next;
}

ProviderContainer _container({bool mutableUser = false}) {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWithValue(AuthState.authenticated),
      if (mutableUser)
        authUserIdProvider.overrideWith((ref) => ref.watch(_user))
      else
        authUserIdProvider.overrideWithValue('A'),
      setupTodayProvider.overrideWithValue(DateTime(2027, 1, 2)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpForm(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scr03SetupBudgetDate()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _input(WidgetTester tester, String budget, String date) async {
  await tester.enterText(find.byKey(const Key('setup-budget')), budget);
  await tester.enterText(find.byKey(const Key('setup-date')), date);
  await tester.tap(find.byKey(const Key('setup-next')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invalid budget names its field and retains valid date', (
    tester,
  ) async {
    final container = _container();
    await _pumpForm(tester, container);
    await _input(tester, 'abc', '2028-02-29');
    expect(
      find.text('Total budget must be a valid peso amount.'),
      findsOneWidget,
    );
    expect(container.read(setupDraftProvider).dateInput, '2028-02-29');
    expect(find.text('2028-02-29'), findsOneWidget);
  });

  testWidgets('zero and negative budget have distinct inline reasons', (
    tester,
  ) async {
    final container = _container();
    await _pumpForm(tester, container);
    await _input(tester, '0', '2028-02-29');
    expect(
      find.text('Total budget must be greater than zero.'),
      findsOneWidget,
    );
    await _input(tester, '-5000', '2028-02-29');
    expect(find.text('Total budget cannot be negative.'), findsOneWidget);
  });

  testWidgets('invalid calendar date retains budget without a plan', (
    tester,
  ) async {
    final container = _container();
    await _pumpForm(tester, container);
    await _input(tester, '₱28,000.00', '2027-02-29');
    expect(find.text('Enter a valid wedding date.'), findsOneWidget);
    expect(container.read(setupDraftProvider).budgetInput, '₱28,000.00');
    expect(find.textContaining('No plan has been created.'), findsOneWidget);
  });

  testWidgets('declining a past date restores the previously accepted date', (
    tester,
  ) async {
    final container = _container();
    container.read(setupDraftProvider.notifier).acceptDate('2028-05-06');
    await _pumpForm(tester, container);
    await _input(tester, '₱28,000.00', '2027-01-01');
    expect(find.textContaining('2027-01-01'), findsWidgets);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('setup-date')))
          .controller!
          .text,
      '2028-05-06',
    );
    expect(container.read(setupDraftProvider).budgetInput, '₱28,000.00');
  });

  testWidgets(
    'valid high budget advances to unfinished SCR-04 without Supabase',
    (tester) async {
      final container = _container();
      final router = GoRouter(
        initialLocation: Routes.onboardingBudgetDate,
        routes: [
          GoRoute(
            path: Routes.onboardingBudgetDate,
            builder: (_, _) => const Scr03SetupBudgetDate(),
          ),
          GoRoute(
            path: '/onboarding/budget-date/guest-region',
            builder: (_, _) => const Scr04SetupGuestRegion(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await _input(tester, '₱500,001.00', '2028-02-29');
      expect(find.textContaining('no plan has been created'), findsOneWidget);
      expect(container.read(setupDraftProvider).acceptedDate, '2028-02-29');
      await tester.tap(find.text('Back to budget & date'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('setup-budget')))
            .controller!
            .text,
        '₱500,001.00',
      );
    },
  );

  testWidgets(
    'mounted A-B-A clears visible input and stale past-date confirmation',
    (tester) async {
      final container = _container(mutableUser: true);
      await _pumpForm(tester, container);
      await _input(tester, '123', '2027-01-01');
      expect(find.text('Past wedding date'), findsOneWidget);
      container.read(_user.notifier).value = 'B';
      await tester.pump();
      expect(find.textContaining('2027-01-01'), findsNothing);
      container.read(_user.notifier).value = 'A';
      await tester.pump();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(container.read(setupDraftProvider).acceptedDate, isNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('setup-budget')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('setup-date')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );
}
