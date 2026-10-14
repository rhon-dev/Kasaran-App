import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/db/app_database.dart';

void main() {
  test('phase-07 schema has seven typed application tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 2);
    expect(db.allTables.map((table) => table.actualTableName).toSet(), {
      'plans',
      'plan_member_aliases',
      'plan_members',
      'ledger_entries',
      'change_log',
      'sync_state',
      'outbox',
    });
    final columns = await db
        .customSelect('PRAGMA table_info(ledger_entries)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('estimated_cents'),
    );
    expect(
      columns.map((row) => row.read<String>('type')).toSet(),
      isNot(contains('REAL')),
    );
  });

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
