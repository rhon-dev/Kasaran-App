import 'dart:async';

import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/data/repositories/local_plan_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/platform/secure_storage/sync_device_identity.dart';
import 'package:kasaran/sync/queue/account_metadata_bootstrapper.dart';
import 'package:kasaran/sync/queue/account_sync_worker.dart';
import 'package:kasaran/sync/queue/durable_inbox_puller.dart';
import 'package:kasaran/sync/queue/durable_outbox_pusher.dart';
import 'package:kasaran/sync/replay/durable_projection_rebuilder.dart';
import 'package:kasaran/sync/transport/bootstrap_transport.dart';
import 'package:kasaran/sync/transport/sync_protocol.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

enum AccountSyncHostStatus {
  unknown,
  initializing,
  none,
  ready,
  pending,
  error,
  updateRequired,
  stopped,
}

/// Permanently owns one ready session, never a replacement. Both supplied HTTP
/// transports transfer to this owner; coordinator and device resolver do not.
/// Discovery must use the supplied immutable binding and not mutate Auth or await
/// coordinator drain: its complete callback future is a counted account operation.
final class AccountSyncHost {
  AccountSyncHost.ownedTransports({
    required this.coordinator,
    required this.deviceIdentity,
    required this.discoverMembership,
    required this.syncTransport,
    required this.bootstrapTransport,
    this.schedule = Timer.new,
    this.foregroundInterval = const Duration(seconds: 30),
  }) : _session = coordinator.identity.capture(),
       _generation = coordinator.generation {
    if (foregroundInterval < const Duration(seconds: 1)) {
      throw ArgumentError('Foreground interval must be bounded');
    }
    if (_session == null || !coordinator.isReady) {
      throw StateError('Ready account required');
    }
    coordinator.addListener(_observe);
  }
  final AccountStoreCoordinator coordinator;
  final SyncDeviceIdentity deviceIdentity;
  final Future<String?> Function(SyncSessionBinding) discoverMembership;
  final HttpSyncTransport syncTransport;
  final HttpBootstrapTransport bootstrapTransport;
  final Timer Function(Duration, void Function()) schedule;
  final Duration foregroundInterval;
  final VerifiedSessionSnapshot? _session;
  final int _generation;
  bool _stopped = false;
  bool _terminal = false;
  StreamSubscription<AccountSyncStatus>? _workerSubscription;
  AccountSyncHostStatus _status = AccountSyncHostStatus.unknown;
  AccountSyncHostStatus get status =>
      _fresh() ? _status : AccountSyncHostStatus.stopped;
  LedgerActor? _actor;
  LedgerActor? get actor => _fresh() ? _actor : null;
  AccountSyncWorker? _worker;
  AccountSyncStatus get syncStatus => _fresh()
      ? _worker?.status ?? AccountSyncStatus.stopped
      : AccountSyncStatus.stopped;

  bool _fresh() {
    if (_stopped) return false;
    final current = coordinator.identity.capture();
    if (current == null ||
        current.userId != _session!.userId ||
        !identical(current.marker, _session.marker) ||
        coordinator.generation != _generation ||
        !coordinator.isReady) {
      unawaited(dispose());
      return false;
    }
    return !_stopped;
  }

  void _observe() {
    _fresh();
  }

  void _check() {
    if (!_fresh()) throw StateError('Sync host stopped');
  }

  final _listeners = <void Function()>{};
  bool _notifying = false;

