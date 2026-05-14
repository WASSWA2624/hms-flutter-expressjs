import 'package:flutter/widgets.dart';

typedef AppTextNormalizer = String Function(String value);

abstract final class AppValidators {
  static FormFieldValidator<String> requiredText(
    String message, {
    bool trim = true,
  }) {
    return (String? value) {
      final String normalized = _normalizeText(value, trim: trim);
      return normalized.isEmpty ? message : null;
    };
  }

  static FormFieldValidator<T> requiredValue<T>(String message) {
    return (T? value) {
      return value == null ? message : null;
    };
  }

  static FormFieldValidator<bool> requiredTrue(String message) {
    return (bool? value) {
      return value ?? false ? null : message;
    };
  }

  static FormFieldValidator<String> email(
    String message, {
    bool allowEmpty = true,
    bool trim = true,
  }) {
    return (String? value) {
      final String normalized = _normalizeText(value, trim: trim);
      if (allowEmpty && normalized.isEmpty) {
        return null;
      }

      return _emailPattern.hasMatch(normalized) ? null : message;
    };
  }

  static FormFieldValidator<String> minLength(
    int minLength,
    String message, {
    bool allowEmpty = true,
    bool trim = false,
  }) {
    assert(minLength >= 0, 'minLength must not be negative.');

    return (String? value) {
      final String normalized = _normalizeText(value, trim: trim);
      if (allowEmpty && normalized.isEmpty) {
        return null;
      }

      return normalized.length < minLength ? message : null;
    };
  }

  static FormFieldValidator<String> maxLength(
    int maxLength,
    String message, {
    bool allowEmpty = true,
    bool trim = false,
  }) {
    assert(maxLength >= 0, 'maxLength must not be negative.');

    return (String? value) {
      final String normalized = _normalizeText(value, trim: trim);
      if (allowEmpty && normalized.isEmpty) {
        return null;
      }

      return normalized.length > maxLength ? message : null;
    };
  }

  static FormFieldValidator<String> pattern(
    RegExp pattern,
    String message, {
    bool allowEmpty = true,
    bool trim = true,
  }) {
    return (String? value) {
      final String normalized = _normalizeText(value, trim: trim);
      if (allowEmpty && normalized.isEmpty) {
        return null;
      }

      return pattern.hasMatch(normalized) ? null : message;
    };
  }

  static FormFieldValidator<T> compose<T>(
    Iterable<FormFieldValidator<T>> validators,
  ) {
    return (T? value) {
      for (final FormFieldValidator<T> validator in validators) {
        final String? error = validator(value);
        if (error != null) {
          return error;
        }
      }

      return null;
    };
  }

  static FormFieldValidator<String> normalizedText(
    FormFieldValidator<String> validator,
    AppTextNormalizer normalizer,
  ) {
    return (String? value) {
      return validator(value == null ? null : normalizer(value));
    };
  }

  static String _normalizeText(String? value, {required bool trim}) {
    final String resolvedValue = value ?? '';
    return trim ? resolvedValue.trim() : resolvedValue;
  }

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
}
