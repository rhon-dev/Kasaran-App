# platform/db/

**Layering rule:** Native wiring only. No business logic, no SQL queries beyond
database open and `PRAGMA` setup.

Responsibilities:

- Open the SQLite file at the platform-appropriate path using `path_provider`.
- Derive the encryption key from the OS secure store (Keychain on iOS, Android
  Keystore on Android) per SEC-12 and SEC-13.
- Initialise SQLCipher (`PRAGMA key`, `PRAGMA cipher_*` as required by
  `sqlcipher_flutter_libs`).
- Return a configured `drift` `QueryExecutor` to `data/db/AppDatabase`.

The raw database key must never appear in logs, crash reports, or analytics (SEC-14).
Minimum supported OS versions set the floor for the Keystore APIs used here:
iOS 15.0, Android API 24 (deployment-plan §4.4).
