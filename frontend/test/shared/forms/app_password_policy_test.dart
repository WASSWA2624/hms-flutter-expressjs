import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/forms/app_password_policy.dart';

void main() {
  group('AppPasswordPolicy', () {
    test('accepts a password that meets every rule', () {
      expect(AppPasswordPolicy.firstViolation('StrongPass123!'), isNull);
    });

    test('reports rules in the same order as the API', () {
      expect(
        AppPasswordPolicy.firstViolation('  Ab1!  '),
        AppPasswordRule.minLength,
        reason: 'Surrounding whitespace is trimmed before length is checked',
      );
      expect(
        AppPasswordPolicy.firstViolation('strongpass123!'),
        AppPasswordRule.uppercase,
      );
      expect(
        AppPasswordPolicy.firstViolation('STRONGPASS123!'),
        AppPasswordRule.lowercase,
      );
      expect(
        AppPasswordPolicy.firstViolation('StrongPass!'),
        AppPasswordRule.number,
      );
      expect(
        AppPasswordPolicy.firstViolation('StrongPass123'),
        AppPasswordRule.symbol,
      );
    });

    test('validator requires a value and maps violations to messages', () {
      final validator = AppPasswordPolicy.validator(
        requiredMessage: 'required',
        messageFor: (AppPasswordRule rule) => rule.name,
      );

      expect(validator(null), 'required');
      expect(validator('   '), 'required');
      expect(validator('strongpass123!'), 'uppercase');
      expect(validator('StrongPass123!'), isNull);
    });
  });
}
