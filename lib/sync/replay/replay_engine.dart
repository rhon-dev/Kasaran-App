import 'dart:convert';

import 'package:kasaran/sync/transport/sync_protocol.dart';

/// Safe failure for an inconsistent replay input, never containing source values.
final class ReplayException implements Exception {
  const ReplayException(this.code);
  final String code;
  @override
  String toString() => 'ReplayException: $code';
}

Object? _canonical(Object? value) {
  if (value is Map<String, Object?>) {
    return {
      for (final key in value.keys.toList()..sort())
        key: _canonical(value[key]),
    };
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

bool _equal(Object? a, Object? b) =>
    jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));

// Compatibility ONLY for the old SQL pull's Dart millisecond -> PostgreSQL
// microsecond padding. No other timestamp spelling/instant or member may differ.
bool _legacyPullIdentity(Map<String, Object?> a, Map<String, Object?> b) {
  if (_equal(a, b)) return true;
  final left = a['created_at'];
  final right = b['created_at'];
  String? padded(Object? value) =>
      value is String &&
          RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
          ).hasMatch(value)
      ? '${value.substring(0, value.length - 1)}000Z'
      : null;
  if (padded(left) != right && padded(right) != left) return false;
  return _equal({...a, 'created_at': right}, b);
}

/// Source-only materialization. No derived financial totals are stored.
final class LedgerSourceSnapshot {
  LedgerSourceSnapshot._(Map<String, Object?> source)
    : _source = Map.unmodifiable(source);

  final Map<String, Object?> _source;
  String get id => _source['id']! as String;
  String get planId => _source['plan_id']! as String;
  String get categoryCode => _source['category_code']! as String;
  String get entryType => _source['entry_type']! as String;
  String get supplierName => _source['supplier_name']! as String;
  int get manuallyValued => _source['manually_valued']! as int;
  String? get templateSuggestionId =>
      _source['template_suggestion_id'] as String?;
  String? get checklistItemId => _source['checklist_item_id'] as String?;
  String get createdAt => _source['created_at']! as String;
  String? get deletedAt => _source['deleted_at'] as String?;
  List<LedgerSourceConstraint> get sourceConstraints =>
      List.unmodifiable(_sourceConstraints(_source));
  int? get estimatedCents => _source['estimated_cents'] as int?;
  int? get actualCents => _source['actual_cents'] as int?;
  String? get notes => _source['notes'] as String?;
  String get pricingMode => _source['pricing_mode']! as String;
  int? get perHeadRateCents => _source['per_head_rate_cents'] as int?;
  bool get isSourceValid => _validSource(_source);
  bool get isDeleted => _source['deleted_at'] != null;
  Map<String, Object?> toJson() => _source;
}

/// Derived from a typed mismatch with the effective immediately preceding value.
final class StaleConflict {
  StaleConflict._(SyncEvent event, this.actualPriorValue)
    : eventId = event.id,
      fieldName = event.data['field_name']! as String,
      recordedOldValue = event.data['old_value'],
      replacingValue = event.data['new_value'];
  final String eventId;
  final String fieldName;
  final Object? recordedOldValue;
  final Object? actualPriorValue;
  final Object? replacingValue;
  Map<String, Object?> toJson() => {
    'event_id': eventId,
    'field_name': fieldName,
    'recorded_old_value': recordedOldValue,
    'actual_prior_value': actualPriorValue,
    'replacing_value': replacingValue,
  };
}

enum ReplayIssueKind {
  unknownSchema,
  unsupportedEntity,
  unknownField,
  invalidSnapshot,
  missingCreate,
  invalidValue,
  invalidSource,
  tombstoneSuppressed,
  duplicateCreate,
}

enum LedgerSourceConstraint {
  completeSnapshot,
  category,
  subtypeCategory,
  supplierName,
  nonnegativeMoney,
  pricingShape,
  manuallyValuedFlag,
  manualActualCoherence,
  notesLength,
  unsupportedProvenance,
  sourceTimestamps,
}

/// Classification only; raw values remain in [ReplayResult.records].
final class ReplayIssue {
  ReplayIssue._(
    SyncEvent event,
    this.kind, [
    Iterable<LedgerSourceConstraint> sourceConstraints = const [],
  ]) : eventId = event.id,
       entityId = event.data['entity_id']! as String,
       constraints = List.unmodifiable(sourceConstraints);
  final String eventId;
  final String entityId;
  final ReplayIssueKind kind;
  final List<LedgerSourceConstraint> constraints;
  Map<String, Object?> toJson() => {
    'event_id': eventId,
    'entity_id': entityId,
    'kind': kind.name,
    'constraints': constraints.map((constraint) => constraint.name).toList(),
  };
}

