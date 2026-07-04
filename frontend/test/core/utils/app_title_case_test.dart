import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/utils/app_title_case.dart';

void main() {
  group('toDialogTitleCase', () {
    test('converts all-caps words to title case', () {
      expect(toDialogTitleCase('LAB RESULT ENTRY'), 'Lab Result Entry');
      expect(toDialogTitleCase('CONFIRM ACTION'), 'Confirm Action');
    });

    test('preserves already title-cased text', () {
      expect(toDialogTitleCase('Lab Result Entry'), 'Lab Result Entry');
      expect(toDialogTitleCase('Edit record'), 'Edit Record');
    });

    test('preserves identifiers containing digits', () {
      expect(
        toDialogTitleCase('Order LAB0000006 Details'),
        'Order LAB0000006 Details',
      );
    });

    test('preserves mixed-case tokens', () {
      expect(toDialogTitleCase('iPhone Settings'), 'iPhone Settings');
    });
  });
}
