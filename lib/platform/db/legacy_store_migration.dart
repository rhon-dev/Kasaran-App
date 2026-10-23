import 'dart:convert';
import 'dart:io';
import 'dart:math';

// The pinned transitive crypto package is used until migration packaging owns
// a direct dependency; never use a non-cryptographic source fingerprint.
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';

import 'package:kasaran/platform/db/account_store_registry.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Intentionally non-promoting Task 3 boundary. A desktop test cannot certify
/// the iOS directory-entry durability barrier required by ADR-79; until the
/// native protocol is established, even a valid source remains unavailable.
final class LocalStoreUnavailable implements Exception {
  const LocalStoreUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'LocalStoreUnavailable: $reason';
}

final class _TableCopy {
  const _TableCopy(this.columns, this.rows);
  final List<String> columns;
  final List<List<Object?>> rows;
}

// Exact supported v2 table DDL from schema.drift. Check constraints before staging.
const _v2TableSql = <String, String>{
  'plans': '''
CREATE TABLE plans (
  id TEXT NOT NULL PRIMARY KEY, creator_user_id TEXT NOT NULL,
  wedding_date TEXT NOT NULL, total_budget_cents INTEGER NOT NULL CHECK (total_budget_cents > 0),
  guest_cap INTEGER NOT NULL CHECK (guest_cap >= 0), region_code TEXT NOT NULL,
  ceremony_type TEXT, venue_type TEXT,
  reminder_enabled INTEGER NOT NULL DEFAULT 1 CHECK (reminder_enabled IN (0,1)),
  reminder_window_days INTEGER NOT NULL DEFAULT 7 CHECK (reminder_window_days >= 0),
  reminder_days_before TEXT NOT NULL DEFAULT '[7,1]',
  reminder_overdue INTEGER NOT NULL DEFAULT 1 CHECK (reminder_overdue IN (0,1)),
  ruleset_version TEXT NOT NULL, driving_rsvp_status TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  setup_completed_at TEXT, created_at TEXT NOT NULL, deleted_at TEXT
)''',
  'plan_member_aliases': '''
CREATE TABLE plan_member_aliases (
  plan_member_id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
  user_id TEXT, UNIQUE(plan_id,plan_member_id), UNIQUE(plan_id,user_id,plan_member_id)
)''',
  'plan_members': '''
CREATE TABLE plan_members (
  plan_id TEXT NOT NULL REFERENCES plans(id), user_id TEXT NOT NULL UNIQUE,
  plan_member_id TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK (role IN ('creator','partner')),
  joined_at TEXT NOT NULL, PRIMARY KEY(plan_id,user_id),
  FOREIGN KEY(plan_id,user_id,plan_member_id)
    REFERENCES plan_member_aliases(plan_id,user_id,plan_member_id)
)''',
  'ledger_entries': '''
CREATE TABLE ledger_entries (
  id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
  category_code TEXT NOT NULL CHECK (category_code IN
    ('catering_venue','photo_video','attire_styling','coordination','entourage_misc','buffer')),
  entry_type TEXT NOT NULL CHECK (entry_type IN
    ('standard','crew_meals','oot_fees','church_aircon','corkage','overtime','venue_power')),
  supplier_name TEXT NOT NULL CHECK (length(trim(supplier_name)) BETWEEN 1 AND 200),
  estimated_cents INTEGER, actual_cents INTEGER CHECK (actual_cents >= 0),
  pricing_mode TEXT NOT NULL CHECK (pricing_mode IN ('flat','per_head')),
  per_head_rate_cents INTEGER, manually_valued INTEGER NOT NULL DEFAULT 0
    CHECK (manually_valued IN (0,1)),
  notes TEXT CHECK (length(notes)<=2000),
  template_suggestion_id TEXT, checklist_item_id TEXT,
  created_at TEXT NOT NULL, deleted_at TEXT,
  CHECK ((pricing_mode='flat' AND estimated_cents IS NOT NULL
    AND estimated_cents >= 0 AND per_head_rate_cents IS NULL)
    OR (pricing_mode='per_head' AND estimated_cents IS NULL
    AND per_head_rate_cents IS NOT NULL AND per_head_rate_cents >= 0))
)''',
  'change_log': '''
CREATE TABLE change_log (
  id TEXT NOT NULL PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id),
  entity_type TEXT NOT NULL CHECK(length(entity_type)>0), entity_id TEXT NOT NULL,
  field_name TEXT NOT NULL CHECK(length(field_name)>0), change_group_id TEXT,
  schema_version INTEGER NOT NULL CHECK(schema_version>0),
  old_value TEXT, new_value TEXT, server_ts INTEGER,
  device_monotonic INTEGER NOT NULL CHECK(device_monotonic>=0),
  device_id TEXT NOT NULL, plan_member_id TEXT NOT NULL, created_at TEXT NOT NULL,
  FOREIGN KEY(plan_id,plan_member_id)
    REFERENCES plan_member_aliases(plan_id,plan_member_id),
  UNIQUE(id,plan_id)
)''',
  'sync_state': '''
CREATE TABLE sync_state (
  device_id TEXT NOT NULL, plan_id TEXT NOT NULL REFERENCES plans(id),
  last_pushed_server_ts INTEGER, last_pulled_server_ts INTEGER,
  device_monotonic INTEGER NOT NULL DEFAULT 0 CHECK(device_monotonic>=0),
  PRIMARY KEY(device_id,plan_id)
)''',
  'outbox': '''
CREATE TABLE outbox (
  event_id TEXT NOT NULL PRIMARY KEY,
  plan_id TEXT NOT NULL REFERENCES plans(id), device_id TEXT NOT NULL,
  queued_at TEXT NOT NULL,
  FOREIGN KEY(event_id,plan_id) REFERENCES change_log(id,plan_id)
)''',
};

