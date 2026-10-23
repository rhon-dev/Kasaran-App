import 'package:flutter/material.dart';

/// Await Auth initialization and device protection without opening a financial
/// database. Signed-out/unverified routes can mount independently of any key.
class LocalStoreGate extends StatefulWidget {
  const LocalStoreGate({
    required this.prepare,
    required this.markWarningShown,
    required this.child,
    super.key,
  });

  final Future<bool> Function() prepare;
  final Future<void> Function() markWarningShown;
  final Widget child;

  @override
  State<LocalStoreGate> createState() => _LocalStoreGateState();
}

class _LocalStoreGateState extends State<LocalStoreGate> {
  late final Future<bool> _opening = widget.prepare();
  bool _dismissed = false;

  Future<void> _acknowledge() async {
    await widget.markWarningShown();
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
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
      final warningNeeded = snapshot.requireData;
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              widget.child,
              if (warningNeeded && !_dismissed)
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
