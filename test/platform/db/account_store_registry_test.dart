import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/account_store_registry.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';

class _MemoryMetadata implements SecureKeyValueStore {
  final values = <String, String>{};
  int writes = 0;
  int attemptWrites = 0;
  bool failAccountKeyWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failAccountKeyWrite && key.startsWith('kasaran.account_db.v1.')) {
      throw StateError('interrupted key write');
    }
    values[key] = value;
    writes++;
    if (key.startsWith('kasaran.account_db_attempt.v1.')) attemptWrites++;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _MetadataWrapper implements SecureKeyValueStore {
  _MetadataWrapper(this.backing);
  final _MemoryMetadata backing;
  @override
  Future<String?> read(String key) async {
    final value = await backing.read(key);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return value;
  }

  @override
  Future<void> write(String key, String value) => backing.write(key, value);
  @override
  Future<void> delete(String key) => backing.delete(key);
}

class _Security implements LocalDeviceSecurity {
  final directories = <String>[];
  final files = <String>[];
  bool failFile = false;
  @override
  Future<void> protectDirectory(String path) async => directories.add(path);
  @override
  Future<void> protectFile(String path) async {
    if (failFile) throw StateError('unsafe $path');
    files.add(path);
  }

  @override
  Future<bool> hasDeviceLock() async => true;
  @override
  Future<bool> hasShownLockWarning() async => false;
  @override
  Future<void> markLockWarningShown() async {}
}

