import 'package:drift/drift.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/db/app_database.dart';

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
  LedgerRepository(this.db, {LocalLedgerWriter? writer})
    : _writer = writer ?? LocalLedgerWriter(db);
  final AppDatabase db;
  final LocalLedgerWriter _writer;

  Future<List<LedgerEntry>> listLive(String planId) =>
      (db.select(db.ledgerEntries)
            ..where((row) => row.planId.equals(planId) & row.deletedAt.isNull())
            ..orderBy([
              (row) => OrderingTerm.asc(row.createdAt),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .get();

  Future<LedgerEntry> create(LedgerActor actor, LedgerDraft draft) =>
      _writer.create(actor, draft);

  /// Only present, mutable source fields may be patched. Value(null) clears a field.
  Future<LedgerEntry> edit(
    LedgerActor actor,
    String entryId,
    LedgerEntriesCompanion changes,
  ) => _writer.edit(actor, entryId, changes);

  Future<void> delete(LedgerActor actor, String entryId) =>
      _writer.delete(actor, entryId);
}
