import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/repositories/auth_repository.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';

class FakeAuthGateway implements AuthGateway {
  AuthSessionStatus status = AuthSessionStatus.signedOut;
  AuthSessionStatus next = AuthSessionStatus.emailUnverified;
  // ignore: close_sinks
  final changes = StreamController<AuthSessionStatus>.broadcast();
  int signUpCalls = 0;
  int signOutCalls = 0;
  String? displayName;
  bool failSignOut = false;

  @override
  AuthSessionStatus get currentStatus => status;
  @override
  Stream<AuthSessionStatus> get onStatusChanged => changes.stream;
  @override
  Future<AuthSessionStatus> signUp(
    String email,
    String password,
    String name,
  ) async {
    signUpCalls++;
    displayName = name;
    status = next;
    return next;
  }

  @override
  Future<AuthSessionStatus> signIn(String email, String password) async {
    status = next;
    return next;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) throw StateError('network unavailable');
    status = AuthSessionStatus.signedOut;
  }
}

class MemorySecureStorage implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  test('signup refuses unchecked adulthood without contacting auth', () async {
    final gateway = FakeAuthGateway();
    final repository = SupabaseAuthRepository(gateway);
    await expectLater(
      repository.signUp(
        email: 'test@example.invalid',
        password: 'synthetic',
        displayName: 'Tester',
        isAdult: false,
      ),
      throwsA(isA<AgeDeclarationRequired>()),
    );
    expect(gateway.signUpCalls, 0);
  });

  test(
    'signup passes display name and reports unverified until email confirmation',
    () async {
      final gateway = FakeAuthGateway();
      final repository = SupabaseAuthRepository(gateway);
      expect(
        await repository.signUp(
          email: ' test@example.invalid ',
          password: 'synthetic',
          displayName: ' Tester ',
          isAdult: true,
        ),
        AuthSessionStatus.emailUnverified,
      );
      expect(gateway.displayName, 'Tester');
      expect(gateway.signUpCalls, 1);
    },
  );

  test(
    'sign-in can return verified and sign-out invokes server gateway',
    () async {
      final gateway = FakeAuthGateway()..next = AuthSessionStatus.verified;
      final repository = SupabaseAuthRepository(gateway);
      expect(
        await repository.signIn(
          email: 'test@example.invalid',
          password: 'synthetic',
        ),
        AuthSessionStatus.verified,
      );
      await repository.signOut();
      expect(gateway.signOutCalls, 1);
      expect(repository.currentStatus, AuthSessionStatus.signedOut);
    },
  );

  test('failed remote sign-out reports failure instead of success', () async {
    final gateway = FakeAuthGateway()..failSignOut = true;
    final repository = SupabaseAuthRepository(gateway);
    await expectLater(repository.signOut(), throwsStateError);
    expect(gateway.signOutCalls, 1);
  });

  test(
    'router state updates on verified auth event without changing provider type',
    () async {
      final gateway = FakeAuthGateway();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            SupabaseAuthRepository(gateway),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(authStateProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(container.read(authStateProvider), AuthState.unauthenticated);
      gateway.changes.add(AuthSessionStatus.verified);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authStateProvider), AuthState.authenticated);
    },
  );

  test(
    'secure session and PKCE verifier storage are separate and removable',
    () async {
      final backing = MemorySecureStorage();
      final storage = SecureTokenStore(backing);
      await storage.initialize();
      await storage.persistSession('synthetic-session');
      await storage.setItem(key: 'verifier', value: 'synthetic-verifier');
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), 'synthetic-session');
      expect(await storage.getItem(key: 'verifier'), 'synthetic-verifier');
      await storage.removePersistedSession();
      expect(await storage.accessToken(), isNull);
      expect(await storage.getItem(key: 'verifier'), 'synthetic-verifier');
      await storage.removeItem(key: 'verifier');
      expect(await storage.getItem(key: 'verifier'), isNull);
    },
  );
}
