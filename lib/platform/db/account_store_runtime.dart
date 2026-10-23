import 'dart:io';

import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/account_store_registry.dart';
import 'package:kasaran/platform/db/encrypted_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';

/// Auth initialization and device preparation create no financial database.
/// Only a fresh verified coordinator snapshot can select/open an account file.
final class AccountStoreRuntime {
  AccountStoreRuntime._(this.coordinator, this.warningNeeded);
  final AccountStoreCoordinator coordinator;
  final bool warningNeeded;

  static Future<AccountStoreRuntime> initialize({
    required Future<void> Function() initializeAuth,
    required VerifiedLocalIdentity Function() identity,
    required Future<Directory> Function() applicationSupportDirectory,
    required SecureKeyValueStore metadata,
    required DatabaseKeyStore legacyKeys,
    required LocalDeviceSecurity security,
  }) async {
    await initializeAuth();
    // Only canonicalize the trusted platform directory, never a caller-selected
    // account path. Descendant links still fail the registry/bootstrap checks.
    final supplied = await applicationSupportDirectory();
    await supplied.create(recursive: true);
    final root = Directory(await supplied.resolveSymbolicLinks());
    final bootstrap = LocalStoreBootstrap(root, legacyKeys, security);
    final warning = await bootstrap.prepare();
    final registry = AccountStoreRegistry(root, metadata, security);
    final source = identity();
    final coordinator = AccountStoreCoordinator(source, (session) async {
      void requireCurrent() {
        final current = source.capture();
        if (current == null ||
            current.userId != session.userId ||
            !identical(current.marker, session.marker)) {
          throw StateError('Account session changed');
        }
      }

      requireCurrent();
      final location = await registry.resolveVerified(session);
      requireCurrent();
      // Bootstrap deliberately rejects any legacy file/sidecar. Durable native
      // legacy promotion has not been attested; never open the global source or
      // replace it with an empty destination through this production path.
      return bootstrap.openAccount(location);
    });
    return AccountStoreRuntime._(coordinator, warning);
  }
}
