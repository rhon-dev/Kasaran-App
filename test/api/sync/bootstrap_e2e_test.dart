// Exact synthetic disposable services only; never starts or applies services.
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
import 'package:kasaran/sync/queue/account_metadata_bootstrapper.dart';
import 'package:kasaran/sync/queue/account_sync_worker.dart';
import 'package:kasaran/sync/queue/durable_inbox_puller.dart';
import 'package:kasaran/sync/queue/durable_outbox_pusher.dart';
import 'package:kasaran/sync/replay/durable_projection_rebuilder.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

String uuid() {
  final b = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  b[6] = (b[6] & 15) | 0x70;
  b[8] = (b[8] & 63) | 0x80;
  final h = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class Sessions implements SyncSessionSource {
  Sessions(this.user, this.token);
  final String user, token;
  final marker = Object();
  @override
  SyncAuthSession capture() =>
      SyncAuthSession(userId: user, marker: marker, accessToken: token);
}

class LocalIdentity implements VerifiedLocalIdentity {
  LocalIdentity(this.source);
  final Sessions source;
  @override
  VerifiedSessionSnapshot capture() =>
      VerifiedSessionSnapshot(source.user, source.marker);
}

class Keys implements DatabaseKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async {
    value = key;
  }
}

void main() {
  test(
    'actual authoritative Edge bootstrap feeds fresh encrypted second-device worker without seeded membership',
    () async {
      final disposable = Platform.environment['SUPABASE_WORKDIR'] ?? '';
      expect(
        disposable,
        isNotEmpty,
        reason: 'Explicit disposable workdir required',
      );
      final config = await File(
        '$disposable/supabase/config.toml',
      ).readAsString();
      expect(
        RegExp(
          r'^project_id\s*=\s*"kasaran_p08_disposable"\s*$',
          multiLine: true,
        ).hasMatch(config),
        isTrue,
      );
      final status = await Process.run('supabase', [
        'status',
        '-o',
        'json',
      ], workingDirectory: disposable);
      expect(
        status.exitCode,
        0,
        reason: 'Exclusive running disposable project required',
      );
      final settings =
          jsonDecode(status.stdout as String) as Map<String, dynamic>;
      final base = Uri.parse(settings['API_URL'] as String);
      expect(base.host, '127.0.0.1');
      expect(base.scheme, 'http');
      final anon = settings['ANON_KEY'] as String,
          service = settings['SERVICE_ROLE_KEY'] as String;
      final client = http.Client();
      addTearDown(client.close);
      Future<http.Response> request(String path, Object body, String token) =>
          client.post(
            base.resolve(path),
            headers: {
              'apikey': anon,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          );
      Future<Map<String, dynamic>> post(
        String path,
        Object body,
        String token,
      ) async {
        final r = await request(path, body, token);
        expect(
          r.statusCode,
          anyOf(200, 201),
          reason: 'Synthetic fixture request',
        );
        return jsonDecode(r.body) as Map<String, dynamic>;
      }

      Future<void> sql(String source) async {
        final r = await Process.run('docker', [
          'exec',
          'supabase_db_kasaran_p08_disposable',
          'psql',
          '-XAt',
          '-v',
          'ON_ERROR_STOP=1',
          '-U',
          'postgres',
          '-d',
          'postgres',
          '-c',
          source,
        ]);
        expect(r.exitCode, 0, reason: 'Synthetic disposable fixture SQL');
      }

      Future<Sessions> account() async {
        final email = 'bootstrap-${uuid()}@example.test',
            password = '${uuid()}Aa1!';
        final u = await post('/auth/v1/admin/users', {
          'email': email,
          'password': password,
          'email_confirm': true,
        }, service);
        final s = await post('/auth/v1/token?grant_type=password', {
          'email': email,
          'password': password,
        }, anon);
        return Sessions(u['id'] as String, s['access_token'] as String);
      }

      final sessions = await account(), foreign = await account();
      final plan = uuid();
      await post('/rest/v1/rpc/create_plan', {
        'p_id': plan,
        'p_wedding_date': '2027-06-01',
        'p_total_budget_cents': 9223372036854775807,
        'p_guest_cap': 20,
        'p_region_code': 'PH-NCR',
        'p_ruleset_version': 'synthetic',
        'p_driving_rsvp_status': 'unknown',
      }, sessions.token);
      final historicalAlias = uuid();
      await sql(
        "insert into public.plan_member_aliases(plan_id,plan_member_id,user_id) values('$plan'::uuid,'$historicalAlias'::uuid,null)",
      );
      final body = {
        'protocol_version': {'major': 1, 'minor': 0},
        'plan_id': plan,
      };
      final response = await request(
        '/functions/v1/sync_bootstrap',
        body,
        sessions.token,
      );
      expect(
        response.statusCode,
        200,
        reason: 'New authoritative bootstrap endpoint required',
      );
      final remote = jsonDecode(response.body) as Map<String, dynamic>;
      expect(
        (remote['plan'] as Map)['total_budget_cents'],
        '9223372036854775807',
      );
      expect((remote['member'] as Map)['user_id'], sessions.user);
      expect(remote['aliases'], hasLength(2));
      expect(
        (remote['aliases'] as List).any(
          (a) =>
              (a as Map)['plan_member_id'] == historicalAlias &&
              a['user_id'] == null,
        ),
        isTrue,
      );
      final denied = await request(
        '/functions/v1/sync_bootstrap',
        body,
        foreign.token,
      );
      final missing = await request('/functions/v1/sync_bootstrap', {
        'protocol_version': {'major': 1, 'minor': 0},
        'plan_id': uuid(),
      }, sessions.token);
      expect(denied.statusCode, 403);
      expect(missing.statusCode, 403);
      expect(denied.body, missing.body);
      final update = await request('/functions/v1/sync_bootstrap', {
        'protocol_version': {'major': 2, 'minor': 0},
        'plan_id': plan,
      }, sessions.token);
      expect(update.statusCode, 426);
      expect(jsonDecode(update.body), {
        'error': 'unsupported_protocol',
        'min_supported_build': 1,
      });
      final local = LocalIdentity(sessions);
      final dir = await Directory.systemTemp.createTemp(
        'kasaran-bootstrap-edge-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final bootstrapTransport = HttpBootstrapTransport(
        baseUrl: base,
        anonKey: anon,
        sessions: sessions,
        maxAttempts: 1,
      );
      addTearDown(bootstrapTransport.close);
      final sync = HttpSyncTransport(
        baseUrl: base,
        anonKey: anon,
        sessions: sessions,
        maxAttempts: 1,
      );
      addTearDown(sync.close);
      final databases = <AppDatabase>[],
          coordinators = <AccountStoreCoordinator>[],
          actors = <LedgerActor>[],
          workers = <AccountSyncWorker>[],
          keys = <Keys>[];
      addTearDown(() async {
        for (final w in workers) {
          await w.dispose();
        }
        for (final c in coordinators) {
          await c.close();
        }
      });
      List<Map<String, Object?>>? expectedSource;
      String? entryId;
      Future<List<Map<String, Object?>>> source(AppDatabase db) async =>
          (await db
                  .customSelect('SELECT * FROM ledger_entries ORDER BY id')
                  .get())
              .map((r) => r.data)
              .toList();
      for (var i = 0; i < 2; i++) {
        final k = Keys();
        keys.add(k);
        late AppDatabase db;
        final c = AccountStoreCoordinator(
          local,
          (_) async => db = await EncryptedDatabaseOpener(
            File('${dir.path}/$i.sqlite'),
            k,
          ).open(),
        );
        await c.observeSession();
        coordinators.add(c);
        databases.add(db);
        for (final table in [
          'plans',
          'plan_member_aliases',
          'plan_members',
          'ledger_entries',
          'change_log',
          'sync_state',
          'sync_inbox',
          'outbox',
        ]) {
          expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
        }
        actors.add(
          await AccountMetadataBootstrapper(
            c,
            bootstrapTransport,
          ).bootstrap(planId: plan, deviceId: uuid()),
        );
        expect(
          (await db.customSelect('SELECT total_budget_cents FROM plans').get())
              .single
              .data['total_budget_cents'],
          9223372036854775807,
        );
        for (final table in [
          'ledger_entries',
          'change_log',
          'sync_state',
          'sync_inbox',
          'outbox',
        ]) {
          expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
        }
        if (i == 0) {
          final created = await LocalLedgerWriter(db, identity: local).create(
            actors[i],
            const LedgerDraft(
              categoryCode: 'buffer',
              entryType: 'standard',
              supplierName: 'Synthetic',
              pricingMode: 'flat',
              estimatedCents: 9007199254740993,
            ),
          );
          entryId = created.id;
        }
        final w = AccountSyncWorker(
          coordinator: c,
          actor: actors[i],
          pusher: DurableOutboxPusher(c, sync),
          puller: DurableInboxPuller(c, sync),
          rebuilder: DurableProjectionRebuilder(c),
        );
        workers.add(w);
        await w.start();
        expect(w.status, AccountSyncStatus.idle);
        final actual = await source(db);
        if (i == 0) {
          expectedSource = actual;
        } else {
          expect(actual, expectedSource);
        }
        expect(actual.single['id'], entryId);
        expect(actual.single['estimated_cents'], 9007199254740993);
        await w.dispose();
        await c.close();
      }
      final reopened = await EncryptedDatabaseOpener(
        File('${dir.path}/1.sqlite'),
        keys[1],
      ).open();
      try {
        expect(
          (await source(reopened)).single['estimated_cents'],
          9007199254740993,
        );
      } finally {
        await reopened.close();
      }
      final callerAlias = (remote['member'] as Map)['plan_member_id'] as String;
      final joined = (remote['member'] as Map)['joined_at'] as String;
      await sql(
        "update public.plans set is_active=false where id='$plan'::uuid",
      );
      final inactive = await request(
        '/functions/v1/sync_bootstrap',
        body,
        sessions.token,
      );
      expect(inactive.statusCode, 403);
      expect(inactive.body, denied.body);
      await sql(
        "update public.plans set is_active=true where id='$plan'::uuid; delete from public.plan_members where plan_id='$plan'::uuid and user_id='${sessions.user}'::uuid",
      );
      final removed = await request(
        '/functions/v1/sync_bootstrap',
        body,
        sessions.token,
      );
      expect(removed.statusCode, 403);
      expect(removed.body, denied.body);
      await sql(
        "insert into public.plan_members(plan_id,user_id,plan_member_id,role,joined_at) values('$plan'::uuid,'${sessions.user}'::uuid,'$callerAlias'::uuid,'creator','$joined'::timestamptz)",
      );
      final forged = await request('/functions/v1/sync_bootstrap', {
        ...body,
        'user_id': sessions.user,
        'role': 'creator',
        'plan_member_id': callerAlias,
      }, foreign.token);
      expect(forged.statusCode, 403);
      await sql(
        "update auth.sessions set not_after=now()-interval '1 second' where user_id='${sessions.user}'::uuid",
      );
      final expired = await request(
        '/functions/v1/sync_bootstrap',
        body,
        sessions.token,
      );
      expect(expired.statusCode, 401);
      await sql(
        "delete from auth.sessions where user_id='${sessions.user}'::uuid",
      );
      final revoked = await request(
        '/functions/v1/sync_bootstrap',
        body,
        sessions.token,
      );
      expect(revoked.statusCode, 401);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
