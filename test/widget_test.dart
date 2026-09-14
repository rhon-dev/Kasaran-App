// test/widget_test.dart
//
// Smoke test: the app boots without crashing inside a ProviderScope.
// Phase 03 onwards the app is a go_router app; we just verify it renders
// the MaterialApp without error. Detailed screen tests live in
// test/ui/router/ and test/ui/golden/.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/main.dart';

void main() {
  testWidgets('App boots inside ProviderScope without crash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: KasaranApp()),
    );
    await tester.pumpAndSettle();
    // The stub auth provider returns unauthenticated, so the app lands on
    // SCR-01 (sign-in placeholder).
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
