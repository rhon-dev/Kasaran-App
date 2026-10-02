/// Money formatting: the single chokepoint where centavo [int] values
/// become display [String]s.
///
/// REQ-GEN-2  — full form: peso sign, comma thousands separators, exactly
///               two decimals, half-up rounding away from zero, leading
///               minus inside the format (e.g. `−₱1,200.00`).
/// REQ-GEN-2A — constrained bento form: drop centavos below ₱1 000 000;
///               two-decimal millions shorthand at or above (e.g. `₱1.25M`);
///               truncate toward zero so a tile never overstates.
///              cl. 6: accessibility label is always the full form.
///
/// **No [double] appears here.** All arithmetic stays in [int] centavos;
/// millions shorthand uses integer division to truncate toward zero.

library;

// The peso sign character (U+20B1) and the Unicode minus sign (U+2212).
// Both are intentional: the Unicode minus is visually distinct and matches
// the REQ-GEN-2 specification ("leading minus inside the format").
const String _pesoSign = '₱';
const String _minus = '−'; // U+2212, not ASCII hyphen

/// The centavo threshold at which the constrained bento form switches to the
/// millions shorthand: ₱1 000 000.00 = 100 000 000 centavos.
const int _millionCentavos = 100000000; // 1 000 000 × 100

/// Formats [centavos] as the **full peso form**.
///
/// Rules (REQ-GEN-2):
/// - Always uses `₱` prefix.
/// - Comma thousands separators on the peso integer part.
/// - Exactly two decimal digits.
/// - Half-up rounding away from zero (applied on the centavo integer; no
///   sub-centavo value exists here because the input is already centavos).
/// - Negative values rendered as `−₱1,200.00` (Unicode minus, then sign,
///   then digits) — not `₱−1,200.00`.
///
/// Examples:
/// ```
/// fullForm(35000000)  → '₱350,000.00'
/// fullForm(0)         → '₱0.00'
/// fullForm(-120000)   → '−₱1,200.00'
/// ```
String fullForm(int centavos) {
  final isNeg = centavos < 0;
  final abs = centavos < 0 ? -centavos : centavos;

  final pesoInt = abs ~/ 100;
  final cents = abs % 100;

  final pesoStr = _addThousandsSeparators(pesoInt);
  final centStr = cents.toString().padLeft(2, '0');

  final formatted = '$_pesoSign$pesoStr.$centStr';
  return isNeg ? '$_minus$formatted' : formatted;
}

/// Formats [centavos] as the **constrained bento form** (REQ-GEN-2A).
///
/// Rules:
/// - Below ₱1 000 000: drop centavos, show only the peso integer with
///   comma separators (e.g. `₱350,999`).
/// - At or above ₱1 000 000: millions shorthand with two decimal digits,
///   truncated toward zero so the displayed figure never overstates
///   (e.g. `₱1.25M` for ₱1 259 000.00, not ₱1.3M).
/// - Negative: leading `−` prefix, then `₱`, then digits
///   (e.g. `−₱1,200`).
///
/// This form is for compact bento tiles only. **Never use it in a ledger
/// row, editor field, or accessibility label** — those always use [fullForm].
///
/// Examples:
/// ```
/// constrainedForm(35000000)   → '₱350,000'
/// constrainedForm(125900000)  → '₱1.25M'  (truncated toward zero)
/// constrainedForm(-120000)    → '−₱1,200'
/// ```
String constrainedForm(int centavos) {
  final isNeg = centavos < 0;
  final abs = centavos < 0 ? -centavos : centavos;

  final String digits;

  if (abs >= _millionCentavos) {
    // 0.01M = 1,000,000 centavos. Truncate before splitting the digits.
    final hundredthsOfMillion = abs ~/ 1000000;
    final wholePart = hundredthsOfMillion ~/ 100;
    final fracPart = hundredthsOfMillion % 100;
    digits = '$wholePart.${fracPart.toString().padLeft(2, '0')}M';
  } else {
    // Below ₱1M: drop centavos, show peso integer with separators.
    final pesoInt = abs ~/ 100;
    digits = _addThousandsSeparators(pesoInt);
  }

  final formatted = '$_pesoSign$digits';
  return isNeg ? '$_minus$formatted' : formatted;
}

/// Returns the **accessibility-label form** for [centavos].
///
/// REQ-GEN-2A clause 6: the a11y label is always the full form, never the
/// constrained form. Screen readers must announce the exact value.
///
/// This is a thin wrapper over [fullForm] but named explicitly so call sites
/// cannot accidentally swap the two forms.
String accessibilityLabel(int centavos) => fullForm(centavos);

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Inserts comma thousands separators into a non-negative integer string.
///
/// Example: `_addThousandsSeparators(1234567)` → `'1,234,567'`
String _addThousandsSeparators(int value) {
  assert(value >= 0, '_addThousandsSeparators expects a non-negative value');
  final raw = value.toString();
  final buffer = StringBuffer();
  final offset = raw.length % 3;

  for (var i = 0; i < raw.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(raw[i]);
  }
  return buffer.toString();
}