const _sourceKeys = {
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
};
const _ordinaryFields = {
  'category_code',
  'entry_type',
  'supplier_name',
  'estimated_cents',
  'actual_cents',
  'manually_valued',
  'notes',
  'template_suggestion_id',
  'checklist_item_id',
  'deleted_at',
};
const _categories = {
  'catering_venue',
  'photo_video',
  'attire_styling',
  'coordination',
  'entourage_misc',
  'buffer',
};
const _subtypeCategory = {
  'crew_meals': 'catering_venue',
  'oot_fees': 'coordination',
  'church_aircon': 'catering_venue',
  'corkage': 'catering_venue',
  'overtime': 'coordination',
  'venue_power': 'catering_venue',
};

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

bool _cents(Object? value) => value == null || (value is int && value >= 0);

bool _typedValue(String field, Object? value) => switch (field) {
  'estimated_cents' || 'actual_cents' => value == null || value is int,
  'manually_valued' => value is int,
  'notes' ||
  'template_suggestion_id' ||
  'checklist_item_id' => value == null || value is String,
  'deleted_at' => value == null || _timestamp(value),
  'category_code' || 'entry_type' || 'supplier_name' => value is String,
  _ => false,
};

bool _pricingGroup(Object? value) =>
    value is Map<String, Object?> &&
    value.length == 2 &&
    value.containsKey('pricing_mode') &&
    value.containsKey('per_head_rate_cents') &&
    (value['pricing_mode'] == 'flat' || value['pricing_mode'] == 'per_head') &&
    _cents(value['per_head_rate_cents']) &&
    ((value['pricing_mode'] == 'flat' &&
            value['per_head_rate_cents'] == null) ||
        (value['pricing_mode'] == 'per_head' &&
            value['per_head_rate_cents'] is int));

bool _validSource(Map<String, Object?> row) => _sourceConstraints(row).isEmpty;

List<LedgerSourceConstraint> _sourceConstraints(Map<String, Object?> row) {
  final supplier = row['supplier_name'];
  final notes = row['notes'];
  return [
    if (!_sourceKeys.every(row.containsKey))
      LedgerSourceConstraint.completeSnapshot,
    if (!_categories.contains(row['category_code']))
      LedgerSourceConstraint.category,
    if (!(row['entry_type'] == 'standard' ||
        (_subtypeCategory.containsKey(row['entry_type']) &&
            _subtypeCategory[row['entry_type']] == row['category_code'])))
      LedgerSourceConstraint.subtypeCategory,
    if (!(supplier is String &&
        supplier.trim().isNotEmpty &&
        supplier.trim().length <= 200))
      LedgerSourceConstraint.supplierName,
    if (!_cents(row['estimated_cents']) ||
        !_cents(row['actual_cents']) ||
        !_cents(row['per_head_rate_cents']))
      LedgerSourceConstraint.nonnegativeMoney,
    if (!((row['pricing_mode'] == 'flat' &&
            row['estimated_cents'] != null &&
            row['per_head_rate_cents'] == null) ||
        (row['pricing_mode'] == 'per_head' &&
            row['estimated_cents'] == null &&
            row['per_head_rate_cents'] != null)))
      LedgerSourceConstraint.pricingShape,
    if (!(row['manually_valued'] is int &&
        (row['manually_valued'] == 0 || row['manually_valued'] == 1)))
      LedgerSourceConstraint.manuallyValuedFlag,
    if (row['pricing_mode'] == 'per_head' &&
        row['actual_cents'] != null &&
        row['manually_valued'] != 1)
      LedgerSourceConstraint.manualActualCoherence,
    if (!(notes == null || (notes is String && notes.length <= 2000)))
      LedgerSourceConstraint.notesLength,
    if (row['template_suggestion_id'] != null ||
        row['checklist_item_id'] != null)
      LedgerSourceConstraint.unsupportedProvenance,
    if (!_timestamp(row['created_at']) ||
        !(row['deleted_at'] == null || _timestamp(row['deleted_at'])))
      LedgerSourceConstraint.sourceTimestamps,
  ];
}

/// Immutable replay output; retained records include superseded source events.
final class ReplayResult {
  ReplayResult._(
    Map<String, LedgerSourceSnapshot> ledger,
    List<SyncEvent> rows,
    List<SyncEvent> envelopes,
    List<StaleConflict> stale,
    List<ReplayIssue> classifications,
    Set<String> provisionalIds,
  ) : ledgerEntries = Map.unmodifiable(ledger),
      records = List.unmodifiable(rows),
      retainedEnvelopes = List.unmodifiable(envelopes),
      conflicts = List.unmodifiable(stale),
      issues = List.unmodifiable(classifications),
      provisionalEventIds = Set.unmodifiable(provisionalIds);

