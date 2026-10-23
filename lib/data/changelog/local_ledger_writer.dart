import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';

/// RFC 9562 UUIDv7: millisecond timestamp plus cryptographically random bits.
String newLedgerUuidV7() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (var i = 0; i < 6; i++) {
    bytes[i] = (millis >> ((5 - i) * 8)) & 0xff;
  }
  bytes[6] = (bytes[6] & 15) | 0x70;
  bytes[8] = (bytes[8] & 63) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class LocalLedgerWriter {
  LocalLedgerWriter(
    this.db, {
    required VerifiedLocalIdentity identity,
    String Function()? newId,
    DateTime Function()? utcNow,
  }) : _identity = identity,
       _newId = newId ?? newLedgerUuidV7,
       _utcNow = utcNow ?? DateTime.now;
  final AppDatabase db;
  final VerifiedLocalIdentity _identity;
  VerifiedLocalIdentity get identity => _identity;
  final String Function() _newId;
  final DateTime Function() _utcNow;
  static const _maxInt64 = 9223372036854775807;
  static const _categories = {
    'catering_venue',
    'photo_video',
    'attire_styling',
    'coordination',
    'entourage_misc',
    'buffer',
  };
  static const _types = {
    'standard',
    'crew_meals',
    'oot_fees',
    'church_aircon',
    'corkage',
    'overtime',
    'venue_power',
  };
  static const _subtypeCategory = {
    'crew_meals': 'catering_venue',
    'oot_fees': 'coordination',
    'church_aircon': 'catering_venue',
    'corkage': 'catering_venue',
    'overtime': 'coordination',
    'venue_power': 'catering_venue',
  };
  static final _uuidV7 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  String _id() {
    final id = _newId();
    if (!_uuidV7.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'UUIDv7 required');
    }
    return id;
  }

  String _timestamp() => _utcNow().toUtc().toIso8601String();

  void requireSameSession(LedgerActor actor, VerifiedSessionSnapshot expected) {
    final current = _identity.capture();
    if (current == null ||
        current.userId != actor.userId ||
        current.userId != expected.userId ||
        !identical(current.marker, expected.marker)) {
      throw StateError('Verified local session changed');
    }
  }

  Future<VerifiedSessionSnapshot> _authorize(LedgerActor actor) async {
    final session = _identity.capture();
    if (session == null || actor.userId != session.userId) {
      throw StateError('Verified local session unavailable for actor');
    }
    if (actor.planId.isEmpty ||
        actor.userId.isEmpty ||
        actor.planMemberId.isEmpty ||
        actor.deviceId.isEmpty) {
      throw StateError('Local identity incomplete');
    }
    final rows = await db
        .customSelect(
          '''
SELECT 1 FROM plans p
JOIN plan_members m ON m.plan_id=p.id AND m.user_id=? AND m.plan_member_id=?
JOIN plan_member_aliases a ON a.plan_id=m.plan_id
 AND a.plan_member_id=m.plan_member_id AND a.user_id=m.user_id
WHERE p.id=? AND p.deleted_at IS NULL AND p.is_active=1 LIMIT 1''',
          variables: [
            Variable(actor.userId),
            Variable(actor.planMemberId),
            Variable(actor.planId),
          ],
        )
        .get();
    if (rows.isEmpty) throw StateError('Local plan membership unavailable');
    requireSameSession(actor, session);
    return session;
  }

  /// Checks only the last-known encrypted-local membership and alias.
  /// Server authorization must be rechecked before any future sync.
  Future<VerifiedSessionSnapshot> requireLocalMembership(LedgerActor actor) =>
      _authorize(actor);

  static void _validate(LedgerEntry row) {
    bool validCents(int? n) => n == null || (n >= 0 && n <= _maxInt64);
    if (!_categories.contains(row.categoryCode) ||
        !_types.contains(row.entryType) ||
        (row.entryType != 'standard' &&
            _subtypeCategory[row.entryType] != row.categoryCode) ||
        row.supplierName.trim().isEmpty ||
        row.supplierName.trim().length > 200 ||
        (row.notes?.length ?? 0) > 2000 ||
        // Neither checklist items nor the pinned template catalog has a
        // local validator in this slice; refuse unverified provenance.
        row.templateSuggestionId != null ||
        row.checklistItemId != null ||
        (row.manuallyValued != 0 && row.manuallyValued != 1) ||
        !validCents(row.estimatedCents) ||
        !validCents(row.actualCents) ||
        !validCents(row.perHeadRateCents) ||
        !((row.pricingMode == 'flat' &&
                row.estimatedCents != null &&
                row.perHeadRateCents == null) ||
            (row.pricingMode == 'per_head' &&
                row.estimatedCents == null &&
                row.perHeadRateCents != null))) {
      throw ArgumentError('Invalid ledger source values');
    }
  }

  Future<LedgerEntry> create(LedgerActor actor, LedgerDraft draft) =>
      db.transaction(() async {
        final session = await _authorize(actor);
        final now = _timestamp();
        final row = LedgerEntry(
          id: _id(),
          planId: actor.planId,
          categoryCode: draft.categoryCode,
          entryType: draft.entryType,
          supplierName: draft.supplierName,
          pricingMode: draft.pricingMode,
          estimatedCents: draft.estimatedCents,
          actualCents: draft.actualCents,
          perHeadRateCents: draft.perHeadRateCents,
          manuallyValued: draft.manuallyValued ? 1 : 0,
          notes: draft.notes,
          templateSuggestionId: draft.templateSuggestionId,
          checklistItemId: draft.checklistItemId,
          createdAt: now,
        );
        _validate(row);
        await db.into(db.ledgerEntries).insert(row);
        await _event(actor, row.id, r'$create', null, row.toJson(), now);
        requireSameSession(actor, session);
        return row;
      });

  Future<LedgerEntry> _existing(LedgerActor actor, String id) async {
    final row =
        await (db.select(db.ledgerEntries)
              ..where((r) => r.id.equals(id) & r.planId.equals(actor.planId)))
            .getSingleOrNull();
    if (row == null) throw StateError('Ledger entry unavailable in plan');
    return row;
  }

  Future<LedgerEntry> edit(
    LedgerActor actor,
    String entryId,
    LedgerEntriesCompanion patch,
  ) => db.transaction(() async {
    final session = await _authorize(actor);
    final before = await _existing(actor, entryId);
    if (before.deletedAt != null) throw StateError('Tombstoned entry');
    if (patch.id.present ||
        patch.rowid.present ||
        patch.planId.present ||
        patch.createdAt.present ||
        patch.deletedAt.present) {
      throw ArgumentError('Immutable ledger field');
    }
    final after = before.copyWithCompanion(patch);
    _validate(after);
    final old = before.toJson();
    final updated = after.toJson();
    const fields = [
      'category_code',
      'entry_type',
      'supplier_name',
      'estimated_cents',
      'actual_cents',
      'manually_valued',
      'notes',
      'template_suggestion_id',
      'checklist_item_id',
    ];
    final modeChanged =
        before.pricingMode != after.pricingMode ||
        before.perHeadRateCents != after.perHeadRateCents;
    if (!modeChanged && fields.every((f) => old[f] == updated[f])) {
      requireSameSession(actor, session);
      return before;
    }
    final now = _timestamp();
    await db.update(db.ledgerEntries).replace(after);
    for (final field in fields) {
      if (old[field] != updated[field]) {
        await _event(actor, entryId, field, old[field], updated[field], now);
      }
    }
    if (modeChanged) {
      await _event(
        actor,
        entryId,
        'pricing_mode',
        {
          'pricing_mode': before.pricingMode,
          'per_head_rate_cents': before.perHeadRateCents,
        },
        {
          'pricing_mode': after.pricingMode,
          'per_head_rate_cents': after.perHeadRateCents,
        },
        now,
        groupId: _id(),
      );
    }
    requireSameSession(actor, session);
    return after;
  });

  Future<void> delete(LedgerActor actor, String entryId) =>
      db.transaction(() async {
        final session = await _authorize(actor);
        final row = await _existing(actor, entryId);
        if (row.deletedAt != null) {
          requireSameSession(actor, session);
          return;
        }
        final now = _timestamp();
        await db
            .update(db.ledgerEntries)
            .replace(row.copyWith(deletedAt: Value(now)));
        await _event(actor, entryId, 'deleted_at', null, now, now);
        requireSameSession(actor, session);
      });

  Future<void> _event(
    LedgerActor actor,
    String entityId,
    String field,
    Object? oldValue,
    Object? newValue,
    String now, {
    String? groupId,
  }) async {
    final eventId = _id();
    final current = await db
        .customSelect(
          '''
SELECT device_monotonic FROM sync_state
      WHERE device_id=? AND plan_id=?''',
          variables: [Variable(actor.deviceId), Variable(actor.planId)],
        )
        .getSingleOrNull();
    final previous = current?.read<int>('device_monotonic') ?? 0;
    if (previous < 0 || previous >= _maxInt64) {
      throw StateError('Device counter exhausted');
    }
    final monotonic = previous + 1;
    if (current == null) {
      await db.customStatement(
        '''
INSERT INTO sync_state
        (device_id,plan_id,device_monotonic) VALUES (?,?,?)''',
        [actor.deviceId, actor.planId, monotonic],
      );
    } else {
      await db.customStatement(
        '''
UPDATE sync_state SET device_monotonic=?
        WHERE device_id=? AND plan_id=?''',
        [monotonic, actor.deviceId, actor.planId],
      );
    }
    await db.customStatement(
      '''
INSERT INTO change_log
      (id,plan_id,entity_type,entity_id,field_name,change_group_id,
       schema_version,old_value,new_value,server_ts,device_monotonic,
       device_id,plan_member_id,created_at)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        eventId,
        actor.planId,
        'ledger_entries',
        entityId,
        field,
        groupId,
        1,
        jsonEncode(oldValue),
        jsonEncode(newValue),
        null,
        monotonic,
        actor.deviceId,
        actor.planMemberId,
        now,
      ],
    );
    await db.customStatement(
      '''
INSERT INTO outbox
      (event_id,plan_id,device_id,queued_at) VALUES (?,?,?,?)''',
      [eventId, actor.planId, actor.deviceId, now],
    );
  }
}
