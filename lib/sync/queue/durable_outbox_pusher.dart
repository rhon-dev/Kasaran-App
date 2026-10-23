import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

/// Counts only, never event payloads, account identifiers or credentials.
final class DurablePushResult {
  const DurablePushResult({
    required this.attempted,
    required this.acknowledged,
  });
  final int attempted;
  final int acknowledged;
}

final class DurableOutboxException implements Exception {
  const DurableOutboxException(this.code);
  final String code;
  @override
  String toString() => 'DurableOutboxException: $code';
}

final class _Pending {
  const _Pending(this.event, this.queue, this.wire);
  final Map<String, Object?> event;
  final Map<String, Object?> queue;
  final SyncEvent wire;
}

bool _same(
  Map<String, Object?> a,
  Map<String, Object?> b, {
  bool ignoreStamp = false,
}) =>
    a.length == b.length &&
    a.entries.every(
      (e) => (ignoreStamp && e.key == 'server_ts') || b[e.key] == e.value,
    );

/// A single explicit push, admitted and drained by the account-store owner.
/// This service is deliberately not instantiated by application startup.
final class DurableOutboxPusher {
  const DurableOutboxPusher(this.coordinator, this.transport);
  final AccountStoreCoordinator coordinator;
  final HttpSyncTransport transport;

  Future<DurablePushResult> pushOnce(LedgerActor actor) async {
    try {
      if (!isSyncUuid(actor.deviceId)) {
        throw const DurableOutboxException('invalid_device');
      }
      return await coordinator.withAccount(
        (lease) => lease.run((db) async {
          final writer = LocalLedgerWriter(db, identity: coordinator.identity);
          final session = coordinator.identity.capture();
          if (session == null) {
            throw const DurableOutboxException('session_changed');
          }
          void check() {
            if (lease.generation != coordinator.generation ||
                lease.userId != session.userId) {
              throw const DurableOutboxException('session_changed');
            }
            writer.requireSameSession(actor, session);
          }

          check();
          final pending = await db.transaction(() async {
            await writer.requireLocalMembership(actor);
            check();
            // LEFT JOIN is essential: a corrupt matching dangling queue row must
            // fail, not disappear. Rows owned by another original author/device
            // are excluded without rewriting or adopting them.
            final selected = await db
                .customSelect(
                  '''
SELECT q.event_id AS queue_event_id,q.plan_id AS queue_plan_id,
q.device_id AS queue_device_id,q.queued_at AS queue_queued_at,c.*
FROM outbox q LEFT JOIN change_log c ON c.id=q.event_id
WHERE q.plan_id=? AND q.device_id=?
AND (c.id IS NULL OR (c.plan_member_id=? AND c.device_id=?))
ORDER BY c.device_monotonic,q.event_id LIMIT 100''',
                  variables: [
                    Variable(actor.planId),
                    Variable(actor.deviceId),
                    Variable(actor.planMemberId),
                    Variable(actor.deviceId),
                  ],
                )
                .get();
            check();
            final snapshots = <_Pending>[];
            for (final row in selected) {
              final data = Map<String, Object?>.from(row.data);
              final queue = <String, Object?>{
                'event_id': data.remove('queue_event_id'),
                'plan_id': data.remove('queue_plan_id'),
                'device_id': data.remove('queue_device_id'),
                'queued_at': data.remove('queue_queued_at'),
              };
              if (data['id'] == null || data['plan_id'] != actor.planId) {
                throw const DurableOutboxException('invalid_pending_event');
              }
              final event = Map<String, Object?>.unmodifiable(data);
              final persistedStamp = event['server_ts'];
              if (persistedStamp != null &&
                  (persistedStamp is! int || persistedStamp < 1)) {
                throw const DurableOutboxException('invalid_pending_event');
              }
              final source = Map<String, Object?>.from(event)
                ..remove('server_ts');
              source['old_value'] = event['old_value'] == null
                  ? null
                  : jsonDecode(event['old_value']! as String);
              source['new_value'] = event['new_value'] == null
                  ? null
                  : jsonDecode(event['new_value']! as String);
              source['device_monotonic'] = '${event['device_monotonic']}';
              snapshots.add(
                _Pending(
                  event,
                  Map.unmodifiable(queue),
                  SyncEvent.fromJson(source),
                ),
              );
            }
            if (snapshots.isNotEmpty) {
              await _requireState(db, actor);
              check();
            }
            check();
            return snapshots;
          });
          check();
          if (pending.isEmpty) {
            return const DurablePushResult(attempted: 0, acknowledged: 0);
          }
          final result = await transport.push(
            actor.planId,
            pending.map((p) => p.wire).toList(),
            requiredSession: SyncSessionBinding(
              userId: session.userId,
              marker: session.marker,
            ),
          );
          check();
          await db.transaction(() async {
            await writer.requireLocalMembership(actor);
            check();
            await _requireState(db, actor);
            check();
            for (final p in pending) {
              final stamp = result.accepted[p.wire.id];
              if (stamp == null) continue;
              await _ack(db, p, stamp, check);
              check();
              await db.customStatement(
                '''
UPDATE sync_state
SET last_pushed_server_ts=CASE WHEN last_pushed_server_ts IS NULL OR last_pushed_server_ts<?
THEN ? ELSE last_pushed_server_ts END WHERE plan_id=? AND device_id=?''',
                [stamp, stamp, actor.planId, actor.deviceId],
              );
              check();
            }
            check();
          });
          check();
          return DurablePushResult(
            attempted: pending.length,
            acknowledged: result.accepted.length,
          );
        }),
      );
    } on DurableOutboxException {
      rethrow;
    } on SyncTransportException {
      rethrow;
    } on SyncProtocolException {
      rethrow;
    } on SyncUpdateRequired {
      rethrow;
    } catch (_) {
      // SQLite/JSON/platform failures can include source values; never leak them.
      throw const DurableOutboxException('local_operation_failed');
    }
  }

