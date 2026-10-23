import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kasaran/sync/queue/sync_runtime_owner.dart';

/// Single root binding, outside the keyed navigator. Never opens a database.
class SyncRuntimeGate extends StatefulWidget {
  const SyncRuntimeGate({required this.owner, required this.child, super.key});
  final SyncRuntimeOwner? owner;
  final Widget child;
  @override
  State<SyncRuntimeGate> createState() => _SyncRuntimeGateState();
}

class _SyncRuntimeGateState extends State<SyncRuntimeGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply(WidgetsBinding.instance.lifecycleState);
  }

  void _apply(AppLifecycleState? state) {
    if (state == AppLifecycleState.resumed) {
      widget.owner?.notifyForeground();
    } else {
      // Unknown startup lifecycle is not permission for foreground polling.
      widget.owner?.notifyBackground();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _apply(state);

  @override
  void didUpdateWidget(covariant SyncRuntimeGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.owner, widget.owner)) {
      unawaited(oldWidget.owner?.close().catchError((Object _) {}));
      _apply(WidgetsBinding.instance.lifecycleState);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.owner?.close().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
