import 'package:flutter/widgets.dart';

/// A password rule the API enforces wherever a password is chosen.
enum AppPasswordRule { minLength, uppercase, lowercase, number, symbol }

/// Password policy shared with `backend/src/lib/validation/password-policy.js`.
///
/// Rules are checked in the order the API reports them, so the first message a
/// user sees here matches the first field-level error the server would return.
/// Change both files together.
abstract final class AppPasswordPolicy {
  static const int minLength = 8;

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _number = RegExp(r'[0-9]');
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9]');

  /// The first rule [password] breaks after trimming, or null when it passes.
  static AppPasswordRule? firstViolation(String password) {
    final String value = password.trim();
    if (value.length < minLength) {
      return AppPasswordRule.minLength;
    }
    if (!_uppercase.hasMatch(value)) {
      return AppPasswordRule.uppercase;
    }
    if (!_lowercase.hasMatch(value)) {
      return AppPasswordRule.lowercase;
    }
    if (!_number.hasMatch(value)) {
      return AppPasswordRule.number;
    }
    if (!_symbol.hasMatch(value)) {
      return AppPasswordRule.symbol;
    }
    return null;
  }

  /// Validator requiring a password that satisfies every rule.
  static FormFieldValidator<String> validator({
    required String requiredMessage,
    required String Function(AppPasswordRule rule) messageFor,
  }) {
    return (String? value) {
      final String normalized = (value ?? '').trim();
      if (normalized.isEmpty) {
        return requiredMessage;
      }
      final AppPasswordRule? violation = firstViolation(normalized);
      return violation == null ? null : messageFor(violation);
    };
  }
}
