import 'dart:convert';

/// Synthetic-only protocol model. Never import this from production sync code.
final class SyntheticEvent {
  const SyntheticEvent({
    required this.id,
    required this.planId,
    required this.deviceId,
    required this.deviceMonotonic,
    required this.schemaVersion,
    required this.entityType,
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
  });

  final String id;
  final String planId;
  final String deviceId;
  final int deviceMonotonic;
  final int schemaVersion;
  final String entityType;
  final String fieldName;
  final String? oldValue;
  final String? newValue;

  bool samePayload(SyntheticEvent other) =>
      id == other.id &&
      planId == other.planId &&
      deviceId == other.deviceId &&
      deviceMonotonic == other.deviceMonotonic &&
      schemaVersion == other.schemaVersion &&
      entityType == other.entityType &&
      fieldName == other.fieldName &&
      oldValue == other.oldValue &&
      newValue == other.newValue;
}

final class SyntheticAccepted {
  const SyntheticAccepted(this.event, this.sequence);
  final SyntheticEvent event;
  final int sequence;
}

final class SyntheticPage {
  const SyntheticPage(this.rows, this.nextCursor, {required this.hasMore});
  final List<SyntheticAccepted> rows;
  final int nextCursor;
  final bool hasMore;
}

final class SyntheticSyncError implements Exception {
  const SyntheticSyncError(this.reason);
  final String reason;
  @override
  String toString() => 'SyntheticSyncError: $reason';
}

/// Models logical acceptance only, not a database commit lock or Auth.
final class SyntheticSyncServer {
  SyntheticSyncServer({
    required Map<String, Set<String>> memberships,
    required this.maxBatchSize,
    required this.supportedMajor,
  }) : _memberships = {
         for (final entry in memberships.entries)
           entry.key: Set.of(entry.value),
       } {
    if (maxBatchSize < 1 || supportedMajor < 1) {
      throw ArgumentError('Positive batch size and protocol major required');
    }
  }

  final Map<String, Set<String>> _memberships;
  final int maxBatchSize;
  final int supportedMajor;
  final Map<String, List<SyntheticAccepted>> _logs = {};
  final Map<String, SyntheticAccepted> _byId = {};

  void _authorize(String actor, String planId, int protocolMajor) {
    if (protocolMajor != supportedMajor) {
      throw const SyntheticSyncError('unsupportedVersion');
    }
    if (_memberships[planId]?.contains(actor) != true) {
      throw const SyntheticSyncError('planUnavailable');
    }
  }

  List<SyntheticAccepted> push({
    required String actor,
    required String planId,
    required int protocolMajor,
    required List<SyntheticEvent> rows,
    bool failBeforeCommit = false,
  }) {
    _authorize(actor, planId, protocolMajor);
    if (rows.length > maxBatchSize) {
      throw const SyntheticSyncError('invalidBatch');
    }
    final log = List<SyntheticAccepted>.of(_logs[planId] ?? const []);
    final candidates = <String, SyntheticAccepted>{};
    final accepted = <SyntheticAccepted>[];
    for (final event in rows) {
      _validateEvent(event, planId);
      final prior = candidates[event.id] ?? _byId[event.id];
      if (prior != null) {
        if (!prior.event.samePayload(event)) {
          throw const SyntheticSyncError('conflictingDuplicate');
        }
        accepted.add(prior);
      } else {
        final stamp = SyntheticAccepted(event, log.length + 1);
        log.add(stamp);
        candidates[event.id] = stamp;
        accepted.add(stamp);
      }
    }
    if (failBeforeCommit) {
      throw const SyntheticSyncError('commitFailed');
    }
    _logs[planId] = log;
    _byId.addAll(candidates);
    return List.unmodifiable(accepted);
  }

  void _validateEvent(SyntheticEvent event, String planId) {
    if (event.planId != planId ||
        event.id.trim().isEmpty ||
        event.deviceId.trim().isEmpty ||
        event.entityType.trim().isEmpty ||
        event.fieldName.trim().isEmpty ||
        event.deviceMonotonic < 1 ||
        event.schemaVersion < 1) {
      throw const SyntheticSyncError('invalidEvent');
    }
    for (final raw in [event.oldValue, event.newValue]) {
      if (raw != null) {
        try {
          jsonDecode(raw);
        } on FormatException {
          throw const SyntheticSyncError('invalidEvent');
        }
      }
    }
  }