// PRAGMA inventory of schema.drift v2 plus AppDatabase.beforeOpen's parity
// index. A pre-constraint v2 file is deliberately unsupported, not repaired.
// Columns are name,type,notnull,default,pk-ordinal in table order.
const _v2Columns = <String, String>{
  'plans':
      "id,TEXT,1,-,1;creator_user_id,TEXT,1,-,0;wedding_date,TEXT,1,-,0;total_budget_cents,INTEGER,1,-,0;guest_cap,INTEGER,1,-,0;region_code,TEXT,1,-,0;ceremony_type,TEXT,0,-,0;venue_type,TEXT,0,-,0;reminder_enabled,INTEGER,1,1,0;reminder_window_days,INTEGER,1,7,0;reminder_days_before,TEXT,1,'[7,1]',0;reminder_overdue,INTEGER,1,1,0;ruleset_version,TEXT,1,-,0;driving_rsvp_status,TEXT,1,-,0;is_active,INTEGER,1,1,0;setup_completed_at,TEXT,0,-,0;created_at,TEXT,1,-,0;deleted_at,TEXT,0,-,0",
  'plan_member_aliases':
      'plan_member_id,TEXT,1,-,1;plan_id,TEXT,1,-,0;user_id,TEXT,0,-,0',
  'plan_members':
      'plan_id,TEXT,1,-,1;user_id,TEXT,1,-,2;plan_member_id,TEXT,1,-,0;role,TEXT,1,-,0;joined_at,TEXT,1,-,0',
  'ledger_entries':
      'id,TEXT,1,-,1;plan_id,TEXT,1,-,0;category_code,TEXT,1,-,0;entry_type,TEXT,1,-,0;supplier_name,TEXT,1,-,0;estimated_cents,INTEGER,0,-,0;actual_cents,INTEGER,0,-,0;pricing_mode,TEXT,1,-,0;per_head_rate_cents,INTEGER,0,-,0;manually_valued,INTEGER,1,0,0;notes,TEXT,0,-,0;template_suggestion_id,TEXT,0,-,0;checklist_item_id,TEXT,0,-,0;created_at,TEXT,1,-,0;deleted_at,TEXT,0,-,0',
  'change_log':
      'id,TEXT,1,-,1;plan_id,TEXT,1,-,0;entity_type,TEXT,1,-,0;entity_id,TEXT,1,-,0;field_name,TEXT,1,-,0;change_group_id,TEXT,0,-,0;schema_version,INTEGER,1,-,0;old_value,TEXT,0,-,0;new_value,TEXT,0,-,0;server_ts,INTEGER,0,-,0;device_monotonic,INTEGER,1,-,0;device_id,TEXT,1,-,0;plan_member_id,TEXT,1,-,0;created_at,TEXT,1,-,0',
  'sync_state':
      'device_id,TEXT,1,-,1;plan_id,TEXT,1,-,2;last_pushed_server_ts,INTEGER,0,-,0;last_pulled_server_ts,INTEGER,0,-,0;device_monotonic,INTEGER,1,0,0',
  'outbox':
      'event_id,TEXT,1,-,1;plan_id,TEXT,1,-,0;device_id,TEXT,1,-,0;queued_at,TEXT,1,-,0',
};

