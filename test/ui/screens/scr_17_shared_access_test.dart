import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/repositories/invitation_repository.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/providers/plan_provider.dart';
import 'package:kasaran/ui/screens/scr_17_shared_access.dart';

final _auth = NotifierProvider<_AuthController, AuthState>(_AuthController.new);

class _AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.authenticated;
  set value(AuthState next) => state = next;
}

final _plan = NotifierProvider<_PlanController, String>(_PlanController.new);

class _PlanController extends Notifier<String> {
  @override
  String build() => 'plan-1';
  set value(String next) => state = next;
}

final _identity = NotifierProvider<_IdentityController, String>(
  _IdentityController.new,
);

class _IdentityController extends Notifier<String> {
  @override
  String build() => 'user-1';
  set value(String next) => state = next;
}

class _FakeAuthIdentitySource implements AuthIdentitySource {
  final changes = StreamController<String?>.broadcast();
  String? userId = 'user-1';

  @override
  String? get currentUserId => userId;

  @override
  Stream<String?> get onUserChanged => changes.stream;

  Future<void> dispose() => changes.close();
}

class _ChangingIdentityLookup implements PlanMembershipLookup {
  _ChangingIdentityLookup(this.userId);
  final String Function() userId;
  int calls = 0;

  @override
  Future<String?> currentPlanId() async {
    calls++;
    return userId() == 'user-1' ? 'plan-1' : 'plan-2';
  }
}

class _FakeInvitations implements InvitationRepository {
  final token = List.filled(32, 'a').join();
  int issueCalls = 0;
  int revokeCalls = 0;
  int listCalls = 0;
  bool failListAfterIssue = false;
  bool failList = false;
  bool failRevoke = false;
  Completer<IssuedInvite>? pendingIssue;
  Completer<void>? pendingRevoke;
  PairingEligibility eligibility = const PairingEligibility(
    isActive: true,
    memberCount: 1,
  );
  List<InviteMetadata> metadata = [];

  @override
  Future<PairingEligibility> pairingEligibility(String planId) async =>
      eligibility;

  @override
  Future<List<InviteMetadata>> listInvites(String planId) async {
    listCalls++;
    if (failList || (failListAfterIssue && issueCalls > 0)) {
      throw StateError('synthetic read failure');
    }
    return metadata;
  }

  @override
  Future<IssuedInvite> issueInvite(String planId) async {
    issueCalls++;
    if (pendingIssue case final pending?) return pending.future;
    return IssuedInvite(
      id: 'invite-1',
      expiresAt: DateTime.utc(2026, 10, 11),
      token: token,
    );
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    revokeCalls++;
    if (pendingRevoke case final pending?) await pending.future;
    if (failRevoke) throw StateError('synthetic revoke failure');
    metadata = [
      for (final invite in metadata)
        if (invite.id == inviteId)
          InviteMetadata(
            id: invite.id,
            expiresAt: invite.expiresAt,
            acceptedAt: invite.acceptedAt,
            revokedAt: DateTime.now().toUtc(),
          )
        else
          invite,
    ];
  }
}

