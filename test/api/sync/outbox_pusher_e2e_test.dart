// Real encrypted writer -> production pusher -> actual disposable Edge.
@Tags(['local_supabase'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/sync/queue/durable_inbox_puller.dart';
import 'package:kasaran/sync/queue/durable_outbox_pusher.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

String _uuid() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (var i = 0; i < 6; i++) {
    bytes[i] = (millis >> ((5 - i) * 8)) & 255;
  }
  bytes[6] = (bytes[6] & 15) | 0x70;
  bytes[8] = (bytes[8] & 63) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final class _Identity implements SyncSessionSource {
  _Identity(this.userId, this.token);
  final String userId, token;
  final Object marker = Object();
  @override
  SyncAuthSession capture() =>
      SyncAuthSession(userId: userId, marker: marker, accessToken: token);
}

final class _LocalIdentity implements VerifiedLocalIdentity {
  _LocalIdentity(this.source);
  final _Identity source;
  @override
  VerifiedSessionSnapshot capture() =>
      VerifiedSessionSnapshot(source.userId, source.marker);
}

final class _Keys implements DatabaseKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async {
    value = key;
  }
}

// Narrow transparent spy: all exercised operations use the real native client.
final class _RecordingClient implements HttpClient {
  final HttpClient inner = HttpClient();
  final List<List<int>> pushes = [];
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  Future<HttpClientRequest> postUrl(Uri uri) async {
    final request = await inner.postUrl(uri);
    if (!uri.path.endsWith('/sync_push')) return request;
    final bytes = <int>[];
    pushes.add(bytes);
    return _RecordingRequest(request, bytes);
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingRequest implements HttpClientRequest {
  _RecordingRequest(this.inner, this.bytes);
  final HttpClientRequest inner;
  final List<int> bytes;
  @override
  HttpHeaders get headers => inner.headers;
  @override
  set followRedirects(bool value) => inner.followRedirects = value;
  @override
  set contentLength(int value) => inner.contentLength = value;
  @override
  void add(List<int> data) {
    bytes.addAll(data);
    inner.add(data);
  }

  @override
  Future<HttpClientResponse> close() => inner.close();
  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      inner.abort(exception, stackTrace);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'actual Edge accepted additive page persists atomically in second encrypted device through rollback and restart',
    () => _exercise(false, inbox: true),
    timeout: const Timeout(Duration(seconds: 90)),
  );
  for (final failLocally in [false, true]) {
    test(
      failLocally
          ? 'persisted writer actual Edge acceptance survives local rollback reopen and exact retry'
          : 'persisted writer actual Edge acknowledgment survives encrypted reopen',
      () => _exercise(failLocally),
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }
}

Future<void> _exercise(bool failLocally, {bool inbox = false}) async {
  final workdir = Platform.environment['SUPABASE_WORKDIR'];
  expect(
    workdir,
    '/Users/ahronjanl.rafaelahron.0804icloudcom/.hermes/cache/scratch/kasaran_p08_disposable',
    reason: 'Only the preserved exact disposable workdir is authorized',
  );
  final config = await File('$workdir/supabase/config.toml').readAsString();
  expect(
    RegExp(
      r'^project_id\s*=\s*"kasaran_p08_disposable"\s*$',
      multiLine: true,
    ).hasMatch(config),
    isTrue,
    reason: 'Exact disposable guard required before fixture writes',
  );
  final status = await Process.run('supabase', [
    'status',
    '-o',
    'json',
  ], workingDirectory: workdir);
  expect(status.exitCode, 0, reason: 'Disposable services must be running');
  final settings = jsonDecode(status.stdout as String) as Map<String, dynamic>;
  final base = Uri.parse(settings['API_URL'] as String);
  expect(base.host, '127.0.0.1', reason: 'Literal loopback only');
  final anon = settings['ANON_KEY'] as String;
  final service = settings['SERVICE_ROLE_KEY'] as String;
  final client = http.Client();
  addTearDown(client.close);
  Future<Map<String, dynamic>> post(
    String path,
    Object body, {
    String? token,
  }) async {
    final response = await client.post(
      base.resolve(path),
      headers: {
        'apikey': anon,
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    expect(
      response.statusCode,
      anyOf(200, 201),
      reason: 'Synthetic fixture request',
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  final email = 'dart-sync-${_uuid()}@example.test';
  final password = '${_uuid()}Aa1!';
  final user = await post('/auth/v1/admin/users', {
    'email': email,
    'password': password,
    'email_confirm': true,
  }, token: service);
  final login = await post('/auth/v1/token?grant_type=password', {
    'email': email,
    'password': password,
  });
  final token = login['access_token'] as String;
  final planId = _uuid();
  await post('/rest/v1/rpc/create_plan', {
    'p_id': planId,
    'p_wedding_date': '2027-06-01',
    'p_total_budget_cents': 100000,
    'p_guest_cap': 20,
    'p_region_code': 'PH-NCR',
    'p_ruleset_version': 'synthetic',
    'p_driving_rsvp_status': 'unknown',
  }, token: token);
  final aliases = await client.get(
    base.resolve(
      '/rest/v1/plan_member_aliases?select=plan_member_id&plan_id=eq.$planId',
    ),
    headers: {'apikey': anon, 'Authorization': 'Bearer $token'},
  );
  expect(aliases.statusCode, 200);
  final aliasRows = jsonDecode(aliases.body) as List<dynamic>;
  expect(aliasRows, hasLength(1));
  final alias =
      (aliasRows.single as Map<String, dynamic>)['plan_member_id'] as String;
  final identity = _Identity(user['id'] as String, token);
  final local = _LocalIdentity(identity);
  final recording = _RecordingClient();
  final transport = HttpSyncTransport(
    baseUrl: base,
    anonKey: anon,
    sessions: identity,
    client: recording,
    maxAttempts: 1,
  );
  addTearDown(transport.close);
  addTearDown(() => recording.close(force: true));
  final dir = await Directory.systemTemp.createTemp('kasaran-edge-outbox-');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/account.sqlite');
  final keys = _Keys();
  late AppDatabase db;
  AccountStoreCoordinator makeCoordinator() => AccountStoreCoordinator(
    local,
    (_) async => db = await EncryptedDatabaseOpener(file, keys).open(),
  );
  var coordinator = makeCoordinator();
  addTearDown(() => coordinator.close());
  await coordinator.observeSession();
  final actor = LedgerActor(
    planId: planId,
    userId: identity.userId,
    planMemberId: alias,
    deviceId: _uuid(),
  );
  await db.customStatement(
    '''
INSERT INTO plans (id,creator_user_id,wedding_date,total_budget_cents,guest_cap,
region_code,ruleset_version,driving_rsvp_status,created_at)
VALUES (?,?,?,?,?,?,?,?,?)''',
    [
      planId,
      identity.userId,
      '2027-06-01',
      100000,
      20,
      'PH-NCR',
      'synthetic',
      'unknown',
      '2026-10-20T00:00:00Z',
    ],
  );
  await db.customStatement(
    'INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id) VALUES (?,?,?)',
    [alias, planId, identity.userId],
  );
  await db.customStatement(
    'INSERT INTO plan_members (plan_id,user_id,plan_member_id,role,joined_at) VALUES (?,?,?,?,?)',
    [planId, identity.userId, alias, 'creator', '2026-10-20T00:00:00Z'],
  );
  await LocalLedgerWriter(db, identity: local).create(
    actor,
    const LedgerDraft(
      categoryCode: 'buffer',
      entryType: 'standard',
      supplierName: 'Synthetic Edge',
      pricingMode: 'flat',
      estimatedCents: 9007199254740993,
    ),
  );
  Future<List<Map<String, Object?>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table').get())
          .map((r) => r.data)
          .toList();
  final before = await rows('change_log');
  final queue = await rows('outbox');
  final state = await rows('sync_state');
  await coordinator.close();
  coordinator = makeCoordinator();
  await coordinator.observeSession();
  if (failLocally) {
    await db.customStatement('''
CREATE TRIGGER fail_local_ack BEFORE DELETE ON outbox
BEGIN SELECT RAISE(ABORT, 'synthetic local acknowledgment failure'); END''');
    await expectLater(
      DurableOutboxPusher(coordinator, transport).pushOnce(actor),
      throwsA(isA<DurableOutboxException>()),
    );
    expect(await rows('change_log'), before);
    expect(await rows('outbox'), queue);
    expect(await rows('sync_state'), state);
    final acceptedBeforeLocalAck = await transport.pull(planId, cursor: 0);
    expect(acceptedBeforeLocalAck.rows, hasLength(1));
    expect(acceptedBeforeLocalAck.rows.single.id, before.single['id']);
    expect(acceptedBeforeLocalAck.rows.single.serverTimestamp, 1);
    await db.customStatement('DROP TRIGGER fail_local_ack');
    await coordinator.close();
    coordinator = makeCoordinator();
    await coordinator.observeSession();
    expect(await rows('change_log'), before);
    expect(await rows('outbox'), queue);
  }
  final result = await DurableOutboxPusher(
    coordinator,
    transport,
  ).pushOnce(actor);
  expect(result.attempted, 1);
  expect(result.acknowledged, 1);
  expect(recording.pushes, hasLength(failLocally ? 2 : 1));
  if (failLocally) expect(recording.pushes[1], recording.pushes[0]);
  final serverPage = await transport.pull(planId, cursor: 0);
  expect(serverPage.rows, hasLength(1));
  expect(serverPage.rows.single.id, before.single['id']);
  expect(serverPage.rows.single.serverTimestamp, 1);
  expect(
    serverPage.rows.single.data['new_value'],
    jsonDecode(before.single['new_value']! as String),
  );
  expect(serverPage.nextCursor, 1);
  expect(serverPage.hasMore, isFalse);
  await coordinator.close();
  coordinator = makeCoordinator();
  await coordinator.observeSession();
  expect(await rows('outbox'), isEmpty);
  expect(await rows('change_log'), [
    {...before.single, 'server_ts': 1},
  ]);
  expect((await rows('sync_state')).single, {
    ...state.single,
    'last_pushed_server_ts': 1,
  });
  expect(
    (await db.select(db.ledgerEntries).get()).single.estimatedCents,
    9007199254740993,
  );
  expect(
    (await file.readAsBytes()).take(16).toList(),
    isNot(utf8.encode('SQLite format 3\u0000')),
  );
  if (inbox) {
    // Publicly accepted supported event with unknown additive fields, not a
    // future schema/entity insertion or a claim about financial projection.
    final additive = SyncEvent.fromJson({
      'id': _uuid(),
      'plan_id': planId,
      'entity_id': _uuid(),
      'entity_type': 'ledger_entries',
      'field_name': 'supplier_name',
      'schema_version': 1,
      'change_group_id': null,
      'old_value': null,
      'new_value': 'Compatible additive event',
      'device_monotonic': '0',
      'device_id': actor.deviceId,
      'plan_member_id': alias,
      'created_at': '2026-10-20T00:00:00.000000Z',
      'future': {
        'array': [9007199254740993, -9007199254740993, true, null],
      },
    });
    expect((await transport.push(planId, [additive])).accepted[additive.id], 2);
    final accepted = await transport.pull(planId, cursor: 0);
    expect(accepted.rows, hasLength(2));
    final secondFile = File('${dir.path}/second.sqlite'), secondKeys = _Keys();
    late AppDatabase secondDb;
    AccountStoreCoordinator secondOwner() => AccountStoreCoordinator(
      local,
      (_) async => secondDb = await EncryptedDatabaseOpener(
        secondFile,
        secondKeys,
      ).open(),
    );
    var second = secondOwner();
    addTearDown(() => second.close());
    await second.observeSession();
    for (final table in ['plans', 'plan_member_aliases', 'plan_members']) {
      for (final row in await rows(table)) {
        await secondDb.customStatement(
          'INSERT INTO $table (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
          row.values.toList(),
        );
      }
    }
    expect(secondKeys.value, isNot(keys.value));
    final secondActor = LedgerActor(
      planId: planId,
      userId: identity.userId,
      planMemberId: alias,
      deviceId: _uuid(),
    );
    await LocalLedgerWriter(secondDb, identity: local).create(
      secondActor,
      const LedgerDraft(
        categoryCode: 'buffer',
        entryType: 'standard',
        supplierName: 'Second pending original',
        pricingMode: 'flat',
        estimatedCents: 9007199254740993,
      ),
    );
    Future<List<Map<String, Object?>>> secondRows(String table) async =>
        (await secondDb.customSelect('SELECT * FROM $table').get())
            .map((r) => r.data)
            .toList();
    final originals = {
      for (final t in ['ledger_entries', 'change_log', 'outbox', 'sync_state'])
        t: await secondRows(t),
    };
    await secondDb.customStatement(
      "CREATE TRIGGER fail_inbox_cursor BEFORE UPDATE ON sync_state BEGIN SELECT RAISE(ABORT,'synthetic cursor failure'); END",
    );
    await expectLater(
      DurableInboxPuller(second, transport).pullOnce(secondActor),
      throwsA(isA<DurableInboxException>()),
    );
    expect(await secondRows('sync_inbox'), isEmpty);
    for (final t in originals.keys) {
      expect(await secondRows(t), originals[t]);
    }
    await secondDb.customStatement('DROP TRIGGER fail_inbox_cursor');
    await second.close();
    second = secondOwner();
    await second.observeSession();
    expect(await secondRows('sync_inbox'), isEmpty);
    for (final t in originals.keys) {
      expect(await secondRows(t), originals[t]);
    }
    final firstPage = await DurableInboxPuller(
      second,
      transport,
    ).pullOnce(secondActor, limit: 1);
    expect(firstPage.received, 1);
    expect(firstPage.cursor, 1);
    expect(firstPage.hasMore, isTrue);
    await second.close();
    second = secondOwner();
    await second.observeSession();
    final finalPage = await DurableInboxPuller(
      second,
      transport,
    ).pullOnce(secondActor, limit: 1);
    expect(finalPage.received, 1);
    expect(finalPage.cursor, 2);
    expect(finalPage.hasMore, isFalse);
    await second.close();
    second = secondOwner();
    await second.observeSession();
    final retained = await secondRows('sync_inbox');
    expect(retained, hasLength(2));
    expect(
      retained.map((r) => jsonDecode(r['raw_event']! as String)).toList(),
      accepted.rows.map((r) => r.data).toList(),
    );
    expect(jsonDecode(retained.last['raw_event']! as String), {
      ...additive.data,
      'server_ts': '2',
    });
    for (final t in ['ledger_entries', 'change_log', 'outbox']) {
      expect(await secondRows(t), originals[t]);
    }
    expect((await secondRows('sync_state')).single, {
      ...originals['sync_state']!.single,
      'last_pulled_server_ts': 2,
    });
    final empty = await DurableInboxPuller(
      second,
      transport,
    ).pullOnce(secondActor);
    expect(empty.received, 0);
    expect(empty.cursor, 2);
    expect(empty.hasMore, isFalse);
    expect(await secondRows('sync_inbox'), retained);
    // A new local device cursor re-fetches the same real server events. The
    // retained plan-wide inbox must recognize both exact duplicates after a
    // restart, without changing this second device's pending writes.
    final replayActor = LedgerActor(
      planId: planId,
      userId: identity.userId,
      planMemberId: alias,
      deviceId: _uuid(),
    );
    final priorState = await secondRows('sync_state');
    expect(
      (await DurableInboxPuller(
        second,
        transport,
      ).pullOnce(replayActor, limit: 1)).cursor,
      1,
    );
    await second.close();
    second = secondOwner();
    await second.observeSession();
    expect(
      (await DurableInboxPuller(
        second,
        transport,
      ).pullOnce(replayActor, limit: 1)).cursor,
      2,
    );
    expect(await secondRows('sync_inbox'), retained);
    final replayStates = await secondRows('sync_state');
    expect(
      replayStates
          .where((row) => row['device_id'] == secondActor.deviceId)
          .single,
      priorState.single,
    );
    expect(
      replayStates
          .where((row) => row['device_id'] == replayActor.deviceId)
          .single,
      {
        'device_id': replayActor.deviceId,
        'plan_id': planId,
        'device_monotonic': 0,
        'last_pushed_server_ts': null,
        'last_pulled_server_ts': 2,
      },
    );
    for (final t in ['ledger_entries', 'change_log', 'outbox']) {
      expect(await secondRows(t), originals[t]);
    }
    expect(
      (await secondFile.readAsBytes()).take(16).toList(),
      isNot(utf8.encode('SQLite format 3\u0000')),
    );
  }
}
