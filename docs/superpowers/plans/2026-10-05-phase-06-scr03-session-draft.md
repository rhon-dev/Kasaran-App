# Phase 06 SCR-03 Session Draft Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the SCR-03 placeholder with a validated budget/date draft that survives navigation for one verified account, without creating or persisting a plan.

**Architecture:** A pure form-input validator handles strict peso/date parsing. A non-auto-disposed Riverpod notifier owns raw inputs and the last accepted date; watching Auth status and the account ID resets it whenever identity becomes unknown or changes. SCR-03 reads/writes this notifier and navigates to a visibly unfinished SCR-04; the production router keeps member/unknown-identity gates.

**Tech Stack:** Flutter, Dart integer centavos, Riverpod, go_router, flutter_test. Authority: `docs/superpowers/specs/2026-10-05-phase-06-scr03-session-draft-design.md`, ADR-75, REQ-BS-1–3, REQ-GEN-1/2.

## Global Constraints

- Budget/date are only a session draft: no Supabase `create_plan`, local DB/preference writes, setup completion, allocation, fee prompts or invitation.
- Use integer centavos and `fullForm` for any displayed money; never use `double` for monetary values. Reuse `parsePesosToC` only after full-input validation.
- Accept valid ISO `YYYY-MM-DD` calendar dates; past dates require confirmation against an injected device-local today. A declined confirmation restores the prior accepted date.
- Clear raw fields on sign-out, unknown/loading/errored identity, and direct verified A→B→A account switches. No per-user family cache may resurrect an old draft.
- No arbitrary ₱30K–₱500K budget block or product-imposed year range. Restrict integer centavos to signed 64-bit storage range.
- Keep existing membership/loading/error route guards. Change only onboarding path constants needed to match actual nested routes.
- Synthetic local results are not CI, staging, iOS/device, counsel or real-user evidence. If starting local Supabase, stop with plain `supabase stop` to preserve volumes.

## File map

- `lib/ui/validation/setup_budget_date.dart`: strict form parsers and date-only comparison (no widgets, I/O or account state).
- `test/ui/validation/setup_budget_date_test.dart`: centavo/format/date edge cases.
- `lib/ui/providers/setup_draft_provider.dart`: identity-owned in-memory state and injectable local today.
- `test/ui/providers/setup_draft_provider_test.dart`: same-account retention and identity reset regressions.
- `lib/ui/screens/scr_03_setup_budget_date.dart`: form, inline errors, past-date dialog and forward action.
- `lib/ui/screens/scr_04_setup_guest_region.dart`: honest unfinished step with Back/Start actions, not a guest-cap form.
- `lib/ui/router/app_router.dart`: correct both onboarding route constants to actual nested paths.
- `test/ui/screens/scr_03_setup_budget_date_test.dart`, `test/ui/router/app_router_test.dart`: widget and production-router regressions; no initialized Supabase in form-only tests.
- `docs/ux-spec.md`, `docs/development-phases.md`, `docs/testing-plan.md`: mark only executed partial coverage; keep future complete-setup gates open.

---

### Task 1: Strict input parsing and identity-owned draft

**Files:** Create `lib/ui/validation/setup_budget_date.dart`, `lib/ui/providers/setup_draft_provider.dart`, `test/ui/validation/setup_budget_date_test.dart`, `test/ui/providers/setup_draft_provider_test.dart`.

**Interfaces:** `int parseBudgetInput(String raw)`, `DateTime parseWeddingDate(String raw)`, `bool isPastWeddingDate(DateTime selected, DateTime today)` throw `FormatException` with field-specific messages. `setupDraftProvider` exposes `SetupDraft(ownerId, budgetInput, dateInput, acceptedDate)` and `SetupDraftController.setBudget`, `.setDate`, `.acceptDate`, `.restoreDate`. `setupTodayProvider` is a `Provider<DateTime>` for the local date.

