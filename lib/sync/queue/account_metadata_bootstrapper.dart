import 'package:drift/drift.dart' show Variable;
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

final class MetadataBootstrapException implements Exception {
  const MetadataBootstrapException(this.code);
  final String code;
  @override
  String toString() => 'MetadataBootstrapException: $code';
}

/// Explicit one-shot dependency, not a startup hook or ongoing authority refresh.
/// Caller supplies device identity; no projection, history or cursor is seeded.
final class AccountMetadataBootstrapper {
  const AccountMetadataBootstrapper(this.coordinator, this.transport);
  final AccountStoreCoordinator coordinator;
  final HttpBootstrapTransport transport;
  Future<LedgerActor> bootstrap({
    required String planId,
    required String deviceId,
  }) async {
    try {
      if (!isSyncUuid(planId) || !isSyncUuid(deviceId)) {
        throw const MetadataBootstrapException('invalid_request');
      }
      void Function()? finalCheck;
      final result = await coordinator.withAccount(
        (lease) => lease.run((db) async {
          final session = coordinator.identity.capture();
          if (session == null || !isSyncUuid(session.userId)) {
            throw const MetadataBootstrapException('session_changed');
          }
          void check() {
            final current = coordinator.identity.capture();
            if (lease.generation != coordinator.generation ||
                lease.userId != session.userId ||
                current == null ||
                current.userId != session.userId ||
                !identical(current.marker, session.marker)) {
              throw const MetadataBootstrapException('session_changed');
            }
          }

          finalCheck = check;
          check();
          final snapshot = await transport.fetch(
            planId,
            requiredSession: SyncSessionBinding(
              userId: session.userId,
              marker: session.marker,
            ),
          );
          check();
          final actor = LedgerActor(
            planId: planId,
            userId: session.userId,
            planMemberId: snapshot.member['plan_member_id']! as String,
            deviceId: deviceId,
          );
          await db.transaction(() async {
            check();
            final retained = await db
                .customSelect(
                  'SELECT * FROM plans WHERE id=?',
                  variables: [Variable(planId)],
                )
                .getSingleOrNull();
            check();
            if (retained != null) {
              final aliases = await db
                  .customSelect(
                    'SELECT * FROM plan_member_aliases WHERE plan_id=?',
                    variables: [Variable(planId)],
                  )
                  .get();
              check();
              final members = await db
                  .customSelect(
                    'SELECT * FROM plan_members WHERE plan_id=?',
                    variables: [Variable(planId)],
                  )
                  .get();
              check();
              bool same(Map<String, Object?> a, Map<String, Object?> b) =>
                  a.length == b.length && a.keys.every((k) => a[k] == b[k]);
              if (!same(retained.data, snapshot.plan) ||
                  aliases.length != snapshot.aliases.length ||
                  !snapshot.aliases.every(
                    (expected) =>
                        aliases.any((row) => same(row.data, expected)),
                  ) ||
                  members.length != 1 ||
                  !same(members.single.data, snapshot.member)) {
                throw const MetadataBootstrapException('metadata_conflict');
              }
            } else {
              await _insert(db, 'plans', snapshot.plan);
              check();
              for (final alias in snapshot.aliases) {
                await _insert(db, 'plan_member_aliases', alias);
                check();
              }
              await _insert(db, 'plan_members', snapshot.member);
              check();
            }
            await LocalLedgerWriter(
              db,
              identity: coordinator.identity,
            ).requireLocalMembership(actor);
            check();
          });
          check();
          return actor;
        }),
      );
      // withAccount and this async wrapper add await boundaries after the lease.
      // A committed original-account write is not authority to disclose a stale actor.
      finalCheck!();
      return result;
    } on MetadataBootstrapException {
      rethrow;
    } on SyncTransportException {
      rethrow;
    } on SyncProtocolException {
      rethrow;
    } on SyncUpdateRequired {
      rethrow;
    } catch (_) {
      throw const MetadataBootstrapException('local_operation_failed');
    }
  }

  Future<void> _insert(
    AppDatabase db,
    String table,
    Map<String, Object?> row,
  ) => db.customStatement(
    'INSERT INTO $table(${row.keys.join(',')}) VALUES(${List.filled(row.length, '?').join(',')})',
    row.values.toList(),
  );
}
