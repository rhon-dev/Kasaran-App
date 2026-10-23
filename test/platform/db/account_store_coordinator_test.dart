import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, TransactionExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';

class _Identity implements VerifiedLocalIdentity {
  String? user = 'user-a';
  Object marker = Object();
  void switchTo(String? next) {
    user = next;
    marker = Object();
  }

  @override
  VerifiedSessionSnapshot? capture() =>
      user == null ? null : VerifiedSessionSnapshot(user!, marker);
}

class _Keys implements DatabaseKeyStore {
  String? key;
  @override
  Future<String?> read() async => key;
  @override
  Future<void> write(String value) async => key = value;
}

// This intercepts Drift's TransactionExecutor.send(), not a callback await:
// the writer's final requireSameSession has already returned at this point.
class _CommitBarrier extends QueryInterceptor {
  final commitEntered = Completer<void>();
  final releaseCommit = Completer<void>();
  final closed = Completer<void>();
  bool armed = false;

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (armed) {
      armed = false;
      commitEntered.complete();
      await releaseCommit.future;
    }
    await inner.send();
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    await inner.close();
    if (!closed.isCompleted) closed.complete();
  }
}

class _CloseFailure extends QueryInterceptor {
  int calls = 0;
  QueryExecutor? retained;
  bool fail = true;

  @override
  Future<void> close(QueryExecutor inner) async {
    calls++;
    retained = inner;
    // Fail before forwarding: the real SQLite handle remains open.
    if (fail) throw StateError('Synthetic close failure');
    await inner.close();
  }
}

const _a = LedgerActor(
  planId: 'plan-a',
  userId: 'user-a',
  planMemberId: 'member-a',
  deviceId: 'device-a',
);
const _b = LedgerActor(
  planId: 'plan-b',
  userId: 'user-b',
  planMemberId: 'member-b',
  deviceId: 'device-b',
);
const _draft = LedgerDraft(
  categoryCode: 'buffer',
  entryType: 'standard',
  supplierName: 'Synthetic',
  pricingMode: 'flat',
  estimatedCents: 123,
);

Future<void> _seed(AppDatabase db, LedgerActor actor) async {
  await db.customStatement(
    '''
INSERT INTO plans
(id,creator_user_id,wedding_date,total_budget_cents,guest_cap,region_code,
 ruleset_version,driving_rsvp_status,created_at)
VALUES (?,?,?,?,?,?,?,?,?)''',
    [
      actor.planId,
      actor.userId,
      '2027-01-01',
      10000,
      2,
      'TEST',
      'fixture',
      'pending',
      '2026-10-01T00:00:00Z',
    ],
  );
  await db.customStatement(
    'INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id) VALUES (?,?,?)',
    [actor.planMemberId, actor.planId, actor.userId],
  );
  await db.customStatement(
    '''
INSERT INTO plan_members
(plan_id,user_id,plan_member_id,role,joined_at) VALUES (?,?,?,?,?)''',
    [
      actor.planId,
      actor.userId,
      actor.planMemberId,
      'creator',
      '2026-10-01T00:00:00Z',
    ],
  );
  await db.customStatement(
    '''
INSERT INTO change_log
(id,plan_id,entity_type,entity_id,field_name,schema_version,old_value,new_value,
 device_monotonic,device_id,plan_member_id,created_at)
VALUES (?,?,?,?,?,?,?,?,?,?,?,?)''',
    [
      'original-${actor.userId}',
      actor.planId,
      'ledger_entries',
      'original',
      r'$create',
      1,
      'null',
      '{}',
      1,
      actor.deviceId,
      actor.planMemberId,
      '2026-10-01T00:00:00Z',
    ],
  );
  await db.customStatement(
    '''
INSERT INTO outbox
(event_id,plan_id,device_id,queued_at) VALUES (?,?,?,?)''',
    [
      'original-${actor.userId}',
      actor.planId,
      actor.deviceId,
      '2026-10-01T00:00:00Z',
    ],
  );
}

