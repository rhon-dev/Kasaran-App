import 'dart:async';

import 'package:kasaran/data/changelog/verified_local_identity.dart';
import 'package:kasaran/data/repositories/ledger_repository.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/sync/queue/durable_inbox_puller.dart';
import 'package:kasaran/sync/queue/durable_outbox_pusher.dart';
import 'package:kasaran/sync/replay/durable_projection_rebuilder.dart';
import 'package:kasaran/sync/transport/sync_transport.dart';

/// Safe classifications only: no payloads, identifiers, credentials or peer errors.
/// [idle] requires a successful projection, not just a transport acknowledgment.
/// [attention] covers retained unsupported history or incomplete supported history;
/// the latter is terminal for this instance. [pending] may include provisional data.
enum AccountSyncStatus {
  stopped,
  idle,
  syncing,
  pending,
  error,
  updateRequired,
  attention,
}

/// Explicitly started, one-shot scheduling core; deliberately not startup-wired.
///
/// Construct only for an already-ready coordinator and immutable admitted actor.
/// Captures its actual session marker and generation at construction, never adopts
/// a later session (including silent same-user replacement or A→B→A).
///
/// Each cycle admits one existing push batch, at most [maxPullPages] pull pages,
/// and one rebuild only when there are no remaining pages. Incomplete supported
/// history therefore preserves the old projection while asynchronous bounded
/// continuations fetch the remaining history. At exhaustion it becomes terminal
/// attention, never success. Services own their individual counted leases; this
/// scheduler holds no outer lease across nested services or network requests.
///
/// Transient transport failure/partial acknowledgment retries indefinitely at a
/// capped 1/2/4/8/16/30-second delay. No queued/inbox history is discarded.
/// Authorization, protocol, corruption and update-required failures latch until
/// explicit disposal and recreation after the cause is repaired (or app updated).
/// Notifications and repeated [start] cannot reset that latch. Stop/revocation
/// is also permanent for this instance. Never recreate merely to bypass an update.
final class AccountSyncWorker {
  AccountSyncWorker({
    required this.coordinator,
    required this.actor,
    required this.pusher,
    required this.puller,
    required this.rebuilder,
    this.schedule = Timer.new,
    this.maxPullPages = 2,
    this.pullLimit = 100,
  }) : _session = coordinator.identity.capture(),
       _generation = coordinator.generation {
    if (maxPullPages < 1 ||
        maxPullPages > 16 ||
        pullLimit < 1 ||
        pullLimit > 1000 ||
        !identical(pusher.coordinator, coordinator) ||
        !identical(puller.coordinator, coordinator) ||
        !identical(rebuilder.coordinator, coordinator)) {
      throw ArgumentError('Invalid account sync configuration');
    }
  }
  final VerifiedSessionSnapshot? _session;
  final int _generation;
  bool _stopped = false;
  bool _revoked = false;
  bool _listening = false;
  final int maxPullPages, pullLimit;

  /// Timer seam for deterministic tests; must preserve Timer's asynchronous,
  /// one-shot semantics. Does not represent an actual platform event source.
  final Timer Function(Duration, void Function()) schedule;
  final AccountStoreCoordinator coordinator;
  final LedgerActor actor;
  final DurableOutboxPusher pusher;
  final DurableInboxPuller puller;
  final DurableProjectionRebuilder rebuilder;
  final _statuses =
      StreamController<({int revision, AccountSyncStatus status})>.broadcast(
        sync: true,
      );
  int _statusRevision = 0;

  /// Synchronous classification-only notifications, without replay. Read [status]
  /// for the current value. Nested publications coalesce until delivery unwinds.
  /// Each subscriber is checked at delivery (including after pause): superseded,
  /// stopped or account-revoked events are discarded, not replayed as history.
  Stream<AccountSyncStatus> get statuses => _statuses.stream
      .where((event) => event.revision == _statusRevision && _canRun())
      .map((event) => event.status);
  AccountSyncStatus _status = AccountSyncStatus.stopped;
  AccountSyncStatus get status =>
      _stopped || _revoked ? AccountSyncStatus.stopped : _status;
  bool _publishing = false;
  AccountSyncStatus? _queuedStatus;
  void _publish(AccountSyncStatus next) {
    if (!_canRun() || _statuses.isClosed) return;
    // A listener can report another write for the classification it is already
    // receiving. Keep the debounce side effect without an endless echo loop.
    if (_publishing && next == _status) return;
    _status = next;
    _statusRevision++;
    _queuedStatus = next;
    if (_publishing) return;
    _publishing = true;
    try {
      while (_queuedStatus != null && _canRun() && !_statuses.isClosed) {
        final event = _queuedStatus!;
        _queuedStatus = null;
        _statuses.add((revision: _statusRevision, status: event));
      }
    } finally {
      _queuedStatus = null;
      _publishing = false;
    }
  }

