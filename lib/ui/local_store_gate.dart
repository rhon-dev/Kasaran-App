import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';

/// Fail-closed startup: the app router is never mounted if local encryption or
/// platform file protection cannot be established.
class LocalStoreGate extends StatefulWidget {
  const LocalStoreGate({
    required this.open,
    required this.markWarningShown,
    required this.child,
    super.key,
  });

  final Future<LocalStoreResult> Function() open;
  final Future<void> Function() markWarningShown;
  final Widget child;

  @override
  State<LocalStoreGate> createState() => _LocalStoreGateState();
}

class _LocalStoreGateState extends State<LocalStoreGate> {
  late final Future<LocalStoreResult> _opening = widget.open();
  AppDatabase? _db;
  bool _dismissed = false;

  @override
  void dispose() {
    if (_db != null) unawaited(_db!.close());
    super.dispose();
  }

  Future<void> _acknowledge() async {
    await widget.markWarningShown();
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LocalStoreResult>(
    future: _opening,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'The secure local store could not open. Your data was not reset. '
                'Unlock the device and try again.',
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      }
      final result = snapshot.requireData;
      _db ??= result.db;
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              widget.child,
              if (result.warningNeeded && !_dismissed)
                Positioned.fill(
                  child: Material(
                    color: Colors.black54,
                    child: Center(
                      child: AlertDialog(
                        title: const Text('Protect this device'),
                        content: const Text(
                          'Your device has no device lock. Set a passcode or '
                          'biometric lock to protect your financial data.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: _acknowledge,
                            child: const Text('I understand'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