Future<List<String>> _events(AppDatabase db) async =>
    (await db.customSelect('SELECT id FROM change_log ORDER BY id').get())
        .map((r) => r.read<String>('id'))
        .toList();

void main() {
  late Directory directory;
  late File aFile, bFile;
  late _Keys aKeys, bKeys;
  late _Identity identity;
  late _CommitBarrier barrier;
  late List<String> lifecycle;
  late AccountStoreCoordinator coordinator;
  late LedgerRepository repo;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasaran-lease-');
    aFile = File('${directory.path}/a.sqlite');
    bFile = File('${directory.path}/b.sqlite');
    aKeys = _Keys();
    bKeys = _Keys();
    for (final (file, keys, actor) in [
      (aFile, aKeys, _a),
      (bFile, bKeys, _b),
    ]) {
      final db = await EncryptedDatabaseOpener(file, keys).open();
      await _seed(db, actor);
      await db.close();
    }
    identity = _Identity();
    expect(aKeys.key, isNot(bKeys.key));
    barrier = _CommitBarrier();
    lifecycle = [];
    coordinator = AccountStoreCoordinator(identity, (session) async {
      final isA = session.userId == _a.userId;
      if (!isA) expect(barrier.closed.isCompleted, isTrue);
      lifecycle.add('open-${isA ? 'a' : 'b'}');
      final file = isA ? aFile : bFile;
      final key = (isA ? aKeys : bKeys).key!;
      // Same sqlite3mc cipher and independent keys as the account opener.
      return AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            if (raw.select('PRAGMA cipher').isEmpty) {
              throw StateError('Cipher missing');
            }
            raw.execute("PRAGMA key = '$key'");
          },
        ).interceptWith(isA ? barrier : _CommitBarrier()),
      );
    });
    repo = LedgerRepository(coordinator);
  });
  tearDown(() async {
    if (!barrier.releaseCommit.isCompleted) barrier.releaseCommit.complete();
    identity.switchTo(null);
    await coordinator.observeSession();
    await directory.delete(recursive: true);
  });

  for (final trigger in ['transition', 'observation', 'discarded open']) {
    test(
      'close failure from $trigger stays unavailable without retrying uncertain handle',
      () async {
        final fault = _CloseFailure();
        final localIdentity = _Identity();
        final first = AppDatabase(NativeDatabase.memory().interceptWith(fault));
        await first.customSelect('SELECT 1').get();
        var opens = 0;
        final owner = AccountStoreCoordinator(localIdentity, (_) async {
          opens++;
          if (trigger == 'discarded open') localIdentity.switchTo(_b.userId);
          return first;
        });
        addTearDown(() async {
          // The coordinator deliberately cannot prove closure after failure.
          // Only the fixture can repair its interceptor and clean up the handle.
          fault.fail = false;
          await first.close();
          owner.dispose();
        });
        var authCalls = 0;
        if (trigger == 'discarded open') {
          await expectLater(owner.observeSession(), throwsStateError);
        } else {
          await owner.observeSession();
          if (trigger == 'transition') {
            final firstTransition = owner.transition(() async {
              authCalls++;
            });
            final queuedTransition = owner.transition(() async {
              authCalls++;
            });
            await expectLater(firstTransition, throwsStateError);
            await expectLater(queuedTransition, throwsStateError);
          } else {
            localIdentity.switchTo(_b.userId);
            await expectLater(owner.observeSession(), throwsStateError);
          }
        }
        expect(owner.isReady, isFalse);
        expect(
          owner.hasFailure,
          isTrue,
          reason: 'must report unavailable, not endless loading',
        );
        expect(authCalls, 0);
        expect(fault.calls, 1);
        expect(await fault.retained!.runSelect('SELECT 1 AS still_open', []), [
          {'still_open': 1},
        ]);
        await expectLater(owner.withAccount((_) async {}), throwsStateError);
        await expectLater(owner.retryCurrent(), throwsStateError);
        await expectLater(
          owner.transition(() async {
            authCalls++;
          }),
          throwsStateError,
        );
        localIdentity.switchTo(_a.userId);
        await expectLater(owner.observeSession(), throwsStateError);
        await expectLater(owner.close(), throwsStateError);
        expect(opens, 1);
        expect(authCalls, 0);
        expect(
          fault.calls,
          1,
          reason: 'a later no-op close cannot prove native closure',
        );
        expect(owner.hasFailure, isTrue);
      },
    );
  }

  test(
    'failed open remains blocked until explicit same-session retry',
    () async {
      var attempts = 0;
      coordinator = AccountStoreCoordinator(identity, (_) async {
        attempts++;
        if (attempts == 1) throw StateError('open failed');
        return AppDatabase(NativeDatabase.memory());
      });
      repo = LedgerRepository(coordinator);
      await expectLater(repo.listLive(_a), throwsStateError);
      expect(coordinator.isReady, isFalse);
      await expectLater(coordinator.observeSession(), completes);
      await expectLater(repo.listLive(_a), throwsStateError);
      expect(attempts, 1);
      await coordinator.retryCurrent();
      expect(attempts, 2);
      expect(coordinator.isReady, isTrue);
      await expectLater(coordinator.retryCurrent(), throwsStateError);
    },
  );

  test('no-op Auth transition does not retry a failed account open', () async {
    var attempts = 0;
    coordinator = AccountStoreCoordinator(identity, (_) async {
      attempts++;
      if (attempts == 1) throw StateError('open failed');
      return AppDatabase(NativeDatabase.memory());
    });
    await expectLater(coordinator.observeSession(), throwsStateError);
    await coordinator.transition(() async {});
    expect(coordinator.isReady, isFalse);
    expect(attempts, 1);
    await expectLater(coordinator.withAccount((_) async {}), throwsStateError);
    await coordinator.retryCurrent();
    expect(attempts, 2);
    expect(coordinator.isReady, isTrue);
  });

  for (final trigger in ['readiness', 'stale lease']) {
    test('failed B open from $trigger does not leak an async error', () async {
      var bAttempts = 0;
      final bAttempted = Completer<void>();
      coordinator = AccountStoreCoordinator(identity, (session) async {
        if (session.userId == _b.userId) {
          bAttempts++;
          if (bAttempts == 1) {
            bAttempted.complete();
            throw StateError('B open failed');
          }
        }
        return AppDatabase(NativeDatabase.memory());
      });
      final old = await coordinator.withAccount((lease) async => lease);
      identity.switchTo(_b.userId);
      final unhandled = <Object>[];
      await runZonedGuarded<Future<void>>(() async {
        if (trigger == 'readiness') {
          expect(coordinator.isReady, isFalse);
        } else {
          expect(() => old.run((db) async {}), throwsStateError);
        }
        await bAttempted.future.timeout(const Duration(seconds: 5));
        // Let the queued open failure propagate to detached Future listeners.
        await Future<void>.delayed(Duration.zero);
      }, (error, stack) => unhandled.add(error));
      expect(unhandled, isEmpty);
      expect(coordinator.isReady, isFalse);
      expect(bAttempts, 1);
      await expectLater(
        coordinator.withAccount((_) async {}),
        throwsStateError,
      );
      await coordinator.retryCurrent();
      expect(bAttempts, 2);
      expect(coordinator.isReady, isTrue);
    });
  }

  test('retry closes candidate on identity change without opening B', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final retryBarrier = _CommitBarrier();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    var aAttempts = 0;
    var bAttempts = 0;
    coordinator = AccountStoreCoordinator(identity, (session) async {
      if (session.userId == _b.userId) {
        bAttempts++;
        return AppDatabase(NativeDatabase.memory());
      }
      aAttempts++;
      if (aAttempts == 1) throw StateError('open failed');
      entered.complete();
      await release.future;
      return AppDatabase(NativeDatabase.memory().interceptWith(retryBarrier));
    });
    await expectLater(coordinator.observeSession(), throwsStateError);
    final retry = coordinator.retryCurrent();
    await entered.future.timeout(const Duration(seconds: 5));
    identity.switchTo(_b.userId);
    expect(coordinator.isReady, isFalse);
    release.complete();
    await expectLater(retry, throwsStateError);
    expect(retryBarrier.closed.isCompleted, isTrue);
    expect(bAttempts, 0);
    expect(coordinator.isReady, isFalse);
    await expectLater(coordinator.retryCurrent(), throwsStateError);
    expect(bAttempts, 0);
    await coordinator.observeSession();
    expect(bAttempts, 1);
    expect(coordinator.isReady, isTrue);
  });

  test('queued Auth transition cancels an in-flight retry', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    var attempts = 0;
    coordinator = AccountStoreCoordinator(identity, (_) async {
      attempts++;
      if (attempts == 1) throw StateError('open failed');
      entered.complete();
      await release.future;
      return AppDatabase(NativeDatabase.memory());
    });
    await expectLater(coordinator.observeSession(), throwsStateError);
    final retry = coordinator.retryCurrent();
    await entered.future;
    final transition = coordinator.transition(() async {
      identity.switchTo(null);
    });
    release.complete();
    await expectLater(retry, throwsStateError);
    await transition;
    expect(coordinator.isReady, isFalse);
  });

  test(
    'external replacement blocks B through exact post-callback COMMIT, preserving A queue',
    () async {
      late AccountLease old;
      await coordinator.withAccount((lease) async {
        old = lease;
      });
      barrier.armed = true;
      final create = repo.create(_a, _draft);
      await barrier.commitEntered.future.timeout(const Duration(seconds: 5));
      expect(lifecycle, ['open-a']);
      identity.switchTo(_b.userId);
      final switching = coordinator.observeSession();
      expect(coordinator.isReady, isFalse);
      expect(lifecycle, ['open-a']);
      expect(
        () => old.run((db) => db.select(db.ledgerEntries).get()),
        throwsStateError,
      );
      await expectLater(repo.listLive(_b), throwsStateError);
      barrier.releaseCommit.complete();
      await expectLater(create, throwsStateError);
      await switching;
      expect(barrier.closed.isCompleted, isTrue);
      expect(lifecycle, ['open-a', 'open-b']);
      expect(await repo.listLive(_b), isEmpty);
      final bEvents = await coordinator.withAccount(
        (lease) => lease.run(_events),
      );
      expect(bEvents, ['original-user-b']);
      final bQueue = await coordinator.withAccount(
        (lease) => lease.run(
          (db) => db.customSelect('SELECT event_id FROM outbox').get(),
        ),
      );
      expect(bQueue.single.read<String>('event_id'), 'original-user-b');
      identity.switchTo(null);
      await coordinator.observeSession();
      final reopened = await EncryptedDatabaseOpener(aFile, aKeys).open();
      expect(await _events(reopened), contains('original-user-a'));
      expect((await _events(reopened)).length, 2);
      expect(
        (await reopened.customSelect('SELECT * FROM outbox').get()).length,
        2,
      );
      await reopened.close();
    },
  );

  test(
    'app transition waits for exact COMMIT and close before changing Auth',
    () async {
      barrier.armed = true;
      final create = repo.create(_a, _draft);
      await barrier.commitEntered.future.timeout(const Duration(seconds: 5));
      var authCalled = false;
      final transition = coordinator.transition(() async {
        authCalled = true;
        expect(barrier.closed.isCompleted, isTrue);
        identity.switchTo(_b.userId);
      });
      expect(coordinator.isReady, isFalse);
      expect(authCalled, isFalse);
      expect(lifecycle, ['open-a']);
      barrier.releaseCommit.complete();
      await expectLater(create, throwsStateError);
      await transition;
      expect(authCalled, isTrue);
      expect(lifecycle, ['open-a', 'open-b']);
      expect(await repo.listLive(_b), isEmpty);
      expect(await coordinator.withAccount((lease) => lease.run(_events)), [
        'original-user-b',
      ]);
      identity.switchTo(null);
      await coordinator.observeSession();
      final aReopen = await EncryptedDatabaseOpener(aFile, aKeys).open();
      expect(await _events(aReopen), contains('original-user-a'));
      expect(
        (await aReopen.customSelect('SELECT * FROM outbox').get()).length,
        2,
      );
      await aReopen.close();
    },
  );

  test('failed app Auth mutation leaves protected scope blocked', () async {
    await coordinator.withAccount((lease) async {});
    await expectLater(
      coordinator.transition(() async => throw StateError('Auth rejected')),
      throwsStateError,
    );
    expect(coordinator.isReady, isFalse);
    await expectLater(repo.listLive(_a), throwsStateError);
    expect(lifecycle, ['open-a']);
  });

  for (final failure in ['synchronous', 'asynchronous']) {
    test(
      'failed $failure Auth cannot be recovered by no-op transition',
      () async {
        final old = await coordinator.withAccount((lease) async => lease);
        final originalMarker = identity.marker;
        await expectLater(
          coordinator.transition(() {
            if (failure == 'synchronous') throw StateError('Auth rejected');
            return Future<void>.delayed(Duration.zero, () {
              throw StateError('Auth rejected');
            });
          }),
          throwsStateError,
        );
        expect(identity.marker, same(originalMarker));
        expect(coordinator.isReady, isFalse);
        expect(() => old.run(_events), throwsStateError);

        await coordinator.transition(() async {});
        expect(identity.marker, same(originalMarker));
        expect(coordinator.isReady, isFalse);
        expect(lifecycle, ['open-a']);
        await expectLater(repo.listLive(_a), throwsStateError);
        expect(() => old.run(_events), throwsStateError);
        await expectLater(coordinator.retryCurrent(), throwsStateError);

        await coordinator.transition(() async => identity.switchTo(_b.userId));
        expect(coordinator.isReady, isTrue);
        expect(lifecycle, ['open-a', 'open-b']);
        expect(await coordinator.withAccount((lease) => lease.run(_events)), [
          'original-user-b',
        ]);
        await expectLater(repo.listLive(_a), throwsStateError);
      },
    );
  }

  test(
    'queued Auth transitions do not publish an intermediate account',
    () async {
      await coordinator.withAccount((lease) async {});
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final first = coordinator.transition(() async {
        identity.switchTo(_b.userId);
      });
      final second = coordinator.transition(() async {
        entered.complete();
        await release.future;
        identity.switchTo(_a.userId);
      });
      await entered.future;
      expect(coordinator.isReady, isFalse);
      expect(lifecycle, ['open-a']);
      await expectLater(repo.listLive(_b), throwsStateError);
      release.complete();
      await Future.wait([first, second]);
      expect(coordinator.isReady, isTrue);
      expect(await coordinator.withAccount((lease) => lease.run(_events)), [
        'original-user-a',
      ]);
    },
  );

  test(
    'A to B to A increments generations and drops a paused A read',
    () async {
      final first = await coordinator.withAccount((lease) async => lease);
      final entered = Completer<void>();
      final release = Completer<void>();
      final read = first.run((db) async {
        final rows = await db.customSelect('SELECT id FROM change_log').get();
        entered.complete();
        await release.future;
        return rows;
      });
      await entered.future;
      identity.switchTo(_b.userId);
      final toB = coordinator.observeSession();
      expect(coordinator.isReady, isFalse);
      expect(() => first.run(_events), throwsStateError);
      release.complete();
      await expectLater(read, throwsStateError);
      await toB;
      final second = await coordinator.withAccount((lease) async => lease);
      expect(second.generation, greaterThan(first.generation));
      expect(second.userId, _b.userId);
      identity.switchTo(_a.userId);
      await coordinator.observeSession();
      final third = await coordinator.withAccount((lease) async => lease);
      expect(third.generation, greaterThan(second.generation));
      expect(() => second.run(_events), throwsStateError);
      expect(await repo.listLive(_a), isEmpty);
      expect(await coordinator.withAccount((lease) => lease.run(_events)), [
        'original-user-a',
      ]);
    },
  );
}
