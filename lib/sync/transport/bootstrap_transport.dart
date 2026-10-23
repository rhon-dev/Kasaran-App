import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

/// Read-only metadata adapter. Credentials are captured only in process memory.
/// Owns its HTTP client. Does not share private state with ledger transport.
final class _HttpResult {
  const _HttpResult(this.status, this.body);
  final int status;
  final String body;
}

/// HTTP only: no database, queue acknowledgment, cursor write or projection.
/// The transport owns its HttpClient, including an explicitly supplied client.
final class HttpBootstrapTransport {
  HttpBootstrapTransport({
    required this.baseUrl,
    required String anonKey,
    required SyncSessionSource sessions,
    this.maxAttempts = 3,
    this.timeout = const Duration(seconds: 15),
    this.maxResponseBytes = 2 * 1024 * 1024,
    HttpClient? client,
    Future<void> Function(Duration)? delay,
  }) : _anonKey = anonKey,
       _sessions = sessions,
       _client = client ?? HttpClient(),
       _delay = delay ?? Future<void>.delayed {
    final local =
        baseUrl.scheme == 'http' &&
        (baseUrl.host == '127.0.0.1' || baseUrl.host == '::1');
    if ((baseUrl.scheme != 'https' && !local) ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        (baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        anonKey.isEmpty ||
        anonKey.contains(RegExp(r'[\r\n]')) ||
        maxAttempts < 1 ||
        maxAttempts > 3 ||
        timeout <= Duration.zero ||
        maxResponseBytes < 1) {
      _client.close(force: true);
      throw const SyncTransportException('invalid_configuration');
    }
    _client.connectionTimeout = timeout;
  }

  final Uri baseUrl;
  final String _anonKey;
  final SyncSessionSource _sessions;
  final HttpClient _client;
  final Future<void> Function(Duration) _delay;
  final int maxAttempts;
  final Duration timeout;
  final int maxResponseBytes;
  bool _closed = false;

  SyncAuthSession _capture() {
    if (_closed) throw const SyncTransportException('closed');
    final SyncAuthSession? session;
    try {
      session = _sessions.capture();
    } catch (_) {
      throw const SyncTransportException('session_unavailable');
    }
    if (session == null ||
        session.userId.isEmpty ||
        session.accessToken.isEmpty ||
        session.accessToken.contains(RegExp(r'[\r\n]'))) {
      throw const SyncTransportException('session_unavailable');
    }
    return session;
  }

  SyncAuthSession _requireSame(SyncAuthSession expected) {
    final current = _capture();
    if (current.userId != expected.userId ||
        !identical(current.marker, expected.marker)) {
      throw const SyncTransportException('session_changed');
    }
    return current;
  }

  Future<BootstrapSnapshot> fetch(
    String planId, {
    required SyncSessionBinding requiredSession,
  }) async {
    final expected = _capture();
    if (expected.userId != requiredSession.userId ||
        !identical(expected.marker, requiredSession.marker)) {
      throw const SyncTransportException('session_changed');
    }
    if (!isSyncUuid(planId)) {
      throw const SyncProtocolException('invalid_request');
    }
    final body = await _post('sync_bootstrap', {
      'protocol_version': const SyncProtocolVersion().toJson(),
      'plan_id': planId,
    }, expected: expected);
    final result = BootstrapSnapshot.fromJson(
      body,
      planId: planId,
      userId: expected.userId,
    );
    _requireSame(expected);
    return result;
  }

  Future<Map<String, Object?>> _post(
    String function,
    Map<String, Object?> body, {
    required SyncAuthSession expected,
  }) async {
    final bytes = utf8.encode(jsonEncode(body));
    if (bytes.length > 1024 * 1024) {
      throw const SyncTransportException('request_too_large');
    }
    final uri = baseUrl.resolve('/functions/v1/$function');
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final credentials = _requireSame(expected);
      _HttpResult? result;
      try {
        result = await _exchange(uri, bytes, credentials);
      } on SyncProtocolException {
        rethrow;
      } on SyncTransportException {
        rethrow;
      } on IOException {
        // Socket/TLS/HTTP errors may contain tokens, URIs or raw peer content.
      } on TimeoutException {
        // The exchange aborts its request on timeout before a retry is admitted.
      } catch (_) {
        _requireSame(expected);
        throw const SyncTransportException('request_failed');
      }
      _requireSame(expected);
      if (result != null) {
        if (result.status == HttpStatus.ok || result.status == 426) {
          final Map<String, Object?> decoded;
          try {
            decoded = readSyncObject(jsonDecode(result.body));
          } on FormatException {
            throw const SyncProtocolException('invalid_response');
          }
          if (result.status == 426) {
            final minimum = decoded['min_supported_build'];
            if (decoded['error'] != 'unsupported_protocol' ||
                minimum is! int ||
                minimum < 1 ||
                minimum > 2147483647) {
              throw const SyncProtocolException('invalid_response');
            }
            throw SyncUpdateRequired(minimum);
          }
          return decoded;
        }
        if (!{429, 500, 502, 503, 504}.contains(result.status)) {
          throw SyncTransportException(
            'request_refused',
            statusCode: result.status,
          );
        }
      }
      if (attempt + 1 == maxAttempts) {
        throw SyncTransportException(
          'temporarily_unavailable',
          statusCode: result?.status,
        );
      }
      try {
        await _delay(Duration(milliseconds: 100 * (1 << attempt)));
      } catch (_) {
        throw const SyncTransportException('retry_interrupted');
      }
      _requireSame(expected);
    }
    throw const SyncTransportException('temporarily_unavailable');
  }

