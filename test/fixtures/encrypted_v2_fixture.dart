import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';

/// Frozen genuine canonical v2 fixture, never silently opened by the current
/// production upgrader. Used only for legacy source authorization tests.
class CanonicalV2Fixture extends AppDatabase {
  CanonicalV2Fixture(super.executor);
  @override int get schemaVersion => 2;
  @override MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      final sql = await File('test/fixtures/local_schema_v2.sql').readAsString();
      for (final statement in sql.split(';')) {
        if (statement.trim().isNotEmpty) await customStatement(statement);
      }
    },
    onUpgrade: (_, _, _) async => throw StateError('Fixture upgrade forbidden'),
  );
}
Future<AppDatabase> openCanonicalV2(File file, DatabaseKeyStore keys) async {
  var key = await keys.read();
  if (key == null) {
    if(file.existsSync()) throw StateError('Original fixture key required');
    key = '1234567890abcdef' * 4;
    await keys.write(key);
  }
  final db = CanonicalV2Fixture(NativeDatabase(file, setup: (raw) {
    if(raw.select('PRAGMA cipher').isEmpty) throw StateError('Cipher required');
    raw.execute("PRAGMA key = '$key'");
    final version = raw.select('PRAGMA user_version').single.columnAt(0);
    if(version != 0 && version != 2) throw StateError('Fixture must be genuine v2');
  }));
  await db.customSelect('PRAGMA user_version').get();
  return db;
}
