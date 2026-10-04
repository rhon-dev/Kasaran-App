import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/data/repositories/plan_membership_repository.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/screens/scr_02_invite_acceptance.dart';

class _FakeMembership implements PlanMembershipRepository {
  String? accepted;
  @override
  Future<void> acceptInvite(String token) async => accepted = token;
}

class _FakeLookup implements PlanMembershipLookup {
  int calls = 0;
  @override
  Future<String?> currentPlanId() async {
    calls++;
    return null;
  }
}

final _token = List.filled(32, 'a').join();

void main() {
  test('paste and tap parse to identical invitation token', () {
    expect(parseInviteLink('kasaran://accept/$_token'), _token);
    expect(parseInviteLink('kasaran://accept/$_token?ignored=1'), _token);
    expect(parseInviteLink('https://unowned.example/accept/$_token'), isNull);
    expect(parseInviteLink('kasaran://accept/short'), isNull);
    expect(
      parseInviteLink('kasaran://accept/gggggggggggggggggggggggggggggggg'),
      isNull,
    );
    expect(
      parseInviteLink('kasaran://accept/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
      isNull,
    );
    expect(
      parseInviteLink('kasaran://accept/0000000000000000000000000000000'),
      isNull,
    );
  });

  testWidgets(
    'unauthenticated invite waits for sign-in without revealing token',
    (tester) async {
      final fake = _FakeMembership();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AuthState.unauthenticated),
            planMembershipRepositoryProvider.overrideWith((ref) => fake),
          ],
          child: MaterialApp(home: Scr02InviteAcceptance(token: _token)),
        ),
      );
      expect(find.textContaining(_token), findsNothing);
      expect(find.textContaining('Sign in'), findsWidgets);
      expect(find.text('Accept invitation'), findsNothing);
      expect(fake.accepted, isNull);
    },
  );

  testWidgets('verified partner can paste the same link and accept once', (
    tester,
  ) async {
    final fake = _FakeMembership();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          planMembershipRepositoryProvider.overrideWith((ref) => fake),
        ],
        child: const MaterialApp(home: Scr02InviteAcceptance(token: '')),
      ),
    );
    await tester.enterText(find.byType(TextField), 'kasaran://accept/$_token');
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(fake.accepted, _token);
    expect(find.textContaining(_token), findsNothing);
    expect(find.textContaining('joined'), findsOneWidget);
  });

  testWidgets('declining invite returns to start choice without accepting', (
    tester,
  ) async {
    final fake = _FakeMembership();
    final router = GoRouter(
      initialLocation: '/invite/accept/$_token',
      routes: [
        GoRoute(
          path: '/invite/accept/:token',
          builder: (_, state) => Scr02InviteAcceptance(
            token: state.pathParameters['token']!,
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (_, _) => const Scaffold(body: Text('Start or join')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          planMembershipRepositoryProvider.overrideWith((ref) => fake),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline invitation'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/sign-in');
    expect(fake.accepted, isNull);
    expect(find.textContaining(_token), findsNothing);
  });

  testWidgets('successful acceptance refreshes membership lookup', (
    tester,
  ) async {
    final fake = _FakeMembership();
    final lookup = _FakeLookup();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        planMembershipRepositoryProvider.overrideWith((ref) => fake),
        planMembershipLookupProvider.overrideWith((ref) => lookup),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scr02InviteAcceptance(token: _token)),
      ),
    );
    await container.read(currentPlanIdProvider.future);
    expect(lookup.calls, 1);
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    await container.read(currentPlanIdProvider.future);
    expect(lookup.calls, 2);
  });
}
