import 'dart:ui';

import 'package:flutter_template/core/utils/app_formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  group('AppFormatters', () {
    setUpAll(() async {
      await initializeDateFormatting('en');
    });

    const locale = Locale('en');
    final value = DateTime(2026, 5, 13, 14, 45);

    test('formats dates and times with the provided locale', () {
      expect(AppFormatters.shortDate(value, locale), '5/13/2026');
      expect(AppFormatters.mediumDate(value, locale), 'May 13, 2026');
      expect(_normalizeSpaces(AppFormatters.time(value, locale)), '2:45 PM');
      expect(
        _normalizeSpaces(AppFormatters.dateTime(value, locale)),
        'May 13, 2026 2:45 PM',
      );
    });

    test('formats numbers with the provided locale', () {
      expect(AppFormatters.decimal(12345.67, locale), '12,345.67');
      expect(AppFormatters.compactNumber(1200, locale), '1.2K');
      expect(
        AppFormatters.currency(1234.5, locale, currencyCode: 'USD'),
        r'$1,234.50',
      );
      expect(AppFormatters.percent(0.42, locale), '42%');
    });
  });
}

String _normalizeSpaces(String value) {
  return value.replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ');
}
