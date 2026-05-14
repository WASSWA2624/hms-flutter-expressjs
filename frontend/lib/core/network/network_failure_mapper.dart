import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_template/core/errors/app_failure.dart';

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
      DioExceptionType.connectionError => const AppFailure.offline(),
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

    if (statusCode == 400 || statusCode == 422) {
      return AppFailure.validation(
        statusCode: statusCode,
        validationFields: _validationFields(response?.data),
      );
    }

    if (statusCode == 401) {
      return AppFailure.unauthorized(statusCode: statusCode);
    }

    if (statusCode == 403) {
      return AppFailure.forbidden(statusCode: statusCode);
    }

    if (statusCode == 404) {
      return AppFailure.notFound(statusCode: statusCode);
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

    final errors = data['errors'];
    if (errors is! Map<Object?, Object?>) {
      return const <String>{};
    }

    return errors.keys
        .whereType<String>()
        .map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toSet();
  }
}
