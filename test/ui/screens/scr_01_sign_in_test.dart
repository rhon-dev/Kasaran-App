import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/repositories/auth_repository.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/screens/scr_01_sign_in.dart';

class FakeRepository implements AuthRepository {
  int signUpCalls = 0;
  int signInCalls = 0;
  AuthSessionStatus result = AuthSessionStatus.emailUnverified;
  // ignore: close_sinks
  final events = StreamController<AuthSessionStatus>.broadcast();
  @override
  AuthSessionStatus get currentStatus => AuthSessionStatus.signedOut;
  @override
  Stream<AuthSessionStatus> get onStatusChanged => events.stream;
  @override
  Future<AuthSessionStatus> signUp({
    required String email,
    required String password,
    required String displayName,
    required bool isAdult,
  }) async {
    signUpCalls++;
    return result;
  }

  @override
  Future<AuthSessionStatus> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return result;
  }

  @override
  Future<void> signOut() async {}
}

Future<void> pumpAuth(WidgetTester tester, FakeRepository repository) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scr01SignIn()),
      ),
    );

void main() {
  testWidgets(
    'signup starts unchecked and blocks account creation with explanation',
    (tester) async {
      final repository = FakeRepository();
      await pumpAuth(tester, repository);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('I am 18 or older'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false,
      );
      expect(
        find.textContaining('18 or older', findRichText: true),
        findsWidgets,
      );
      expect(repository.signUpCalls, 0);
    },
  );

  testWidgets(
    'signup shows reachable synthetic-dev notice and unverified state',
    (tester) async {
      final repository = FakeRepository();
      await pumpAuth(tester, repository);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy notice'));
      await tester.pumpAndSettle();
      expect(find.textContaining('synthetic local development'), findsWidgets);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'tester@example.invalid',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'synthetic-password',
      );
      await tester.enterText(
        find.byKey(const Key('auth-display-name')),
        'Tester',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(repository.signUpCalls, 1);
      expect(find.textContaining('Verify your email'), findsOneWidget);
    },
  );

  testWidgets('sign-in submits through injected repository', (tester) async {
    final repository = FakeRepository();
    await pumpAuth(tester, repository);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'tester@example.invalid',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'synthetic-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(repository.signInCalls, 1);
  });
}
