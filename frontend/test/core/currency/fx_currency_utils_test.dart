import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';

void main() {
  group('fx_currency_utils', () {
    test('uses zero decimals for UGX', () {
      expect(decimalDigitsForCurrency('ugx'), 0);
      expect(roundConvertedAmount(1234.56, 'UGX'), 1235);
      expect(formatConvertedAmount(1234.56, 'UGX'), '1235');
    });

    test('uses two decimals for USD', () {
      expect(decimalDigitsForCurrency('USD'), 2);
      expect(roundConvertedAmount(12.345, 'USD'), 12.35);
      expect(formatConvertedAmount(12.3, 'USD'), '12.30');
    });
  });
}