// FK id groups preserve composite-key membership; index entries preserve
// unique origin, partial flag and ordered key columns (not covering rowid).
const _v2ForeignKeys = <String, String>{
  'plans': '',
  'plan_member_aliases': '0:plans:plan_id>id',
  'plan_members':
      '0:plan_member_aliases:plan_id>plan_id;0:plan_member_aliases:user_id>user_id;0:plan_member_aliases:plan_member_id>plan_member_id;1:plans:plan_id>id',
  'ledger_entries': '0:plans:plan_id>id',
  'change_log':
      '0:plan_member_aliases:plan_id>plan_id;0:plan_member_aliases:plan_member_id>plan_member_id;1:plans:plan_id>id',
  'sync_state': '0:plans:plan_id>id',
  'outbox':
      '0:change_log:event_id>id;0:change_log:plan_id>plan_id;1:plans:plan_id>id',
};

const _v2Indexes = <String, String>{
  'plans':
      'one_active_created_plan:1:c:1:creator_user_id;sqlite_autoindex_plans_1:1:pk:0:id',
  'plan_member_aliases':
      'sqlite_autoindex_plan_member_aliases_3:1:u:0:plan_id,user_id,plan_member_id;sqlite_autoindex_plan_member_aliases_2:1:u:0:plan_id,plan_member_id;sqlite_autoindex_plan_member_aliases_1:1:pk:0:plan_member_id',
  'plan_members':
      'one_membership_user:1:c:0:user_id;sqlite_autoindex_plan_members_3:1:pk:0:plan_id,user_id;sqlite_autoindex_plan_members_2:1:u:0:plan_member_id;sqlite_autoindex_plan_members_1:1:u:0:user_id',
  'ledger_entries': 'sqlite_autoindex_ledger_entries_1:1:pk:0:id',
  'change_log':
      'sqlite_autoindex_change_log_2:1:u:0:id,plan_id;sqlite_autoindex_change_log_1:1:pk:0:id',
  'sync_state': 'sqlite_autoindex_sync_state_1:1:pk:0:device_id,plan_id',
  'outbox': 'sqlite_autoindex_outbox_1:1:pk:0:event_id',
};

final class LegacyStoreMigrator {
  LegacyStoreMigrator(
    this.legacyFile,
    this.legacyKeys,
    this.registry,
    this.security,
  );

  final File legacyFile;
  final DatabaseKeyStore legacyKeys;
  final AccountStoreRegistry registry;
  final LocalDeviceSecurity security;

