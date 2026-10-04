import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Small seam for secure storage fakes; production uses the platform keychain.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class PlatformSecureKeyValueStore implements SecureKeyValueStore {
  PlatformSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
            aOptions: AndroidOptions(migrateWithBackup: true),
          );

  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Supabase persists the entire session JSON (including both rotating tokens).
/// The verifier also goes into secure storage, never the SDK's default prefs.
final class SecureTokenStore extends LocalStorage
    implements GotrueAsyncStorage {
  SecureTokenStore(this._store);
  final SecureKeyValueStore _store;
  static const _sessionKey = 'kasaran.auth.session.v1';
  static const _pkcePrefix = 'kasaran.auth.pkce.v1.';

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;
  @override
  Future<String?> accessToken() => _store.read(_sessionKey);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(_sessionKey, persistSessionString);
  @override
  Future<void> removePersistedSession() => _store.delete(_sessionKey);
  @override
  Future<String?> getItem({required String key}) =>
      _store.read('$_pkcePrefix$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      _store.write('$_pkcePrefix$key', value);
  @override
  Future<void> removeItem({required String key}) =>
      _store.delete('$_pkcePrefix$key');
}
