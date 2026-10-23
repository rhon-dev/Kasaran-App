/// Wire-only validation failures never include source data or credentials.
final class SyncProtocolException implements Exception {
  const SyncProtocolException(this.code);
  final String code;
  @override
  String toString() => 'SyncProtocolException: $code';
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final _uuidV7 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

bool isSyncUuid(Object? value) => value is String && _uuid.hasMatch(value);

int readSyncInt64(Object? value, {bool positive = false}) {
  if (value is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)) {
    throw const SyncProtocolException('invalid_integer');
  }
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < (positive ? 1 : 0)) {
    throw const SyncProtocolException('invalid_integer');
  }
  return parsed;
}

Object? _freezeJson(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double && value.isFinite && value.abs() < 9007199254740992) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeJson));
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const SyncProtocolException('invalid_json');
      }
      result[entry.key as String] = _freezeJson(entry.value);
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw const SyncProtocolException('invalid_json');
}

bool _utcTimestamp(Object? value) {
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

/// Immutable source event or accepted event; unknown additive JSON is retained.
/// This model does not project, persist, acknowledge or authorize a queued row.
final class SyncEvent {
  SyncEvent._(this.data, this.deviceMonotonic, this.serverTimestamp);

  factory SyncEvent.fromJson(
    Map<String, Object?> source, {
    bool requireServerTimestamp = false,
  }) {
    final data = _freezeJson(source)! as Map<String, Object?>;
    final id = data['id'];
    final entityId = data['entity_id'];
    final entityType = data['entity_type'];
    final field = data['field_name'];
    final schema = data['schema_version'];
    if (id is! String ||
        !_uuidV7.hasMatch(id) ||
        !isSyncUuid(data['plan_id']) ||
        entityId is! String ||
        !_uuidV7.hasMatch(entityId) ||
        !isSyncUuid(data['device_id']) ||
        !isSyncUuid(data['plan_member_id']) ||
        entityType is! String ||
        entityType.trim().isEmpty ||
        field is! String ||
        field.trim().isEmpty ||
        schema is! int ||
        schema < 1 ||
        schema > 2147483647 ||
        !data.containsKey('old_value') ||
        !data.containsKey('new_value') ||
        !_utcTimestamp(data['created_at'])) {
      throw const SyncProtocolException('invalid_event');
    }
    final group = data['change_group_id'];
    if (group != null && !isSyncUuid(group)) {
      throw const SyncProtocolException('invalid_event');
    }
    if (!requireServerTimestamp &&
        (data.containsKey('server_ts') || data.containsKey('actor_user_id'))) {
      throw const SyncProtocolException('client_order_or_actor');
    }
    final counter = readSyncInt64(data['device_monotonic']);
    final stamp = requireServerTimestamp
        ? readSyncInt64(data['server_ts'], positive: true)
        : null;
    return SyncEvent._(data, counter, stamp);
  }

  final Map<String, Object?> data;
  final int deviceMonotonic;
  final int? serverTimestamp;
  String get id => data['id']! as String;
  String get planId => data['plan_id']! as String;

  Map<String, Object?> toPushJson() {
    if (serverTimestamp != null) {
      throw const SyncProtocolException('accepted_event_cannot_push');
    }
    return data;
  }
}

Map<String, Object?> readSyncObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const SyncProtocolException('invalid_object');
  }
  return value;
}

final class SyncProtocolVersion {
  const SyncProtocolVersion({this.major = 1, this.minor = 0});

  factory SyncProtocolVersion.fromJson(Object? value) {
    final data = readSyncObject(value);
    final major = data['major'];
    final minor = data['minor'];
    if (major is! int ||
        minor is! int ||
        major != 1 ||
        minor < 0 ||
        minor > 2147483647) {
      throw const SyncProtocolException('unsupported_response_version');
    }
    return SyncProtocolVersion(major: major, minor: minor);
  }

  final int major;
  final int minor;
  Map<String, Object?> toJson() => {'major': major, 'minor': minor};
}

final class SyncPushResult {
  SyncPushResult._(this.version, this.accepted, this.highWater);

  factory SyncPushResult.fromJson(
    Map<String, Object?> data, {
    required Set<String> requestedIds,
  }) {
    final version = SyncProtocolVersion.fromJson(data['protocol_version']);
    final high = readSyncInt64(data['server_ts_high']);
    final rows = data['accepted'];
    if (rows is! List || rows.length > requestedIds.length) {
      throw const SyncProtocolException('invalid_acknowledgment');
    }
    final accepted = <String, int>{};
    for (final row in rows) {
      final value = readSyncObject(row);
      final id = value['id'];
      final stamp = readSyncInt64(value['server_ts'], positive: true);
      if (id is! String ||
          !requestedIds.contains(id) ||
          accepted.containsKey(id) ||
          stamp > high) {
        throw const SyncProtocolException('invalid_acknowledgment');
      }
      accepted[id] = stamp;
    }
    return SyncPushResult._(version, Map.unmodifiable(accepted), high);
  }

  final SyncProtocolVersion version;
  final Map<String, int> accepted;
  final int highWater;
}

final class SyncPullPage {
  SyncPullPage._(
    this.version,
    this.rows,
    this.nextCursor, {
    required this.hasMore,
  });

  factory SyncPullPage.fromJson(
    Map<String, Object?> data, {
    required String planId,
    required int cursor,
    required int limit,
  }) {
    if (!isSyncUuid(planId) || cursor < 0 || limit < 1 || limit > 1000) {
      throw const SyncProtocolException('invalid_request');
    }
    final version = SyncProtocolVersion.fromJson(data['protocol_version']);
    final next = readSyncInt64(data['next_cursor']);
    final hasMore = data['has_more'];
    final raw = data['rows'];
    if (raw is! List || raw.length > limit || hasMore is! bool) {
      throw const SyncProtocolException('invalid_page');
    }
    final events = <SyncEvent>[];
    final seen = <String>{};
    var previous = cursor;
    for (final row in raw) {
      final event = SyncEvent.fromJson(
        readSyncObject(row),
        requireServerTimestamp: true,
      );
      if (event.planId != planId ||
          event.serverTimestamp! <= previous ||
          !seen.add(event.id)) {
        throw const SyncProtocolException('invalid_page');
      }
      previous = event.serverTimestamp!;
      events.add(event);
    }
    if (next != previous || (events.isEmpty && hasMore)) {
      throw const SyncProtocolException('invalid_page');
    }
    return SyncPullPage._(
      version,
      List.unmodifiable(events),
      next,
      hasMore: hasMore,
    );
  }

  final SyncProtocolVersion version;
  final List<SyncEvent> rows;
  final int nextCursor;
  final bool hasMore;
}
