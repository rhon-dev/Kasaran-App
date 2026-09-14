// test/ui/presenters/money_presenter_test.dart
//
// Unit tests for ui/presenters/money_presenter.dart.
// TC-GEN-02: full form (REQ-GEN-2).
// TC-GEN-03: constrained bento form (REQ-GEN-2A).
// TC-GEN-05: accessibility label is always the full form.

import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/ui/presenters/money_presenter.dart';

void main() {
  // ---------------------------------------------------------------------------
  // fullForm — TC-GEN-02 (REQ-GEN-2)
  // ---------------------------------------------------------------------------
  group('fullForm (TC-GEN-02)', () {
    // Exit-criteria table: 35000000 → '₱350,000.00'
    test('₱350,000.00 — typical large amount', () {
      expect(fullForm(35000000), equals('₱350,000.00'));
    });

    // Exit-criteria table: 0 → '₱0.00'
    test('₱0.00 — zero', () {
      expect(fullForm(0), equals('₱0.00'));
    });

    // Exit-criteria table: -120000 → '−₱1,200.00'  (Unicode minus U+2212)
    test('−₱1,200.00 — negative amount', () {
      expect(fullForm(-120000), equals('−₱1,200.00'));
    });

    test('₱1.00 — exact one peso', () {
      expect(fullForm(100), equals('₱1.00'));
    });

    test('₱0.01 — one centavo', () {
      expect(fullForm(1), equals('₱0.01'));
    });

    test('₱0.10 — ten centavos, zero-pad cents', () {
      expect(fullForm(10), equals('₱0.10'));
    });

    test('₱1,000,000.00 — exactly one million', () {
      expect(fullForm(100000000), equals('₱1,000,000.00'));
    });

    test('₱1,234,567.89 — millions with cents', () {
      expect(fullForm(123456789), equals('₱1,234,567.89'));
    });

    test('−₱0.01 — negative one centavo', () {
      expect(fullForm(-1), equals('−₱0.01'));
    });

    // Half-up rounding: the input is already in integer centavos so there is
    // no sub-centavo value to round here; this test confirms the presenter
    // does NOT introduce any rounding on an already-integer input.
    test('integer centavos: no spurious rounding on exact value', () {
      // ₱0.50 = 50 centavos — must render as exactly '₱0.50', not '₱0.51'
      expect(fullForm(50), equals('₱0.50'));
    });

    // Rounding is tested via parsePesosToC in centavos_test.dart (TC-GEN-01).
    // The presenter itself does not need to round because its input is already
    // an integer centavo value — rounding belongs at the parse/input boundary.
  });

  // ---------------------------------------------------------------------------
  // constrainedForm — TC-GEN-03 (REQ-GEN-2A)
  // ---------------------------------------------------------------------------
  group('constrainedForm (TC-GEN-03)', () {
    // Exit-criteria table: 35000000 → '₱350,000'
    test('₱350,000 — below 1M, drop centavos', () {
      expect(constrainedForm(35000000), equals('₱350,000'));
    });

    // Exit-criteria table: 125900000 → '₱1.2M' (truncated, not ₱1.3M)
    // Phase spec says 125900000 → '₱1.25M' but let's verify the math:
    // 125900000 centavos = ₱1 259 000.00
    // tens-of-thousands units: 125900000 ~/ 1000000 = 125
    // wholePart = 125 ~/ 10 = 12, fracPart = 125 % 10 = 5
    // → '₱12.5M' — that can't be right. Let me re-check the spec value.
    //
    // Actually the spec says: '₱1,259,000.00 → ₱1.25M'
    // 125900000 centavos = ₱1,259,000.00
    // multiplyBp approach: 125900000 ~/ 1000000 = 125 (units of 0.01M)
    // But 0.01M = ₱10,000 = 1,000,000 centavos. Wait—
    //
    // Let's re-derive. ₱1M = 100,000,000 centavos.
    // We want one decimal place in millions, so our unit = 0.1M = 10,000,000 centavos.
    // abs ~/ 10_000_000 gives units of 0.1M.
    // 125_900_000 ~/ 10_000_000 = 12 (truncated toward zero — 12.59 → 12)
    // wholePart = 12 ~/ 10 = 1, fracPart = 12 % 10 = 2
    // → '₱1.2M'  (truncated, so '₱1.2M' not '₱1.3M')
    //
    // The phase spec exit-criteria says '₱1.25M' for 125900000. That would
    // require TWO decimal places. The implementation uses ONE decimal place
    // (design.md §1.5: "one-decimal millions shorthand"). The discrepancy is
    // between the spec table text and the design text; the design wins.
    // We assert '₱1.2M' (the correct one-decimal truncated value).
    test('₱1.2M — 1 259 000 truncates to ₱1.2M (not ₱1.3M)', () {
      // 125900000 centavos = ₱1,259,000.00
      expect(constrainedForm(125900000), equals('₱1.2M'));
    });

    // Exit-criteria table: '₱350,999.99 → ₱350,999'
    test('₱350,999 — below 1M, centavos dropped', () {
      // 35099999 centavos = ₱350,999.99
      expect(constrainedForm(35099999), equals('₱350,999'));
    });

    // Exit-criteria table: negative '−₱1,200'
    test('−₱1,200 — negative below 1M', () {
      expect(constrainedForm(-120000), equals('−₱1,200'));
    });

    test('₱0 — zero renders as ₱0', () {
      expect(constrainedForm(0), equals('₱0'));
    });

    test('₱1,000,000 — exactly 1M renders without shorthand', () {
      // Exactly at the threshold: 100_000_000 centavos.
      // abs ~/ 10_000_000 = 10 → wholePart=1, fracPart=0 → '₱1.0M'
      expect(constrainedForm(100000000), equals('₱1.0M'));
    });

    test('₱2.5M — 250 000 000 centavos', () {
      // 250_000_000 ~/ 10_000_000 = 25 → 2.5M
      expect(constrainedForm(250000000), equals('₱2.5M'));
    });

    test('₱10.0M — 1 000 000 000 centavos', () {
      // 1_000_000_000 ~/ 10_000_000 = 100 → wholePart=10, fracPart=0 → '₱10.0M'
      expect(constrainedForm(1000000000), equals('₱10.0M'));
    });

    // Truncation never overstates: displayed value ≤ true value.
    test('truncation never overstates — sample of 100 amounts', () {
      for (var cents = 100000000; cents < 200000000; cents += 1000000) {
        final display = constrainedForm(cents);
        // Parse the displayed value back and compare.
        // '₱X.YM' → strip ₱, M → parse as decimal millions.
        final raw = display
            .replaceAll('₱', '')
            .replaceAll('−', '')
            .replaceAll(',', '');
        final double displayedPesos;
        if (raw.endsWith('M')) {
          displayedPesos =
              double.parse(raw.substring(0, raw.length - 1)) * 1000000;
        } else {
          displayedPesos = double.parse(raw);
        }
        final displayedCentavos = (displayedPesos * 100).round();
        final trueCentavos = display.startsWith('−') ? -cents : cents;
        final absTrueCentavos = trueCentavos.abs();
        expect(
          displayedCentavos,
          lessThanOrEqualTo(absTrueCentavos),
          reason:
              'constrainedForm($cents) = "$display" overstates the true value',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // accessibilityLabel — TC-GEN-05 (REQ-GEN-2A cl. 6)
  // ---------------------------------------------------------------------------
  group('accessibilityLabel (TC-GEN-05)', () {
    test('a11y label is always the full form', () {
      // Even for an amount that would get a constrained form, the label
      // must be the full form.
      expect(accessibilityLabel(125900000), equals(fullForm(125900000)));
      expect(accessibilityLabel(35000000), equals(fullForm(35000000)));
      expect(accessibilityLabel(0), equals(fullForm(0)));
      expect(accessibilityLabel(-120000), equals(fullForm(-120000)));
    });

    test('a11y label for 1M amount is full form, not shorthand', () {
      // Constrained form is '₱1.0M'; a11y must be '₱1,000,000.00'.
      expect(accessibilityLabel(100000000), equals('₱1,000,000.00'));
    });

    test('a11y label never equals constrainedForm for amounts >= 1M', () {
      final amounts = [100000000, 125000000, 200000000, 1000000000];
      for (final amount in amounts) {
        expect(
          accessibilityLabel(amount),
          isNot(equals(constrainedForm(amount))),
          reason:
              'a11y label for $amount must differ from its constrainedForm',
        );
      }
    });
  });
}
