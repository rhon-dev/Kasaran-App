import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native protected store persists without HTTP and is encrypted', (
    tester,
  ) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/phase05_integration');
    final security = PlatformLocalDeviceSecurity();
    final keyStore = PlatformDatabaseKeyStore();
    final path = '${dir.path}/kasaran.sqlite';
    final file = File(path);
    // Integration uses a synthetic-only install, never an app with real data.
    // ignore: avoid_slow_async_io
    if (await dir.exists()) await dir.delete(recursive: true);

    var attemptedHttp = 0;
    await HttpOverrides.runZoned(
      () async {
        final first = await LocalStoreBootstrap(dir, keyStore, security).open();
        await first.db.customStatement(
          'CREATE TABLE phase05_probe(value TEXT)',
        );
        await first.db.customStatement('INSERT INTO phase05_probe VALUES (?)', [
          'synthetic-offline-test-marker',
        ]);
        await first.db.close();
        final reopened = await LocalStoreBootstrap(
          dir,
          keyStore,
          security,
        ).open();
        final rows = await reopened.db
            .customSelect('SELECT value FROM phase05_probe')
            .get();
        expect(
          rows.single.read<String>('value'),
          'synthetic-offline-test-marker',
        );
        await reopened.db.close();
      },
      createHttpClient: (context) {
        attemptedHttp++;
        throw StateError('Database startup attempted HTTP');
      },
    );
    expect(attemptedHttp, 0);
    final bytes = await file.readAsBytes();
    expect(
      utf8.decode(bytes.take(16).toList(), allowMalformed: true),
      isNot('SQLite format 3\u0000'),
    );
    expect(
      utf8.decode(bytes, allowMalformed: true),
      isNot(contains('synthetic-offline-test-marker')),
    );
    await dir.delete(recursive: true);
  });
}
