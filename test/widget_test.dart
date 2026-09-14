// test/widget_test.dart
//
// Smoke test for the phase-01 placeholder screen.
// This file will be replaced with proper widget tests in phase 03.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kasaran/main.dart';

void main() {
  testWidgets('Placeholder screen renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const KasaranApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Kasaran — coming soon'), findsOneWidget);
  });
}
