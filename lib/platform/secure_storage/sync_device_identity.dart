import 'dart:async';
import 'dart:math';

import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/db/account_store_registry.dart';
import 'package:kasaran/platform/secure_storage/token_store.dart';

/// Safe, value-free failure. [code] is one of:
/// - `account_unavailable`: the caller has not supplied a ready coordinator;
/// - `session_changed`: readiness, generation or the captured session changed;
/// - `invalid_stored_identity`: retained metadata is not a canonical UUID;
/// - `retained_history_without_identity`: creation would hide retained sync work;
/// - `installation_unproven`: absent key without a trustworthy sole-store proof;
/// - `storage_failed`: a secure-storage operation failed;
/// - `persistence_unconfirmed`: readback did not match the newly written UUID;
/// - `local_operation_failed`: retained-state inspection/admission failed.
/// No underlying platform error, device ID or account identifier is disclosed.
final class SyncDeviceIdentityException implements Exception {
  const SyncDeviceIdentityException(this.code);
  final String code;
  @override
  String toString() => 'SyncDeviceIdentityException: $code';
}

/// Installation-scoped, non-secret sync identity backed by secure metadata.
/// Production callers supply [PlatformSecureKeyValueStore]. This is not an Auth
/// token, account ID, hardware ID or network authorization capability.
///
/// All wrappers share a single serialization queue in the application's Dart
/// isolate, even when their secure-store adapter instances differ. The entire
/// read/create/write/readback sequence is serialized and counted by a lease.
/// There is no cross-isolate/process CAS in [SecureKeyValueStore]: callers must
/// keep initialization in one application isolate/process. Other writers to the
/// same key are unsupported; readback detects interference, not atomicity.
///
/// A valid stored UUID is returned without inventory or history inspection.
/// Absent-key creation requires the actual installation [AccountStoreRegistry];
/// without it, resolution fails closed. Its sole-account inventory guard holds
/// the shared registry lock across leased-path validation, history inspection,
/// secure creation and exact readback. Other mapped/unmapped/staged/legacy or
/// unknown filesystem entries refuse creation without opening other databases.
/// Never adopts another device's events or changes database rows. Hosts must
/// keep unrelated sync writers quiescent: a lease is not a database-write lock.
/// The registry/root and metadata adapters must be the installation's actual
/// protected namespace. This does not certify legacy migration/publication.
///
/// Secure writes cannot be rolled back safely. If a write completes but the
/// attempt later fails, its persisted identity is left intact for a fresh,
/// admitted retry. Durability beyond successful platform write/readback (OS
/// backup, reinstall, restore, keychain loss) is not guaranteed by this API.
final class SyncDeviceIdentity {
  SyncDeviceIdentity(this._metadata, {AccountStoreRegistry? registry})
    : _registry = registry;
  final SecureKeyValueStore _metadata;
  final AccountStoreRegistry? _registry;

  /// New metadata key only; existing Auth and account-store keys are untouched.
  static const metadataKey = 'kasaran.sync.device_identity.v1';

  static Future<void> _pending = Future<void>.value();

  /// Requires an already-ready account store; never starts or closes its owner.
  /// Session checks cover every await and the outermost completion boundary.
  /// The returned ID is only a value, not a lease: consumers must obtain their
  /// own current account admission before constructing actors or doing sync.
  Future<String> resolve(AccountStoreCoordinator coordinator) async {
    if (!coordinator.isReady) {
      throw const SyncDeviceIdentityException('account_unavailable');
    }
    final session = coordinator.identity.capture();
    final generation = coordinator.generation;
    void check() {
      final current = coordinator.identity.capture();
      if (session == null ||
          current == null ||
          current.userId != session.userId ||
          !identical(current.marker, session.marker) ||
          coordinator.generation != generation ||
          !coordinator.isReady) {
        throw const SyncDeviceIdentityException('session_changed');
      }
    }

    try {
      final result = await coordinator.withAccount(
        (lease) => lease.run((db) => _serialized(db, session!.userId, check)),
      );
      check();
      return result;
    } on SyncDeviceIdentityException {
      rethrow;
    } catch (_) {
      check();
      throw const SyncDeviceIdentityException('local_operation_failed');
    }
  }

  Future<String> _serialized(
    AppDatabase db,
    String userId,
    void Function() check,
  ) async {
    final previous = _pending;
    final done = Completer<void>();
    _pending = done.future;
    try {
      await previous;
      check();
      final result = await _resolve(db, userId, check);
      check();
      return result;
    } finally {
      // Never poison the queue with a failed operation's future.
      done.complete();
    }
  }

  Future<String?> _read() async {
    try {
      return await _metadata.read(metadataKey);
    } catch (_) {
      throw const SyncDeviceIdentityException('storage_failed');
    }
  }

  Future<void> _write(String id) async {
    try {
      await _metadata.write(metadataKey, id);
    } catch (_) {
      throw const SyncDeviceIdentityException('storage_failed');
    }
  }

  Future<String> _resolve(
    AppDatabase db,
    String userId,
    void Function() check,
  ) async {
    final stored = await _read();
    check();
    if (stored != null) {
      if (!RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(stored)) {
        throw const SyncDeviceIdentityException('invalid_stored_identity');
      }
      return stored;
    }
    final registry = _registry;
    if (registry == null) {
      throw const SyncDeviceIdentityException('installation_unproven');
    }
    var admitted = false;
    try {
      return await registry.withSoleAccountStore(userId, (file) async {
        admitted = true;
        check();
        // Bind the inventory to the actual leased connection, not a caller's
        // assertion or a second pristine registry/root. No other DB is opened.
        final databases = await db.customSelect('PRAGMA database_list').get();
        check();
        final main = databases.where(
          (row) => row.read<String>('name') == 'main',
        );
        if (main.length != 1 || main.single.read<String>('file') != file.path) {
          throw const SyncDeviceIdentityException('installation_unproven');
        }
        return _create(db, check);
      });
    } on SyncDeviceIdentityException {
      rethrow;
    } catch (_) {
      check();
      if (admitted) rethrow;
      throw const SyncDeviceIdentityException('installation_unproven');
    }
  }

  Future<String> _create(AppDatabase db, void Function() check) async {
    final history = await db
        .customSelect(
          'SELECT 1 FROM sync_state UNION ALL SELECT 1 FROM change_log '
          'UNION ALL SELECT 1 FROM outbox '
          'UNION ALL SELECT 1 FROM sync_inbox LIMIT 1',
        )
        .get();
    check();
    if (history.isNotEmpty) {
      throw const SyncDeviceIdentityException(
        'retained_history_without_identity',
      );
    }
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 0x40;
    bytes[8] = (bytes[8] & 63) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _write(id);
    check();
    final persisted = await _read();
    check();
    if (persisted != id) {
      throw const SyncDeviceIdentityException('persistence_unconfirmed');
    }
    return id;
  }
}