void main() {
  late Directory root;
  late _MemoryMetadata metadata;
  late _Security security;
  setUp(() async {
    final fixture = await Directory.systemTemp.createTemp('kasaran-registry-');
    root = Directory(await fixture.resolveSymbolicLinks());
    metadata = _MemoryMetadata();
    security = _Security();
  });
  tearDown(() async => root.delete(recursive: true));

  AccountStoreRegistry registry() =>
      AccountStoreRegistry(root, metadata, security);
  VerifiedSessionSnapshot session(String id) =>
      VerifiedSessionSnapshot(id, Object());

  test(
    'sole-store guard holds actual registry lock through callback',
    () async {
      final location = await registry().resolveVerified(session('A'));
      final db = await LocalStoreBootstrap(
        root,
        PlatformDatabaseKeyStore(),
        security,
      ).openAccount(location);
      await db.close();
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final guarded = registry().withSoleAccountStore('A', (file) async {
        expect(file.path, location.file.path);
        entered.complete();
        await release.future;
        return 'completed';
      });
      await entered.future;
      var resolved = false;
      final competing = registry().resolveVerified(session('B')).then((value) {
        resolved = true;
        return value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(resolved, isFalse);
      release.complete();
      expect(await guarded, 'completed');
      await competing;
      var called = false;
      await expectLater(
        registry().withSoleAccountStore('A', (_) async {
          called = true;
        }),
        throwsA(isA<StateError>()),
      );
      expect(called, isFalse);
    },
  );

  test(
    'resolution protects parent but leaves fresh final directory absent',
    () async {
      final a = await registry().resolveVerified(session('A'));
      expect(a.file.parent.parent.existsSync(), isTrue);
      expect(security.directories, contains(a.file.parent.parent.path));
      expect(a.file.parent.existsSync(), isFalse);
      final b = await registry().resolveVerified(session('B'));
      expect(b.file.parent.existsSync(), isFalse);
      expect(
        (await registry().resolveVerified(session('A'))).storeId,
        a.storeId,
      );
      expect(a.file.parent.existsSync(), isFalse);
    },
  );

  test(
    'A and B get opaque independent encrypted stores and stable reopen',
    () async {
      final a = await registry().resolveVerified(session('private-user-A'));
      final b = await registry().resolveVerified(session('private-user-B'));
      expect(a.storeId, isNot(b.storeId));
      expect(a.file.path, isNot(contains('private-user-A')));
      expect(b.file.path, isNot(contains('private-user-B')));
      expect(a.file.path, isNot(b.file.path));
      expect(a.file.path, isNot(contains('kasaran.sqlite/')));
      expect(security.directories, contains(a.file.parent.parent.path));
      expect(a.file.parent.existsSync(), isFalse);
      expect(b.file.parent.existsSync(), isFalse);

      final bootstrap = LocalStoreBootstrap(
        root,
        PlatformDatabaseKeyStore(),
        security,
      );
      final aDb = await bootstrap.openAccount(a);
      await aDb.customStatement(
        'CREATE TABLE account_probe(value TEXT NOT NULL)',
      );
      await aDb.customStatement('INSERT INTO account_probe VALUES (?)', [
        'A-private-row',
      ]);
      await aDb.close();
      final bDb = await bootstrap.openAccount(b);
      await bDb.customStatement(
        'CREATE TABLE account_probe(value TEXT NOT NULL)',
      );
      await bDb.customStatement('INSERT INTO account_probe VALUES (?)', [
        'B-private-row',
      ]);
      await bDb.close();
      expect(security.files, containsAll([a.file.path, b.file.path]));
      final aKey = await a.keys.read();
      final bKey = await b.keys.read();
      expect(aKey, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(bKey, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(aKey, isNot(bKey));
      final bytes = utf8.decode(
        await a.file.readAsBytes(),
        allowMalformed: true,
      );
      expect(bytes, isNot(contains('A-private-row')));
      expect(bytes, isNot(contains(aKey)));
      final again = await registry().resolveVerified(session('private-user-A'));
      expect(again.storeId, a.storeId);
      expect(again.file.path, a.file.path);
      final reopened = await bootstrap.openAccount(again);
      expect(
        (await reopened.customSelect('SELECT value FROM account_probe').get())
            .single
            .read<String>('value'),
        'A-private-row',
      );
      await reopened.close();
      expect(File('${root.path}/kasaran.sqlite').existsSync(), isFalse);
      expect(
        metadata.values.containsKey(PlatformDatabaseKeyStore.keyName),
        isFalse,
      );
    },
  );

  test(
    'missing account key with existing file fails without replacement',
    () async {
      final location = await registry().resolveVerified(session('A'));
      final bootstrap = LocalStoreBootstrap(
        root,
        PlatformDatabaseKeyStore(),
        security,
      );
      final db = await bootstrap.openAccount(location);
      await db.close();
      final keyName = 'kasaran.account_db.v1.${location.storeId}';
      metadata.values.remove(keyName);
      final before = metadata.writes;
      await expectLater(
        bootstrap.openAccount(location),
        throwsA(isA<StateError>()),
      );
      expect(metadata.writes, before);
      expect(metadata.values.containsKey(keyName), isFalse);
    },
  );

  test(
    'mapped account with key and vanished file never creates replacement',
    () async {
      final location = await registry().resolveVerified(session('A'));
      final bootstrap = LocalStoreBootstrap(
        root,
        PlatformDatabaseKeyStore(),
        security,
      );
      final db = await bootstrap.openAccount(location);
      await db.close();
      await location.file.delete();
      final originalKey = await location.keys.read();
      final writes = metadata.writes;
      await expectLater(
        bootstrap.openAccount(location),
        throwsA(isA<StateError>()),
      );
      expect(location.file.existsSync(), isFalse);
      expect(await location.keys.read(), originalKey);
      expect(metadata.writes, writes);
    },
  );

  test('interrupted first open cannot silently retry as a new store', () async {
    final location = await registry().resolveVerified(session('A'));
    final bootstrap = LocalStoreBootstrap(
      root,
      PlatformDatabaseKeyStore(),
      security,
    );
    metadata.failAccountKeyWrite = true;
    await expectLater(
      bootstrap.openAccount(location),
      throwsA(isA<StateError>()),
    );
    expect(location.file.existsSync(), isFalse);
    metadata.failAccountKeyWrite = false;
    await expectLater(
      bootstrap.openAccount(location),
      throwsA(isA<StateError>()),
    );
    expect(location.file.existsSync(), isFalse);
  });

  test(
    'orphan staging bytes block creation without writing a new key',
    () async {
      final location = await registry().resolveVerified(session('A'));
      await location.file.parent.create();
      await File('${location.file.path}-wal').writeAsBytes([1, 2, 3]);
      final before = metadata.writes;
      await expectLater(
        LocalStoreBootstrap(
          root,
          PlatformDatabaseKeyStore(),
          security,
        ).openAccount(location),
        throwsA(isA<StateError>()),
      );
      expect(location.file.existsSync(), isFalse);
      expect(metadata.writes, before);
      expect(security.files, contains('${location.file.path}-wal'));
    },
  );

  test('concurrent resolutions retain both mappings', () async {
    final locations = await Future.wait([
      registry().resolveVerified(session('A')),
      registry().resolveVerified(session('B')),
    ]);
    final againA = await registry().resolveVerified(session('A'));
    final againB = await registry().resolveVerified(session('B'));
    expect(againA.storeId, locations[0].storeId);
    expect(againB.storeId, locations[1].storeId);
  });

  test('separate metadata wrappers preserve concurrent mappings', () async {
    final a = AccountStoreRegistry(root, _MetadataWrapper(metadata), security);
    final b = AccountStoreRegistry(root, _MetadataWrapper(metadata), security);
    final locations = await Future.wait([
      a.resolveVerified(session('A')),
      b.resolveVerified(session('B')),
    ]);
    final againA = await a.resolveVerified(session('A'));
    final againB = await b.resolveVerified(session('B'));
    expect(againA.storeId, locations[0].storeId);
    expect(againB.storeId, locations[1].storeId);
  });

  test('concurrent first opens persist one creation intent', () async {
    final location = await AccountStoreRegistry(
      root,
      _MetadataWrapper(metadata),
      security,
    ).resolveVerified(session('A'));
    final first = LocalStoreBootstrap(
      root,
      PlatformDatabaseKeyStore(),
      security,
    );
    final second = LocalStoreBootstrap(
      root,
      PlatformDatabaseKeyStore(),
      security,
    );
    metadata.failAccountKeyWrite = true;
    await Future.wait(
      [first.openAccount(location), second.openAccount(location)].map((
        operation,
      ) async {
        try {
          final db = await operation;
          await db.close();
          // A deliberate fail-closed StateError is the expected competing result.
          // ignore: avoid_catching_errors
        } on StateError {
          // One opener may fail closed while another is creating the store.
        }
      }),
    );
    expect(metadata.attemptWrites, 1);
  });

  test('missing registry with existing account parent fails closed', () async {
    final first = await registry().resolveVerified(session('A'));
    metadata.values.remove(AccountStoreRegistry.metadataKey);
    await expectLater(
      registry().resolveVerified(session('A')),
      throwsA(isA<StateError>()),
    );
    expect(first.file.parent.parent.existsSync(), isTrue);
    expect(first.file.parent.existsSync(), isFalse);
  });

  test('malformed or unknown registry metadata fails closed', () async {
    metadata.values['kasaran.account_stores.v1'] = '{broken';
    await expectLater(
      registry().resolveVerified(session('A')),
      throwsA(isA<StateError>()),
    );
    metadata.values['kasaran.account_stores.v1'] = jsonEncode({
      'version': 42,
      'accounts': <String, String>{},
    });
    await expectLater(
      registry().resolveVerified(session('A')),
      throwsA(isA<StateError>()),
    );
    metadata.values['kasaran.account_stores.v1'] = jsonEncode({
      'version': 1,
      'accounts': {'A': '../bad'},
    });
    await expectLater(
      registry().resolveVerified(session('A')),
      throwsA(isA<StateError>()),
    );
    metadata.values['kasaran.account_stores.v1'] = jsonEncode({
      'version': 1,
      'accounts': {'A': 'a' * 32, 'B': 'a' * 32},
    });
    await expectLater(
      registry().resolveVerified(session('A')),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'registry rejects symlinked account parent and account directory',
    () async {
      final location = await registry().resolveVerified(session('A'));
      final parent = location.file.parent.parent;
      final savedParent = Directory('${root.path}/saved-parent');
      await parent.rename(savedParent.path);
      await Link(parent.path).create(savedParent.path);
      await expectLater(
        registry().resolveVerified(session('A')),
        throwsA(isA<StateError>()),
      );
      await Link(parent.path).delete();
      await savedParent.rename(parent.path);
      final account = location.file.parent;
      await account.create();
      final savedAccount = Directory('${root.path}/saved-account');
      await account.rename(savedAccount.path);
      await Link(account.path).create(savedAccount.path);
      await expectLater(
        registry().resolveVerified(session('A')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        LocalStoreBootstrap(
          root,
          PlatformDatabaseKeyStore(),
          security,
        ).openAccount(location),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'registry and bootstrap reject symlink ancestors above support root',
    () async {
      final actual = Directory('${root.path}/actual/support');
      await actual.create(recursive: true);
      final alias = Link('${root.path}/alias');
      await alias.create('${root.path}/actual');
      final linkedRoot = Directory('${alias.path}/support');
      final writes = metadata.writes;
      await expectLater(
        AccountStoreRegistry(
          linkedRoot,
          metadata,
          security,
        ).resolveVerified(session('A')),
        throwsA(isA<StateError>()),
      );
      expect(metadata.writes, writes);

      final location = await AccountStoreRegistry(
        actual,
        metadata,
        security,
      ).resolveVerified(session('A'));
      final parent = Directory('${root.path}/actual');
      final moved = await parent.rename('${root.path}/moved');
      await Link(parent.path).create(moved.path);
      await expectLater(
        LocalStoreBootstrap(
          actual,
          PlatformDatabaseKeyStore(),
          security,
        ).openAccount(location),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('iOS signs Runner with complete default file protection', () async {
    final entitlements = await File(
      'ios/Runner/Runner.entitlements',
    ).readAsString();
    final project = await File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsString();
    expect(
      entitlements,
      contains('<key>com.apple.developer.default-data-protection</key>'),
    );
    expect(entitlements, contains('<string>NSFileProtectionComplete</string>'));
    expect(
      RegExp(
        r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;',
      ).allMatches(project).length,
      3,
    );
  });

  test(
    'bootstrap rejects symlinked database and sidecars before open',
    () async {
      final location = await registry().resolveVerified(session('A'));
      final bootstrap = LocalStoreBootstrap(
        root,
        PlatformDatabaseKeyStore(),
        security,
      );
      final outside = File('${root.path}/outside');
      final db = await bootstrap.openAccount(location);
      await db.close();
      await location.file.rename(outside.path);
      await Link(location.file.path).create(outside.path);
      await expectLater(
        bootstrap.openAccount(location),
        throwsA(isA<StateError>()),
      );
      await Link(location.file.path).delete();
      await outside.rename(location.file.path);
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final sidecar = Link('${location.file.path}$suffix');
        await sidecar.create(location.file.path);
        await expectLater(
          bootstrap.openAccount(location),
          throwsA(isA<StateError>()),
        );
        await sidecar.delete();
      }
    },
  );

  test('location construction is registry-only', () async {
    final source = await File(
      'lib/platform/db/account_store_registry.dart',
    ).readAsString();
    final declaration = source
        .split('final class AccountStoreLocation {')
        .last
        .split('final class AccountStoreRegistry {')
        .first;
    expect(declaration, contains('AccountStoreLocation._('));
    expect(declaration, isNot(contains('AccountStoreLocation(')));
    final location = await registry().resolveVerified(session('A'));
    expect(location.keys.storeId, location.storeId);
  });

  test('protection errors never disclose user identity or secret', () async {
    final location = await registry().resolveVerified(
      session('private-user-A'),
    );
    security.failFile = true;
    metadata.values['kasaran.account_db.v1.${location.storeId}'] = 'c' * 64;
    final secret = await location.keys.read();
    await expectLater(
      LocalStoreBootstrap(
        root,
        PlatformDatabaseKeyStore(),
        security,
      ).openAccount(location),
      throwsA(
        isA<StateError>().having(
          (error) => '$error',
          'sanitized error',
          allOf(
            isNot(contains('private-user-A')),
            isNot(contains(location.file.path)),
            isNot(contains(secret)),
          ),
        ),
      ),
    );
  });
}
