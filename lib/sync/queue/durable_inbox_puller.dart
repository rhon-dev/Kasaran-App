import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

/// Safe metadata only: never publishes incoming payloads before later replay.
final class DurablePullResult {
  const DurablePullResult({
    required this.received,
    required this.cursor,
    required this.hasMore,
  });
  final int received, cursor;
  final bool hasMore;
}

final class DurableInboxException implements Exception {
  const DurableInboxException(this.code);
  final String code;
  @override
  String toString() => 'DurableInboxException: $code';
}

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameJson(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num && (a is int) != (b is int)) return false;
  return a == b;
}

/// One explicit, counted-account-leased page. Deliberately not startup-wired.
final class DurableInboxPuller {
  const DurableInboxPuller(this.coordinator, this.transport);
  final AccountStoreCoordinator coordinator;
  final HttpSyncTransport transport;
  Future<DurablePullResult> pullOnce(
    LedgerActor actor, {
    int limit = 100,
  }) async {
    try {
      if (!isSyncUuid(actor.deviceId) || limit < 1 || limit > 1000) {
        throw const DurableInboxException('invalid_request');
      }
      return await coordinator.withAccount(
        (lease) => lease.run((db) async {
          final writer = LocalLedgerWriter(db, identity: coordinator.identity);
          final session = coordinator.identity.capture();
          if (session == null) {
            throw const DurableInboxException('session_changed');
          }
          void check() {
            if (lease.generation != coordinator.generation ||
                lease.userId != session.userId) {
              throw const DurableInboxException('session_changed');
            }
            writer.requireSameSession(actor, session);
          }

          check();
          final cursor = await db.transaction(() async {
            await writer.requireLocalMembership(actor);
            check();
            final value = await _cursor(db, actor);
            check();
            return value;
          });
          check();
          final page = await transport.pull(
            actor.planId,
            cursor: cursor,
            limit: limit,
            requiredSession: SyncSessionBinding(
              userId: session.userId,
              marker: session.marker,
            ),
          );
          check();
          await db.transaction(() async {
            await writer.requireLocalMembership(actor);
            check();
            final current = await _cursor(db, actor);
            check();
            if (current != cursor && current != page.nextCursor) {
              throw const DurableInboxException('cursor_changed');
            }
            for (final event in page.rows) {
              final retained = await db
                  .customSelect(
                    'SELECT * FROM sync_inbox WHERE event_id=?',
                    variables: [Variable(event.id)],
                  )
                  .getSingleOrNull();
              check();
              if (retained != null) {
                if (retained.data['plan_id'] != event.planId ||
                    retained.data['server_ts'] != event.serverTimestamp ||
                    !_sameJson(
                      jsonDecode(retained.data['raw_event']! as String),
                      event.data,
                    )) {
                  throw const DurableInboxException('event_conflict');
                }
                continue;
              }
              // A stale request may only recognize a fully committed identical page,
              // never fill gaps under somebody else's published cursor.
              if (current != cursor) {
                throw const DurableInboxException('cursor_changed');
              }
              await db.customStatement(
                'INSERT INTO sync_inbox(event_id,plan_id,server_ts,raw_event) VALUES(?,?,?,?)',
                [
                  event.id,
                  event.planId,
                  event.serverTimestamp,
                  jsonEncode(event.data),
                ],
              );
              check();
            }
            if (page.rows.isEmpty) {
              check();
              return;
            }
            await db.customStatement(
              'INSERT INTO sync_state(device_id,plan_id,last_pulled_server_ts) VALUES(?,?,?) ON CONFLICT(device_id,plan_id) DO UPDATE SET last_pulled_server_ts=excluded.last_pulled_server_ts',
              [actor.deviceId, actor.planId, page.nextCursor],
            );
            check();
          });
          check();
          return DurablePullResult(
            received: page.rows.length,
            cursor: page.nextCursor,
            hasMore: page.hasMore,
          );
        }),
      );
    } on DurableInboxException {
      rethrow;
    } on SyncTransportException {
      rethrow;
    } on SyncProtocolException {
      rethrow;
    } on SyncUpdateRequired {
      rethrow;
    } catch (_) {
      throw const DurableInboxException('local_operation_failed');
    }
  }

  Future<int> _cursor(AppDatabase db, LedgerActor actor) async {
    final state = await db
        .customSelect(
          'SELECT last_pulled_server_ts FROM sync_state WHERE plan_id=? AND device_id=?',
          variables: [Variable(actor.planId), Variable(actor.deviceId)],
        )
        .getSingleOrNull();
    if (state == null) return 0;
    final value = state.data['last_pulled_server_ts'];
    if (value == null) return 0;
    if (value is! int || value < 0) {
      throw const DurableInboxException('invalid_cursor');
    }
    return value;
  }
}
