import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/utils/person_display_name.dart';

void main() {
  group('resolvePersonDisplayName', () {
    test('prefers profile names over email', () {
      expect(
        resolvePersonDisplayName(
          firstName: 'Wasswa',
          lastName: 'Wilson',
          email: 'wasswawilson0001@gmail.com',
        ),
        'Wasswa Wilson',
      );
    });

    test('humanizes email local part before full email', () {
      expect(
        resolvePersonDisplayName(email: 'wasswawilson0001@gmail.com'),
        'Wasswawilson0001',
      );
    });
  });

  group('personInitials', () {
    test('returns two initials for multi-word names', () {
      expect(personInitials('Wasswa Wilson'), 'WW');
    });
  });
}