  Future<_HttpResult> _exchange(
    Uri uri,
    List<int> bytes,
    SyncAuthSession session,
  ) async {
    HttpClientRequest? request;
    var expired = false;
    Future<_HttpResult> send() async {
      request = await _client.postUrl(uri);
      if (expired || _closed) {
        request!.abort();
        throw const SyncTransportException('exchange_no_longer_active');
      }
      _requireSame(session);
      request!.followRedirects = false;
      request!.headers.set('Authorization', 'Bearer ${session.accessToken}');
      request!.headers.set('apikey', _anonKey);
      request!.headers.contentType = ContentType.json;
      request!.contentLength = bytes.length;
      request!.add(bytes);
      final response = await request!.close();
      final collected = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (collected.length + chunk.length > maxResponseBytes) {
          request!.abort();
          throw const SyncTransportException('response_too_large');
        }
        collected.add(chunk);
      }
      return _HttpResult(
        response.statusCode,
        utf8.decode(collected.takeBytes()),
      );
    }

    try {
      return await send().timeout(
        timeout,
        onTimeout: () {
          expired = true;
          request?.abort();
          throw TimeoutException('Sync request timed out');
        },
      );
    } on FormatException {
      request?.abort();
      throw const SyncProtocolException('invalid_response');
    } catch (_) {
      request?.abort();
      rethrow;
    }
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}

/// Known local columns only; unknown additive wire fields are not authority.
final class BootstrapSnapshot {
  BootstrapSnapshot._(this.plan, this.aliases, this.member);

