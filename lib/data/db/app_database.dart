import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Encrypted local v3 schema retaining authoritative raw incoming events.
@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (to != 3 || (from != 1 && from != 2)) {
        throw StateError('Unsupported local schema transition');
      }
      // Explicit transaction: a failed parity check or COMMIT must leave both
      // the old layout and its version usable, not a half-upgraded v2 file.
      await transaction(() async {
        if (from == 1) {
          await m.createAll();
        } else {
          await m.createTable(syncInbox);
        }
        await _installParityIndexes();
        await customStatement('PRAGMA user_version = 3');
      });
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // This bounded v2 slice also existed before the parity indexes were
      // added. Install both on reopen, atomically; do not silently choose a
      // survivor if old local rows violate either invariant.
      await transaction(_installParityIndexes);
    },
  );

  Future<void> _installParityIndexes() async {
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS one_membership_user
      ON plan_members(user_id)
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS one_active_created_plan
      ON plans(creator_user_id) WHERE is_active = 1
    ''');
  }
}
