import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';
import 'package:kasaran/sync/queue/account_sync_host.dart';

/// Root lifetime, outside keyed account UI. Hosts permanently bind one session.
final class SyncRuntimeOwner extends ChangeNotifier {
  SyncRuntimeOwner({required this.coordinator, required this.createHost}) {
    coordinator.addListener(_reconcile);
    _reconcile();
  }
  final AccountStoreCoordinator coordinator;
  final AccountSyncHost Function(SyncTransportLifetime) createHost;
  SyncTransportLifetime? _lifetime;
  Future<void>? _coordinatorDrain;
  AccountSyncHost? _host;
  Future<void> _replacement = Future.value();
  Future<void>? _closing;
  bool _foreground = false;
  bool _failed = false;
  final _retired = <SyncTransportLifetime>{};
  bool _notifierDisposed = false;
  int _epoch = 0;
  int? _generation;
  Object? _marker;

  AccountSyncHostStatus get status => _closing != null
      ? AccountSyncHostStatus.stopped
      : host?.status ?? (_failed ? AccountSyncHostStatus.error : AccountSyncHostStatus.unknown);

  AccountSyncHost? get host {
    if (_closing != null) return null;
    final value = _host;
    return value?.status == AccountSyncHostStatus.stopped ? null : value;
  }

  void _changed() {
    if (_closing == null) notifyListeners();
  }

  void _reconcile() {
    if (_closing != null) return;
    final ready = coordinator.isReady;
    final marker = coordinator.identity.capture()?.marker;
    final generation = coordinator.generation;
    if (ready && _generation == generation && identical(_marker, marker)) {
      return;
    }
    final epoch = ++_epoch;
    _failed = false;
    _generation = ready ? generation : null;
    _marker = ready ? marker : null;
    final old = _host;
    final lifetime = _lifetime;
    _lifetime = null;
    _host = null;
    old?.removeListener(_changed);
    final drain = old
        ?.dispose(); // synchronous revocation before async replacement
    _replacement = _replacement.then((_) async {
      await _drainHost(drain, lifetime);
      if (_closing != null || epoch != _epoch || !coordinator.isReady) return;
      final current = coordinator.identity.capture();
      if (coordinator.generation != generation ||
          !identical(current?.marker, marker)) {
        return;
      }
      final resources = _lifetime = SyncTransportLifetime._();
      final AccountSyncHost admitted;
      try {
        admitted = _host = createHost(resources);
      } catch (_) {
        // Synchronous construction has admitted no host work. No peer/platform
        // details escape this classification, and partial clients remain owned.
        resources._release();
        _lifetime = null;
        _failed = true;
        _changed();
        return;
      }
      admitted.addListener(_changed);
      final start = admitted
          .start(); // eager, never dependent on UI consumption
      if (_foreground) admitted.notifyForeground();
      _changed();
      await start;
    }).catchError((Object _) {
      // Failed replacement stays closed. Retired native clients are retained
      // until the root's confirmed coordinator barrier, never released early.
      if (_closing == null) { _failed = true; _changed(); }
    });
    _changed();
  }

  Future<void> _drainHost(
    Future<void>? drain,
    SyncTransportLifetime? lifetime,
  ) async {
    if (lifetime == null) return;
    _retired.add(lifetime);
    await drain;
    // Coordinator notifications are synchronous, before its transition future
    // is queued. This async continuation observes the complete queued barrier.
    // In particular local facade writes are not host-worker operations.
    await (_coordinatorDrain ?? coordinator.observeSession());
    lifetime._release();
    _retired.remove(lifetime);
  }

  void notifyForeground() {
    if (_closing != null) return;
    _foreground = true;
    host?.notifyForeground();
  }

  void notifyBackground() {
    _foreground = false;
    _host?.notifyBackground();
  }

  Future<void> get settled async {
    await _replacement;
    await host?.settled;
  }

  /// Synchronous admission revocation; complete future owns all drain work.
  /// Flutter dispose only initiates it, and cannot promise process-death waiting.
  Future<void> close() {
    if (_closing != null) return _closing!;
    final done = Completer<void>();
    _closing = done.future;
    ++_epoch;
    coordinator.removeListener(_reconcile);
    final old = _host;
    final lifetime = _lifetime;
    _lifetime = null;
    _host = null;
    old?.removeListener(_changed);
    final hostDrain = old?.dispose();
    final coordinatorDrain = _coordinatorDrain = coordinator.close();
    unawaited(() async {
      try {
        await Future.wait<void>([
          _replacement,
          _drainHost(hostDrain, lifetime),
          coordinatorDrain,
        ]);
        for (final retired in _retired) { retired._release(); }
        _retired.clear();
        coordinator.dispose();
        dispose();
        done.complete();
      } catch (error, stack) {
        // Keep ownership failure closed; do not pretend native close succeeded.
        done.completeError(error, stack);
      }
    }());
    return done.future;
  }

  @override
  void dispose() {
    unawaited(close().catchError((Object _) {}));
    if (!_notifierDisposed) {
      _notifierDisposed = true;
      super.dispose();
    }
  }
}

/// Host close revokes HTTP immediately; native client release belongs to the
/// root barrier so unrelated admitted local COMMIT/read work drains first.
final class SyncTransportLifetime {
  SyncTransportLifetime._();
  final _clients = <_DeferredHttpClient>[];
  HttpClient wrap(HttpClient client) {
    final wrapper = _DeferredHttpClient(client);
    _clients.add(wrapper);
    return wrapper;
  }

  void _release() {
    for (final client in _clients) {
      client.release();
    }
    _clients.clear();
  }
}

final class _DeferredHttpClient implements HttpClient {
  _DeferredHttpClient(this.inner);
  final HttpClient inner;
  bool _closed = false;
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    if (_closed) throw StateError('Sync HTTP stopped');
    return inner.postUrl(url);
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }

  void release() {
    _closed = true;
    inner.close(force: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
