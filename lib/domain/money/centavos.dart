/// Integer-centavo arithmetic and parsing helpers.
///
/// REQ-GEN-1: money is represented as signed 64-bit integer centavos throughout.
/// Dart's [int] is natively 64-bit on all Flutter targets (design.md §1.5),
/// so no wrapper type is needed. These are pure extension helpers.
///
/// **Rule:** no [double] or [num] may appear in any monetary computation.
/// All ratio arithmetic uses basis points (10 000 = 100%) so the intermediate
/// values remain [int] until the final truncating division.

library;

/// Basis-point constant: 10 000 bp = 100%.
/// Used for percentage and multiplier arithmetic without floating point.
const int bpBase = 10000;

/// Extensions on [int] for centavo arithmetic.
///
/// All methods operate on centavo values (₱1.00 = 100). Callers are
/// responsible for ensuring the receiver is in centavos; these helpers
/// do not track units.
extension CentavosArithmetic on int {
  /// Adds [other] centavos, returning the sum.
  ///
  /// Equivalent to plain `+`, provided for readable chaining.
  int addCentavos(int other) => this + other;

  /// Subtracts [other] centavos, returning the difference.
  int subtractCentavos(int other) => this - other;

  /// Multiplies this centavo amount by a basis-point multiplier.
  ///
  /// [basisPoints] — e.g. 10000 = 100% (identity), 5000 = 50%, 12000 = 120%.
  /// Truncates toward zero so money is never overstated (same policy as the
  /// constrained bento form in REQ-GEN-2A).
  ///
  /// Example: `₱1 000 000 × 40% = 40000_00 centavos`
  ///   `100000000.multiplyBp(4000)` → `40000000`
  int multiplyBp(int basisPoints) => this * basisPoints ~/ bpBase;

  /// Divides this centavo amount by [divisor], truncating toward zero.
  ///
  /// Used for per-head rate calculations and split arithmetic.
  /// Remainder is returned separately via [remainderAfterSplit] to prevent
  /// silent loss.
  int splitBy(int divisor) => this ~/ divisor;

  /// The centavo remainder after [splitBy].
  ///
  /// `amount == amount.splitBy(n) * n + amount.remainderAfterSplit(n)`
  /// holds for all non-zero [n], making the split lossless when the
  /// remainder is handled by the caller.
  int remainderAfterSplit(int divisor) => this % divisor;

  /// Whether this amount is negative (e.g. a credit or refund).
  bool get isDebit => this < 0;

  /// Whether this amount is zero.
  bool get isZero => this == 0;

  /// Absolute value in centavos.
  int get absCentavos => abs();
}

/// Parsing helpers: convert common representations to centavo [int].
extension CentavosParsing on int {
  /// Converts a whole-peso integer to centavos.
  ///
  /// Example: `1000.pesosToC` → `100000`
  int get pesosToC => this * 100;
}

/// Standalone parsing helpers (not extension methods so they work on literals).

/// Parses a decimal peso string to integer centavos using half-up rounding.
///
/// Accepts strings like `"350000.00"`, `"1.005"`, `"-1200.00"`.
/// The peso-sign prefix `"₱"` and thousands-separator commas are stripped
/// before parsing.
///
/// Throws [FormatException] if [pesoString] cannot be parsed.
///
/// Rounding rule: half-up away from zero (REQ-GEN-2 rounding requirement).
int parsePesosToC(String pesoString) {
  // Strip display-only characters.
  final cleaned = pesoString
      .replaceAll('₱', '')
      .replaceAll(',', '')
      .trim();

  final isNegative = cleaned.startsWith('-');
  final absolute = isNegative ? cleaned.substring(1) : cleaned;

  final dotIndex = absolute.indexOf('.');
  final int pesos;
  final int subCentavo; // third decimal digit, for rounding

  if (dotIndex == -1) {
    // Whole pesos, no cents — multiply by 100 to get centavos.
    pesos = int.parse(absolute) * 100;
    subCentavo = 0;
  } else {
    final intPart = absolute.substring(0, dotIndex);
    final fracPart = absolute.substring(dotIndex + 1);

    // Pad or truncate to exactly 3 decimal digits for rounding inspection.
    final padded = fracPart.padRight(3, '0').substring(0, 3);
    final centDigits = int.parse(padded.substring(0, 2));
    subCentavo = int.parse(padded[2]);

    pesos = (int.parse(intPart.isEmpty ? '0' : intPart)) * 100 + centDigits;
  }

  // Half-up rounding away from zero: if the sub-centavo digit ≥ 5, add 1.
  final rounded = pesos + (subCentavo >= 5 ? 1 : 0);
  return isNegative ? -rounded : rounded;
}
