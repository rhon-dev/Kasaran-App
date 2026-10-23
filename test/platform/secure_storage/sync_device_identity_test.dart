import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/account_store_registry.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/sync_device_identity.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';

class _Storage implements SecureKeyValueStore {
  _Storage({Map<String, String>? backing}) : values = backing ?? {};
  final Map<String, String> values;
  final writes = <String>[];
  bool rejectWrite = false;
  bool dropWrite = false;
  String? replaceWrite;
  bool failRead = false;
  bool failRegistryRead = false;
  Future<void> Function()? beforeRegistryRead;
  Future<void> Function()? beforeRead;
  Future<void> Function()? afterWrite;
  void Function()? afterRead;
  @override
  Future<String?> read(String key) async {
    if (key == AccountStoreRegistry.metadataKey) {
      await beforeRegistryRead?.call();
      if (failRegistryRead) throw StateError('sensitive registry detail');
    }
    if (key == SyncDeviceIdentity.metadataKey) await beforeRead?.call();
    if (failRead && key == SyncDeviceIdentity.metadataKey) {
      throw StateError('sensitive storage detail');
    }
    if (key == SyncDeviceIdentity.metadataKey) afterRead?.call();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes.add(key);
    if (key == SyncDeviceIdentity.metadataKey) {
      if (rejectWrite) throw StateError('sensitive storage detail');
      if (dropWrite) return;
      values[key] = replaceWrite ?? value;
      await afterWrite?.call();
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async => throw StateError('Never delete');
}

class _Security implements LocalDeviceSecurity {
  @override
  Future<void> protectDirectory(String path) async {}
  @override
  Future<void> protectFile(String path) async {}
  @override
  Future<bool> hasDeviceLock() async => true;
  @override
  Future<bool> hasShownLockWarning() async => false;
  @override
  Future<void> markLockWarningShown() async {}
}

class _Identity implements VerifiedLocalIdentity {
  String? user = 'account-a';
  Object marker = Object();
  void Function()? onCapture;
  void replace(String? next) {
    user = next;
    marker = Object();
  }

  @override
  VerifiedSessionSnapshot? capture() {
    final snapshot = user == null
        ? null
        : VerifiedSessionSnapshot(user!, marker);
    onCapture?.call();
    return snapshot;
  }
}

Future<void> _seedPlan(AppDatabase db) async {
  await db.customStatement("""
INSERT INTO plans
(id,creator_user_id,wedding_date,total_budget_cents,guest_cap,region_code,
 ruleset_version,driving_rsvp_status,created_at)
VALUES ('plan','account-a','2027-01-01',10000,2,'TEST','fixture','pending','2026-10-01')
""");
  await db.customStatement("""
INSERT INTO plan_member_aliases (plan_member_id,plan_id,user_id)
VALUES ('member','plan','account-a')
""");
}

Future<void> _seedEvent(
  AppDatabase db, {
  String id = 'event',
  String device = '550e8400-e29b-41d4-a716-446655440000',
}) async {
  await db.customStatement(
    """
INSERT INTO change_log
(id,plan_id,entity_type,entity_id,field_name,schema_version,device_monotonic,
 device_id,plan_member_id,created_at,server_ts)
VALUES (?,'plan','ledger_entries','entry',?,1,1,?,'member','2026-10-01',1)
""",
    [id, r'$create', device],
  );
}

Future<Map<String, List<Map<String, Object?>>>> _snapshot(
  AppDatabase db,
) async => {
  for (final table in [
    'plans',
    'plan_member_aliases',
    'plan_members',
    'ledger_entries',
    'change_log',
    'sync_state',
    'sync_inbox',
    'outbox',
  ])
    table: (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
        .map((r) => r.data)
        .toList(),
};

// Executes real encrypted SQLite first, then pauses only the awaited delivery.
class _HistoryBarrier extends QueryInterceptor {
  bool armed = false;
  bool fail = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (statement.contains('FROM sync_state UNION ALL')) {
      if (fail) throw StateError('sensitive database detail');
      if (armed) {
        armed = false;
        entered.complete();
        await release.future;
      }
    }
    return rows;
  }
}

void main() {
  late Directory directory;
  late _Storage storage;
  late _Identity identity;
  late AccountStoreCoordinator coordinator;
  late AppDatabase db;
  late _HistoryBarrier historyBarrier;
  late AccountStoreRegistry registry;
  late File accountFile;
  setUp(() async {
    final fixture = await Directory(
      Platform.environment['TMPDIR']!,
    ).createTemp('kasaran-device-identity-');
    directory = Directory(await fixture.resolveSymbolicLinks());
    storage = _Storage();
    identity = _Identity();
    historyBarrier = _HistoryBarrier();
    registry = AccountStoreRegistry(directory, storage, _Security());
    coordinator = AccountStoreCoordinator(identity, (session) async {
      final location = await registry.resolveVerified(session);
      final file = accountFile = location.file;
      final keys = location.keys;
      final created = await LocalStoreBootstrap(
        directory,
        PlatformDatabaseKeyStore(),
        _Security(),
      ).openAccount(location);
      await created.close();
      final key = await keys.read();
      db = AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            if (raw.select('PRAGMA cipher').isEmpty) {
              throw StateError('Cipher missing');
            }
            raw.execute("PRAGMA key = '$key'");
          },
        ).interceptWith(historyBarrier),
      );
      await db.customSelect('SELECT 1').get();
      return db;
    });
    await coordinator.observeSession();
  });
  tearDown(() async {
    if (!historyBarrier.release.isCompleted) historyBarrier.release.complete();
    await coordinator.close();
    coordinator.dispose();
    await directory.delete(recursive: true);
  });

  test('F1 lost installation key on pristine B cannot mask retained A queue', () async {
    const original = '550e8400-e29b-41d4-a716-446655440000';
    storage.values[SyncDeviceIdentity.metadataKey] = original;
    await _seedPlan(db);
    await _seedEvent(db, id: 'original');
    await db.customStatement(
      "INSERT INTO sync_state (device_id,plan_id,device_monotonic) VALUES (?,'plan',7)",
      [original],
    );
    await db.customStatement(
      "INSERT INTO outbox (event_id,plan_id,device_id,queued_at) VALUES ('original','plan',?,'2026-10-01')",
      [original],
    );
    final aBefore = await _snapshot(db);
    storage.values.remove(SyncDeviceIdentity.metadataKey);
    await coordinator.transition(() async => identity.replace('account-b'));
    final bBefore = await _snapshot(db);
    final metadata = Map<String, String>.of(storage.values);
    final writes = storage.writes.length;
    await expectLater(
      SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
      throwsA(isA<SyncDeviceIdentityException>()),
    );
    expect(storage.values, metadata);
    expect(storage.writes.length, writes);
    expect(await _snapshot(db), bBefore);
    await coordinator.transition(() async => identity.replace('account-a'));
    await expectLater(
      SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
      throwsA(isA<SyncDeviceIdentityException>()),
    );
    expect(storage.values.containsKey(SyncDeviceIdentity.metadataKey), isFalse);
    expect(await _snapshot(db), aBefore);
    // Explicit trusted metadata restoration, never inference from financial rows.
    storage.values[SyncDeviceIdentity.metadataKey] = original;
    final selected = await SyncDeviceIdentity(
      storage,
      registry: registry,
    ).resolve(coordinator);
    expect(selected, original);
    final pending = await db
        .customSelect(
          'SELECT q.event_id FROM outbox q LEFT JOIN change_log c ON c.id=q.event_id '
          'WHERE q.plan_id=? AND q.device_id=? '
          'AND (c.id IS NULL OR (c.plan_member_id=? AND c.device_id=?))',
          variables: [
            const Variable('plan'),
            Variable(selected),
            const Variable('member'),
            Variable(selected),
          ],
        )
        .get();
    expect(pending.single.read<String>('event_id'), 'original');
    expect(await _snapshot(db), aBefore);
  });

  test(
    'absent key without registry fails closed but valid key needs no guard',
    () async {
      final metadata = Map<String, String>.of(storage.values);
      final before = await _snapshot(db);
      final writes = storage.writes.length;
      await expectLater(
        SyncDeviceIdentity(storage).resolve(coordinator),
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'installation_unproven',
          ),
        ),
      );
      expect(storage.values, metadata);
      expect(storage.writes.length, writes);
      expect(await _snapshot(db), before);
      const original = '550e8400-e29b-41d4-a716-446655440000';
      storage.values[SyncDeviceIdentity.metadataKey] = original;
      storage.values[AccountStoreRegistry.metadataKey] = '{corrupt';
      expect(await SyncDeviceIdentity(storage).resolve(coordinator), original);
    },
  );

  for (final scenario in [
    'missing',
    'corrupt',
    'unknown version',
    'empty',
    'foreign sole account',
    'other mapped account',
    'duplicate store',
    'invalid store',
    'read failed',
  ]) {
    test(
      'unprovable registry $scenario refuses without identity or database writes',
      () async {
        final id = accountFile.parent.path.split(Platform.pathSeparator).last;
        switch (scenario) {
          case 'missing':
            storage.values.remove(AccountStoreRegistry.metadataKey);
          case 'corrupt':
            storage.values[AccountStoreRegistry.metadataKey] = '{broken';
          case 'unknown version':
            storage.values[AccountStoreRegistry.metadataKey] = jsonEncode({
              'version': 42,
              'accounts': {'account-a': id},
            });
          case 'empty':
            storage.values[AccountStoreRegistry.metadataKey] = jsonEncode({
              'version': 1,
              'accounts': <String, String>{},
            });
          case 'foreign sole account':
            storage.values[AccountStoreRegistry.metadataKey] = jsonEncode({
              'version': 1,
              'accounts': {'account-b': id},
            });
          case 'other mapped account':
            storage.values[AccountStoreRegistry.metadataKey] = jsonEncode({
              'version': 1,
              'accounts': {'account-a': id, 'account-b': 'b' * 32},
            });
          case 'duplicate store':
            storage.values[AccountStoreRegistry.metadataKey] = jsonEncode({
              'version': 1,
              'accounts': {'account-a': id, 'account-b': id},
            });
          case 'invalid store':
            storage.values[AccountStoreRegistry.metadataKey] = jsonEncode({
              'version': 1,
              'accounts': {'account-a': '../outside'},
            });
          case 'read failed':
            storage.failRegistryRead = true;
        }
        final metadata = Map<String, String>.of(storage.values);
        final writes = storage.writes.length;
        final before = await _snapshot(db);
        await expectLater(
          SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
          throwsA(
            isA<SyncDeviceIdentityException>().having(
              (e) => e.code,
              'code',
              'installation_unproven',
            ),
          ),
        );
        expect(storage.values, metadata);
        expect(storage.writes.length, writes);
        expect(await _snapshot(db), before);
      },
    );
  }

  for (final scenario in [
    'unmapped store',
    'staged store',
    'legacy file',
    'legacy sidecar',
    'unknown root',
    'unknown account file',
    'linked sidecar',
    'sidecar directory',
    'linked account',
    'linked parent',
    'missing account',
    'missing parent',
    'missing database',
    'missing root',
  ]) {
    test(
      'unprovable filesystem $scenario refuses without changing retained bytes',
      () async {
        final before = await _snapshot(db);
        final metadata = Map<String, String>.of(storage.values);
        final writes = storage.writes.length;
        final bytes = await accountFile.readAsBytes();
        Future<void> Function()? restore;
        final parent = accountFile.parent.parent;
        switch (scenario) {
          case 'unmapped store':
            await Directory('${parent.path}/${'b' * 32}').create();
          case 'staged store':
            await Directory('${parent.path}/.stage-retained').create();
          case 'legacy file':
            await File(
              '${directory.path}/kasaran.sqlite',
            ).writeAsBytes([1, 2, 3]);
          case 'legacy sidecar':
            await File(
              '${directory.path}/kasaran.sqlite-wal',
            ).writeAsBytes([1, 2, 3]);
          case 'unknown root':
            await Directory('${directory.path}/unknown').create();
          case 'unknown account file':
            await File(
              '${accountFile.parent.path}/retained.stage',
            ).writeAsBytes([1, 2, 3]);
          case 'linked sidecar':
            await Link(
              '${accountFile.path}-journal',
            ).create('${directory.path}/missing-target');
          case 'sidecar directory':
            await Directory('${accountFile.path}-journal').create();
          case 'linked account':
            final moved = await accountFile.parent.rename(
              '${directory.path}/saved',
            );
            await Link(accountFile.parent.path).create(moved.path);
            restore = () async {
              await Link(accountFile.parent.path).delete();
              await moved.rename(accountFile.parent.path);
            };
          case 'linked parent':
            final moved = await parent.rename('${directory.path}/saved');
            await Link(parent.path).create(moved.path);
            restore = () async {
              await Link(parent.path).delete();
              await moved.rename(parent.path);
            };
          case 'missing account':
            final moved = await accountFile.parent.rename(
              '${directory.path}/saved',
            );
            restore = () async {
              await moved.rename(accountFile.parent.path);
            };
          case 'missing parent':
            final moved = await parent.rename('${directory.path}/saved');
            restore = () async {
              await moved.rename(parent.path);
            };
          case 'missing database':
            final moved = await accountFile.rename('${accountFile.path}.saved');
            restore = () async {
              await moved.rename(accountFile.path);
            };
          case 'missing root':
            final moved = await directory.rename('${directory.path}-saved');
            restore = () async {
              await moved.rename(directory.path);
            };
        }
        try {
          await expectLater(
            SyncDeviceIdentity(
              storage,
              registry: registry,
            ).resolve(coordinator),
            throwsA(
              isA<SyncDeviceIdentityException>().having(
                (e) => e.code,
                'code',
                'installation_unproven',
              ),
            ),
          );
          if (scenario == 'missing root') {
            expect(directory.existsSync(), isFalse);
          }
        } finally {
          await restore?.call();
        }
        expect(storage.values, metadata);
        expect(storage.writes.length, writes);
        expect(await _snapshot(db), before);
        expect(await accountFile.readAsBytes(), bytes);
      },
    );
  }

  test(
    'independent pristine registry cannot authorize a different leased database',
    () async {
      // Drain A before constructing another Drift instance; never suppress warnings.
      await coordinator.transition(() async => identity.replace(null));
      final otherRoot = await Directory('${directory.path}/other').create();
      final otherMetadata = _Storage();
      final otherRegistry = AccountStoreRegistry(
        otherRoot,
        otherMetadata,
        _Security(),
      );
      final location = await otherRegistry.resolveVerified(
        const VerifiedSessionSnapshot('account-a', Object()),
      );
      final otherDb = await LocalStoreBootstrap(
        otherRoot,
        PlatformDatabaseKeyStore(),
        _Security(),
      ).openAccount(location);
      await otherDb.close();
      await coordinator.transition(() async => identity.replace('account-a'));
      final metadata = Map<String, String>.of(storage.values);
      final before = await _snapshot(db);
      final writes = storage.writes.length;
      await expectLater(
        SyncDeviceIdentity(
          storage,
          registry: otherRegistry,
        ).resolve(coordinator),
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'installation_unproven',
          ),
        ),
      );
      expect(storage.values, metadata);
      expect(storage.writes.length, writes);
      expect(await _snapshot(db), before);
    },
  );

  test('registry lock spans actual history creation and readback', () async {
    historyBarrier.armed = true;
    final wrote = Completer<void>();
    final releaseWrite = Completer<void>();
    final readback = Completer<void>();
    final releaseReadback = Completer<void>();
    addTearDown(() {
      if (!releaseWrite.isCompleted) releaseWrite.complete();
      if (!releaseReadback.isCompleted) releaseReadback.complete();
    });
    storage.afterWrite = () async {
      wrote.complete();
      await releaseWrite.future;
    };
    var reads = 0;
    storage.beforeRead = () async {
      if (++reads == 2) {
        readback.complete();
        await releaseReadback.future;
      }
    };
    final attempt = SyncDeviceIdentity(
      storage,
      registry: registry,
    ).resolve(coordinator);
    await historyBarrier.entered.future;
    var resolved = false;
    final competing = registry
        .resolveVerified(const VerifiedSessionSnapshot('account-b', Object()))
        .then((value) {
          resolved = true;
          return value;
        });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(resolved, isFalse);
    historyBarrier.release.complete();
    await wrote.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(resolved, isFalse);
    releaseWrite.complete();
    await readback.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(resolved, isFalse);
    releaseReadback.complete();
    final id = await attempt;
    await competing;
    expect(storage.values[SyncDeviceIdentity.metadataKey], id);
    expect(resolved, isTrue);
  });

  test(
    'session replacement during guarded registry read prevents creation',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      storage.beforeRegistryRead = () async {
        storage.beforeRegistryRead = null;
        entered.complete();
        await release.future;
      };
      final attempt = SyncDeviceIdentity(
        storage,
        registry: registry,
      ).resolve(coordinator);
      final rejected = expectLater(
        attempt,
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'session_changed',
          ),
        ),
      );
      await entered.future;
      identity.replace('account-a');
      var drained = false;
      final switching = coordinator.observeSession().then((_) {
        drained = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      release.complete();
      await rejected;
      await switching;
      expect(
        storage.values.containsKey(SyncDeviceIdentity.metadataKey),
        isFalse,
      );
    },
  );

  test(
    'pristine resolution persists canonical UUID and survives reopen',
    () async {
      final id = await SyncDeviceIdentity(
        storage,
        registry: registry,
      ).resolve(coordinator);
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(storage.values[SyncDeviceIdentity.metadataKey], id);
      await coordinator.close();
      coordinator.dispose();
      coordinator = AccountStoreCoordinator(
        identity,
        (_) async => db = await EncryptedDatabaseOpener(
          accountFile,
          (await registry.resolveVerified(identity.capture()!)).keys,
        ).open(),
      );
      await coordinator.observeSession();
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        id,
      );
      expect(
        storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
        hasLength(1),
      );
      expect(await db.customSelect('SELECT * FROM sync_state').get(), isEmpty);
    },
  );

  test('malformed stored metadata fails closed unchanged', () async {
    for (final value in [
      '',
      ' ',
      'not-a-uuid',
      '550E8400-E29B-41D4-A716-446655440000',
      '550e8400-e29b-41d4-a716-446655440000 ',
      '00000000-0000-0000-0000-000000000000',
      '550e8400-e29b-41d4-7716-446655440000',
    ]) {
      storage.values[SyncDeviceIdentity.metadataKey] = value;
      final before = Map<String, String>.of(storage.values);
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString() ==
                'SyncDeviceIdentityException: invalid_stored_identity',
          ),
        ),
      );
      expect(storage.values, before);
    }
    expect(
      storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
      isEmpty,
    );
  });

  test(
    'concurrent independent wrappers serialize shared installation creation',
    () async {
      final ids = await Future.wait(
        List.generate(
          12,
          (_) => SyncDeviceIdentity(
            storage,
            registry: registry,
          ).resolve(coordinator),
        ),
      );
      expect(ids.toSet(), hasLength(1));
      expect(storage.values[SyncDeviceIdentity.metadataKey], ids.first);
      expect(
        storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
        hasLength(1),
      );
    },
  );

  test(
    'rejected secure write returns safe failure and permits fresh retry',
    () async {
      storage.rejectWrite = true;
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString() == 'SyncDeviceIdentityException: storage_failed',
          ),
        ),
      );
      expect(
        storage.values.containsKey(SyncDeviceIdentity.metadataKey),
        isFalse,
      );
      storage.rejectWrite = false;
      final id = await SyncDeviceIdentity(
        storage,
        registry: registry,
      ).resolve(coordinator);
      expect(storage.values[SyncDeviceIdentity.metadataKey], id);
    },
  );

  test('readback mismatch never publishes unpersisted identity', () async {
    for (final replacement in [
      null,
      '550e8400-e29b-41d4-a716-446655440000',
      'invalid',
    ]) {
      storage.values.remove(SyncDeviceIdentity.metadataKey);
      storage.dropWrite = replacement == null;
      storage.replaceWrite = replacement;
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString() ==
                'SyncDeviceIdentityException: persistence_unconfirmed',
          ),
        ),
      );
      expect(storage.values[SyncDeviceIdentity.metadataKey], replacement);
    }
  });

  test(
    'missing key with retained sync state refuses creation unchanged',
    () async {
      await _seedPlan(db);
      await db.customStatement("""
INSERT INTO sync_state (device_id,plan_id,device_monotonic)
VALUES ('550e8400-e29b-41d4-a716-446655440000','plan',7)
""");
      final before = (await db.customSelect('SELECT * FROM sync_state').get())
          .map((r) => r.data)
          .toList();
      final metadata = Map<String, String>.of(storage.values);
      final allTables = await _snapshot(db);
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString() ==
                'SyncDeviceIdentityException: retained_history_without_identity',
          ),
        ),
      );
      expect(
        (await db.customSelect('SELECT * FROM sync_state').get())
            .map((r) => r.data)
            .toList(),
        before,
      );
      expect(storage.values, metadata);
      expect(await _snapshot(db), allTables);
    },
  );

  test(
    'missing key with retained foreign change history refuses unchanged',
    () async {
      await _seedPlan(db);
      await _seedEvent(db);
      final before = (await db.customSelect('SELECT * FROM change_log').get())
          .map((r) => r.data)
          .toList();
      final metadata = Map<String, String>.of(storage.values);
      final allTables = await _snapshot(db);
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString() ==
                'SyncDeviceIdentityException: retained_history_without_identity',
          ),
        ),
      );
      expect(
        (await db.customSelect('SELECT * FROM change_log').get())
            .map((r) => r.data)
            .toList(),
        before,
      );
      expect(storage.values, metadata);
      expect(await _snapshot(db), allTables);
    },
  );

  test('missing key with retained orphan queue fails closed unchanged', () async {
    await _seedPlan(db);
    // Defensive corruption fixture: valid queues are also caught by change_log.
    await db.customStatement('PRAGMA foreign_keys=OFF');
    await db.customStatement("""
INSERT INTO outbox (event_id,plan_id,device_id,queued_at)
VALUES ('retained-orphan','plan','550e8400-e29b-41d4-a716-446655440000','2026-10-01')
""");
    await db.customStatement('PRAGMA foreign_keys=ON');
    final before = (await db.customSelect('SELECT * FROM outbox').get())
        .map((r) => r.data)
        .toList();
    final metadata = Map<String, String>.of(storage.values);
    final allTables = await _snapshot(db);
    await expectLater(
      SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
      throwsA(
        predicate<Object>(
          (e) =>
              e.toString() ==
              'SyncDeviceIdentityException: retained_history_without_identity',
        ),
      ),
    );
    expect(
      (await db.customSelect('SELECT * FROM outbox').get())
          .map((r) => r.data)
          .toList(),
      before,
    );
    expect(storage.values, metadata);
    expect(await _snapshot(db), allTables);
  });

  test(
    'session replacement during secure read prevents stale creation',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      storage.beforeRead = () async {
        storage.beforeRead = null;
        entered.complete();
        await release.future;
      };
      final attempt = SyncDeviceIdentity(
        storage,
        registry: registry,
      ).resolve(coordinator);
      final rejected = expectLater(
        attempt,
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString() == 'SyncDeviceIdentityException: session_changed',
          ),
        ),
      );
      await entered.future;
      identity.replace('account-a'); // Same account, different session marker.
      final switching = coordinator.observeSession();
      expect(coordinator.isReady, isFalse);
      var drained = false;
      unawaited(
        switching.then((_) {
          drained = true;
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      release.complete();
      await rejected;
      await switching;
      expect(drained, isTrue);
      expect(
        storage.values.containsKey(SyncDeviceIdentity.metadataKey),
        isFalse,
      );
      storage.beforeRead = null;
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        isNotEmpty,
      );
    },
  );

  test(
    'unready coordinator rejects without opening or touching metadata',
    () async {
      await coordinator.close();
      coordinator.dispose();
      var opens = 0;
      coordinator = AccountStoreCoordinator(identity, (_) async {
        opens++;
        throw StateError('Must not open');
      });
      final before = Map<String, String>.of(storage.values);
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString() ==
                'SyncDeviceIdentityException: account_unavailable',
          ),
        ),
      );
      expect(opens, 0);
      expect(storage.values, before);
    },
  );

  test(
    'missing key with staged inbox history refuses creation unchanged',
    () async {
      await _seedPlan(db);
      await db.customStatement("""
INSERT INTO sync_inbox (event_id,plan_id,server_ts,raw_event)
VALUES ('incoming','plan',1,'{}')
""");
      final before = (await db.customSelect('SELECT * FROM sync_inbox').get())
          .map((r) => r.data)
          .toList();
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          predicate<Object>(
            (e) =>
                e.toString() ==
                'SyncDeviceIdentityException: retained_history_without_identity',
          ),
        ),
      );
      expect(
        storage.values.containsKey(SyncDeviceIdentity.metadataKey),
        isFalse,
      );
      expect(
        (await db.customSelect('SELECT * FROM sync_inbox').get())
            .map((r) => r.data)
            .toList(),
        before,
      );
    },
  );

  test(
    'installation identity survives independent wrappers and account switches',
    () async {
      const original = '550e8400-e29b-41d4-a716-446655440000';
      storage.values[SyncDeviceIdentity.metadataKey] = original;
      final before = Map<String, String>.of(storage.values);
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        original,
      );
      await coordinator.transition(() async {
        identity.replace('account-b');
      });
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        original,
      );
      await coordinator.transition(() async {
        identity.replace('account-a');
      });
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        original,
      );
      for (final entry in before.entries) {
        // Account opening legitimately extends the secure registry mapping.
        if (entry.key != AccountStoreRegistry.metadataKey) {
          expect(storage.values[entry.key], entry.value);
        }
      }
      expect(
        storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
        isEmpty,
      );
      expect(coordinator.isReady, isTrue);
    },
  );

  test(
    'valid retained identity keeps original queue selected despite foreign incoming history',
    () async {
      const original = '550e8400-e29b-41d4-a716-446655440000';
      const foreign = '660e8400-e29b-41d4-a716-446655440000';
      storage.values[SyncDeviceIdentity.metadataKey] = original;
      await _seedPlan(db);
      await _seedEvent(db, id: 'original');
      await _seedEvent(db, id: 'foreign', device: foreign);
      await db.customStatement(
        """
INSERT INTO outbox (event_id,plan_id,device_id,queued_at)
VALUES ('original','plan',?,'2026-10-01')
""",
        [original],
      );
      await db.customStatement(
        """
INSERT INTO sync_state (device_id,plan_id,device_monotonic)
VALUES (?,'plan',7)
""",
        [original],
      );
      final before = await _snapshot(db);
      final selected = await SyncDeviceIdentity(
        storage,
        registry: registry,
      ).resolve(coordinator);
      expect(selected, original);
      // Existing durable pusher's original-device / author selector, unchanged.
      final pending = await db
          .customSelect(
            '''
SELECT q.event_id FROM outbox q LEFT JOIN change_log c ON c.id=q.event_id
WHERE q.plan_id=? AND q.device_id=?
AND (c.id IS NULL OR (c.plan_member_id=? AND c.device_id=?))
''',
            variables: [
              const Variable('plan'),
              Variable(selected),
              const Variable('member'),
              Variable(selected),
            ],
          )
          .get();
      expect(pending.single.read<String>('event_id'), 'original');
      expect(await _snapshot(db), before);
      expect(
        storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
        isEmpty,
      );
    },
  );

  test('canonical UUID excludes a trailing newline', () async {
    const value = '550e8400-e29b-41d4-a716-446655440000\n';
    storage.values[SyncDeviceIdentity.metadataKey] = value;
    await expectLater(
      SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
      throwsA(
        isA<SyncDeviceIdentityException>().having(
          (e) => e.code,
          'code',
          'invalid_stored_identity',
        ),
      ),
    );
    expect(storage.values[SyncDeviceIdentity.metadataKey], value);
  });

  test(
    'account transition drains paused write and retains persisted identity for fresh retry',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      storage.afterWrite = () async {
        storage.afterWrite = null;
        entered.complete();
        await release.future;
      };
      final before = await _snapshot(db);
      final attempt = SyncDeviceIdentity(
        storage,
        registry: registry,
      ).resolve(coordinator);
      final rejected = expectLater(
        attempt,
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'session_changed',
          ),
        ),
      );
      await entered.future;
      final persisted = storage.values[SyncDeviceIdentity.metadataKey];
      expect(persisted, isNotNull);
      expect(await _snapshot(db), before);
      var changedAuth = false;
      final transition = coordinator.transition(() async {
        changedAuth = true;
        identity.replace('account-b');
      });
      await Future<void>.delayed(Duration.zero);
      expect(changedAuth, isFalse);
      release.complete();
      await rejected;
      await transition;
      expect(changedAuth, isTrue);
      expect(storage.values[SyncDeviceIdentity.metadataKey], persisted);
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        persisted,
      );
      expect(
        storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
        hasLength(1),
      );
      expect(coordinator.isReady, isTrue);
    },
  );

  test('failed initial secure read fails closed without writing', () async {
    final before = Map<String, String>.of(storage.values);
    storage.failRead = true;
    await expectLater(
      SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
      throwsA(
        isA<SyncDeviceIdentityException>().having(
          (e) => e.code,
          'code',
          'storage_failed',
        ),
      ),
    );
    expect(storage.values, before);
    expect(
      storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
      isEmpty,
    );
    expect(coordinator.isReady, isTrue);
  });

  test(
    'failed secure readback retains valid metadata and fresh retry revalidates',
    () async {
      storage.afterWrite = () async {
        storage.failRead = true;
      };
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'storage_failed',
          ),
        ),
      );
      final persisted = storage.values[SyncDeviceIdentity.metadataKey];
      expect(persisted, isNotNull);
      storage.failRead = false;
      storage.afterWrite = null;
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        persisted,
      );
      expect(
        storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
        hasLength(1),
      );
    },
  );

  test(
    'write reporting failure after persistence never rolls metadata back',
    () async {
      storage.afterWrite = () async {
        throw StateError('sensitive platform detail');
      };
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'storage_failed',
          ),
        ),
      );
      final persisted = storage.values[SyncDeviceIdentity.metadataKey];
      expect(persisted, isNotNull);
      storage.afterWrite = null;
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        persisted,
      );
      expect(
        storage.writes.where((k) => k == SyncDeviceIdentity.metadataKey),
        hasLength(1),
      );
    },
  );

  test(
    'session change across actual encrypted history read prevents creation and drains lease',
    () async {
      historyBarrier.armed = true;
      final attempt = SyncDeviceIdentity(
        storage,
        registry: registry,
      ).resolve(coordinator);
      final rejected = expectLater(
        attempt,
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'session_changed',
          ),
        ),
      );
      await historyBarrier.entered.future;
      identity.replace('account-b');
      var drained = false;
      final switching = coordinator.observeSession().then((_) {
        drained = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      expect(
        storage.values.containsKey(SyncDeviceIdentity.metadataKey),
        isFalse,
      );
      historyBarrier.release.complete();
      await rejected;
      await switching;
      expect(
        storage.values.containsKey(SyncDeviceIdentity.metadataKey),
        isFalse,
      );
      expect(coordinator.isReady, isTrue);
    },
  );

  test(
    'failed retained-state query returns safe local failure without writing',
    () async {
      final before = await _snapshot(db);
      historyBarrier.fail = true;
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'local_operation_failed',
          ),
        ),
      );
      expect(await _snapshot(db), before);
      expect(
        storage.values.containsKey(SyncDeviceIdentity.metadataKey),
        isFalse,
      );
      expect(coordinator.isReady, isTrue);
    },
  );

  test(
    'separate secure-store adapters share one serialized metadata sequence',
    () async {
      final secondAdapter = _Storage(backing: storage.values);
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      storage.beforeRead = () async {
        storage.beforeRead = null;
        entered.complete();
        await release.future;
      };
      final first = SyncDeviceIdentity(
        storage,
        registry: registry,
      ).resolve(coordinator);
      await entered.future;
      var secondRead = false;
      secondAdapter.beforeRead = () async {
        secondRead = true;
      };
      final second = SyncDeviceIdentity(secondAdapter).resolve(coordinator);
      await Future<void>.delayed(Duration.zero);
      expect(secondRead, isFalse);
      release.complete();
      final ids = await Future.wait([first, second]);
      expect(secondRead, isTrue);
      expect(ids.toSet(), hasLength(1));
      expect(storage.values[SyncDeviceIdentity.metadataKey], ids.first);
      expect(
        [
          ...storage.writes,
          ...secondAdapter.writes,
        ].where((k) => k == SyncDeviceIdentity.metadataKey),
        hasLength(1),
      );
    },
  );

  test(
    'final return fence rejects session replacement in completion microtasks',
    () async {
      const stored = '550e8400-e29b-41d4-a716-446655440000';
      storage.values[SyncDeviceIdentity.metadataKey] = stored;
      var rejected = 0;
      var completedBeforeReplacement = 0;
      for (var hops = 0; hops < 16; hops++) {
        final originalMarker = identity.marker;
        final changed = Completer<void>();
        void replaceAfter(int remaining) {
          if (remaining == 0) {
            identity.replace('account-a');
            changed.complete();
          } else {
            scheduleMicrotask(() => replaceAfter(remaining - 1));
          }
        }

        storage.afterRead = () {
          storage.afterRead = null;
          replaceAfter(hops);
        };
        await SyncDeviceIdentity(storage, registry: registry)
            .resolve(coordinator)
            .then(
              (id) {
                expect(
                  identity.marker,
                  same(originalMarker),
                  reason: 'stale completion at microtask hop $hops',
                );
                expect(id, stored);
                completedBeforeReplacement++;
              },
              onError: (Object error) {
                expect(
                  error,
                  isA<SyncDeviceIdentityException>().having(
                    (e) => e.code,
                    'code',
                    'session_changed',
                  ),
                );
                rejected++;
              },
            );
        await changed.future;
        await coordinator.observeSession();
      }
      expect(rejected, greaterThan(0));
      expect(completedBeforeReplacement, greaterThan(0));
      expect(storage.values[SyncDeviceIdentity.metadataKey], stored);
    },
  );

  test(
    'replacement at completed lease snapshot cannot bypass outer return fence',
    () async {
      const stored = '550e8400-e29b-41d4-a716-446655440000';
      storage.values[SyncDeviceIdentity.metadataKey] = stored;
      var readCompleted = false;
      var checks = 0;
      var replaced = false;
      storage.afterRead = () => readCompleted = true;
      identity.onCapture = () {
        // Two checks in the resolver use capture + isReady (four captures).
        // The fifth is the real coordinator's final isReady snapshot. Replace
        // immediately AFTER that snapshot: its lease can finish, but our outer
        // return fence must reject. No fake coordinator or database is involved.
        if (readCompleted && ++checks == 5) {
          replaced = true;
          identity.replace('account-a');
        }
      };
      await expectLater(
        SyncDeviceIdentity(storage, registry: registry).resolve(coordinator),
        throwsA(
          isA<SyncDeviceIdentityException>().having(
            (e) => e.code,
            'code',
            'session_changed',
          ),
        ),
      );
      expect(replaced, isTrue);
      identity.onCapture = null;
      storage.afterRead = null;
      await coordinator.observeSession();
      expect(
        await SyncDeviceIdentity(
          storage,
          registry: registry,
        ).resolve(coordinator),
        stored,
      );
    },
  );
}
