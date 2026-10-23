import 'package:drift/drift.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';

/// Last-known local identity. Server authorization is rechecked in Phase 08.
class LedgerActor {
  const LedgerActor({
    required this.planId,
    required this.userId,
    required this.planMemberId,
    required this.deviceId,
  });
  final String planId;
  final String userId;
  final String planMemberId;
  final String deviceId;
}

/// Source values supplied by the couple; no inferred price or status.
class LedgerDraft {
  const LedgerDraft({
    required this.categoryCode,
    required this.entryType,
    required this.supplierName,
    required this.pricingMode,
    this.estimatedCents,
    this.actualCents,
    this.perHeadRateCents,
    this.manuallyValued = false,
    this.notes,
    this.templateSuggestionId,
    this.checklistItemId,
  });
  final String categoryCode;
  final String entryType;
  final String supplierName;
  final String pricingMode;
  final int? estimatedCents;
  final int? actualCents;
  final int? perHeadRateCents;
  final bool manuallyValued;
  final String? notes;
  final String? templateSuggestionId;
  final String? checklistItemId;
}

class LedgerRepository {
  /// Production entry point: the account coordinator owns DB selection.
  LedgerRepository(AccountStoreCoordinator coordinator)
    : _coordinator = coordinator,
      _writerFactory = ((db) =>
          LocalLedgerWriter(db, identity: coordinator.identity));

  /// Synthetic fixtures must explicitly provide their lease coordinator and
  /// writer factory; no raw database fallback exists on the production path.
  LedgerRepository.forTestLease(
    AccountStoreCoordinator coordinator, {
    required LocalLedgerWriter Function(AppDatabase) writerFactory,
  }) : _coordinator = coordinator,
       _writerFactory = writerFactory;

  final AccountStoreCoordinator _coordinator;
  final LocalLedgerWriter Function(AppDatabase) _writerFactory;

  Future<T> _withWriter<T>(
    Future<T> Function(AppDatabase, LocalLedgerWriter) work,
  ) => _coordinator.withAccount(
    (lease) => lease.run((db) {
      final writer = _writerFactory(db);
      if (!identical(writer.db, db) ||
          !identical(writer.identity, _coordinator.identity)) {
        throw StateError('Ledger writer does not match account lease');
      }
      return work(db, writer);
    }),
  );

  /// Authenticated by the last-known local plan/member/alias snapshot.
  Future<List<LedgerEntry>> listLive(LedgerActor actor) => _withWriter((
    db,
    writer,
  ) async {
    final result = await db.transaction(() async {
      final session = await writer.requireLocalMembership(actor);
      final rows =
          await (db.select(db.ledgerEntries)
                ..where(
                  (row) =>
                      row.planId.equals(actor.planId) & row.deletedAt.isNull(),
                )
                ..orderBy([
                  (row) => OrderingTerm.asc(row.createdAt),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      writer.requireSameSession(actor, session);
      return (session, rows);
    });
    // Drift's COMMIT is asynchronous; never return rows after an Auth switch.
    writer.requireSameSession(actor, result.$1);
    return result.$2;
  });

  Future<LedgerEntry> create(LedgerActor actor, LedgerDraft draft) =>
      _withWriter((_, writer) => writer.create(actor, draft));

  /// Only present, mutable source fields may be patched. Value(null) clears a field.
  Future<LedgerEntry> edit(
    LedgerActor actor,
    String entryId,
    LedgerEntriesCompanion changes,
  ) => _withWriter((_, writer) => writer.edit(actor, entryId, changes));

  Future<void> delete(LedgerActor actor, String entryId) =>
      _withWriter((_, writer) => writer.delete(actor, entryId));
}
