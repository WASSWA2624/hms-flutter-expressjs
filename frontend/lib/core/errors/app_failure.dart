enum AppFailureCategory {
  network,
  timeout,
  offline,
  cancelled,
  unauthorized,
  forbidden,
  notFound,
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
  });

  const factory AppFailure.network({
    String code,
    int? statusCode,
    bool isRetryable,
  }) = NetworkFailure;

  const factory AppFailure.timeout({int? statusCode}) = TimeoutFailure;

  const factory AppFailure.offline({int? statusCode}) = OfflineFailure;

  const factory AppFailure.cancelled() = CancelledFailure;

  const factory AppFailure.unauthorized({String code, int? statusCode}) =
      UnauthorizedFailure;

  const factory AppFailure.forbidden({String code, int? statusCode}) =
      ForbiddenFailure;

  const factory AppFailure.notFound({int? statusCode}) = NotFoundFailure;

  factory AppFailure.validation({
    String code,
    int? statusCode,
    Set<String> validationFields,
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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppFailure &&
            other.category == category &&
            other.code == code &&
            other.messageKey == messageKey &&
            other.isRetryable == isRetryable &&
            other.statusCode == statusCode &&
            _setEquals(other.validationFields, validationFields);
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
    );
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
  const ForbiddenFailure({super.code = 'auth.forbidden', super.statusCode})
    : super._(
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

final class ValidationFailure extends AppFailure {
  ValidationFailure({
    super.code = 'validation.failed',
    super.statusCode,
    Set<String> validationFields = const <String>{},
  }) : super._(
         category: AppFailureCategory.validation,
         messageKey: 'errors.validation',
         isRetryable: false,
         validationFields: AppFailure._normalizedFields(validationFields),
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
