import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/account_store_registry.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';
import 'package:path_provider/path_provider.dart';

/// Isolate synthetic probe metadata from the production registry and keys.
class _ProbeMetadata implements SecureKeyValueStore {
  _ProbeMetadata(this.prefix);
  final String prefix;
  final _storage = PlatformSecureKeyValueStore();
  final _writtenKeys = <String>{};

  @override
  Future<String?> read(String key) => _storage.read('$prefix.$key');
  @override
  Future<void> write(String key, String value) async {
    _writtenKeys.add(key);
    await _storage.write('$prefix.$key', value);
  }

  @override
  Future<void> delete(String key) => _storage.delete('$prefix.$key');

  Future<void> clearProbe() async {
    for (final key in _writtenKeys) {
      await delete(key);
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native protected store persists without HTTP and is encrypted', (
    tester,
  ) async {
    final supplied = await getApplicationSupportDirectory();
    final root = Directory(await supplied.resolveSymbolicLinks());
    // This unique fixture never resets a retained production or probe directory.
    final dir = await root.createTemp('phase05_integration_');
    final security = PlatformLocalDeviceSecurity();
    final metadata = _ProbeMetadata(
      dir.uri.pathSegments.where((part) => part.isNotEmpty).last,
    );
    final registry = AccountStoreRegistry(dir, metadata, security);
    final location = await registry.resolveVerified(
      const VerifiedSessionSnapshot('synthetic-native-probe', Object()),
    );
    final bootstrap = LocalStoreBootstrap(
      dir,
      PlatformDatabaseKeyStore(),
      security,
    );
    var attemptedHttp = 0;
    try {
      await HttpOverrides.runZoned(
        () async {
          await bootstrap.prepare();
          final first = await bootstrap.openAccount(location);
          try {
            await first.customStatement(
              'CREATE TABLE phase05_probe(value TEXT)',
            );
            await first.customStatement(
              'INSERT INTO phase05_probe VALUES (?)',
              ['synthetic-offline-test-marker'],
            );
          } finally {
            await first.close();
          }
          final reopened = await bootstrap.openAccount(location);
          try {
            final rows = await reopened
                .customSelect('SELECT value FROM phase05_probe')
                .get();
            expect(
              rows.single.read<String>('value'),
              'synthetic-offline-test-marker',
            );
          } finally {
            await reopened.close();
          }
        },
        createHttpClient: (context) {
          attemptedHttp++;
          throw StateError('Database startup attempted HTTP');
        },
      );
      expect(attemptedHttp, 0);
      final bytes = await location.file.readAsBytes();
      final key =
          await location.keys.read() ??
          (throw StateError('Device key missing'));
      expect(utf8.decode(bytes, allowMalformed: true), isNot(contains(key)));
      expect(
        utf8.decode(bytes.take(16).toList(), allowMalformed: true),
        isNot('SQLite format 3\u0000'),
      );
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('synthetic-offline-test-marker')),
      );
    } finally {
      await dir.delete(recursive: true);
      await metadata.clearProbe();
    }
  });
}
