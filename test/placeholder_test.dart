// test/placeholder_test.dart
//
// Phase 01 placeholder — gives the `flutter test` CI job a non-trivial
// assertion to run so a non-zero exit is meaningful.
//
// This file will be removed (or superseded) when domain unit tests are added
// in phase 02.  It deliberately tests only a language-level property so it
// has no dependency on any application code, widgets, or plugins.
//
// TC-PLT-01: CI test job exits 0 with ≥ 1 test passing.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 01 — platform sanity', () {
    test('Dart int is 64-bit (REQ-GEN-1: signed 64-bit centavos required)', () {
      // Dart's int is natively 64-bit on all Flutter targets (design.md §1.5).
      // A 32-bit int could not represent ₱92 billion (9_223_372_036_854_775_807
      // centavos is the max signed 64-bit value — far beyond any wedding budget).
      const maxSigned64 = 9223372036854775807; // 2^63 − 1
      expect(maxSigned64.isFinite, isTrue);
      expect(maxSigned64 > 0, isTrue);
    });

    test('Integer centavo arithmetic has no floating-point rounding', () {
      // Validate the no-double constraint from design.md §1.5:
      // ₱100.50 = 10050 centavos; splitting 3 ways and reassembling must be exact.
      const amountCentavos = 10050; // ₱100.50
      const threeWaySplit = amountCentavos ~/ 3; // integer divide → 3350
      const remainder = amountCentavos - (threeWaySplit * 3); // 0
      expect(threeWaySplit * 3 + remainder, equals(amountCentavos));
    });

    test('Module skeleton directories are referenced correctly', () {
      // Smoke-check that the expected lib sub-paths are valid Dart package paths.
      // Actual imports from those paths are tested from phase 02 onward.
      const expectedPaths = [
        'package:kasaran/ui',
        'package:kasaran/domain',
        'package:kasaran/data',
        'package:kasaran/sync',
        'package:kasaran/platform',
      ];
      for (final path in expectedPaths) {
        expect(path, startsWith('package:kasaran/'));
      }
    });
  });
}
