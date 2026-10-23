import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/bound_ledger_repository.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';
import 'package:kasaran/sync/queue/sync_runtime_owner.dart';

/// Installed by the production root, never owns provider-order shutdown.
final syncRuntimeOwnerProvider = Provider<SyncRuntimeOwner?>((ref) => null);

class _RuntimeUpdates extends ChangeNotifier {
  _RuntimeUpdates(this.owner) {
    owner?.addListener(_changed);
  }
  final SyncRuntimeOwner? owner;
  int revision = 0;
  void _changed() {
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    owner?.removeListener(_changed);
    super.dispose();
  }
}

final _updatesProvider = ChangeNotifierProvider<_RuntimeUpdates>(
  (ref) => _RuntimeUpdates(ref.watch(syncRuntimeOwnerProvider)),
);
final syncRuntimeRevisionProvider = Provider<int>(
  (ref) => ref.watch(_updatesProvider).revision,
);
final syncHostProvider = Provider<AccountSyncHost?>((ref) {
  ref.watch(syncRuntimeRevisionProvider);
  return ref.watch(syncRuntimeOwnerProvider)?.host;
});
final syncHostStatusProvider = Provider<AccountSyncHostStatus>((ref) {
  ref.watch(syncRuntimeRevisionProvider);
  return ref.watch(syncRuntimeOwnerProvider)?.status ??
      AccountSyncHostStatus.unknown;
});
final boundLedgerProvider = Provider<BoundLedgerRepository?>((ref) {
  ref.watch(syncRuntimeRevisionProvider);
  final host = ref.watch(syncHostProvider);
  return host?.actor == null ? null : BoundLedgerRepository(host!);
});
final _ledgerReadsProvider = FutureProvider.autoDispose
    .family<List<LedgerEntry>, AccountSyncHost>((ref, host) async {
      ref.watch(syncRuntimeRevisionProvider);
      if (!identical(ref.watch(syncHostProvider), host)) {
        throw StateError('Account changed');
      }
      final rows = await BoundLedgerRepository(host).listLive();
      if (!ref.mounted) throw StateError('Account changed');
      return rows;
    });

/// A synchronous facade deliberately drops AsyncValue's previous-account data.
/// The finite query is keyed by immutable host, not merely user ID.
final ledgerEntriesProvider = Provider<AsyncValue<List<LedgerEntry>>>((ref) {
  ref.watch(syncRuntimeRevisionProvider);
  final host = ref.watch(syncHostProvider);
  if (host?.actor == null) return const AsyncLoading();
  return ref.watch(_ledgerReadsProvider(host!));
});
final ledgerEntriesFutureProvider = Provider<Future<List<LedgerEntry>>>((ref) {
  ref.watch(syncRuntimeRevisionProvider);
  final host = ref.watch(syncHostProvider);
  if (host?.actor == null) {
    return Future.error(StateError('Ledger capability unavailable'));
  }
  return ref.watch(_ledgerReadsProvider(host!).future);
});
