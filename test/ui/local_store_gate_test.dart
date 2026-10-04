import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/ui/local_store_gate.dart';

void main() {
  testWidgets('no-passcode warning appears once before the app continues', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    var acknowledgements = 0;
    await tester.pumpWidget(
      LocalStoreGate(
        open: () async => LocalStoreResult(db, warningNeeded: true),
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
        open: () async => throw StateError('no key'),
        markWarningShown: () async {},
        child: const MaterialApp(home: Scaffold(body: Text('sign in'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sign in'), findsNothing);
    expect(find.textContaining('secure local store'), findsOneWidget);
  });
}
