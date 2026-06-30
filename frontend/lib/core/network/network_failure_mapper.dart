import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';

AppFailure mapToFailure(Object error, StackTrace stackTrace) {
  return const NetworkFailureMapper().map(error, stackTrace);
}

final class NetworkFailureMapper {
  const NetworkFailureMapper();

  AppFailure map(Object error, StackTrace stackTrace) {
    if (error is AppFailure) {
      return error;
    }

    if (error is DioException) {
      return _mapDioException(error);
    }

    if (error is TimeoutException) {
      return const AppFailure.timeout();
    }

    if (error is FormatException || error is TypeError) {
      return const AppFailure.unexpectedResponse();
    }

    return const AppFailure.unexpected();
  }

  AppFailure _mapDioException(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const AppFailure.timeout(),
      DioExceptionType.connectionError => const AppFailure.network(
        code: 'network.connection_failed',
      ),
      DioExceptionType.cancel => const AppFailure.cancelled(),
      DioExceptionType.badCertificate => const AppFailure.network(
        code: 'network.bad_certificate',
        isRetryable: false,
      ),
      DioExceptionType.badResponse => _mapResponse(error.response),
      DioExceptionType.unknown => _mapUnknownDioException(error),
    };
  }

  AppFailure _mapResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;

    if (statusCode == null) {
      return const AppFailure.unexpectedResponse();
    }

    if (statusCode == 400 || statusCode == 422 || statusCode == 428) {
      return AppFailure.validation(
        statusCode: statusCode,
        validationFields: _validationFields(response?.data),
        detailMessage: _responseDetail(response?.data),
        fieldMessages: _validationFieldMessages(response?.data),
      );
    }

    if (statusCode == 409) {
      return AppFailure.validation(
        statusCode: statusCode,
        validationFields: _validationFields(response?.data),
        detailMessage: _responseDetail(response?.data),
        fieldMessages: _validationFieldMessages(response?.data),
      );
    }

    if (statusCode == 401) {
      return AppFailure.unauthorized(
        code: _unauthorizedFailureCode(response?.data),
        statusCode: statusCode,
      );
    }

    if (statusCode == 403) {
      final code = _responseCode(response?.data);
      if (code == 'ACCOUNT_PENDING') {
        return AppFailure.forbidden(
          code: 'auth.account_pending',
          statusCode: statusCode,
        );
      }
      return AppFailure.forbidden(statusCode: statusCode);
    }

    if (statusCode == 404) {
      return AppFailure.notFound(statusCode: statusCode);
    }

    if (statusCode == 429) {
      return AppFailure.network(
        code: 'network.rate_limited',
        statusCode: statusCode,
      );
    }

    if (statusCode >= 500) {
      return AppFailure.network(
        code: 'network.server_error',
        statusCode: statusCode,
      );
    }

    return AppFailure.unexpectedResponse(statusCode: statusCode);
  }

  AppFailure _mapUnknownDioException(DioException error) {
    final innerError = error.error;

    if (innerError is TimeoutException) {
      return const AppFailure.timeout();
    }

    if (innerError is FormatException || innerError is TypeError) {
      return const AppFailure.unexpectedResponse();
    }

    return const AppFailure.unexpected();
  }

  Set<String> _validationFields(Object? data) {
    if (data is! Map<Object?, Object?>) {
      return const <String>{};
    }

    final Object? errors = data['errors'];
    if (errors is Map<Object?, Object?>) {
      return errors.keys
          .whereType<String>()
          .map((field) => field.trim())
          .where((field) => field.isNotEmpty)
          .toSet();
    }

    if (errors is List<Object?>) {
      return errors
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> entry) => entry['field']?.toString().trim())
          .whereType<String>()
          .where((String field) => field.isNotEmpty)
          .toSet();
    }

    return const <String>{};
  }

  Map<String, String> _validationFieldMessages(Object? data) {
    if (data is! Map<Object?, Object?>) {
      return const <String, String>{};
    }

    final Object? errors = data['errors'];
    if (errors is! List<Object?>) {
      return const <String, String>{};
    }

    final Map<String, String> messages = <String, String>{};
    for (final Object? entry in errors) {
      if (entry is! Map<Object?, Object?>) {
        continue;
      }
      final String? field = entry['field']?.toString().trim();
      final String? message = entry['message']?.toString().trim();
      if (field == null || field.isEmpty || message == null || message.isEmpty) {
        continue;
      }
      messages.putIfAbsent(field, () => message);
    }
    return messages;
  }

  String? _responseDetail(Object? data) {
    if (data is! Map<Object?, Object?>) {
      return null;
    }

    for (final String key in <String>['detail', 'message', 'title']) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _responseCode(Object? data) {
    if (data is! Map<Object?, Object?>) {
      return null;
    }

    final code = data['code'];
    if (code == null) {
      return null;
    }

    return code.toString().trim().toUpperCase();
  }

  String _unauthorizedFailureCode(Object? data) {
    return switch (_responseCode(data)) {
      'USER_NOT_FOUND' => 'auth.account_not_found',
      'WRONG_PASSWORD' => 'auth.wrong_password',
      'INVALID_CREDENTIALS' => 'auth.invalid_credentials',
      _ => 'auth.unauthorized',
    };
  }
}
