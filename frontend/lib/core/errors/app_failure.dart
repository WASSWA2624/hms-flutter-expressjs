enum AppFailureCategory {
  network,
  timeout,
  offline,
  cancelled,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  unexpectedResponse,
  storage,
  unexpected,
}

sealed class AppFailure {
  const AppFailure._({
    required this.category,
    required this.code,
    required this.messageKey,
    required this.isRetryable,
    this.statusCode,
    this.validationFields = const <String>{},
    this.detailMessage,
    this.fieldMessages = const <String, String>{},
  });

  const factory AppFailure.network({
    String code,
    int? statusCode,
    bool isRetryable,
    String? detailMessage,
  }) = NetworkFailure;

  const factory AppFailure.timeout({int? statusCode}) = TimeoutFailure;

  const factory AppFailure.offline({int? statusCode}) = OfflineFailure;

  const factory AppFailure.cancelled() = CancelledFailure;

  const factory AppFailure.unauthorized({String code, int? statusCode}) =
      UnauthorizedFailure;

  const factory AppFailure.forbidden({
    String code,
    int? statusCode,
    String? detailMessage,
  }) = ForbiddenFailure;

  const factory AppFailure.notFound({int? statusCode}) = NotFoundFailure;

  factory AppFailure.conflict({
    String code,
    int? statusCode,
    Set<String> validationFields,
    String? detailMessage,
    Map<String, String> fieldMessages,
    List<Map<String, Object?>> conflictEntries,
    bool isRetryable,
  }) = ConflictFailure;

  factory AppFailure.validation({
    String code,
    int? statusCode,
    Set<String> validationFields,
    String? detailMessage,
    Map<String, String> fieldMessages,
  }) = ValidationFailure;

  const factory AppFailure.unexpectedResponse({int? statusCode}) =
      UnexpectedResponseFailure;

  const factory AppFailure.storage({String code, bool isRetryable}) =
      StorageFailure;

  const factory AppFailure.unexpected() = UnexpectedFailure;

  final AppFailureCategory category;
  final String code;
  final String messageKey;
  final bool isRetryable;
  final int? statusCode;
  final Set<String> validationFields;
  final String? detailMessage;
  final Map<String, String> fieldMessages;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppFailure &&
            other.category == category &&
            other.code == code &&
            other.messageKey == messageKey &&
            other.isRetryable == isRetryable &&
            other.statusCode == statusCode &&
            _setEquals(other.validationFields, validationFields) &&
            other.detailMessage == detailMessage &&
            _mapEquals(other.fieldMessages, fieldMessages);
  }

  @override
  int get hashCode {
    return Object.hash(
      category,
      code,
      messageKey,
      isRetryable,
      statusCode,
      Object.hashAllUnordered(validationFields),
      detailMessage,
      Object.hashAllUnordered(fieldMessages.entries),
    );
  }

  static bool _mapEquals(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final MapEntry<String, String> entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static Map<String, String> _normalizedFieldMessages(
    Map<String, String> messages,
  ) {
    return Map<String, String>.unmodifiable(<String, String>{
      for (final MapEntry<String, String> entry in messages.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key.trim(): entry.value.trim(),
    });
  }

  static Set<String> _normalizedFields(Set<String> fields) {
    final normalizedFields = fields
        .map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toSet();

    return Set<String>.unmodifiable(normalizedFields);
  }

  static bool _setEquals(Set<String> left, Set<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (final value in left) {
      if (!right.contains(value)) {
        return false;
      }
    }

    return true;
  }
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.code = 'network.request_failed',
    super.statusCode,
    super.isRetryable = true,
    super.detailMessage,
  }) : super._(
         category: AppFailureCategory.network,
         messageKey: 'errors.network',
       );
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.statusCode})
    : super._(
        category: AppFailureCategory.timeout,
        code: 'network.timeout',
        messageKey: 'errors.timeout',
        isRetryable: true,
      );
}

