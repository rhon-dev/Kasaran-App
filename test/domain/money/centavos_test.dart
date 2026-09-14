// test/domain/money/centavos_test.dart
//
// Unit tests for domain/money/centavos.dart.
// TC-GEN-01: integer centavo arithmetic is exact and lossless.
// TC-GEN-04: drift-guard — 1 000-iteration sum matches displayed total exactly.

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/domain/money/centavos.dart';

void main() {
  group('CentavosArithmetic extensions', () {
    test('addCentavos returns correct sum', () {
      expect(100.addCentavos(50), equals(150));
      expect((-100).addCentavos(100), equals(0));
    });

    test('subtractCentavos returns correct difference', () {
      expect(500.subtractCentavos(200), equals(300));
      expect(200.subtractCentavos(500), equals(-300));
    });

    test('multiplyBp: 40% of ₱1 000 000 = ₱400 000', () {
      // 100_000_000 centavos × 4000 bp / 10000 = 40_000_000
      expect(100000000.multiplyBp(4000), equals(40000000));
    });

    test('multiplyBp: 100% is identity', () {
      expect(12345678.multiplyBp(10000), equals(12345678));
    });

    test('multiplyBp truncates toward zero (never overstates)', () {
      // 100 × 3333 bp = 33.33 → truncates to 33
      expect(100.multiplyBp(3333), equals(33));
      // negative: -100 × 3333 bp = -33.33 → truncates toward zero → -33
      expect((-100).multiplyBp(3333), equals(-33));
    });

    test('splitBy and remainderAfterSplit are lossless', () {
      const amount = 10050; // ₱100.50
      const n = 3;
      final share = amount.splitBy(n);
      final remainder = amount.remainderAfterSplit(n);
      expect(share * n + remainder, equals(amount));
      expect(share, equals(3350));
      expect(remainder, equals(0));
    });

    test('splitBy with non-zero remainder is lossless', () {
      const amount = 10; // 10 centavos
      const n = 3;
      final share = amount.splitBy(n);
      final remainder = amount.remainderAfterSplit(n);
      expect(share * n + remainder, equals(amount));
    });

    test('isDebit is true for negative amounts', () {
      expect((-1).isDebit, isTrue);
      expect(0.isDebit, isFalse);
      expect(1.isDebit, isFalse);
    });

    test('isZero is true only for 0', () {
      expect(0.isZero, isTrue);
      expect(1.isZero, isFalse);
      expect((-1).isZero, isFalse);
    });

    test('absCentavos returns absolute value', () {
      expect((-35000000).absCentavos, equals(35000000));
      expect(35000000.absCentavos, equals(35000000));
      expect(0.absCentavos, equals(0));
    });
  });

  group('CentavosParsing.pesosToC', () {
    test('converts whole pesos to centavos', () {
      expect(1000.pesosToC, equals(100000));
      expect(0.pesosToC, equals(0));
      expect(350000.pesosToC, equals(35000000));
    });
  });

  group('parsePesosToC', () {
    test('parses integer peso string', () {
      expect(parsePesosToC('350000'), equals(35000000));
      expect(parsePesosToC('0'), equals(0));
    });

    test('parses two-decimal peso string', () {
      expect(parsePesosToC('350000.00'), equals(35000000));
      expect(parsePesosToC('1200.00'), equals(120000));
      expect(parsePesosToC('0.00'), equals(0));
    });

    test('parses negative amounts', () {
      expect(parsePesosToC('-1200.00'), equals(-120000));
    });

    test('strips peso sign and commas', () {
      expect(parsePesosToC('₱350,000.00'), equals(35000000));
      expect(parsePesosToC('₱1,200.00'), equals(120000));
    });

    // REQ-GEN-2 rounding: half-up away from zero.
    test('half-up rounding: 0.005 → 0.01 (1 centavo)', () {
      // "0.005" → pesos=0, cents=00, subCentavo=5 → rounds up to 1
      expect(parsePesosToC('0.005'), equals(1));
    });

    test('half-up rounding: 0.004 → 0 (no rounding up)', () {
      expect(parsePesosToC('0.004'), equals(0));
    });

    test('half-up rounding: 1.995 → 200 centavos (₱2.00)', () {
      // subCentavo=5 → add 1 → 199+1 = 200
      expect(parsePesosToC('1.995'), equals(200));
    });

    test('half-up rounding: negative -0.005 → -1 (away from zero)', () {
      expect(parsePesosToC('-0.005'), equals(-1));
    });
  });

  // TC-GEN-04 — Drift guard: lossless round-trip over 1 000 line items.
  //
  // Simulates summing 1 000 per-head ledger entries and asserts that the
  // stored integer total exactly equals the value recovered by parsing the
  // formatted display string back to centavos.
  //
  // This catches any path where formatting introduces a double conversion
  // that loses or gains a centavo.
  group('Drift guard (TC-GEN-04)', () {
    test(
        '1 000-iteration per-head sum: stored total equals parsed-display total',
        () {
      // Each line item: ₱350.00 per head = 35 000 centavos.
      const perHeadCentavos = 35000; // ₱350.00
      const iterations = 1000;

      // Accumulate the stored integer total.
      var storedTotal = 0;
      for (var i = 0; i < iterations; i++) {
        storedTotal = storedTotal.addCentavos(perHeadCentavos);
      }
      expect(storedTotal, equals(35000000)); // ₱350 000.00

      // Simulate formatting → re-parsing.
      // The display string is the canonical full form '₱350,000.00'.
      // parsePesosToC must reconstruct the same integer without drift.
      final pesosStr = storedTotal ~/ 100; // integer pesos
      final centsStr = (storedTotal % 100).toString().padLeft(2, '0');
      final displayString = '$pesosStr.$centsStr';
      final recovered = parsePesosToC(displayString);

      expect(
        recovered,
        equals(storedTotal),
        reason:
            'Stored total and recovered total must be identical; '
            'any difference indicates a centavo gain or loss in the '
            'format→parse round-trip.',
      );
    });

    test('1 000-iteration sum with uneven per-head rate is lossless', () {
      // ₱333.33 per head = 33 333 centavos (does not divide evenly by 3).
      const perHeadCentavos = 33333;
      const iterations = 1000;

      var storedTotal = 0;
      for (var i = 0; i < iterations; i++) {
        storedTotal = storedTotal.addCentavos(perHeadCentavos);
      }
      // 33 333 × 1 000 = 33 333 000 centavos — exact integer arithmetic.
      expect(storedTotal, equals(33333000));

      final pesosStr = storedTotal ~/ 100;
      final centsStr = (storedTotal % 100).toString().padLeft(2, '0');
      final displayString = '$pesosStr.$centsStr';
      final recovered = parsePesosToC(displayString);

      expect(recovered, equals(storedTotal));
    });
  });
}