  /// Builds only a private stage; the sealed source is never upgraded or
  /// checkpointed by Drift. Publication remains blocked without native durability.
  Future<void> ensurePromoted(
    String verifiedUserId,
    AccountStoreLocation destination,
  ) async {
    try {
      await registry.withAccountLock(() async {
        await registry.requireMappedLocation(verifiedUserId, destination);
        await _ensurePromotedLocked(verifiedUserId, destination);
      });
    } on LocalStoreUnavailable {
      rethrow;
    } catch (_) {
      throw const LocalStoreUnavailable('migrationUnavailable');
    }
  }

  // The registry lock spans ownership validation, key retention and the entire
  // stage build. No resolveVerified call is made inside this non-reentrant lock.
  Future<void> _ensurePromotedLocked(
    String verifiedUserId,
    AccountStoreLocation destination,
  ) async {
    try {
      if (verifiedUserId.isEmpty ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(destination.storeId) ||
          destination.file.parent.parent.path !=
              '${registry.supportDirectory.path}/account_stores' ||
          destination.file.path !=
              '${registry.supportDirectory.path}/account_stores/${destination.storeId}/kasaran.sqlite') {
        throw const LocalStoreUnavailable('invalidDestination');
      }
      await rejectAccountPathLinks(
        registry.supportDirectory,
        destination.storeId,
      );
      await rejectAccountPathLinks(registry.supportDirectory);
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final path = '${legacyFile.path}$suffix';
        // ignore: avoid_slow_async_io
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw const LocalStoreUnavailable('unsupportedSourceSidecar');
        }
      }
      // ignore: avoid_slow_async_io
      final sourceType = await FileSystemEntity.type(
        legacyFile.path,
        followLinks: false,
      );
      // Absence alone cannot prove an existing, attributable account store.
      // Until promotion/recovery is implemented, never report completion.
      if (sourceType == FileSystemEntityType.notFound) {
        throw const LocalStoreUnavailable('sourceUnavailable');
      }
      if (sourceType != FileSystemEntityType.file) {
        throw const LocalStoreUnavailable('invalidSource');
      }
      final key = await legacyKeys.read();
      if (key == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
        throw const LocalStoreUnavailable('legacyKeyUnavailable');
      }
      final before = await legacyFile.readAsBytes();
      late final Map<String, _TableCopy> snapshot;
      final db = sqlite.sqlite3.open(
        legacyFile.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        if (db.select('PRAGMA cipher').isEmpty) {
          throw const LocalStoreUnavailable('cipherUnavailable');
        }
        db.execute("PRAGMA key = '$key'");
        db.execute('PRAGMA query_only = ON');
        db.execute('BEGIN');
        try {
          final version = db.select('PRAGMA user_version').single.columnAt(0);
          if (version != 2) {
            throw const LocalStoreUnavailable('unsupportedSourceVersion');
          }
          _authorizeV2Layout(db);
          if (db.select('PRAGMA foreign_key_check').isNotEmpty) {
            throw const LocalStoreUnavailable('invalidSourceRelations');
          }
          snapshot = _capture(db, verifiedUserId);
        } finally {
          db.execute('ROLLBACK');
        }
      } finally {
        db.close();
      }
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final path = '${legacyFile.path}$suffix';
        // ignore: avoid_slow_async_io
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw const LocalStoreUnavailable('unsupportedSourceSidecar');
        }
      }
      if (!_sameBytes(before, await legacyFile.readAsBytes())) {
        throw const LocalStoreUnavailable('sourceChanged');
      }
      await _buildStage(destination, before, snapshot, legacyKey: key);
      // Publication remains blocked until native no-replace rename and parent
      // directory durability are verified on each supported target.
      throw const LocalStoreUnavailable('durabilityUnverified');
    } on LocalStoreUnavailable {
      rethrow;
    } catch (_) {
      throw const LocalStoreUnavailable('migrationUnavailable');
    }
  }

  void _authorizeV2Layout(sqlite.Database db) {
    final objects = db.select(
      "SELECT type,name FROM sqlite_master WHERE name NOT GLOB 'sqlite_*'",
    );
    if (objects.any(
      (row) => row['type'] != 'table' && row['type'] != 'index',
    )) {
      throw const LocalStoreUnavailable('unsupportedSourceLayout');
    }
    final tables = objects
        .where((row) => row['type'] == 'table')
        .map((row) => row['name'] as String)
        .toSet();
    if (tables.length != _v2Columns.length ||
        !tables.containsAll(_v2Columns.keys)) {
      throw const LocalStoreUnavailable('unsupportedSourceLayout');
    }
    for (final table in _v2Columns.keys) {
      final definitions = db.select(
        'SELECT sql FROM sqlite_master WHERE type=? AND name=?',
        ['table', table],
      );
      if (definitions.length != 1 ||
          _normalizeV2Sql(definitions.single['sql'] as String) !=
              _normalizeV2Sql(_v2TableSql[table]!)) {
        throw const LocalStoreUnavailable('unsupportedSourceLayout');
      }
      final columns = db
          .select('PRAGMA table_xinfo($table)')
          .map((row) {
            if (row['hidden'] != 0) {
              throw const LocalStoreUnavailable('unsupportedSourceLayout');
            }
            return '${row['name']},${row['type']},${row['notnull']},${row['dflt_value'] ?? '-'},${row['pk']}';
          })
          .join(';');
      final foreignKeys = db
          .select('PRAGMA foreign_key_list($table)')
          .map((row) {
            if (row['on_update'] != 'NO ACTION' ||
                row['on_delete'] != 'NO ACTION' ||
                row['match'] != 'NONE') {
              throw const LocalStoreUnavailable('unsupportedSourceLayout');
            }
            return '${row['id']}:${row['table']}:${row['from']}>${row['to']}';
          })
          .join(';');
      final indexes = db
          .select('PRAGMA index_list($table)')
          .map((row) {
            final name = row['name'] as String;
            final keys = db
                .select('PRAGMA index_xinfo($name)')
                .where((part) => part['key'] == 1)
                .map((part) {
                  if (part['cid'] == -2 ||
                      part['coll'] != 'BINARY' ||
                      part['desc'] != 0) {
                    throw const LocalStoreUnavailable(
                      'unsupportedSourceLayout',
                    );
                  }
                  return part['name'] as String;
                })
                .join(',');
            return '$name:${row['unique']}:${row['origin']}:${row['partial']}:$keys';
          })
          .join(';');
      if (columns != _v2Columns[table] ||
          foreignKeys != _v2ForeignKeys[table] ||
          indexes != _v2Indexes[table]) {
        throw const LocalStoreUnavailable('unsupportedSourceLayout');
      }
    }
    // PRAGMA reports only that an index is partial, not its predicate.
    final predicate = db.select(
      "SELECT sql FROM sqlite_master WHERE type='index' AND name='one_active_created_plan'",
    );
    if (predicate.length != 1 ||
        (predicate.single['sql'] as String)
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ')
                .toLowerCase() !=
            'create unique index one_active_created_plan on plans (creator_user_id) where is_active = 1') {
      throw const LocalStoreUnavailable('unsupportedSourceLayout');
    }
  }

  // Drift quotes identifier names in sqlite_master; schema.drift does not.
  // Ignore formatting outside string literals, never ignore SQL semantics.
  String _normalizeV2Sql(String source) {
    final normalized = StringBuffer();
    var inString = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == "'") {
        normalized.write(char);
        if (inString && i + 1 < source.length && source[i + 1] == "'") {
          normalized.write(source[++i]);
        } else {
          inString = !inString;
        }
      } else if (inString) {
        normalized.write(char);
      } else if (char != '"' && !RegExp(r'\s').hasMatch(char)) {
        normalized.write(char.toLowerCase());
      }
    }
    return normalized.toString();
  }

  // All reads share the source's read transaction. No table is reconstructed
  // from domain models: SQLite values (including int64 and JSON text) survive.
  Map<String, _TableCopy> _capture(sqlite.Database db, String userId) {
    final memberships = db.select(
      '''
      SELECT m.plan_id FROM plan_members m
      JOIN plans p ON p.id=m.plan_id AND p.deleted_at IS NULL
      JOIN plan_member_aliases a ON a.plan_id=m.plan_id
        AND a.user_id=m.user_id AND a.plan_member_id=m.plan_member_id
      WHERE m.user_id=?
    ''',
      [userId],
    );
    if (memberships.isEmpty ||
        memberships.length !=
            db
                .select(
                  '''
                  SELECT m.plan_id FROM plan_members m
              JOIN plans p ON p.id=m.plan_id AND p.deleted_at IS NULL
              WHERE m.user_id=?''',
                  [userId],
                )
                .length) {
      throw const LocalStoreUnavailable('membershipUnavailable');
    }
    final ids = memberships.map((row) => row['plan_id'] as String).toList();
    if (ids.toSet().length != ids.length) {
      throw const LocalStoreUnavailable('membershipUnavailable');
    }
    final marks = List.filled(ids.length, '?').join(',');
    // Every pending event for a selected plan needs one live author alias.
    // Device identity and creator identity never select the queue owner.
    final pending = db.select('''
      SELECT o.event_id, o.plan_id, o.device_id, c.id AS change_id,
        c.device_id AS change_device, a.user_id AS author,
        m.plan_member_id AS live_member
      FROM outbox o
      LEFT JOIN change_log c ON c.id=o.event_id AND c.plan_id=o.plan_id
      LEFT JOIN plan_member_aliases a ON a.plan_id=c.plan_id
        AND a.plan_member_id=c.plan_member_id
      LEFT JOIN plan_members m ON m.plan_id=a.plan_id
        AND m.user_id=a.user_id AND m.plan_member_id=a.plan_member_id
      WHERE o.plan_id IN ($marks)
    ''', ids);
    final expectedPending =
        db
                .select(
                  'SELECT COUNT(*) AS n FROM outbox WHERE plan_id IN ($marks)',
                  ids,
                )
                .single['n']
            as int;
    final seenEvents = <String>{};
    for (final row in pending) {
      final eventId = row['event_id'] as String;
      // The LEFT JOIN must be one-to-one at every hop. A multiplying join
      // cannot be used to guess an owner or silently copy an event twice.
      if (!seenEvents.add(eventId) ||
          row['change_id'] == null ||
          row['author'] == null ||
          row['live_member'] == null ||
          row['device_id'] != row['change_device']) {
        throw const LocalStoreUnavailable('ambiguousPendingAuthor');
      }
    }
    if (pending.length != expectedPending ||
        seenEvents.length != expectedPending) {
      throw const LocalStoreUnavailable('ambiguousPendingAuthor');
    }
    final ownEvents = pending
        .where((row) => row['author'] == userId)
        .map((row) => row['event_id'] as String)
        .toList();
    const tables = [
      'plans',
      'plan_member_aliases',
      'plan_members',
      'ledger_entries',
      'change_log',
      'sync_state',
      'outbox',
    ];
    final result = <String, _TableCopy>{};
    for (final table in tables) {
      final columns = db
          .select('PRAGMA table_info($table)')
          .map((row) => row['name'] as String)
          .toList();
      final where = table == 'plans'
          ? 'id IN ($marks)'
          : table == 'outbox'
          ? ownEvents.isEmpty
                ? '0'
                : 'event_id IN (${List.filled(ownEvents.length, '?').join(',')})'
          : 'plan_id IN ($marks)';
      final arguments = table == 'outbox' ? ownEvents : ids;
      final rows = db.select(
        'SELECT * FROM $table WHERE $where ORDER BY rowid',
        table == 'outbox' && ownEvents.isEmpty ? [] : arguments,
      );
      result[table] = _TableCopy(columns, [
        for (final row in rows) [for (final column in columns) row[column]],
      ]);
    }
    return result;
  }

  Future<void> _buildStage(
    AccountStoreLocation destination,
    List<int> sourceBytes,
    Map<String, _TableCopy> snapshot, {
    required String legacyKey,
  }) async {
    final finalDirectory = destination.file.parent;
    final stage = Directory(
      '${finalDirectory.parent.path}/.stage-${destination.storeId}',
    );
    // Never replace a published destination or reset a retained private stage.
    // ignore: avoid_slow_async_io
    if (await FileSystemEntity.type(finalDirectory.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const LocalStoreUnavailable('destinationConflict');
    }
    // ignore: avoid_slow_async_io
    final stageType = await FileSystemEntity.type(
      stage.path,
      followLinks: false,
    );
    if (stageType != FileSystemEntityType.notFound) {
      if (stageType != FileSystemEntityType.directory) {
        throw const LocalStoreUnavailable('invalidRetainedStage');
      }
      await _verifyRetainedStage(
        destination,
        stage,
        sourceBytes,
        snapshot,
        legacyKey: legacyKey,
      );
      return;
    }
    final retained = await destination.keys.read();
    if (retained != null) {
      throw const LocalStoreUnavailable('destinationKeyConflict');
    }
    final random = Random.secure();
    final fresh = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    if (fresh == legacyKey) {
      throw const LocalStoreUnavailable('stageKeyNotIndependent');
    }
    await destination.keys.write(fresh);
    await stage.create();
    await security.protectDirectory(stage.path);
    final stageFile = File('${stage.path}/kasaran.sqlite');
    // Keep recovery stages at the canonical source version. They remain private
    // v2 evidence, not published current account stores or an upgrade shortcut.
    final db = sqlite.sqlite3.open(stageFile.path);
    try {
      if (db.select('PRAGMA cipher').isEmpty) {
        throw const LocalStoreUnavailable('cipherUnavailable');
      }
      db.execute("PRAGMA key = '$fresh'");
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final ddl in _v2TableSql.values) {
          db.execute(ddl);
        }
        db.execute('CREATE UNIQUE INDEX one_membership_user ON plan_members(user_id)');
        db.execute('CREATE UNIQUE INDEX one_active_created_plan ON plans (creator_user_id) WHERE is_active = 1');
        db.execute('PRAGMA user_version = 2');
        for (final copy in snapshot.entries) {
          final table = copy.key;
          final values = copy.value;
          final placeholders = List.filled(
            values.columns.length,
            '?',
          ).join(',');
          final insert = db.prepare(
            'INSERT INTO $table '
            '(${values.columns.join(',')}) VALUES ($placeholders)',
          );
          try {
            for (final row in values.rows) {
              insert.execute(row);
            }
          } finally {
            insert.close();
          }
        }
        if (db.select('PRAGMA foreign_key_check').isNotEmpty) {
          throw const LocalStoreUnavailable('invalidStageRelations');
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
      _verifyStage(db, snapshot);
    } finally {
      db.close();
    }
    await security.protectFile(stageFile.path);
    for (final suffix in ['-journal', '-wal', '-shm']) {
      // ignore: avoid_slow_async_io
      if (await FileSystemEntity.type(
            '${stageFile.path}$suffix',
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        throw const LocalStoreUnavailable('stageSidecar');
      }
    }
    if (!_sameBytes(sourceBytes, await legacyFile.readAsBytes())) {
      throw const LocalStoreUnavailable('sourceChanged');
    }
    final manifest = File('${stage.path}/migration-manifest.json');
    await manifest.writeAsString(
      jsonEncode({
        'version': 1,
        'copy_format_version': 1,
        'source_fingerprint': sha256.convert(sourceBytes).toString(),
        'store_id': destination.storeId,
      }),
      flush: true,
    );
    await security.protectFile(manifest.path);
    // Reopen under the retained independent key and verify copied values.
    final reopened = sqlite.sqlite3.open(
      stageFile.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      reopened.execute("PRAGMA key = '$fresh'");
      reopened.execute('PRAGMA query_only = ON');
      _verifyStage(reopened, snapshot);
    } finally {
      reopened.close();
    }
  }

  /// A complete stage may be inspected again, never repaired or published.
  /// Recovery requires the same secure mapping, independent key, immutable
  /// source fingerprint, schema and every copied value, including queue author.
  Future<void> _verifyRetainedStage(
    AccountStoreLocation destination,
    Directory stage,
    List<int> sourceBytes,
    Map<String, _TableCopy> snapshot, {
    required String legacyKey,
  }) async {
    final dbFile = File('${stage.path}/kasaran.sqlite');
    final manifest = File('${stage.path}/migration-manifest.json');
    await rejectAccountPathLinks(stage);
    final entries = await stage.list(followLinks: false).toList();
    final expectedPaths = {dbFile.path, manifest.path};
    if (entries.length != expectedPaths.length ||
        entries.any((entry) => !expectedPaths.contains(entry.path))) {
      throw const LocalStoreUnavailable('invalidRetainedStage');
    }
    for (final file in [dbFile, manifest]) {
      // ignore: avoid_slow_async_io
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const LocalStoreUnavailable('invalidRetainedStage');
      }
    }
    final retainedKey = await destination.keys.read();
    if (retainedKey == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(retainedKey)) {
      throw const LocalStoreUnavailable('stageKeyUnavailable');
    }
    if (retainedKey == legacyKey) {
      throw const LocalStoreUnavailable('stageKeyNotIndependent');
    }
    final manifestBytes = await manifest.readAsBytes();
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(manifestBytes));
    } on FormatException {
      throw const LocalStoreUnavailable('stageManifestMismatch');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 4 ||
        decoded['version'] is! int ||
        decoded['version'] != 1 ||
        decoded['copy_format_version'] is! int ||
        decoded['copy_format_version'] != 1 ||
        decoded['source_fingerprint'] !=
            sha256.convert(sourceBytes).toString() ||
        decoded['store_id'] != destination.storeId) {
      throw const LocalStoreUnavailable('stageManifestMismatch');
    }
    final before = await dbFile.readAsBytes();
    final db = sqlite.sqlite3.open(dbFile.path, mode: sqlite.OpenMode.readOnly);
    try {
      if (db.select('PRAGMA cipher').isEmpty) {
        throw const LocalStoreUnavailable('cipherUnavailable');
      }
      db.execute("PRAGMA key = '$retainedKey'");
      db.execute('PRAGMA query_only = ON');
      db.execute('BEGIN');
      try {
        _authorizeV2Layout(db);
        _verifyStage(db, snapshot);
      } finally {
        db.execute('ROLLBACK');
      }
    } finally {
      db.close();
    }
    if (!_sameBytes(before, await dbFile.readAsBytes()) ||
        !_sameBytes(manifestBytes, await manifest.readAsBytes()) ||
        !_sameBytes(sourceBytes, await legacyFile.readAsBytes())) {
      throw const LocalStoreUnavailable('sourceChanged');
    }
  }

  void _verifyStage(sqlite.Database db, Map<String, _TableCopy> snapshot) {
    if (db.select('PRAGMA user_version').single.columnAt(0) != 2 ||
        db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw const LocalStoreUnavailable('invalidStage');
    }
    for (final entry in snapshot.entries) {
      final actual = db.select('SELECT * FROM ${entry.key} ORDER BY rowid');
      final expected = entry.value.rows;
      if (actual.length != expected.length) {
        throw const LocalStoreUnavailable('stageContentMismatch');
      }
      for (var i = 0; i < actual.length; i++) {
        for (var j = 0; j < entry.value.columns.length; j++) {
          if (jsonEncode(actual[i][entry.value.columns[j]]) !=
              jsonEncode(expected[i][j])) {
            throw const LocalStoreUnavailable('stageContentMismatch');
          }
        }
      }
    }
  }

  bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