  Future<void> _requireState(AppDatabase db, LedgerActor actor) async {
    final state = await db
        .customSelect(
          'SELECT 1 FROM sync_state WHERE plan_id=? AND device_id=?',
          variables: [Variable(actor.planId), Variable(actor.deviceId)],
        )
        .getSingleOrNull();
    if (state == null) throw const DurableOutboxException('invalid_sync_state');
  }

  Future<void> _ack(
    AppDatabase db,
    _Pending p,
    int stamp,
    void Function() check,
  ) async {
    final event = await db
        .customSelect(
          'SELECT * FROM change_log WHERE id=?',
          variables: [Variable(p.wire.id)],
        )
        .getSingleOrNull();
    check();
    final queue = await db
        .customSelect(
          'SELECT * FROM outbox WHERE event_id=?',
          variables: [Variable(p.wire.id)],
        )
        .getSingleOrNull();
    check();
    if (event == null || !_same(p.event, event.data, ignoreStamp: true)) {
      throw const DurableOutboxException('snapshot_changed');
    }
    if (queue == null) {
      if (event.data['server_ts'] != stamp ||
          (p.event['server_ts'] != null && p.event['server_ts'] != stamp)) {
        throw const DurableOutboxException('snapshot_changed');
      }
      return; // Concurrent identical full-event acknowledgment, not absence alone.
    }
    if (!_same(p.queue, queue.data) ||
        event.data['server_ts'] != p.event['server_ts'] ||
        (p.event['server_ts'] != null && p.event['server_ts'] != stamp)) {
      throw const DurableOutboxException('snapshot_changed');
    }
    await db.customStatement('UPDATE change_log SET server_ts=? WHERE id=?', [
      stamp,
      p.wire.id,
    ]);
    check();
    await db.customStatement('DELETE FROM outbox WHERE event_id=?', [
      p.wire.id,
    ]);
    check();
  }
}
