import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/setup_draft_provider.dart';

final _user = NotifierProvider<_User, String?>(_User.new);
final _auth = NotifierProvider<_Auth, AuthState>(_Auth.new);

class _User extends Notifier<String?> {
  @override
  String? build() => 'A';
  set value(String? next) => state = next;
}

class _Auth extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.authenticated;
  set value(AuthState next) => state = next;
}

void main() {
  test('same-account draft survives edits while A-B-A erases it', () {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => ref.watch(_auth)),
        authUserIdProvider.overrideWith((ref) => ref.watch(_user)),
      ],
    );
    addTearDown(container.dispose);
    container.read(setupDraftProvider.notifier).setBudget('123');
    container.read(setupDraftProvider.notifier).setDate('2027-05-06');
    expect(container.read(setupDraftProvider).budgetInput, '123');
    expect(container.read(setupDraftProvider).dateInput, '2027-05-06');
    container.read(_user.notifier).value = 'B';
    expect(container.read(setupDraftProvider).budgetInput, isEmpty);
    container.read(_user.notifier).value = 'A';
    expect(container.read(setupDraftProvider).dateInput, isEmpty);
  });

  test('unknown account and sign-out erase the draft', () {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => ref.watch(_auth)),
        authUserIdProvider.overrideWith((ref) => ref.watch(_user)),
      ],
    );
    addTearDown(container.dispose);
    container.read(setupDraftProvider.notifier).setBudget('456');
    container.read(_user.notifier).value = null;
    expect(container.read(setupDraftProvider).budgetInput, isEmpty);
    container.read(_user.notifier).value = 'A';
    container.read(setupDraftProvider.notifier).setBudget('789');
    container.read(_auth.notifier).value = AuthState.unauthenticated;
    expect(container.read(setupDraftProvider).budgetInput, isEmpty);
    expect(container.read(setupDraftProvider).ownerId, isNull);
  });

  test('declining a changed date restores the previous accepted date', () {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(AuthState.authenticated),
        authUserIdProvider.overrideWithValue('A'),
      ],
    );
    addTearDown(container.dispose);
    container.read(setupDraftProvider.notifier).acceptDate('2027-05-06');
    container.read(setupDraftProvider.notifier).setDate('2026-01-01');
    container.read(setupDraftProvider.notifier).restoreDate();
    expect(container.read(setupDraftProvider).dateInput, '2027-05-06');
  });

  test('failed identity stream erases a previously entered draft', () async {
    final identity = StreamController<String?>();
    addTearDown(identity.close);
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(AuthState.authenticated),
        authIdentityStateProvider.overrideWith((ref) => identity.stream),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(setupDraftProvider, (_, _) {});
    addTearDown(subscription.close);
    identity.add('A');
    await container.read(authIdentityStateProvider.future);
    expect(container.read(setupDraftProvider).ownerId, 'A');
    container.read(setupDraftProvider.notifier).setBudget('123');
    identity.addError(StateError('identity unavailable'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(setupDraftProvider).ownerId, isNull);
    expect(container.read(setupDraftProvider).budgetInput, isEmpty);
  });
}
