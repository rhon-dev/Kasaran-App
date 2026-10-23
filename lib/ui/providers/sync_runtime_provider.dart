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
  return ref.watch(syncRuntimeOwnerProvider)?.status ?? AccountSyncHostStatus.unknown;
});
final boundLedgerProvider = Provider<BoundLedgerRepository?>((ref) {
  ref.watch(syncRuntimeRevisionProvider);
  final host = ref.watch(syncHostProvider);
  return host?.actor == null ? null : BoundLedgerRepository(host!);
});
final ledgerEntriesProvider = FutureProvider<List<LedgerEntry>>((ref) async {
  ref.watch(syncRuntimeRevisionProvider);
  final ledger = ref.watch(boundLedgerProvider);
  if (ledger == null) throw StateError('Ledger capability unavailable');
  final rows = await ledger.listLive();
  if (!ref.mounted) throw StateError('Account changed');
  return rows;
});
