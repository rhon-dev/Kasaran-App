import 'package:drift/drift.dart';

/// Phase-05 local store: no plan or identity entities exist until phases 06–07.
/// SQLite's user_version is managed by drift; tests may create TEMP probes
/// without adding application tables to the persistent schema.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  @override
  final List<TableInfo<Table, dynamic>> allTables = const [];

  @override
  int get schemaVersion => 1;
}