void main() {
  test('account identity provider follows user-ID events', () async {
    final source = _FakeAuthIdentitySource();
    final container = ProviderContainer(
      overrides: [authIdentitySourceProvider.overrideWithValue(source)],
    );
    addTearDown(() async {
      container.dispose();
      await source.dispose();
    });
    final first = Completer<void>();
    final second = Completer<void>();
    final subscription = container.listen(authUserIdProvider, (_, next) {
      if (next == 'user-1' && !first.isCompleted) first.complete();
      if (next == 'user-2' && !second.isCompleted) second.complete();
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await first.future.timeout(const Duration(seconds: 2));
    source.changes.add('user-2');
    await second.future.timeout(const Duration(seconds: 2));
    expect(container.read(authUserIdProvider), 'user-2');
  });

  test('identity refresh never exposes the previous account ID', () async {
    final source = _FakeAuthIdentitySource();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(AuthState.authenticated),
        authIdentitySourceProvider.overrideWithValue(source),
        planMembershipLookupProvider.overrideWithValue(
          _ChangingIdentityLookup(() => 'user-1'),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await source.dispose();
    });
    final known = Completer<void>();
    final subscription = container.listen(authUserIdProvider, (_, next) {
      if (next == 'user-1' && !known.isCompleted) known.complete();
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await known.future.timeout(const Duration(seconds: 2));
    source.userId = 'user-2';
    container.invalidate(authIdentityStateProvider);
    expect(container.read(authUserIdProvider), isNull);
    expect(container.read(planAccessProvider), PlanAccess.loading);
  });

  test(
    'verified status defers plan access without known account identity',
    () async {
      final lookup = _ChangingIdentityLookup(() => 'user-1');
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue(null),
          planMembershipLookupProvider.overrideWithValue(lookup),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentPlanIdProvider.future);
      expect(container.read(planAccessProvider), PlanAccess.loading);
      expect(lookup.calls, 0);
    },
  );

  test('identity stream failure blocks plan access as an error', () async {
    final source = _FakeAuthIdentitySource();
    final lookup = _ChangingIdentityLookup(() => 'user-1');
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authIdentitySourceProvider.overrideWithValue(source),
        planMembershipLookupProvider.overrideWithValue(lookup),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await source.dispose();
    });
    final known = Completer<void>();
    final lost = Completer<void>();
    final subscription = container.listen(authUserIdProvider, (previous, next) {
      if (next == 'user-1' && !known.isCompleted) known.complete();
      if (previous == 'user-1' && next == null && !lost.isCompleted) {
        lost.complete();
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);
    await known.future.timeout(const Duration(seconds: 2));
    source.changes.addError(StateError('synthetic identity failure'));
    await lost.future.timeout(const Duration(seconds: 2));
    expect(container.read(planAccessProvider), PlanAccess.error);
  });

  test('membership lookup refreshes when verified account changes', () async {
    late ProviderContainer container;
    final lookup = _ChangingIdentityLookup(() => container.read(_identity));
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWith((ref) => ref.watch(_identity)),
        planMembershipLookupProvider.overrideWith((ref) => lookup),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(currentPlanIdProvider.future), 'plan-1');
    container.read(_identity.notifier).value = 'user-2';
    expect(await container.read(currentPlanIdProvider.future), 'plan-2');
    expect(lookup.calls, 2);
  });

  testWidgets('failed metadata read blocks issue until retry succeeds', (
    tester,
  ) async {
    final fake = _FakeInvitations()..failList = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue('user-1'),
          currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
          invitationRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Issue invitation'), findsNothing);
    expect(find.textContaining('could not be checked'), findsOneWidget);
    fake.failList = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Issue invitation'), findsOneWidget);
  });

  testWidgets('two members make issue unavailable', (tester) async {
    final fake = _FakeInvitations()
      ..eligibility = const PairingEligibility(isActive: true, memberCount: 2);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue('user-1'),
          currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
          invitationRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Issue invitation'), findsNothing);
    expect(fake.issueCalls, 0);
  });

  testWidgets('inactive plan makes issue unavailable', (tester) async {
    final fake = _FakeInvitations()
      ..eligibility = const PairingEligibility(isActive: false, memberCount: 1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue('user-1'),
          currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
          invitationRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Issue invitation'), findsNothing);
    expect(fake.issueCalls, 0);
  });

  testWidgets('revoke failure keeps link and shows generic error', (
    tester,
  ) async {
    final fake = _FakeInvitations()..failRevoke = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue('user-1'),
          currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
          invitationRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke invitation'));
    await tester.pumpAndSettle();
    expect(fake.revokeCalls, 1);
    expect(find.textContaining(fake.token), findsOneWidget);
    expect(find.textContaining('Could not revoke invitation'), findsOneWidget);
    expect(find.textContaining('synthetic revoke failure'), findsNothing);
  });

  testWidgets('issue shows link only in current view', (tester) async {
    final fake = _FakeInvitations();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWithValue('user-1'),
        currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    Widget app(Widget home) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    );
    await tester.pumpWidget(app(const Scr17SharedAccess()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    expect(fake.issueCalls, 1);
    expect(find.text('kasaran://accept/${fake.token}'), findsOneWidget);
    expect(
      find.textContaining('Copy this invitation link now'),
      findsOneWidget,
    );
    await tester.pumpWidget(app(const Scaffold(body: Text('Other screen'))));
    await tester.pumpWidget(app(const Scr17SharedAccess()));
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('revoke drops transient link after server confirms', (
    tester,
  ) async {
    final fake = _FakeInvitations();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue('user-1'),
          currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
          invitationRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke invitation'));
    await tester.pumpAndSettle();
    expect(fake.revokeCalls, 1);
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('pending revoke keeps link until server confirmation', (
    tester,
  ) async {
    final fake = _FakeInvitations();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue('user-1'),
          currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
          invitationRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    fake.pendingRevoke = Completer<void>();
    await tester.tap(find.text('Revoke invitation'));
    await tester.pump();
    expect(find.textContaining(fake.token), findsOneWidget);
    fake.pendingRevoke!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('existing active invite can be revoked without raw link', (
    tester,
  ) async {
    final fake = _FakeInvitations()
      ..metadata = [
        InviteMetadata(
          id: 'invite-old',
          expiresAt: DateTime.utc(2030),
          acceptedAt: null,
          revokedAt: null,
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue('user-1'),
          currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
          invitationRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('invite-old'), findsWidgets);
    expect(find.textContaining(fake.token), findsNothing);
    await tester.tap(find.byKey(const Key('revoke-invite-old')));
    await tester.pumpAndSettle();
    expect(fake.revokeCalls, 1);
    expect(find.byKey(const Key('revoke-invite-old')), findsNothing);
    expect(find.text('Revoked'), findsOneWidget);
  });

  testWidgets('issued link remains visible if metadata refresh fails', (
    tester,
  ) async {
    final fake = _FakeInvitations()..failListAfterIssue = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthState.authenticated),
          authUserIdProvider.overrideWithValue('user-1'),
          currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
          invitationRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    expect(find.text('kasaran://accept/${fake.token}'), findsOneWidget);
    expect(find.textContaining('could not be checked'), findsOneWidget);
  });

  testWidgets('reentering Shared Access refreshes invitation metadata', (
    tester,
  ) async {
    final fake = _FakeInvitations();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWithValue('user-1'),
        currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    Widget app(Widget home) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    );
    await tester.pumpWidget(app(const Scr17SharedAccess()));
    await tester.pumpAndSettle();
    expect(fake.listCalls, 1);
    await tester.pumpWidget(app(const Scaffold(body: Text('Other screen'))));
    await tester.pump();
    await tester.pumpWidget(app(const Scr17SharedAccess()));
    await tester.pumpAndSettle();
    expect(fake.listCalls, 2);
  });

  testWidgets('sign-out drops one-time invitation link', (tester) async {
    final fake = _FakeInvitations();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => ref.watch(_auth)),
        authUserIdProvider.overrideWithValue('user-1'),
        currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsOneWidget);
    container.read(_auth.notifier).value = AuthState.unauthenticated;
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('late issue response cannot reveal link after sign-out', (
    tester,
  ) async {
    final fake = _FakeInvitations()..pendingIssue = Completer<IssuedInvite>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => ref.watch(_auth)),
        authUserIdProvider.overrideWithValue('user-1'),
        currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pump();
    container.read(_auth.notifier).value = AuthState.unauthenticated;
    await tester.pump();
    container.read(_auth.notifier).value = AuthState.authenticated;
    await tester.pump();
    fake.pendingIssue!.complete(
      IssuedInvite(
        id: 'invite-late',
        expiresAt: DateTime.utc(2030),
        token: fake.token,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('late issue response cannot display under a different plan', (
    tester,
  ) async {
    final fake = _FakeInvitations()..pendingIssue = Completer<IssuedInvite>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWithValue('user-1'),
        currentPlanIdProvider.overrideWith((ref) async => ref.watch(_plan)),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pump();
    container.read(_plan.notifier).value = 'plan-2';
    await tester.pumpAndSettle();
    fake.pendingIssue!.complete(
      IssuedInvite(
        id: 'invite-old-plan',
        expiresAt: DateTime.utc(2030),
        token: fake.token,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('late issue response is discarded after plan A-B-A switch', (
    tester,
  ) async {
    final fake = _FakeInvitations()..pendingIssue = Completer<IssuedInvite>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWithValue('user-1'),
        currentPlanIdProvider.overrideWith((ref) async => ref.watch(_plan)),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pump();
    container.read(_plan.notifier).value = 'plan-2';
    await tester.pumpAndSettle();
    container.read(_plan.notifier).value = 'plan-1';
    await tester.pumpAndSettle();
    fake.pendingIssue!.complete(
      IssuedInvite(
        id: 'invite-late',
        expiresAt: DateTime.utc(2030),
        token: fake.token,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('verified account switch clears a prior account link', (
    tester,
  ) async {
    final fake = _FakeInvitations();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWith((ref) => ref.watch(_identity)),
        currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsOneWidget);
    container.read(_identity.notifier).value = 'user-2';
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
    container.read(_identity.notifier).value = 'user-1';
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('late issue response cannot reveal after account A-B-A switch', (
    tester,
  ) async {
    final fake = _FakeInvitations()..pendingIssue = Completer<IssuedInvite>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWith((ref) => ref.watch(_identity)),
        currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pump();
    container.read(_identity.notifier).value = 'user-2';
    await tester.pump();
    container.read(_identity.notifier).value = 'user-1';
    await tester.pump();
    fake.pendingIssue!.complete(
      IssuedInvite(
        id: 'invite-late-account',
        expiresAt: DateTime.utc(2030),
        token: fake.token,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });

  testWidgets('late revoke failure does not appear for another account', (
    tester,
  ) async {
    final fake = _FakeInvitations()
      ..pendingRevoke = Completer<void>()
      ..failRevoke = true;
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWith((ref) => ref.watch(_identity)),
        currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke invitation'));
    await tester.pump();
    container.read(_identity.notifier).value = 'user-2';
    await tester.pump();
    fake.pendingRevoke!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
    expect(find.textContaining('Could not revoke invitation'), findsNothing);
  });

  testWidgets('late issue failure does not appear for another account', (
    tester,
  ) async {
    final fake = _FakeInvitations()..pendingIssue = Completer<IssuedInvite>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWith((ref) => ref.watch(_identity)),
        currentPlanIdProvider.overrideWith((ref) async => 'plan-1'),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pump();
    container.read(_identity.notifier).value = 'user-2';
    await tester.pump();
    fake.pendingIssue!.completeError(StateError('synthetic issue failure'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not issue invitation'), findsNothing);
  });

  testWidgets('plan change drops an already issued link', (tester) async {
    final fake = _FakeInvitations();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthState.authenticated),
        authUserIdProvider.overrideWithValue('user-1'),
        currentPlanIdProvider.overrideWith((ref) async => ref.watch(_plan)),
        invitationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scr17SharedAccess()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invitation'));
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsOneWidget);
    container.read(_plan.notifier).value = 'plan-2';
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
    container.read(_plan.notifier).value = 'plan-1';
    await tester.pumpAndSettle();
    expect(find.textContaining(fake.token), findsNothing);
  });
}
