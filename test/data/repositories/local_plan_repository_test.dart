import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/local_plan_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';

import '../../sync/queue/account_metadata_bootstrapper_test.dart'
    show AfterCommitHook, BoundaryLocalIdentity;
import '../../sync/queue/durable_outbox_pusher_test.dart' as fixture;

class LocalReadHook extends AfterCommitHook {
  int? queryOrdinal;
  Future<void> Function()? afterQuery;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (queryOrdinal != null && statement.toLowerCase().contains('plans')) {
      queryOrdinal = queryOrdinal! - 1;
      if (queryOrdinal == 0) {
        queryOrdinal = null;
        await afterQuery?.call();
      }
    }
    return rows;
  }
}

class NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Network forbidden');
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late AccountStoreCoordinator coordinator;
  late LocalPlanRepository repository;
  late fixture.Identity identity;
  late BoundaryLocalIdentity local;
  late LocalReadHook commit;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kasaran-local-plan-');
    identity = fixture.Identity();
    local = BoundaryLocalIdentity(identity);
    final keys = fixture.Keys(), file = File('${dir.path}/account.sqlite');
    final initial = await EncryptedDatabaseOpener(file, keys).open();
    await initial.close();
    commit = LocalReadHook();
    coordinator = AccountStoreCoordinator(
      local,
      (_) async => db = AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            if (raw.select('PRAGMA cipher').isEmpty) {
              throw StateError('Cipher required');
            }
            raw.execute("PRAGMA key = '${keys.key!}'");
          },
        ).interceptWith(commit),
      ),
    );
    await coordinator.observeSession();
    repository = LocalPlanRepository(coordinator);
  });
  tearDown(() async {
    await coordinator.close();
    await dir.delete(recursive: true);
  });
  for (final query in [1, 2]) {
    for (final change in ['same-user', 'A-B-A', 'generation']) {
      test(
        '$change after local metadata query $query rejects stale snapshot',
        () async {
          await fixture.seed(db, fixture.actor);
          final entered = Completer<void>(), release = Completer<void>();
          commit.queryOrdinal = query;
          commit.afterQuery = () async {
            entered.complete();
            await release.future;
          };
          final rejected = expectLater(
            repository.currentActivePlan(),
            throwsStateError,
          );
          await entered.future.timeout(const Duration(seconds: 5));
          final Future<void> changing;
          if (change == 'generation') {
            changing = coordinator.transition(() async {});
          } else {
            if (change == 'A-B-A') identity.user = fixture.actorB.userId;
            identity.marker = Object();
            changing = coordinator.observeSession();
            if (change == 'A-B-A') {
              identity.user = fixture.actor.userId;
              identity.marker = Object();
            }
          }
          release.complete();
          await rejected;
          await changing;
          expect(commit.queryOrdinal, isNull);
        },
      );
    }
  }
  for (final mode in ['same-user', 'A-B-A', 'generation']) {
    test(
      'local read native COMMIT suppresses disclosure across $mode',
      () async {
        await fixture.seed(db, fixture.actor);
        final entered = Completer<void>(), release = Completer<void>();
        commit.action = () async {
          entered.complete();
          await release.future;
        };
        final reading = repository.currentActivePlan();
        final rejected = expectLater(reading, throwsStateError);
        await entered.future.timeout(const Duration(seconds: 5));
        final Future<void> changing;
        if (mode == 'generation') {
          changing = coordinator.transition(() async {});
        } else {
          if (mode == 'A-B-A') identity.user = fixture.actorB.userId;
          identity.marker = Object();
          changing = coordinator.observeSession();
          if (mode == 'A-B-A') {
            identity.user = fixture.actor.userId;
            identity.marker = Object();
          }
        }
        release.complete();
        await rejected;
        await changing;
        local.onCapture = null;
        await coordinator.observeSession();
        expect(
          (await repository.currentActivePlan())!.member.userId,
          fixture.actor.userId,
        );
      },
    );
  }
  for (final gap in ['after COMMIT', 'completed wrapper']) {
    test('$gap session replacement rejects final local snapshot', () async {
      await fixture.seed(db, fixture.actor);
      var committed = false, checks = 0, replaced = false;
      commit.committed = () {
        committed = true;
        if (gap == 'after COMMIT') {
          identity.marker = Object();
          replaced = true;
        }
      };
      local.onCapture = () {
        if (gap == 'completed wrapper' && committed && ++checks == 3) {
          identity.marker = Object();
          replaced = true;
        }
      };
      await expectLater(repository.currentActivePlan(), throwsStateError);
      expect(replaced, isTrue);
      local.onCapture = null;
      commit.committed = null;
      await coordinator.observeSession();
      expect(
        (await repository.currentActivePlan())!.plan.id,
        fixture.actor.planId,
      );
    });
  }
  test(
    'multiple active plans fail closed rather than selecting an arbitrary plan',
    () async {
      await fixture.seed(db, fixture.actor);
      await fixture.seed(db, fixture.actorB);
      await expectLater(repository.currentActivePlan(), throwsStateError);
    },
  );
  test('missing or mismatched caller alias fails closed', () async {
    await fixture.seed(db, fixture.actor);
    await db.customStatement('PRAGMA foreign_keys=OFF');
    await db.customStatement(
      "UPDATE plan_member_aliases SET user_id='foreign'",
    );
    await expectLater(repository.currentActivePlan(), throwsStateError);
  });
  test('inactive and deleted plans are not current capabilities', () async {
    await fixture.seed(db, fixture.actor);
    await db.customStatement('UPDATE plans SET is_active=0');
    expect(await repository.currentActivePlan(), isNull);
    await db.customStatement(
      "UPDATE plans SET is_active=1, deleted_at='2026-10-23T00:00:00Z'",
    );
    expect(await repository.currentActivePlan(), isNull);
  });
  test(
    'a pristine encrypted store has absent, not inconsistent facts',
    () async {
      expect(await repository.currentActivePlan(), isNull);
    },
  );
  test('active metadata missing caller membership fails closed', () async {
    await fixture.seed(db, fixture.actor);
    await db.customStatement('DELETE FROM plan_members');
    await expectLater(repository.currentActivePlan(), throwsStateError);
  });
  test(
    'creator identity inconsistent with role is corrupt, not a capability',
    () async {
      await fixture.seed(db, fixture.actor);
      await db.customStatement("UPDATE plan_members SET role='partner'");
      await expectLater(repository.currentActivePlan(), throwsStateError);
    },
  );
  test('encrypted current caller identity is readable without HTTP', () async {
    await fixture.seed(db, fixture.actor);
    final result = await HttpOverrides.runZoned(
      repository.currentActivePlan,
      createHttpClient: (_) => throw StateError('Network forbidden'),
    );
    expect(result!.plan.id, fixture.actor.planId);
    expect(result.member.userId, fixture.actor.userId);
    expect(result.alias.planMemberId, fixture.actor.planMemberId);
  });
}
