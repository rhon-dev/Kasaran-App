import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show ApplyInterceptor, TransactionExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/local_ledger_writer.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/sync/queue/account_metadata_bootstrapper.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import '../transport/bootstrap_transport_test.dart' as wire;
import 'durable_outbox_pusher_test.dart' as fixture;

class BoundaryLocalIdentity extends fixture.LocalIdentity {
  BoundaryLocalIdentity(super.source);
  void Function()? onCapture;
  @override
  VerifiedSessionSnapshot capture() {
    final result = super.capture();
    onCapture?.call();
    return result;
  }
}

class AfterCommitHook extends fixture.CommitHook {
  void Function()? committed;
  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await super.commitTransaction(inner);
    committed?.call();
  }
}

void main() {
  late Directory dir;
  late File file;
  late fixture.Keys keys;
  late fixture.Identity identity;
  late BoundaryLocalIdentity local;
  late AccountStoreCoordinator coordinator;
  late AppDatabase db;
  late sqlite.Database native;
  late AfterCommitHook commit;
  late HttpServer server;
  late HttpBootstrapTransport transport;
  late AccountMetadataBootstrapper bootstrapper;
  late Future<void> Function(HttpRequest) respond;
  late int requests;
  Future<List<Map<String, Object?>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
          .map((r) => r.data)
          .toList();
  Future<Map<String, List<Map<String, Object?>>>> surfaces() async => {
    for (final t in [
      'plans',
      'plan_member_aliases',
      'plan_members',
      'ledger_entries',
      'change_log',
      'sync_state',
      'sync_inbox',
      'outbox',
    ])
      t: await rows(t),
  };
  Future<void> reply(HttpRequest req, [Map<String, Object?>? data]) async {
    req.response.write(jsonEncode(data ?? wire.snapshot()));
    await req.response.close();
  }

  Future<void> reopen() async {
    await coordinator.close();
    coordinator = AccountStoreCoordinator(
      local,
      (_) async => db = await EncryptedDatabaseOpener(file, keys).open(),
    );
    await coordinator.observeSession();
    bootstrapper = AccountMetadataBootstrapper(coordinator, transport);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kasaran-bootstrap-');
    file = File('${dir.path}/a.sqlite');
    keys = fixture.Keys();
    identity = fixture.Identity()..user = wire.userId;
    local = BoundaryLocalIdentity(identity);
    final initial = await EncryptedDatabaseOpener(file, keys).open();
    await initial.close();
    commit = AfterCommitHook();
    coordinator = AccountStoreCoordinator(
      local,
      (_) async => db = AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            native = raw;
            if (raw.select('PRAGMA cipher').isEmpty) {
              throw StateError('Cipher required');
            }
            raw.execute("PRAGMA key = '${keys.key!}'");
          },
        ).interceptWith(commit),
      ),
    );
    await coordinator.observeSession();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = 0;
    respond = reply;
    server.listen((r) async {
      await r.drain<void>();
      requests++;
      await respond(r);
    });
    transport = HttpBootstrapTransport(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      anonKey: 'synthetic-anon',
      sessions: identity,
      maxAttempts: 1,
    );
    bootstrapper = AccountMetadataBootstrapper(coordinator, transport);
  });
  tearDown(() async {
    transport.close();
    await server.close(force: true);
    await coordinator.close();
    await dir.delete(recursive: true);
  });
  test(
    'replacement in completed lease wrapper gap suppresses final actor return',
    () async {
      var afterCommit = false, checks = 0, replaced = false;
      commit.committed = () => afterCommit = true;
      local.onCapture = () {
        if (afterCommit && ++checks == 2) {
          replaced = true;
          identity.marker = Object();
        }
      };
      await expectLater(
        bootstrapper.bootstrap(planId: wire.planId, deviceId: wire.deviceId),
        throwsA(anything),
      );
      expect(replaced, isTrue);
      local.onCapture = null;
      await coordinator.observeSession();
      expect(await rows('plan_members'), hasLength(1));
    },
  );
  test(
    'native rejected COMMIT preserves all surfaces through encrypted reopen and permits retry',
    () async {
      final before = await surfaces();
      var rejected = 0;
      respond = (r) async {
        native.commitFilter = () {
          if (rejected == 0) {
            rejected++;
            return false;
          }
          return true;
        };
        await reply(r);
      };
      await expectLater(
        bootstrapper.bootstrap(planId: wire.planId, deviceId: wire.deviceId),
        throwsA(isA<MetadataBootstrapException>()),
      );
      expect(rejected, 1);
      await reopen();
      expect(await surfaces(), before);
      respond = reply;
      expect(
        (await bootstrapper.bootstrap(
          planId: wire.planId,
          deviceId: wire.deviceId,
        )).userId,
        wire.userId,
      );
    },
  );
  for (final mode in ['observed replacement', 'transition']) {
    test(
      'paused actual COMMIT drains original account and suppresses stale result: $mode',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        commit.action = () async {
          entered.complete();
          await release.future;
        };
        final pending = bootstrapper.bootstrap(
          planId: wire.planId,
          deviceId: wire.deviceId,
        );
        await entered.future.timeout(const Duration(seconds: 5));
        var changed = false;
        final Future<void> draining;
        if (mode == 'transition') {
          draining = coordinator.transition(() async {
            changed = true;
            identity.marker = Object();
          });
        } else {
          identity.marker = Object();
          draining = coordinator.observeSession();
        }
        expect(coordinator.isReady, isFalse);
        expect(changed, isFalse);
        release.complete();
        await expectLater(pending, throwsA(anything));
        await draining;
        expect(await rows('plan_members'), hasLength(1));
        await reopen();
        expect(await rows('plans'), hasLength(1));
        for (final t in [
          'ledger_entries',
          'change_log',
          'sync_state',
          'sync_inbox',
          'outbox',
        ]) {
          expect(await rows(t), isEmpty);
        }
      },
    );
  }
  for (final mode in [
    'silent replacement',
    'revoked generation',
    'foreign account',
    'missing alias',
    'invalid budget',
    'invalid device',
  ]) {
    test('all-surface refusal: $mode', () async {
      final before = await surfaces();
      Future<void>? draining;
      respond = (r) async {
        final s =
            jsonDecode(jsonEncode(wire.snapshot())) as Map<String, Object?>;
        if (mode == 'silent replacement') identity.marker = Object();
        if (mode == 'revoked generation') {
          draining = coordinator.transition(() async {});
        }
        if (mode == 'foreign account') {
          final member = s['member']! as Map<String, Object?>;
          member['user_id'] = fixture.actorB.deviceId;
        }
        if (mode == 'missing alias') s['aliases'] = [];
        if (mode == 'invalid budget') {
          final plan = s['plan']! as Map<String, Object?>;
          plan['total_budget_cents'] = '9223372036854775808';
        }
        await reply(r, s);
      };
      await expectLater(
        bootstrapper.bootstrap(
          planId: wire.planId,
          deviceId: mode == 'invalid device' ? 'invalid' : wire.deviceId,
        ),
        throwsA(anything),
      );
      if (draining != null) await draining;
      await coordinator.observeSession();
      expect(await surfaces(), before);
      if (mode == 'invalid device') expect(requests, 0);
    });
  }
  for (final conflict in ['plan', 'alias', 'member', 'extra alias']) {
    test(
      'conflicting $conflict refuses without changing any offline surface',
      () async {
        final actor = await bootstrapper.bootstrap(
          planId: wire.planId,
          deviceId: wire.deviceId,
        );
        await LocalLedgerWriter(
          db,
          identity: local,
        ).create(actor, fixture.draft);
        if (conflict == 'plan') {
          await db.customStatement('UPDATE plans SET guest_cap=99');
        }
        if (conflict == 'alias') {
          await db.customStatement(
            'INSERT INTO plan_member_aliases(plan_id,plan_member_id,user_id) VALUES(?,?,NULL)',
            [wire.planId, fixture.actorB.planMemberId],
          );
        }
        if (conflict == 'member') {
          await db.customStatement(
            "UPDATE plan_members SET joined_at='2026-10-21T00:00:00Z'",
          );
        }
        if (conflict == 'extra alias') {
          respond = (req) {
            final s =
                jsonDecode(jsonEncode(wire.snapshot())) as Map<String, Object?>;
            final aliases = s['aliases']! as List<Object?>;
            aliases.add(<String, Object?>{
              'plan_id': wire.planId,
              'plan_member_id': fixture.actorB.planMemberId,
              'user_id': null,
            });
            return reply(req, s);
          };
        }
        final before = await surfaces();
        await expectLater(
          bootstrapper.bootstrap(planId: wire.planId, deviceId: wire.deviceId),
          throwsA(isA<MetadataBootstrapException>()),
        );
        expect(await surfaces(), before);
        await reopen();
        expect(await surfaces(), before);
      },
    );
  }
  test(
    'empty encrypted account bootstrap publishes full metadata only and exact retry survives reopen',
    () async {
      expect((await surfaces()).values.every((r) => r.isEmpty), isTrue);
      final actor = await bootstrapper.bootstrap(
        planId: wire.planId,
        deviceId: wire.deviceId,
      );
      expect(actor.userId, wire.userId);
      expect(actor.planMemberId, wire.aliasId);
      expect(actor.deviceId, wire.deviceId);
      expect(
        (await rows('plans')).single['total_budget_cents'],
        9223372036854775807,
      );
      expect(await rows('plan_members'), hasLength(1));
      expect(await rows('plan_member_aliases'), hasLength(1));
      for (final t in [
        'ledger_entries',
        'change_log',
        'sync_state',
        'sync_inbox',
        'outbox',
      ]) {
        expect(await rows(t), isEmpty);
      }
      final before = await surfaces();
      await reopen();
      expect(await surfaces(), before);
      await bootstrapper.bootstrap(
        planId: wire.planId,
        deviceId: wire.deviceId,
      );
      expect(await surfaces(), before);
      await coordinator.withAccount(
        (lease) => lease.run(
          (db) => LocalLedgerWriter(
            db,
            identity: local,
          ).requireLocalMembership(actor),
        ),
      );
    },
  );
}
