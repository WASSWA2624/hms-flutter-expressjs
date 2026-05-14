import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

void main() {
  group('AppValidators', () {
    test('requiredText trims input by default', () {
      final validator = AppValidators.requiredText('Required');

      expect(validator('   '), 'Required');
      expect(validator(' name '), isNull);
    });

    test('email allows empty optional values and rejects invalid formats', () {
      final validator = AppValidators.email('Invalid email');

      expect(validator(''), isNull);
      expect(validator('person@example.com'), isNull);
      expect(validator('person.example.com'), 'Invalid email');
    });

    test('compose returns the first validation error', () {
      final validator =
          AppValidators.compose<String>(<String? Function(String?)>[
            AppValidators.requiredText('Required'),
            AppValidators.minLength(8, 'Too short'),
          ]);

      expect(validator(''), 'Required');
      expect(validator('abc'), 'Too short');
      expect(validator('abcdefgh'), isNull);
    });

    test('requiredTrue validates accepted confirmations', () {
      final validator = AppValidators.requiredTrue('Must accept');

      expect(validator(null), 'Must accept');
      expect(validator(false), 'Must accept');
      expect(validator(true), isNull);
    });
  });
}