final class OfflineFailure extends AppFailure {
  const OfflineFailure({super.statusCode})
    : super._(
        category: AppFailureCategory.offline,
        code: 'network.offline',
        messageKey: 'errors.offline',
        isRetryable: true,
      );
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure()
    : super._(
        category: AppFailureCategory.cancelled,
        code: 'network.cancelled',
        messageKey: 'errors.cancelled',
        isRetryable: false,
      );
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({
    super.code = 'auth.unauthorized',
    super.statusCode,
  }) : super._(
         category: AppFailureCategory.unauthorized,
         messageKey: 'errors.unauthorized',
         isRetryable: false,
       );
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({
    super.code = 'auth.forbidden',
    super.statusCode,
    super.detailMessage,
  }) : super._(
         category: AppFailureCategory.forbidden,
         messageKey: 'errors.forbidden',
         isRetryable: false,
       );
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.statusCode})
    : super._(
        category: AppFailureCategory.notFound,
        code: 'network.not_found',
        messageKey: 'errors.notFound',
        isRetryable: false,
      );
}

final class ConflictFailure extends AppFailure {
  ConflictFailure({
    super.code = 'network.conflict',
    super.statusCode,
    Set<String> validationFields = const <String>{},
    String? detailMessage,
    Map<String, String> fieldMessages = const <String, String>{},
    List<Map<String, Object?>> conflictEntries = const <Map<String, Object?>>[],
    super.isRetryable = true,
  }) : conflictEntries = List<Map<String, Object?>>.unmodifiable(
         conflictEntries,
       ),
       super._(
         category: AppFailureCategory.conflict,
         messageKey: 'errors.conflict',
         validationFields: AppFailure._normalizedFields(validationFields),
         detailMessage: () {
           final String? trimmed = detailMessage?.trim();
           if (trimmed == null || trimmed.isEmpty) {
             return null;
           }
           return trimmed;
         }(),
         fieldMessages: AppFailure._normalizedFieldMessages(fieldMessages),
       );

  /// Nested `errors[].matches` payloads from uniqueness / similarity conflicts.
  final List<Map<String, Object?>> conflictEntries;

  @override
  bool operator ==(Object other) {
    return other is ConflictFailure &&
        super == other &&
        _listMapEquals(conflictEntries, other.conflictEntries);
  }

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    Object.hashAll(
      conflictEntries.map(
        (Map<String, Object?> entry) => Object.hashAllUnordered(
          entry.entries.map(
            (MapEntry<String, Object?> value) =>
                Object.hash(value.key, value.value),
          ),
        ),
      ),
    ),
  );

  static bool _listMapEquals(
    List<Map<String, Object?>> left,
    List<Map<String, Object?>> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (!_shallowMapEquals(left[i], right[i])) {
        return false;
      }
    }
    return true;
  }

  static bool _shallowMapEquals(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final MapEntry<String, Object?> entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

final class ValidationFailure extends AppFailure {
  ValidationFailure({
    super.code = 'validation.failed',
    super.statusCode,
    Set<String> validationFields = const <String>{},
    String? detailMessage,
    Map<String, String> fieldMessages = const <String, String>{},
  }) : super._(
         category: AppFailureCategory.validation,
         messageKey: 'errors.validation',
         isRetryable: false,
         validationFields: AppFailure._normalizedFields(validationFields),
         detailMessage: () {
           final String? trimmed = detailMessage?.trim();
           if (trimmed == null || trimmed.isEmpty) {
             return null;
           }
           return trimmed;
         }(),
         fieldMessages: AppFailure._normalizedFieldMessages(fieldMessages),
       );
}

final class UnexpectedResponseFailure extends AppFailure {
  const UnexpectedResponseFailure({super.statusCode})
    : super._(
        category: AppFailureCategory.unexpectedResponse,
        code: 'network.unexpected_response',
        messageKey: 'errors.unexpectedResponse',
        isRetryable: false,
      );
}

final class StorageFailure extends AppFailure {
  const StorageFailure({
    super.code = 'storage.failed',
    super.isRetryable = false,
  }) : super._(
         category: AppFailureCategory.storage,
         messageKey: 'errors.storage',
       );
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure()
    : super._(
        category: AppFailureCategory.unexpected,
        code: 'unexpected.failed',
        messageKey: 'errors.unexpected',
        isRetryable: false,
      );
}