- [ ] **Step 1: Write failing validator tests.** Create `test/ui/validation/setup_budget_date_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/ui/validation/setup_budget_date.dart';

void main() {
  test('strict money accepts cents and rounds one third digit', () {
    expect(parseBudgetInput('₱28,000.00'), 2800000);
    expect(parseBudgetInput('500001'), 50000100);
    expect(parseBudgetInput('0.005'), 1);
  });
  test('money errors name the field without a price-band warning', () {
    for (final input in ['abc', '1,20.00', '1.0009']) {
      expect(() => parseBudgetInput(input), throwsFormatException);
    }
    expect(() => parseBudgetInput('0'), throwsFormatException);
    expect(() => parseBudgetInput('-5000'), throwsFormatException);
    expect(() => parseBudgetInput('92233720368547759'), throwsFormatException);
  });
  test('strict leap day and date-only past comparison', () {
    expect(parseWeddingDate('2028-02-29').day, 29);
    expect(() => parseWeddingDate('2027-02-29'), throwsFormatException);
    expect(() => parseWeddingDate('2027-13-01'), throwsFormatException);
    expect(() => parseWeddingDate('not a date'), throwsFormatException);
    expect(isPastWeddingDate(parseWeddingDate('2027-01-01'), DateTime(2027, 1, 2, 0)), isTrue);
    expect(isPastWeddingDate(parseWeddingDate('2027-01-02'), DateTime(2027, 1, 2, 23)), isFalse);
  });
}
```

- [ ] **Step 2: Verify RED.** Run `flutter test --no-pub test/ui/validation/setup_budget_date_test.dart`; expect missing validator import or undefined functions, not a passing suite.

- [ ] **Step 3: Implement the pure validator.** Create `lib/ui/validation/setup_budget_date.dart` with the following behavior (use the complete file below; no extra packages):

```dart
import 'package:kasaran/domain/money/centavos.dart';

final _money = RegExp(r'^(?:₱\s*)?-?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]{1,3})?$');
final _date = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$');
const _maxInt64 = 9223372036854775807;

int parseBudgetInput(String raw) {
  final value = raw.trim();
  if (value.isEmpty) throw const FormatException('Enter a total budget.');
  if (!_money.hasMatch(value)) {
    throw const FormatException('Total budget must be a valid peso amount.');
  }
  final cleaned = value.replaceAll('₱', '').replaceAll(',', '').trim();
  if (cleaned.startsWith('-')) {
    throw const FormatException('Total budget cannot be negative.');
  }
  final parts = cleaned.split('.');
  final fraction = (parts.length == 1 ? '' : parts[1]).padRight(3, '0');
  final magnitude = BigInt.parse(parts[0]) * BigInt.from(100) +
      BigInt.parse(fraction.substring(0, 2)) +
      (int.parse(fraction[2]) >= 5 ? BigInt.one : BigInt.zero);
  if (magnitude == BigInt.zero) {
    throw const FormatException('Total budget must be greater than zero.');
  }
  if (magnitude > BigInt.from(_maxInt64)) {
    throw const FormatException('Total budget is too large.');
  }
  return parsePesosToC(value);
}

DateTime parseWeddingDate(String raw) {
  final match = _date.firstMatch(raw.trim());
  if (match == null) throw const FormatException('Enter a wedding date as YYYY-MM-DD.');
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  if (year == 0) throw const FormatException('Enter a valid wedding date.');
  final value = DateTime.utc(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    throw const FormatException('Enter a valid wedding date.');
  }
  return value;
}

bool isPastWeddingDate(DateTime selected, DateTime today) =>
    DateTime.utc(selected.year, selected.month, selected.day).isBefore(
      DateTime.utc(today.year, today.month, today.day),
    );
```

- [ ] **Step 4: Run `flutter test --no-pub test/ui/validation/setup_budget_date_test.dart`; expect all tests pass.** If the existing centavo parser accepts input that strict regex should reject, add a failing case first, then tighten only the new validator, not the shared parser.

- [ ] **Step 5: Write failing draft reset tests.** Create `test/ui/providers/setup_draft_provider_test.dart` with a mutable identity override; check A→B→A, unknown, and sign-out:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/setup_draft_provider.dart';

