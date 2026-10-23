import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/sync/replay/replay_engine.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';

/// Counts/classifications only, never financial sources or session identifiers.
final class DurableProjectionResult {
  const DurableProjectionResult({
    required this.projected,
    required this.needsAttention,
  });
  final int projected;
  final bool needsAttention;
}

final class DurableProjectionException implements Exception {
  const DurableProjectionException(this.code);
  final String code;
  @override
  String toString() => 'DurableProjectionException: $code';
}

/// Explicit ledger-only rebuild. Not scheduled or connected to app startup.
final class DurableProjectionRebuilder {
  const DurableProjectionRebuilder(this.coordinator);
  final AccountStoreCoordinator coordinator;

  Future<DurableProjectionResult> rebuild(LedgerActor actor) async {
    try {
      if (!isSyncUuid(actor.deviceId)) {
        throw const DurableProjectionException('invalid_device');
      }
      late void Function() checkResult;
      final result = await coordinator.withAccount(
        (lease) => lease.run((db) async {
          final writer = LocalLedgerWriter(db, identity: coordinator.identity);
          final session = coordinator.identity.capture();
          if (session == null) {
            throw const DurableProjectionException('session_changed');
          }
          void check() {
            if (lease.generation != coordinator.generation ||
                lease.userId != session.userId) {
              throw const DurableProjectionException('session_changed');
            }
            writer.requireSameSession(actor, session);
          }

          checkResult = check;
          check();
          final result = await db.transaction(() async {
            await writer.requireLocalMembership(actor);
            check();
            final states = await db
                .customSelect(
                  'SELECT * FROM sync_state WHERE plan_id=?',
                  variables: [Variable(actor.planId)],
                )
                .get();
            check();
            for (final row in states) {
              final state = row.data;
              bool validCounter(Object? value) => value is int && value >= 0;
              if (!isSyncUuid(state['device_id']) ||
                  !validCounter(state['device_monotonic']) ||
                  (state['last_pushed_server_ts'] != null &&
                      !validCounter(state['last_pushed_server_ts'])) ||
                  (state['last_pulled_server_ts'] != null &&
                      !validCounter(state['last_pulled_server_ts']))) {
                throw const DurableProjectionException('invalid_sync_state');
              }
            }
            final inbox = await db
                .customSelect(
                  'SELECT * FROM sync_inbox WHERE plan_id=?',
                  variables: [Variable(actor.planId)],
                )
                .get();
            check();
            final accepted = <SyncEvent>[];
            for (final row in inbox) {
              final event = SyncEvent.fromJson(
                readSyncObject(jsonDecode(row.data['raw_event']! as String)),
                requireServerTimestamp: true,
              );
              if (event.id != row.data['event_id'] ||
                  event.planId != actor.planId ||
                  event.serverTimestamp != row.data['server_ts']) {
                throw const DurableProjectionException('invalid_inbox');
              }
              accepted.add(event);
            }
            final acknowledged = await db
                .customSelect(
                  'SELECT * FROM change_log WHERE plan_id=? AND server_ts IS NOT NULL',
                  variables: [Variable(actor.planId)],
                )
                .get();
            check();
            accepted.addAll(acknowledged.map((row) => _localEvent(row.data)));
            final queues = await db
                .customSelect(
                  '''
SELECT q.event_id AS queue_id,q.plan_id AS queue_plan,q.device_id AS queue_device,
q.queued_at AS queue_time,c.* FROM outbox q LEFT JOIN change_log c ON c.id=q.event_id
WHERE q.plan_id=? OR c.plan_id=?''',
                  variables: [Variable(actor.planId), Variable(actor.planId)],
                )
                .get();
            check();
            for (final row in queues) {
              final q = row.data;
              if (q['id'] == null ||
                  q['id'] != q['queue_id'] ||
                  q['plan_id'] != q['queue_plan'] ||
                  q['device_id'] != q['queue_device'] ||
                  !_timestamp(q['queue_time'])) {
                throw const DurableProjectionException('invalid_queue');
              }
              // Exclusion from this device's overlay is not permission to hide
              // corrupt persisted queue sources. Validate, never adopt them.
              final original = Map<String, Object?>.of(q)
                ..remove('queue_id')
                ..remove('queue_plan')
                ..remove('queue_device')
                ..remove('queue_time');
              _localEvent(original);
            }
            final orphan = await db
                .customSelect(
                  '''
SELECT 1 FROM change_log c LEFT JOIN outbox q ON q.event_id=c.id
WHERE c.plan_id=? AND c.device_id=? AND c.plan_member_id=?
AND c.server_ts IS NULL AND q.event_id IS NULL LIMIT 1''',
                  variables: [
                    Variable(actor.planId),
                    Variable(actor.deviceId),
                    Variable(actor.planMemberId),
                  ],
                )
                .get();
            check();
            if (orphan.isNotEmpty) {
              throw const DurableProjectionException('invalid_queue');
            }
            final pendingRows = await db
                .customSelect(
                  '''
SELECT c.* FROM outbox q JOIN change_log c ON c.id=q.event_id
WHERE q.plan_id=? AND q.device_id=? AND c.plan_id=q.plan_id
AND c.device_id=q.device_id AND c.plan_member_id=? AND c.server_ts IS NULL''',
                  variables: [
                    Variable(actor.planId),
                    Variable(actor.deviceId),
                    Variable(actor.planMemberId),
                  ],
                )
                .get();
            check();
            final pending = [
              for (final row in pendingRows) _localEvent(row.data),
            ];
            if (pending.isNotEmpty) {
              final state = await db
                  .customSelect(
                    'SELECT * FROM sync_state WHERE plan_id=? AND device_id=?',
                    variables: [
                      Variable(actor.planId),
                      Variable(actor.deviceId),
                    ],
                  )
                  .getSingleOrNull();
              check();
              final counter = state?.data['device_monotonic'];
              if (counter is! int ||
                  counter < 0 ||
                  pending.any((event) => event.deviceMonotonic > counter)) {
                throw const DurableProjectionException('invalid_sync_state');
              }
            }
            final replay = ReplayEngine.rebuild(accepted, provisional: pending);
            if (replay.issues.any(
              (issue) => issue.kind == ReplayIssueKind.missingCreate,
            )) {
              // A supported orphan cannot authorize even partial publication.
              throw const DurableProjectionException('incomplete_history');
            }
            if (replay.ledgerEntries.values.any((row) => !row.isSourceValid) ||
                replay.issues.any(
                  (issue) => switch (issue.kind) {
                    ReplayIssueKind.invalidSnapshot ||
                    ReplayIssueKind.invalidValue ||
                    ReplayIssueKind.invalidSource => true,
                    _ => false,
                  },
                )) {
              throw const DurableProjectionException('invalid_projection');
            }
            final previous = await db
                .customSelect(
                  'SELECT id FROM ledger_entries WHERE plan_id=?',
                  variables: [Variable(actor.planId)],
                )
                .get();
            check();
            if (previous.any(
              (row) => !replay.ledgerEntries.containsKey(row.data['id']),
            )) {
              // There is no versioned checkpoint proving omitted creation history.
              throw const DurableProjectionException('incomplete_history');
            }
            await db.customStatement(
              'DELETE FROM ledger_entries WHERE plan_id=?',
              [actor.planId],
            );
            check();
            for (final snapshot in replay.ledgerEntries.values) {
              final row = snapshot.toJson();
              await db.customStatement(
                '''
INSERT INTO ledger_entries
(id,plan_id,category_code,entry_type,supplier_name,estimated_cents,actual_cents,
pricing_mode,per_head_rate_cents,manually_valued,notes,template_suggestion_id,
checklist_item_id,created_at,deleted_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
                [for (final key in _columns) row[key]],
              );
              check();
            }
            check();
            return DurableProjectionResult(
              projected: replay.ledgerEntries.length,
              needsAttention: replay.needsAttention,
            );
          });
          check(); // COMMIT is awaited while the counted lease is still active.
          return result;
        }),
      );
      // The coordinator completion itself is another asynchronous boundary.
      checkResult();
      return result;
    } on DurableProjectionException {
      rethrow;
    } catch (_) {
      // SQLite, JSON and reducer errors may carry private source values.
      throw const DurableProjectionException('local_operation_failed');
    }
  }
}

bool _timestamp(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$',
      ).hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
      parsed.isUtc &&
      parsed.toIso8601String().substring(0, 19) == value.substring(0, 19);
}

SyncEvent _localEvent(Map<String, Object?> row) {
  final data = Map<String, Object?>.of(row)..remove('server_ts');
  data['old_value'] = row['old_value'] == null
      ? null
      : jsonDecode(row['old_value']! as String);
  data['new_value'] = row['new_value'] == null
      ? null
      : jsonDecode(row['new_value']! as String);
  data['device_monotonic'] = '${row['device_monotonic']}';
  if (row['server_ts'] != null) data['server_ts'] = '${row['server_ts']}';
  return SyncEvent.fromJson(
    data,
    requireServerTimestamp: row['server_ts'] != null,
  );
}

const _columns = [
  'id',
  'plan_id',
  'category_code',
  'entry_type',
  'supplier_name',
  'estimated_cents',
  'actual_cents',
  'pricing_mode',
  'per_head_rate_cents',
  'manually_valued',
  'notes',
  'template_suggestion_id',
  'checklist_item_id',
  'created_at',
  'deleted_at',
];