  SyntheticPage pull({
    required String actor,
    required String planId,
    required int protocolMajor,
    required int cursor,
    required int limit,
  }) {
    _authorize(actor, planId, protocolMajor);
    if (cursor < 0 || limit < 1 || limit > 1000) {
      throw const SyntheticSyncError('invalidPage');
    }
    final rows = (_logs[planId] ?? const <SyntheticAccepted>[])
        .where((row) => row.sequence > cursor)
        .take(limit)
        .toList();
    final next = rows.isEmpty ? cursor : rows.last.sequence;
    final hasMore = (_logs[planId] ?? const <SyntheticAccepted>[]).any(
      (row) => row.sequence > next,
    );
    return SyntheticPage(List.unmodifiable(rows), next, hasMore: hasMore);
  }
}

/// In-memory queue and page-swap simulation, not durable storage or ledger LWW.
final class SyntheticSyncClient {
  SyntheticSyncClient({required this.planId, required this.deviceId});

  final String planId;
  final String deviceId;
  final List<SyntheticEvent> _pending = [];
  Map<String, SyntheticAccepted> _retained = {};
  int _cursor = 0;
  bool _applyingPage = false;

  List<SyntheticEvent> get pending => List.unmodifiable(_pending);
  Map<String, SyntheticAccepted> get retained => Map.unmodifiable(_retained);
  int get cursor => _cursor;

  /// Selects only the prototype's known typed rows; no financial state is built.
  List<SyntheticAccepted> get projectedRows => List.unmodifiable(
    _retained.values.where((row) {
      final event = row.event;
      if (event.schemaVersion != 2 ||
          event.entityType != 'ledger_entries' ||
          event.fieldName != 'estimated_cents') {
        return false;
      }
      final raw = event.newValue;
      return raw == null || jsonDecode(raw) is int || raw.trim() == 'null';
    }),
  );

  void enqueue(SyntheticEvent event) => _pending.add(event);

  void pushQueue(SyntheticSyncServer server, String actor, int protocolMajor) {
    final batch = _pending.take(server.maxBatchSize).toList();
    if (batch.any(
      (event) => event.planId != planId || event.deviceId != deviceId,
    )) {
      throw const SyntheticSyncError('invalidEvent');
    }
    final accepted = server.push(
      actor: actor,
      planId: planId,
      protocolMajor: protocolMajor,
      rows: batch,
    );
    if (accepted.length != batch.length) {
      throw const SyntheticSyncError('invalidAcceptance');
    }
    for (var i = 0; i < batch.length; i++) {
      if (!accepted[i].event.samePayload(batch[i]) ||
          accepted[i].sequence < 1) {
        throw const SyntheticSyncError('invalidAcceptance');
      }
    }
    _pending.removeRange(0, batch.length);
  }

  void pullPage(
    SyntheticSyncServer server,
    String actor,
    int protocolMajor,
    int limit, {
    void Function()? beforeCommit,
  }) {
    if (_applyingPage) {
      throw const SyntheticSyncError('pageInProgress');
    }
    _applyingPage = true;
    try {
      final page = server.pull(
        actor: actor,
        planId: planId,
        protocolMajor: protocolMajor,
        cursor: _cursor,
        limit: limit,
      );
      final candidate = Map<String, SyntheticAccepted>.of(_retained);
      var next = _cursor;
      for (final row in page.rows) {
        if (row.event.planId != planId || row.sequence <= next) {
          throw const SyntheticSyncError('invalidPage');
        }
        final prior = candidate[row.event.id];
        if (prior != null &&
            (prior.sequence != row.sequence ||
                !prior.event.samePayload(row.event))) {
          throw const SyntheticSyncError('invalidPage');
        }
        candidate[row.event.id] = row;
        next = row.sequence;
      }
      if (page.nextCursor != next || (page.rows.isEmpty && page.hasMore)) {
        throw const SyntheticSyncError('invalidPage');
      }
      beforeCommit?.call();
      _retained = candidate;
      _cursor = next;
    } finally {
      _applyingPage = false;
    }
  }
}
