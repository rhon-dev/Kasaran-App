import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/auth_repository.dart';
import 'package:kasaran/data/repositories/invitation_repository.dart';
import 'package:kasaran/main.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/ui/providers/account_store_provider.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/providers/setup_draft_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';
import 'package:kasaran/ui/screens/scr_17_shared_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show GoTrueClient;

void main() {
  for (final stage in [
    'issue admission',
    'issue completion',
    'eligibility completion',
    'list completion',
    'revoke admission',
    'revoke completion',
  ]) {
    testWidgets(
      'SCR17 rejects silent same-user recovery at $stage without navigation',
      (tester) async {
        final auth = GoTrueClient(
          url: 'http://synthetic.invalid',
          autoRefreshToken: false,
          httpClient: MockClient(
            (_) async => throw StateError('Network forbidden'),
          ),
        );
        addTearDown(auth.dispose);
        await auth.recoverSession(_session('synthetic-a'));
        final identity = SupabaseVerifiedLocalIdentity(auth);
        final pendingOpen = Completer<void>();
        var opens = 0;
        final coordinator = AccountStoreCoordinator(identity, (_) async {
          opens++;
          if (opens > 1) await pendingOpen.future;
          return AppDatabase(NativeDatabase.memory());
        });
        await coordinator.observeSession();
        final invitations = _PendingInvitations(stage);
        final container = ProviderContainer(
          overrides: [
            accountStoreCoordinatorProvider.overrideWithValue(coordinator),
            accountSessionEventsProvider.overrideWithValue(
              auth.onAuthStateChange.map((_) {}),
            ),
            authStateProvider.overrideWithValue(AuthState.authenticated),
            authUserIdProvider.overrideWithValue('synthetic-a'),
            currentPlanIdProvider.overrideWith(
              (ref) => const AsyncData('plan-a'),
            ),
            invitationRepositoryProvider.overrideWithValue(invitations),
          ],
        );
        addTearDown(() async {
          pendingOpen.complete();
          final closing = coordinator.close();
          await tester.pumpAndSettle();
          await closing;
          container.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scr17SharedAccess()),
          ),
        );
        if (stage == 'eligibility completion' || stage == 'list completion') {
          await tester.pump();
          await tester.pump();
        } else {
          await tester.pumpAndSettle();
          if (stage == 'issue completion') {
            await tester.tap(find.text('Issue invitation'));
            await tester.pump();
          } else if (stage == 'revoke completion') {
            await tester.tap(find.byKey(const Key('revoke-old')));
            await tester.pump();
          }
        }
        final oldMarker = identity.capture()!.marker;
        var events = 0;
        final subscription = auth.onAuthStateChange.listen((_) => events++);
        addTearDown(subscription.cancel);
        await tester.pump(); // Drain this subscription's initialSession event.
        events = 0;
        await auth.recoverSession(_session('synthetic-a'));
        expect(identity.capture()!.marker, isNot(same(oldMarker)));
        expect(events, 0);
        // No router navigation, readiness read or provider invalidation here.
        if (stage == 'issue admission') {
          await tester.tap(find.text('Issue invitation'));
        } else if (stage == 'revoke admission') {
          await tester.tap(find.byKey(const Key('revoke-old')));
        } else {
          invitations.release.complete();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.textContaining('synthetic-private-token'), findsNothing);
        expect(find.text('Invitation old'), findsNothing);
        if (stage == 'issue admission') expect(invitations.issues, 0);
        if (stage == 'revoke admission') expect(invitations.revokes, 0);
        if (stage == 'eligibility completion') expect(invitations.lists, 0);
        expect(coordinator.isReady, isFalse);
      },
    );
  }
  testWidgets(
    'app-controlled signed-out Auth failure keeps reachable feedback',
    (tester) async {
      final auth = GoTrueClient(
        url: 'http://synthetic.invalid',
        autoRefreshToken: false,
        httpClient: MockClient(
          (_) async => throw StateError('Synthetic failure'),
        ),
      );
      addTearDown(auth.dispose);
      final coordinator = AccountStoreCoordinator(
        SupabaseVerifiedLocalIdentity(auth),
        (_) async => throw StateError('No DB'),
      );
      final container = ProviderContainer(
        overrides: [
          accountStoreCoordinatorProvider.overrideWithValue(coordinator),
          accountSessionEventsProvider.overrideWithValue(
            auth.onAuthStateChange.map((_) {}),
          ),
          authRepositoryProvider.overrideWithValue(
            SupabaseAuthRepository(
              SupabaseAuthGateway(auth),
              transition: coordinator.transition,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KasaranApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'synthetic@example.invalid',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'synthetic-only',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Authentication failed'), findsOneWidget);
      expect(find.text('Start our plan'), findsNothing);
      await coordinator.close();
    },
  );
  for (final verified in [null, false]) {
    testWidgets(
      'Auth-only production root opens no DB for verification=$verified',
      (tester) async {
        final auth = GoTrueClient(
          url: 'http://synthetic.invalid',
          autoRefreshToken: false,
          httpClient: MockClient(
            (_) async => throw StateError('Network forbidden'),
          ),
        );
        addTearDown(auth.dispose);
        if (verified != null) {
          await auth.recoverSession(
            _session('synthetic-a', verified: verified),
          );
        }
        var opens = 0;
        final coordinator = AccountStoreCoordinator(
          SupabaseVerifiedLocalIdentity(auth),
          (_) async {
            opens++;
            throw StateError('No financial open expected');
          },
        );
        final container = ProviderContainer(
          overrides: [
            accountStoreCoordinatorProvider.overrideWithValue(coordinator),
            accountSessionEventsProvider.overrideWithValue(
              auth.onAuthStateChange.map((_) {}),
            ),
            authRepositoryProvider.overrideWithValue(
              SupabaseAuthRepository(
                SupabaseAuthGateway(auth),
                transition: coordinator.transition,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const KasaranApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('auth-email')), findsOneWidget);
        expect(find.text('Start our plan'), findsNothing);
        if (verified == false) {
          expect(find.textContaining('Verify your email'), findsOneWidget);
        }
        expect(opens, 0);
        await coordinator.close();
      },
    );
  }
  test('membership lookup never starts before account readiness', () async {
    final lookup = _Lookup();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(AuthState.authenticated),
        authUserIdProvider.overrideWithValue('synthetic-a'),
        localPlanLookupProvider.overrideWithValue(lookup),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentPlanIdFutureProvider);
    expect(lookup.calls, 0);
    expect(container.read(planAccessProvider), PlanAccess.error);
  });
  testWidgets(
    'SDK A-B-A discards intermediate open and unavailable store only returns after explicit retry',
    (tester) async {
      final auth = GoTrueClient(
        url: 'http://synthetic.invalid',
        autoRefreshToken: false,
        httpClient: MockClient(
          (_) async => throw StateError('Network forbidden'),
        ),
      );
      addTearDown(auth.dispose);
      await auth.recoverSession(_session('synthetic-a'));
      final pendingB = Completer<AppDatabase>();
      final opens = <String>[];
      var fail = false;
      final coordinator = AccountStoreCoordinator(
        SupabaseVerifiedLocalIdentity(auth),
        (session) async {
          opens.add(session.userId);
          if (session.userId == 'synthetic-b') return pendingB.future;
          if (fail) throw StateError('Synthetic store unavailable');
          return AppDatabase(NativeDatabase.memory());
        },
      );
      await coordinator.observeSession();
      final container = ProviderContainer(
        overrides: [
          accountStoreCoordinatorProvider.overrideWithValue(coordinator),
          accountSessionEventsProvider.overrideWithValue(
            auth.onAuthStateChange.map((_) {}),
          ),
          authRepositoryProvider.overrideWithValue(
            SupabaseAuthRepository(
              SupabaseAuthGateway(auth),
              transition: coordinator.transition,
            ),
          ),
          authUserIdProvider.overrideWithValue('synthetic-a'),
          planAccessProvider.overrideWithValue(PlanAccess.none),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KasaranApp(),
        ),
      );
      await tester.pumpAndSettle();
      final oldScope = ProviderScope.containerOf(
        tester.element(find.text('Start our plan')),
        listen: false,
      );
      oldScope.read(setupDraftProvider.notifier).setBudget('A draft');
      await auth.recoverSession(_session('synthetic-b'));
      await tester.pump();
      expect(find.text('Start our plan'), findsNothing);
      fail = true;
      await auth.recoverSession(_session('synthetic-a'));
      await tester.pump();
      pendingB.complete(AppDatabase(NativeDatabase.memory()));
      await tester.pumpAndSettle();
      expect(opens, ['synthetic-a', 'synthetic-b', 'synthetic-a']);
      expect(find.text('Start our plan'), findsNothing);
      expect(find.textContaining('store is unavailable'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry local store'));
      await tester.pumpAndSettle();
      expect(find.text('Start our plan'), findsOneWidget);
      final scope = ProviderScope.containerOf(
        tester.element(find.text('Start our plan')),
        listen: false,
      );
      expect(scope.read(setupDraftProvider).budgetInput, isEmpty);
      await coordinator.close();
    },
  );
  testWidgets('verified status without coordinator never admits onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWithValue(AuthState.authenticated),
          authUserIdProvider.overrideWithValue('synthetic-a'),
          planAccessProvider.overrideWithValue(PlanAccess.none),
        ],
        child: const KasaranApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start our plan'), findsNothing);
    expect(find.textContaining('store is unavailable'), findsOneWidget);
  });

  testWidgets(
    'production app hides dialog and draft on real SDK same-user session replacement',
    (tester) async {
      final auth = GoTrueClient(
        url: 'http://synthetic.invalid',
        autoRefreshToken: false,
        httpClient: MockClient(
          (_) async => throw StateError('Network forbidden'),
        ),
      );
      addTearDown(auth.dispose);
      await auth.recoverSession(_session('synthetic-a'));
      final identity = SupabaseVerifiedLocalIdentity(auth);
      final pending = Completer<AppDatabase>();
      var opens = 0;
      final coordinator = AccountStoreCoordinator(identity, (_) async {
        opens++;
        return opens == 1
            ? AppDatabase(NativeDatabase.memory())
            : pending.future;
      });
      await coordinator.observeSession();
      final container = ProviderContainer(
        overrides: [
          accountStoreCoordinatorProvider.overrideWithValue(coordinator),
          accountSessionEventsProvider.overrideWithValue(
            auth.onAuthStateChange.map((_) {}),
          ),
          authRepositoryProvider.overrideWithValue(
            SupabaseAuthRepository(
              SupabaseAuthGateway(auth),
              transition: coordinator.transition,
            ),
          ),
          authUserIdProvider.overrideWithValue('synthetic-a'),
          planAccessProvider.overrideWithValue(PlanAccess.none),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KasaranApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start our plan'), findsOneWidget);
      final context = tester.element(find.text('Start our plan'));
      final scope = ProviderScope.containerOf(context, listen: false);
      scope.read(setupDraftProvider.notifier).setBudget('synthetic draft');
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(content: Text('A private dialog')),
        ),
      );
      await tester.pumpAndSettle();
      final old = identity.capture()!;
      // Pinned GoTrue replaces the Session without a same-user recovery event.
      await auth.recoverSession(_session('synthetic-a'));
      expect(identical(old.marker, identity.capture()!.marker), isFalse);
      scope.read(appRouterProvider).go(Routes.onboardingBudgetDate);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('A private dialog'), findsNothing);
      expect(find.text('Start our plan'), findsNothing);

      pending.complete(AppDatabase(NativeDatabase.memory()));
      await tester.pumpAndSettle();
      expect(find.text('Start our plan'), findsOneWidget);
      final nextScope = ProviderScope.containerOf(
        tester.element(find.text('Start our plan')),
        listen: false,
      );
      expect(identical(scope, nextScope), isFalse);
      expect(nextScope.read(setupDraftProvider).budgetInput, isEmpty);
      await coordinator.close();
    },
  );
}

class _PendingInvitations implements InvitationRepository {
  _PendingInvitations(this.stage);
  final String stage;
  final release = Completer<void>();
  int issues = 0;
  int revokes = 0;
  int lists = 0;

  @override
  Future<PairingEligibility> pairingEligibility(String planId) async {
    if (stage == 'eligibility completion') await release.future;
    return const PairingEligibility(isActive: true, memberCount: 1);
  }

  @override
  Future<List<InviteMetadata>> listInvites(String planId) async {
    lists++;
    if (stage == 'list completion') await release.future;
    return [
      InviteMetadata(
        id: 'old',
        expiresAt: DateTime.utc(2030),
        acceptedAt: null,
        revokedAt: null,
      ),
    ];
  }

  @override
  Future<IssuedInvite> issueInvite(String planId) async {
    issues++;
    if (stage == 'issue completion') await release.future;
    return IssuedInvite(
      id: 'new',
      expiresAt: DateTime.utc(2030),
      token: 'synthetic-private-token',
    );
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    revokes++;
    if (stage == 'revoke completion') await release.future;
  }
}

class _Lookup implements LocalPlanLookup {
  int calls = 0;
  @override
  Future<String?> currentPlanId() async {
    calls++;
    return null;
  }
}

String _session(String user, {bool verified = true}) => jsonEncode({
  'access_token': 'synthetic-not-a-credential',
  'refresh_token': 'synthetic',
  'token_type': 'bearer',
  'user': {
    'id': user,
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'email_confirmed_at': verified ? '2026-01-01T00:00:00Z' : null,
  },
});