  final Map<String, LedgerSourceSnapshot> ledgerEntries;
  final List<SyncEvent> records;

  /// Distinct exact input envelopes, including legacy normalized copies and
  /// reconciled pending sources. Sorted canonically, never rewritten.
  final List<SyncEvent> retainedEnvelopes;
  final List<StaleConflict> conflicts;
  final List<ReplayIssue> issues;
  final Set<String> provisionalEventIds;
  List<SyncEvent> get unknownRecords {
    final unknown = issues
        .where(
          (issue) => switch (issue.kind) {
            ReplayIssueKind.unknownSchema ||
            ReplayIssueKind.unsupportedEntity ||
            ReplayIssueKind.unknownField => true,
            _ => false,
          },
        )
        .map((issue) => issue.eventId)
        .toSet();
    return List.unmodifiable(records.where((row) => unknown.contains(row.id)));
  }

  bool get needsAttention => conflicts.isNotEmpty || issues.isNotEmpty;
  Map<String, Object?> toJson() =>
      _canonical({
            'ledger_entries': ledgerEntries.map(
              (id, row) => MapEntry(id, row.toJson()),
            ),
            'records': records.map((row) => row.data).toList(),
            'conflicts': conflicts.map((row) => row.toJson()).toList(),
            'issues': issues.map((row) => row.toJson()).toList(),
            'provisional_event_ids': provisionalEventIds.toList()..sort(),
          })!
          as Map<String, Object?>;
}

int _acceptedOrder(SyncEvent a, SyncEvent b) {
  var order = a.serverTimestamp!.compareTo(b.serverTimestamp!);
  if (order != 0) return order;
  order = a.deviceMonotonic.compareTo(b.deviceMonotonic);
  if (order != 0) return order;
  return (a.data['device_id']! as String).compareTo(
    b.data['device_id']! as String,
  );
}

