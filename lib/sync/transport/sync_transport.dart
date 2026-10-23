import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show GoTrueClient;

/// Binds a request to an independently admitted account without credentials.
final class SyncSessionBinding {
  const SyncSessionBinding({required this.userId, required this.marker});
  final String userId;
  final Object marker;
  @override
  String toString() => 'SyncSessionBinding(redacted)';
}

/// Transient credentials only. Never persist or log this object.
final class SyncAuthSession {
  const SyncAuthSession({
    required this.userId,
    required this.marker,
    required this.accessToken,
  });
  final String userId;
  final Object marker;
  final String accessToken;
  @override
  String toString() => 'SyncAuthSession(redacted)';
}

// The synchronous capture is required to guard silent Session replacement.
// ignore: one_member_abstracts
abstract interface class SyncSessionSource {
  SyncAuthSession? capture();
}

final class SupabaseSyncSessionSource implements SyncSessionSource {
  const SupabaseSyncSessionSource(this.auth);
  final GoTrueClient auth;
  @override
  SyncAuthSession? capture() {
    final session = auth.currentSession;
    if (session == null || session.user.emailConfirmedAt == null) return null;
    return SyncAuthSession(
      userId: session.user.id,
      marker: session,
      accessToken: session.accessToken,
    );
  }
}

final class SyncTransportException implements Exception {
  const SyncTransportException(this.code, {this.statusCode});
  final String code;
  final int? statusCode;
  @override
  String toString() => 'SyncTransportException: $code';
}

final class SyncUpdateRequired implements Exception {
  const SyncUpdateRequired(this.minSupportedBuild);
  final int minSupportedBuild;
  @override
  String toString() => 'SyncUpdateRequired: minimum build $minSupportedBuild';
}

final class _HttpResult {
  const _HttpResult(this.status, this.body);
  final int status;
  final String body;
}

/// HTTP only: no database, queue acknowledgment, cursor write or projection.
/// The transport owns its HttpClient, including an explicitly supplied client.
final class HttpSyncTransport {
  HttpSyncTransport({
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

  Future<SyncPushResult> push(
    String planId,
    List<SyncEvent> rows, {
    SyncSessionBinding? requiredSession,
  }) async {
    final expected = _capture();
    if (requiredSession != null &&
        (expected.userId != requiredSession.userId ||
            !identical(expected.marker, requiredSession.marker))) {
      throw const SyncTransportException('session_changed');
    }
    if (!isSyncUuid(planId) || rows.length > 100) {
      throw const SyncProtocolException('invalid_request');
    }
    final ids = <String>{};
    final payload = <Map<String, Object?>>[];
    for (final row in rows) {
      if (row.planId != planId || !ids.add(row.id)) {
        throw const SyncProtocolException('invalid_request');
      }
      payload.add(row.toPushJson());
    }
    final body = await _post('sync_push', {
      'protocol_version': const SyncProtocolVersion().toJson(),
      'plan_id': planId,
      'rows': payload,
    }, expected: expected);
    final result = SyncPushResult.fromJson(body, requestedIds: ids);
    _requireSame(expected);
    return result;
  }

  Future<SyncPullPage> pull(
    String planId, {
    required int cursor,
    int limit = 100,
    SyncSessionBinding? requiredSession,
  }) async {
    final expected = _capture();
    if (requiredSession != null &&
        (expected.userId != requiredSession.userId ||
            !identical(expected.marker, requiredSession.marker))) {
      throw const SyncTransportException('session_changed');
    }
    if (!isSyncUuid(planId) || cursor < 0 || limit < 1 || limit > 1000) {
      throw const SyncProtocolException('invalid_request');
    }
    final body = await _post('sync_pull', {
      'protocol_version': const SyncProtocolVersion().toJson(),
      'plan_id': planId,
      'cursor': '$cursor',
      'limit': limit,
    }, expected: expected);
    final result = SyncPullPage.fromJson(
      body,
      planId: planId,
      cursor: cursor,
      limit: limit,
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
