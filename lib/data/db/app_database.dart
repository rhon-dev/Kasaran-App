import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Encrypted local v2 core schema; writers and transport are later slices.
@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from != 1 || to != 2) {
        throw StateError('Unsupported local schema transition');
      }
      await m.createAll();
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // This bounded v2 slice also existed before the parity indexes were
      // added. Install both on reopen, atomically; do not silently choose a
      // survivor if old local rows violate either invariant.
      await transaction(() async {
        await customStatement('''
          CREATE UNIQUE INDEX IF NOT EXISTS one_membership_user
          ON plan_members(user_id)
        ''');
        await customStatement('''
          CREATE UNIQUE INDEX IF NOT EXISTS one_active_created_plan
          ON plans(creator_user_id) WHERE is_active = 1
        ''');
      });
    },
  );
}