/// Pure deterministic reducer, independent of local storage and UI.
abstract final class ReplayEngine {
  static ReplayResult rebuild(
    Iterable<SyncEvent> accepted, {
    Iterable<SyncEvent> provisional = const [],
  }) {
    final unique = <String, SyncEvent>{};
    final raw = <String, SyncEvent>{};
    void retain(SyncEvent event) {
      raw[jsonEncode(_canonical(event.data))] = event;
    }

    String? planId;
    void requirePlan(SyncEvent event) {
      planId ??= event.planId;
      if (planId != event.planId) throw const ReplayException('mixed_plans');
    }

    for (final event in accepted) {
      retain(event);
      requirePlan(event);
      if (event.serverTimestamp == null) {
        throw const ReplayException('accepted_stamp_required');
      }
      final prior = unique[event.id];
      if (prior != null && !_legacyPullIdentity(prior.data, event.data)) {
        throw const ReplayException('conflicting_event_id');
      }
      // Prefer the actual unpadded source when both raw spellings are present.
      unique[event.id] =
          prior != null &&
              (prior.data['created_at']! as String).length <
                  (event.data['created_at']! as String).length
          ? prior
          : event;
    }
    final authoritative = unique.values.toList()..sort(_acceptedOrder);
    for (var i = 1; i < authoritative.length; i++) {
      if (_acceptedOrder(authoritative[i - 1], authoritative[i]) == 0) {
        throw const ReplayException('ambiguous_order');
      }
    }
    final pendingById = <String, SyncEvent>{};
    String? provisionalDevice;
    for (final event in provisional) {
      retain(event);
      requirePlan(event);
      provisionalDevice ??= event.data['device_id']! as String;
      if (provisionalDevice != event.data['device_id']) {
        throw const ReplayException('multiple_provisional_devices');
      }
      if (event.serverTimestamp != null) {
        throw const ReplayException('provisional_stamp_forbidden');
      }
      final acceptedMatch = unique[event.id];
      if (acceptedMatch != null) {
        final source = Map<String, Object?>.of(acceptedMatch.data)
          ..remove('server_ts')
          ..remove('actor_user_id');
        if (!_legacyPullIdentity(source, event.data)) {
          throw const ReplayException('conflicting_event_id');
        }
        continue;
      }
      final prior = pendingById[event.id];
      if (prior != null && !_equal(prior.data, event.data)) {
        throw const ReplayException('conflicting_event_id');
      }
      pendingById[event.id] = event;
    }
    final pending = pendingById.values.toList()
      ..sort((a, b) => a.deviceMonotonic.compareTo(b.deviceMonotonic));
    for (var i = 1; i < pending.length; i++) {
      if (pending[i - 1].deviceMonotonic == pending[i].deviceMonotonic) {
        throw const ReplayException('ambiguous_order');
      }
    }
    final rows = [...authoritative, ...pending];
    final ledger = <String, LedgerSourceSnapshot>{};
    final conflicts = <StaleConflict>[];
    final issues = <ReplayIssue>[];
    final lastEffective = <String, SyncEvent>{};
    for (final stage in [authoritative, pending]) {
      final supported = <SyncEvent>[];
      for (final event in stage) {
        final field = event.data['field_name']! as String;
        ReplayIssueKind? issue;
        if (event.data['schema_version'] != 1) {
          issue = ReplayIssueKind.unknownSchema;
        } else if (event.data['entity_type'] != 'ledger_entries') {
          issue = ReplayIssueKind.unsupportedEntity;
        } else if (field != r'$create' &&
            field != 'pricing_mode' &&
            !_ordinaryFields.contains(field)) {
          issue = ReplayIssueKind.unknownField;
        } else if (field == r'$create') {
          final source = event.data['new_value'];
          if (source is Map<String, Object?> &&
              source.keys.any((key) => !_sourceKeys.contains(key))) {
            issue = ReplayIssueKind.unknownField;
          } else if (event.data['old_value'] != null ||
              source is! Map<String, Object?> ||
              !_validSource(source) ||
              source['id'] != event.data['entity_id'] ||
              source['plan_id'] != event.planId) {
            issue = ReplayIssueKind.invalidSnapshot;
          }
        } else if (field == 'pricing_mode') {
          final hasUnknownMember =
              [event.data['old_value'], event.data['new_value']].any(
                (value) =>
                    value is Map<String, Object?> &&
                    value.keys.any(
                      (key) =>
                          key != 'pricing_mode' && key != 'per_head_rate_cents',
                    ),
              );
          if (hasUnknownMember) {
            issue = ReplayIssueKind.unknownField;
          } else if (event.data['change_group_id'] == null ||
              !_pricingGroup(event.data['old_value']) ||
              !_pricingGroup(event.data['new_value'])) {
            issue = ReplayIssueKind.invalidValue;
          }
        } else if (!_typedValue(field, event.data['old_value']) ||
            !_typedValue(field, event.data['new_value'])) {
          issue = ReplayIssueKind.invalidValue;
        }
        if (issue != null) {
          issues.add(ReplayIssue._(event, issue));
        } else {
          supported.add(event);
        }
      }
      // Initialize only complete valid creates. Earlier updates then replay in
      // authoritative order, even if their create arrived in a later pull page.
      for (final event in supported) {
        if (event.data['field_name'] == r'$create') {
          final id = event.data['entity_id']! as String;
          if (ledger.containsKey(id)) {
            issues.add(ReplayIssue._(event, ReplayIssueKind.duplicateCreate));
          } else {
            ledger[id] = LedgerSourceSnapshot._(
              event.data['new_value']! as Map<String, Object?>,
            );
            lastEffective[id] = event;
          }
        }
      }
      for (final event in supported) {
        final id = event.data['entity_id']! as String;
        final field = event.data['field_name']! as String;
        if (field == r'$create') continue;
        final before = ledger[id];
        if (before == null) {
          issues.add(ReplayIssue._(event, ReplayIssueKind.missingCreate));
          continue;
        }
        if (before.isDeleted && field != 'deleted_at') {
          issues.add(ReplayIssue._(event, ReplayIssueKind.tombstoneSuppressed));
          continue;
        }
        final actualPrior = field == 'pricing_mode'
            ? Map<String, Object?>.unmodifiable({
                'pricing_mode': before.pricingMode,
                'per_head_rate_cents': before.perHeadRateCents,
              })
            : before.toJson()[field];
        if (!_equal(actualPrior, event.data['old_value'])) {
          conflicts.add(StaleConflict._(event, actualPrior));
        }
        ledger[id] = LedgerSourceSnapshot._({
          ...before.toJson(),
          if (field == 'pricing_mode')
            ...event.data['new_value']! as Map<String, Object?>
          else
            field: event.data['new_value'],
        });
        lastEffective[id] = event;
      }
    }
    for (final id in ledger.keys) {
      if (!ledger[id]!.isSourceValid) {
        issues.add(
          ReplayIssue._(
            lastEffective[id]!,
            ReplayIssueKind.invalidSource,
            ledger[id]!.sourceConstraints,
          ),
        );
      }
    }
    final indices = {for (var i = 0; i < rows.length; i++) rows[i].id: i};
    issues.sort((a, b) => indices[a.eventId]!.compareTo(indices[b.eventId]!));
    return ReplayResult._(
      ledger,
      rows,
      [for (final key in raw.keys.toList()..sort()) raw[key]!],
      conflicts,
      issues,
      pendingById.keys.toSet(),
    );
  }
}
