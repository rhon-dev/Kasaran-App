import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/ui/validation/setup_budget_date.dart';

void main() {
  test(
    'budget accepts ordinary peso amounts, commas, and third-digit rounding',
    () {
      expect(parseBudgetInput('₱28,000.00'), 2800000);
      expect(parseBudgetInput('500001'), 50000100);
      expect(parseBudgetInput('0.005'), 1);
      expect(parseBudgetInput('1.995'), 200);
    },
  );

  test(
    'budget rejects nonnumeric, malformed, zero, negative, and excess precision',
    () {
      for (final value in ['abc', '1,20.00', '1.0009', '', '₱ 1,2']) {
        expect(() => parseBudgetInput(value), throwsFormatException);
      }
      expect(
        () => parseBudgetInput('0'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'reason',
            contains('greater than zero'),
          ),
        ),
      );
      expect(
        () => parseBudgetInput('-5000'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'reason',
            contains('negative'),
          ),
        ),
      );
      expect(
        () => parseBudgetInput('92233720368547759'),
        throwsFormatException,
      );
    },
  );

  test(
    'wedding date accepts valid leap day and rejects invalid calendar dates',
    () {
      expect(parseWeddingDate('2028-02-29').day, 29);
      for (final value in [
        '2027-02-29',
        '2027-13-01',
        '2027-01-32',
        'not a date',
        '',
        '0000-01-01',
      ]) {
        expect(() => parseWeddingDate(value), throwsFormatException);
      }
    },
  );

  test('past date compares only the local calendar day', () {
    expect(
      isPastWeddingDate(parseWeddingDate('2027-01-01'), DateTime(2027, 1, 2)),
      isTrue,
    );
    expect(
      isPastWeddingDate(
        parseWeddingDate('2027-01-02'),
        DateTime(2027, 1, 2, 23),
      ),
      isFalse,
    );
  });
}
