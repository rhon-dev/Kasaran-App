import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasaran/main.dart' as application;
import 'package:kasaran/platform/db/local_store_bootstrap.dart';
import 'package:kasaran/ui/local_store_gate.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app startup gates the router behind the encrypted store', (
    tester,
  ) async {
    application.main();
    await tester.pumpAndSettle();
    expect(find.byType(LocalStoreGate), findsOneWidget);
    expect(find.byType(MaterialApp), findsWidgets);
    expect(find.text('Sign In / Sign Up'), findsOneWidget);
    expect(find.textContaining('secure local store'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlocked emulator warns only once across app restart', (
    tester,
  ) async {
    expect(
      await PlatformLocalDeviceSecurity().hasDeviceLock(),
      isFalse,
      reason: 'This test requires an emulator without a configured passcode',
    );
    application.main();
    await tester.pumpAndSettle();
    expect(find.textContaining('device lock'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(find.textContaining('device lock'), findsNothing);
    application.main();
    await tester.pumpAndSettle();
    expect(find.textContaining('device lock'), findsNothing);
    expect(find.text('Sign In / Sign Up'), findsOneWidget);
  });
}
