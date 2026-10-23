import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kasaran/ui/local_store_gate.dart';

void main() {
  testWidgets('no-passcode warning appears once before the app continues', (
    tester,
  ) async {
    var acknowledgements = 0;
    await tester.pumpWidget(
      LocalStoreGate(
        prepare: () async => true,
        markWarningShown: () async => acknowledgements++,
        child: const MaterialApp(home: Scaffold(body: Text('sign in'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('device lock'), findsOneWidget);
    expect(find.text('sign in'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(find.textContaining('device lock'), findsNothing);
    expect(acknowledgements, 1);
  });

  testWidgets('database failure blocks the app instead of opening plaintext', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalStoreGate(
        prepare: () async => throw StateError('protection unavailable'),
        markWarningShown: () async {},
        child: const MaterialApp(home: Scaffold(body: Text('sign in'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sign in'), findsNothing);
    expect(find.textContaining('secure local store'), findsOneWidget);
  });
}
