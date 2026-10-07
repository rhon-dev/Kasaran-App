import 'package:kasaran/domain/money/centavos.dart';

// Validate the entire input before calling the more permissive common parser.
final _money = RegExp(
  r'^(?:₱\s*)?-?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]{1,3})?$',
);
final _date = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$');
const _maxInt64 = 9223372036854775807;

int parseBudgetInput(String raw) {
  final value = raw.trim();
  if (value.isEmpty) throw const FormatException('Enter a total budget.');
  if (!_money.hasMatch(value)) {
    throw const FormatException('Total budget must be a valid peso amount.');
  }
  final cleaned = value.replaceAll('₱', '').replaceAll(',', '').trim();
  if (cleaned.startsWith('-')) {
    throw const FormatException('Total budget cannot be negative.');
  }
  final parts = cleaned.split('.');
  final fraction = (parts.length == 1 ? '' : parts[1]).padRight(3, '0');
  // Bound before invoking the int-only common parser: oversized input must
  // never overflow or silently wrap into a valid centavo amount.
  final magnitude =
      BigInt.parse(parts[0]) * BigInt.from(100) +
      BigInt.parse(fraction.substring(0, 2)) +
      (int.parse(fraction[2]) >= 5 ? BigInt.one : BigInt.zero);
  if (magnitude == BigInt.zero) {
    throw const FormatException('Total budget must be greater than zero.');
  }
  if (magnitude > BigInt.from(_maxInt64)) {
    throw const FormatException('Total budget is too large.');
  }
  return parsePesosToC(value);
}

DateTime parseWeddingDate(String raw) {
  final match = _date.firstMatch(raw.trim());
  if (match == null) {
    throw const FormatException('Enter a wedding date as YYYY-MM-DD.');
  }
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  if (year == 0) throw const FormatException('Enter a valid wedding date.');
  final value = DateTime.utc(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    throw const FormatException('Enter a valid wedding date.');
  }
  return value;
}

bool isPastWeddingDate(DateTime selected, DateTime today) => DateTime.utc(
  selected.year,
  selected.month,
  selected.day,
).isBefore(DateTime.utc(today.year, today.month, today.day));