  factory BootstrapSnapshot.fromJson(
    Map<String, Object?> data, {
    required String planId,
    required String userId,
  }) {
    SyncProtocolVersion.fromJson(data['protocol_version']);
    if (!isSyncUuid(planId) || !isSyncUuid(userId)) _bad();
    final p = _columns(data['plan'], planColumns);
    if (p['id'] != planId ||
        !isSyncUuid(p['creator_user_id']) ||
        !_date(p['wedding_date']) ||
        !_time(p['created_at']) ||
        (p['setup_completed_at'] != null && !_time(p['setup_completed_at'])) ||
        p['deleted_at'] != null ||
        p['is_active'] != true) {
      _bad();
    }
    p['total_budget_cents'] = readSyncInt64(
      p['total_budget_cents'],
      positive: true,
    );
    for (final key in ['guest_cap', 'reminder_window_days']) {
      final n = p[key];
      if (n is! int || n < 0 || n > 2147483647) _bad();
    }
    for (final key in [
      'region_code',
      'ruleset_version',
      'driving_rsvp_status',
    ]) {
      final value = p[key];
      if (value is! String || value.trim().isEmpty) _bad();
    }
    if (p['ceremony_type'] != null &&
        !{
          'church',
          'civil',
          'other_religious',
          'garden_beach_officiant',
          'other',
        }.contains(p['ceremony_type'])) {
      _bad();
    }
    if (p['venue_type'] != null &&
        !{
          'hotel',
          'garden',
          'beach_resort',
          'restaurant',
          'events_place',
          'other',
        }.contains(p['venue_type'])) {
      _bad();
    }
    for (final key in ['reminder_enabled', 'reminder_overdue', 'is_active']) {
      if (p[key] is! bool) _bad();
      p[key] = p[key] == true ? 1 : 0;
    }
    final days = p['reminder_days_before'];
    if (days is! List) _bad();
    final seenDays = <int>{};
    for (final n in days) {
      if (n is! int || n < 0 || !seenDays.add(n)) _bad();
    }
    p['reminder_days_before'] = jsonEncode(days);
    final m = _columns(data['member'], memberColumns);
    if (m['plan_id'] != planId ||
        m['user_id'] != userId ||
        !isSyncUuid(m['plan_member_id']) ||
        !{'creator', 'partner'}.contains(m['role']) ||
        !_time(m['joined_at']) ||
        ((m['role'] == 'creator') != (p['creator_user_id'] == userId))) {
      _bad();
    }
    final raw = data['aliases'];
    if (raw is! List || raw.isEmpty) _bad();
    final aliases = <Map<String, Object?>>[];
    final seen = <String>{};
    var admitted = false;
    for (final value in raw) {
      final a = _columns(value, aliasColumns);
      final aliasId = a['plan_member_id'];
      if (a['plan_id'] != planId ||
          aliasId is! String ||
          !isSyncUuid(aliasId) ||
          (a['user_id'] != null && !isSyncUuid(a['user_id'])) ||
          !seen.add(aliasId)) {
        _bad();
      }
      if (a['plan_member_id'] == m['plan_member_id']) {
        if (a['user_id'] != userId) _bad();
        admitted = true;
      }
      aliases.add(Map.unmodifiable(a));
    }
    if (!admitted) _bad();
    return BootstrapSnapshot._(
      Map.unmodifiable(p),
      List.unmodifiable(aliases),
      Map.unmodifiable(m),
    );
  }

  final Map<String, Object?> plan;
  final List<Map<String, Object?>> aliases;
  final Map<String, Object?> member;
  static Never _bad() => throw const SyncProtocolException('invalid_bootstrap');
  static const planColumns = [
    'id',
    'creator_user_id',
    'wedding_date',
    'total_budget_cents',
    'guest_cap',
    'region_code',
    'ceremony_type',
    'venue_type',
    'reminder_enabled',
    'reminder_window_days',
    'reminder_days_before',
    'reminder_overdue',
    'ruleset_version',
    'driving_rsvp_status',
    'is_active',
    'setup_completed_at',
    'created_at',
    'deleted_at',
  ];
  static const aliasColumns = ['plan_member_id', 'plan_id', 'user_id'];
  static const memberColumns = [
    'plan_id',
    'user_id',
    'plan_member_id',
    'role',
    'joined_at',
  ];
  static Map<String, Object?> _columns(Object? raw, List<String> columns) {
    final object = readSyncObject(raw);
    if (!columns.every(object.containsKey)) _bad();
    return {for (final key in columns) key: object[key]};
  }

  static bool _date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
  }

  static bool _time(Object? value) {
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
}
