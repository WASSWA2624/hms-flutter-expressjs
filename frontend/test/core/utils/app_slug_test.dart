import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/utils/app_slug.dart';

void main() {
  group('slugify', () {
    test('converts names to lowercase hyphenated slugs', () {
      expect(slugify('DemoCare General Hospital'), 'democare-general-hospital');
    });

    test('trims punctuation and repeated separators', () {
      expect(slugify('  Acme -- Health!!! '), 'acme-health');
    });

    test('returns empty string for punctuation-only input', () {
      expect(slugify('!!!'), '');
    });
  });
}
