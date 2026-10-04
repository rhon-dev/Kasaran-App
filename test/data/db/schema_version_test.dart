import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/db/app_database.dart';

void main() {
  test(
    'phase-05 schema starts at version 1 with no application tables',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, 1);
      expect(db.allTables, isEmpty);
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      expect(tables, isEmpty);
    },
  );

  test(
    'SQLite round-trips signed integer centavos without floating point',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        'CREATE TEMP TABLE centavo_probe(amount INTEGER NOT NULL)',
      );
      await db.customStatement('INSERT INTO centavo_probe VALUES (?)', [
        9007199254740991,
      ]);
      await db.customStatement('INSERT INTO centavo_probe VALUES (?)', [
        -9007199254740991,
      ]);
      final rows = await db
          .customSelect('SELECT amount FROM centavo_probe ORDER BY amount')
          .get();
      expect(rows.map((row) => row.read<int>('amount')).toList(), [
        -9007199254740991,
        9007199254740991,
      ]);
    },
  );
}
