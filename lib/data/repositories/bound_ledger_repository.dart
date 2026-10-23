import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';

/// App capability: immutable admitted actor, never an arbitrary UI identity tuple.
final class BoundLedgerRepository {
  BoundLedgerRepository(AccountSyncHost host)
    : _host = host,
      _actor = host.actor,
      _repository = LedgerRepository(host.coordinator) {
    _check();
  }
  final AccountSyncHost _host;
  final LedgerActor? _actor;
  final LedgerRepository _repository;

  void _check() {
    if (_actor == null || !identical(_host.actor, _actor)) {
      throw StateError('Ledger capability unavailable');
    }
  }

  Future<List<LedgerEntry>> listLive() async {
    _check();
    final rows = await _repository.listLive(_actor!);
    _check();
    return rows;
  }

  Future<T> _mutate<T>(Future<T> Function(LedgerActor) work) async {
    _check();
    final result = await work(_actor!);
    _check(); // Full repository wrapper, account checks and native COMMIT finished.
    try {
      _host.notifyLocalWrite();
    } catch (_) {
      // A notification failure cannot relabel an already committed mutation.
    }
    _check(); // Notification listeners can synchronously revoke the account.
    return result;
  }

  Future<LedgerEntry> create(LedgerDraft draft) =>
      _mutate((actor) => _repository.create(actor, draft));
  Future<LedgerEntry> edit(String id, LedgerEntriesCompanion changes) =>
      _mutate((actor) => _repository.edit(actor, id, changes));
  Future<void> delete(String id) =>
      _mutate((actor) => _repository.delete(actor, id));
}