  int _failures = 0;
  bool _terminal = false;
  bool _started = false;
  bool _running = false;
  bool _pending = false;
  Timer? _timer;
  Timer? _debounceTimer;
  Duration _nextRetry() {
    const seconds = [1, 2, 4, 8, 16, 30];
    final delay = Duration(seconds: seconds[_failures]);
    if (_failures < seconds.length - 1) _failures++;
    return delay;
  }

  /// Call only after a successful durable local write. Trailing-edge debounce;
  /// an already scheduled continuation/retry covers the write without postponement.
  void notifyLocalWrite() {
    if (!_canRun() || _terminal) return;
    if (_timer?.isActive ?? false) return;
    _debounceTimer?.cancel();
    _debounceTimer = schedule(const Duration(milliseconds: 250), _trigger);
    _publish(AccountSyncStatus.pending);
  }

  /// Injectable app-lifecycle seam, not an installed lifecycle observer.
  void notifyForeground() => _trigger();

  /// Injectable connectivity seam; no connectivity package or listener is owned.
  void notifyReconnect() => _trigger();
  void _trigger() {
    if (!_canRun() || _terminal) return;
    if (_running) {
      _pending = true;
      return;
    }
    _timer?.cancel();
    _debounceTimer?.cancel();
    _cycle = _run();
  }

  /// Completion of the currently admitted bounded cycle, not future timer work.
  Future<void> get settled => _cycle ?? Future.value();
  Future<void>? _cycle;

  /// Starts the initial cycle automatically; repeated calls share current work.
  Future<void> start() {
    if (!_started && !_stopped) {
      _started = true;
      coordinator.addListener(_observe);
      _listening = true;
      _trigger();
    }
    return settled;
  }

  bool _canRun() {
    if (!_started || _stopped || _revoked) return false;
    final current = coordinator.identity.capture();
    if (current == null ||
        _session == null ||
        current.userId != actor.userId ||
        current.userId != _session.userId ||
        !identical(current.marker, _session.marker) ||
        coordinator.generation != _generation ||
        !coordinator.isReady) {
      _revoked = true;
      _timer?.cancel();
      _debounceTimer?.cancel();
      return false;
    }
    return true;
  }

  void _observe() {
    _canRun();
  }

  Future<void> _run() async {
    _running = true;
    Duration? retry;
    var attention = false;
    try {
      _publish(AccountSyncStatus.syncing);
      if (!_canRun()) return;
      final pushed = await pusher.pushOnce(actor);
      if (!_canRun()) return;
      if (pushed.acknowledged < pushed.attempted) {
        retry = _nextRetry();
      } else if (pushed.attempted == 100) {
        _pending = true;
      }
      var hasMore = false;
      for (var page = 0; page < maxPullPages; page++) {
        if (!_canRun()) return;
        final pulled = await puller.pullOnce(actor, limit: pullLimit);
        if (!_canRun()) return;
        hasMore = pulled.hasMore;
        if (!hasMore) break;
      }
      if (hasMore) {
        _pending = true;
      } else {
        if (!_canRun()) return;
        final projection = await rebuilder.rebuild(actor);
        attention = projection.needsAttention;
        if (!_canRun()) return;
      }
      if (retry == null) _failures = 0;
      _publish(
        attention
            ? AccountSyncStatus.attention
            : retry != null || _pending || (_debounceTimer?.isActive ?? false)
            ? AccountSyncStatus.pending
            : AccountSyncStatus.idle,
      );
    } catch (error) {
      if (!_canRun()) return;
      if (error is SyncTransportException &&
          error.code == 'temporarily_unavailable') {
        retry = _nextRetry();
        _publish(AccountSyncStatus.pending);
      } else {
        _terminal = true;
        _pending = false;
        _timer?.cancel();
        _debounceTimer?.cancel();
        _publish(
          error is SyncUpdateRequired
              ? AccountSyncStatus.updateRequired
              : error is DurableProjectionException &&
                    error.code == 'incomplete_history'
              ? AccountSyncStatus.attention
              : AccountSyncStatus.error,
        );
      }
    } finally {
      _running = false;
      if ((retry != null || _pending) && _canRun() && !_terminal) {
        _pending = false;
        _timer?.cancel();
        _debounceTimer?.cancel();
        _timer = schedule(retry ?? Duration.zero, _trigger);
      }
    }
  }

  /// Revokes synchronously, cancels timers/listener, then drains the whole cycle
  /// including native COMMIT. Does not close the coordinator or owned transports.
  Future<void> stop() => dispose();

  /// Idempotent asynchronous disposal. The app owner must await this before
  /// releasing account-bound resources; this worker never closes those resources.
  /// Completion drains durable work and initiates stream closure, but never waits
  /// for an external paused subscriber to resume and consume the done event.
  Future<void> dispose() async {
    _stopped = true;
    _started = false;
    if (_listening) {
      coordinator.removeListener(_observe);
      _listening = false;
    }
    _timer?.cancel();
    _debounceTimer?.cancel();
    await settled;
    // Initiate termination, but external paused observers do not own the
    // durable-resource drain barrier (close's future waits for their done).
    if (!_statuses.isClosed) unawaited(_statuses.close());
  }
}