final user = NotifierProvider<User, String?>(User.new);
final auth = NotifierProvider<Auth, AuthState>(Auth.new);
class User extends Notifier<String?> {
  @override String? build() => 'A';
  set value(String? next) => state = next;
}
class Auth extends Notifier<AuthState> {
  @override AuthState build() => AuthState.authenticated;
  set value(AuthState next) => state = next;
}
void main() {
  test('same session retains inputs but A-B-A and unknown identity erase them', () {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => ref.watch(auth)),
      authUserIdProvider.overrideWith((ref) => ref.watch(user)),
    ]);
    addTearDown(container.dispose);
    container.read(setupDraftProvider.notifier).setBudget('123');
    container.read(setupDraftProvider.notifier).setDate('2027-05-06');
    expect(container.read(setupDraftProvider).budgetInput, '123');
    container.read(user.notifier).value = 'B';
    expect(container.read(setupDraftProvider).budgetInput, isEmpty);
    container.read(user.notifier).value = 'A';
    expect(container.read(setupDraftProvider).dateInput, isEmpty);
    container.read(setupDraftProvider.notifier).setBudget('456');
    container.read(user.notifier).value = null;
    expect(container.read(setupDraftProvider).budgetInput, isEmpty);
    container.read(user.notifier).value = 'A';
    container.read(setupDraftProvider.notifier).setBudget('789');
    container.read(auth.notifier).value = AuthState.unauthenticated;
    expect(container.read(setupDraftProvider).budgetInput, isEmpty);
  });
  test('decline restores previously accepted date', () {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWithValue(AuthState.authenticated),
      authUserIdProvider.overrideWithValue('A'),
    ]);
    addTearDown(container.dispose);
    container.read(setupDraftProvider.notifier).acceptDate('2027-05-06');
    container.read(setupDraftProvider.notifier).setDate('2026-01-01');
    container.read(setupDraftProvider.notifier).restoreDate();
    expect(container.read(setupDraftProvider).dateInput, '2027-05-06');
  });
}
```

- [ ] **Step 6: Verify RED.** Run `flutter test --no-pub test/ui/providers/setup_draft_provider_test.dart`; expect missing provider/types. Add an error-source regression with a `StreamController<String?>`, overriding `authIdentityStateProvider` with its stream while keeping the real `authUserIdProvider`. Emit `'A'`, await the provider's first value, enter a draft, then `addError(StateError('identity unavailable'))`; after a microtask the error must drive ownerId to null and erase both fields. Close the controller in teardown. Implement `lib/ui/providers/setup_draft_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';