  /// Guarded invalidation only: pull fresh getters in the callback. No buffered
  /// payload/status stream, and no observer future participates in resource drain.
  void addListener(void Function() listener) {
    if (_fresh()) _listeners.add(listener);
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _invalidate() {
    if (!_fresh() || _notifying) return;
    _notifying = true;
    try {
      for (final listener in List.of(_listeners)) {
        if (!_fresh()) break;
        if (!_listeners.contains(listener)) continue;
        try {
          listener();
        } catch (_) {
          /* Observers cannot relabel durable work. */
        }
      }
    } finally {
      _notifying = false;
    }
  }

  void _setStatus(AccountSyncHostStatus value) {
    _check();
    if (_status == value) return;
    _status = value;
    _invalidate();
  }

  Future<void>? _operation;
  Future<void> start() {
    if (!_fresh()) return Future.value();
    if (_operation != null) return _operation!;
    if (_terminal || _worker != null || _status == AccountSyncHostStatus.none) {
      return Future.value();
    }
    final done = Completer<void>();
    _operation = done.future; // Assign before callbacks can reenter/dispose.
    unawaited(
      _initialize().whenComplete(() {
        _operation = null;
        done.complete();
      }),
    );
    return done.future;
  }

  Future<void>? _refresh;

  /// Explicit invite handoff; retained valid metadata is not an ongoing upsert.
  /// An older discovery may already have captured none before acceptance. Queue
  /// one explicit trailing pass on this immutable host, never a replacement.
  Future<void> refreshMembership() {
    if (!_fresh() || _terminal) return Future.value();
    if (_refresh != null) return _refresh!;
    final older = _operation;
    if (older == null) return _refreshNow();
    final done = Completer<void>();
    _refresh = done.future;
    unawaited(() async {
      await older;
      if (_fresh() && !_terminal) await _refreshNow();
      _refresh = null;
      done.complete();
    }());
    return done.future;
  }

  Future<void> _refreshNow() {
    if (_status == AccountSyncHostStatus.none) {
      _status = AccountSyncHostStatus.unknown;
    }
    return start();
  }

  /// Only the bound facade calls this after its complete commit future succeeds.
  void notifyLocalWrite() {
    if (!_fresh() || _terminal || _actor == null) return;
    _invalidate();
    // A listener can synchronously revoke this host.
    if (!_fresh() || _terminal) return;
    _worker?.notifyLocalWrite();
  }

  bool _foreground = false;
  Timer? _foregroundTimer;

  /// Explicit event contract: initially background. The later SDK binding owns
  /// real lifecycle observation. This policy is NOT a native connectivity event;
  /// it bounds retry/remote polling opportunities only while explicitly foreground.
  void notifyForeground() {
    if (!_fresh()) return;
    _foreground = true;
    _armForeground();
    _wake();
  }

  void notifyBackground() {
    _foreground = false;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }

  void _armForeground() {
    if (!_foreground ||
        !_fresh() ||
        _terminal ||
        (_foregroundTimer?.isActive ?? false)) {
      return;
    }
    _foregroundTimer = schedule(foregroundInterval, () {
      _foregroundTimer = null;
      if (!_foreground || !_fresh()) return;
      _armForeground();
      _wake(periodic: true);
    });
  }

  void _wake({bool periodic = false}) {
    if (!_fresh() || _terminal) return;
    if (_worker != null) {
      // Periodic idle polling must not cancel the worker's own pending retry
      // or turn a slow in-flight pass into a perpetual trailing pass.
      if (periodic &&
          (_worker!.status == AccountSyncStatus.pending ||
              _worker!.status == AccountSyncStatus.syncing)) {
        return;
      }
      _worker!.notifyForeground();
    } else {
      unawaited(start());
    }
  }

  Future<void> _initialize() async {
    var discovering = false;
    try {
      _check();
      _setStatus(AccountSyncHostStatus.initializing);
      _check();
      final local = await readLocalPlan();
      _check();
      final device = await deviceIdentity.resolve(coordinator);
      _check();
      final LedgerActor actor;
      if (local == null) {
        discovering = true;
        final plan = await coordinator.withAccount(
          (lease) => lease.run((_) async {
            _check();
            final plan = await discoverMembership(
              SyncSessionBinding(
                userId: _session!.userId,
                marker: _session.marker,
              ),
            );
            _check();
            return plan;
          }),
        );
        _check();
        discovering = false;
        if (plan == null) {
          _setStatus(AccountSyncHostStatus.none);
          return;
        }
        actor = await AccountMetadataBootstrapper(
          coordinator,
          bootstrapTransport,
        ).bootstrap(planId: plan, deviceId: device);
        _check();
      } else {
        actor = LedgerActor(
          planId: local.plan.id,
          userId: local.member.userId,
          planMemberId: local.member.planMemberId,
          deviceId: device,
        );
      }
      _check();
      _actor = actor;
      _setStatus(AccountSyncHostStatus.ready);
      _check();
      final worker = _worker = AccountSyncWorker(
        coordinator: coordinator,
        actor: actor,
        pusher: DurableOutboxPusher(coordinator, syncTransport),
        puller: DurableInboxPuller(coordinator, syncTransport),
        rebuilder: DurableProjectionRebuilder(coordinator),
        schedule: schedule,
      );
      _check();
      _workerSubscription = worker.statuses.listen(_workerChanged);
      unawaited(worker.start());
    } catch (error) {
      // Do not disclose callback, native or peer errors, credentials or payloads.
      if (!_fresh()) return;
      if (error is SyncUpdateRequired) {
        _latch(AccountSyncHostStatus.updateRequired);
      } else if (error is SyncTransportException) {
        if (error.code == 'temporarily_unavailable') {
          _setStatus(AccountSyncHostStatus.pending);
        } else {
          _latch(AccountSyncHostStatus.error);
        }
      } else if (discovering &&
          error is! SyncProtocolException &&
          error is! MetadataBootstrapException &&
          error is! SyncDeviceIdentityException) {
        _setStatus(AccountSyncHostStatus.pending);
      } else {
        _latch(AccountSyncHostStatus.error);
      }
    }
  }

  void _latch(AccountSyncHostStatus status) {
    _terminal = true;
    _actor = null;
    _status = status;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    _invalidate();
  }

  void _workerChanged(AccountSyncStatus status) {
    if (!_fresh()) return;
    if (status == AccountSyncStatus.error) _latch(AccountSyncHostStatus.error);
    if (status == AccountSyncStatus.updateRequired) {
      _latch(AccountSyncHostStatus.updateRequired);
    }
    _invalidate();
  }

  Future<void> get settled async {
    await _operation;
    await _refresh;
    await _worker?.settled;
  }

  final _reads = <Future<void>>{};
  Future<LocalPlanSnapshot?> readLocalPlan() async {
    _check();
    if (_terminal) throw StateError('Sync host authority unavailable');
    final done = Completer<void>();
    _reads.add(done.future);
    try {
      final result = await LocalPlanRepository(coordinator).currentActivePlan();
      _check();
      if (_terminal) throw StateError('Sync host authority unavailable');
      return result;
    } finally {
      _reads.remove(done.future);
      done.complete();
    }
  }

  Future<void>? _disposal;
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    _stopped =
        true; // Synchronous rejection, even while initialization is pending.
    _actor = null;
    notifyBackground();
    coordinator.removeListener(_observe);
    final workerDrain = _worker
        ?.dispose(); // Immediate worker admission revocation.
    return _disposal = _drain(workerDrain);
  }

  Future<void> _drain(Future<void>? workerDrain) async {
    await _operation;
    await _refresh;
    await workerDrain;
    await Future.wait(List.of(_reads));
    await _workerSubscription?.cancel();
    syncTransport.close();
    bootstrapTransport.close();
  }
}