final setupTodayProvider = Provider<DateTime>((ref) => DateTime.now());
class SetupDraft {
  const SetupDraft({this.ownerId, this.budgetInput = '', this.dateInput = '', this.acceptedDate});
  final String? ownerId;
  final String budgetInput;
  final String dateInput;
  final String? acceptedDate;
  SetupDraft copyWith({String? budgetInput, String? dateInput, String? acceptedDate}) =>
      SetupDraft(ownerId: ownerId, budgetInput: budgetInput ?? this.budgetInput,
        dateInput: dateInput ?? this.dateInput, acceptedDate: acceptedDate ?? this.acceptedDate);
}
final setupDraftProvider = NotifierProvider<SetupDraftController, SetupDraft>(SetupDraftController.new);
class SetupDraftController extends Notifier<SetupDraft> {
  @override
  SetupDraft build() {
    final auth = ref.watch(authStateProvider);
    final user = ref.watch(authUserIdProvider);
    return SetupDraft(ownerId: auth == AuthState.authenticated ? user : null);
  }
  void setBudget(String value) {
    if (state.ownerId != null) state = state.copyWith(budgetInput: value);
  }
  void setDate(String value) {
    if (state.ownerId != null) state = state.copyWith(dateInput: value);
  }
  void acceptDate(String value) {
    if (state.ownerId != null) state = state.copyWith(dateInput: value, acceptedDate: value);
  }
  void restoreDate() {
    if (state.ownerId != null) state = state.copyWith(dateInput: state.acceptedDate ?? '');
  }
}
```

- [ ] **Step 7: GREEN + commit.** Run `flutter test --no-pub test/ui/validation/setup_budget_date_test.dart test/ui/providers/setup_draft_provider_test.dart`; `flutter analyze --no-pub` must have no issues. Commit these four files with `git commit -m "feat(setup): validate budget-date session draft"`.

### Task 2: SCR-03 form, unfinished SCR-04, production navigation

**Files:** Replace `lib/ui/screens/scr_03_setup_budget_date.dart`, `lib/ui/screens/scr_04_setup_guest_region.dart`; modify `lib/ui/router/app_router.dart:38-40`; create `test/ui/screens/scr_03_setup_budget_date_test.dart`; extend `test/ui/router/app_router_test.dart`.

**Interfaces:** Consumes Task 1 parsers, `setupDraftProvider`, `setupTodayProvider` and `fullForm(int)`. The SCR-03 controller writes the draft only; `Routes.onboardingGuestRegion` identifies the existing nested route. The original production `_redirect` remains authoritative.

- [ ] **Step 1: Write failing widget tests.** In the new `test/ui/screens/scr_03_setup_budget_date_test.dart`, mount a `ProviderScope` overriding `authStateProvider` to authenticated and `authUserIdProvider` to `'A'`, with no Supabase initialization. Mount `MaterialApp(home: Scr03SetupBudgetDate())` for inline validation and date-dialog assertions. Use keys `setup-budget`, `setup-date`, `setup-next`, `setup-notice`. Include these exact scenarios:

```dart
await tester.enterText(find.byKey(const Key('setup-budget')), 'abc');
await tester.enterText(find.byKey(const Key('setup-date')), '2028-02-29');
await tester.tap(find.byKey(const Key('setup-next')));
await tester.pump();
expect(find.text('Total budget must be a valid peso amount.'), findsOneWidget);
expect(find.text('2028-02-29'), findsOneWidget);
```

```dart
await tester.enterText(find.byKey(const Key('setup-budget')), '0');
await tester.tap(find.byKey(const Key('setup-next')));
await tester.pump();
expect(find.text('Total budget must be greater than zero.'), findsOneWidget);
await tester.enterText(find.byKey(const Key('setup-budget')), '-5000');
await tester.tap(find.byKey(const Key('setup-next')));
await tester.pump();
expect(find.text('Total budget cannot be negative.'), findsOneWidget);
```

```dart
// Override setupTodayProvider with DateTime(2027, 1, 2).
await tester.enterText(find.byKey(const Key('setup-budget')), '₱28,000.00');
await tester.enterText(find.byKey(const Key('setup-date')), '2027-01-01');
await tester.tap(find.byKey(const Key('setup-next')));
await tester.pumpAndSettle();
expect(find.textContaining('2027-01-01'), findsWidgets);
await tester.tap(find.text('Go back'));
await tester.pumpAndSettle();
// Prior accepted date, or empty when none, is restored without clearing budget.
```

Add a second test accepting the past date and finding the SCR-04 unfinished copy through a two-route test router; the form succeeds with no Supabase client, which is a deliberate no-RPC boundary assertion. Add a valid ₱500,001 budget test, a missing/invalid date test, and a test changing the account with the form mounted: both text controllers clear even after A→B→A. While the past-date dialog is pending, switch A→B→A before tapping Continue and assert that the stale dialog cannot accept a date or navigate. Ensure every failing test reaches the relevant screen before implementation.

- [ ] **Step 2: Verify RED.** Run `flutter test --no-pub test/ui/screens/scr_03_setup_budget_date_test.dart`; expect missing form controls and missing destination copy.

- [ ] **Step 3: Implement the form.** Replace the placeholder with a `ConsumerStatefulWidget`; initialize `TextEditingController`s from `ref.read(setupDraftProvider)` in `initState`, dispose them, and in `build` use `ref.listen(setupDraftProvider, (_, next) { if (_budget.text != next.budgetInput) _budget.text = next.budgetInput; if (_date.text != next.dateInput) _date.text = next.dateInput; })` to clear visible old-account text. If `ref.watch(setupDraftProvider).ownerId == null`, show the identity-check state and no draft values. Render `TextField(key: Key('setup-budget'), controller: _budget, onChanged: ref.read(setupDraftProvider.notifier).setBudget, decoration: InputDecoration(labelText: 'Total budget', errorText: _budgetError))`, and the analogous wedding-date field. `setup-notice` says `Draft for this session only. No plan has been created.`

Implement Next exactly in this order:

```dart
void _next() async {
  final draft = ref.read(setupDraftProvider);
  if (draft.ownerId == null) return;
  int? cents;
  DateTime? date;
  String? budgetError, dateError;
  try { cents = parseBudgetInput(_budget.text); } on FormatException catch (error) { budgetError = error.message; }
  try { date = parseWeddingDate(_date.text); } on FormatException catch (error) { dateError = error.message; }
  setState(() { _budgetError = budgetError; _dateError = dateError; });
  if (budgetError != null || dateError != null || cents == null || date == null) return;
  if (isPastWeddingDate(date, ref.read(setupTodayProvider))) {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Past wedding date'),
      content: Text('Your wedding date is ${_date.text}. Continue with this date?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go back')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))],
    ));
    if (!mounted || !identical(ref.read(setupDraftProvider), draft)) return;
    if (accepted != true) { ref.read(setupDraftProvider.notifier).restoreDate(); return; }
  }
  if (!mounted || !identical(ref.read(setupDraftProvider), draft)) return;
  ref.read(setupDraftProvider.notifier).acceptDate(_date.text);
  context.go(Routes.onboardingGuestRegion);
}
```

`cents` is validated integer-centavo input; if a value is shown in a summary use `fullForm(cents)`, never a raw or constrained formatter. Error text must be field-specific and stay inline. Avoid showing anything that implies plan creation or completed setup.

- [ ] **Step 4: Implement SCR-04 boundary and route constants.** Replace its placeholder with a `Scaffold` saying `Guest cap and region are not available yet. Your budget and date are a session draft; no plan has been created.`; give Back (`context.go(Routes.onboardingBudgetDate)`) and Start/Join (`context.go(Routes.signIn)`) buttons. In `app_router.dart`, set `Routes.onboardingGuestRegion = '/onboarding/budget-date/guest-region'` and `Routes.onboardingHiddenFees = '/onboarding/budget-date/guest-region/hidden-fees'` to match the existing nested route tree; do not change `_redirect` semantics or create any persistence adapter.

- [ ] **Step 5: GREEN + production-router regressions.** Run focused widget tests. Extend `test/ui/router/app_router_test.dart` using its existing `_pump(tester, auth: AuthState.authenticated, plan: false)` fixture: navigate to `Routes.onboardingBudgetDate`, fill valid values, tap Next, assert the actual `Scr04SetupGuestRegion` and unfinished/no-plan text, tap Back and assert the two values. Add a member test that direct navigation to both onboarding paths returns to dashboard. Add an identity-loading test using the existing production router provider watch pattern to ensure no old account text appears while `/plan-check` is active. Run `flutter test --no-pub test/ui/screens/scr_03_setup_budget_date_test.dart test/ui/router/app_router_test.dart` and `flutter analyze --no-pub`; expect no failures or analyzer issues. Commit with `git commit -m "feat(setup): add SCR-03 session draft form"`.

### Task 3: Boundary documentation, verification and PR

**Files:** Modify `docs/ux-spec.md` SCR-03/04 inventory, detailed flow and state-matrix rows; `docs/development-phases.md` phase 06 progress; `docs/testing-plan.md` traceability/evidence ledger. Do not change REQ text (the production requirements remain intact), and do not mark `TC-BS-01`–`03` fully passed.

- [ ] **Step 1: Document the limited states.** In `docs/ux-spec.md` inventory and screen details, distinguish the implemented SCR-03 session draft from future complete setup; SCR-04's current implementation is explicitly unfinished. In state-matrix SCR-03 add default/entered/invalid/past-confirmed/identity-reset and no-network-draft behaviors; in SCR-04 add unfinished/Back states. Correct the stale `Start reaches the SCR-03 placeholder` wording near the Phase 06 boundary. No cross-reference to Phase 11 as the owner of the form; roadmap puts complete setup in Phase 09.

- [ ] **Step 2: Record partial traceability.** In `docs/testing-plan.md` Phase 06 evidence ledger, describe exactly which widget/provider/router tests ran for REQ-BS-1 cl. 1–5, REQ-BS-2 cl. 1–4 and REQ-BS-3 cl. 1–3; leave guest cap/region, allocation, fee prompts, offline setup, overdue behavior, complete TC-BS-01/02/03 and Phase 09 open. Keep every existing TC ID and requirement mapping. In `docs/development-phases.md`, add a bounded SCR-03 draft sitting to Phase 06 status without moving complete setup ownership from Phase 09.

- [ ] **Step 3: Run verification with synthetic services.** Run `flutter analyze --no-pub`, focused validator/provider/widget/router tests, and `flutter test --no-pub --reporter=expanded`. The full suite includes local Edge contract tests: if services are stopped, start the existing local Supabase stack (`supabase start --exclude vector,analytics,studio`) while keeping CLI output containing local credentials out of PR text; verify readiness and run the real tests. A first Edge warm-up timeout warrants one retry after readiness. Run `python3 -m unittest discover -s test/api/identity -v` only if local Auth/API are available. Stop started services using plain `supabase stop` (never `--no-backup`). Record exact exit statuses/counts, not prior counts.

- [ ] **Step 4: Review and commit.** Search for stale placeholder/Phase 11 claims in touched docs and code; compare ADR-75, UX, router and tests; run `git diff --check` and an added-line credential-pattern scan without printing secret values. Commit docs with `git commit -m "docs(phase-06): record SCR-03 draft evidence"`. Review `git log origin/main..HEAD`, run a redacted branch-history gitleaks scan, and verify the clean working tree.

- [ ] **Step 5: Push and open a draft PR to `main`.** Check `gh pr view 12` remains merged and `origin/main` contains its merge. Push `feat/phase-06-scr03-draft`, open a **draft** PR to `main` listing the exact changed files and ADR-75, actual local counts, and outstanding complete-setup/release gates. Read back the PR base/head/body and checks; a billing-blocked/skipped job is not a test result. Do not push code or write a PR until Steps 1–4 pass.
