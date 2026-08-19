import 'dart:async';
import 'dart:convert';

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
      final String detail = error is FormatException
          ? (error.message.trim().isEmpty
                ? error.toString()
                : error.message.trim())
          : error.toString();
      return AppFailure.unexpectedResponse(detailMessage: detail);
    }

    return const AppFailure.unexpected();
  }

  AppFailure _mapDioException(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => const AppFailure.timeout(),
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
    final String? detail = _responseDetail(response?.data);

    if (statusCode == null) {
      return AppFailure.unexpectedResponse(
        detailMessage: detail ?? 'The server returned an empty error response.',
      );
    }

    if (statusCode == 400 || statusCode == 422 || statusCode == 428) {
      return AppFailure.validation(
        statusCode: statusCode,
        validationFields: _validationFields(response?.data),
        detailMessage: detail,
        fieldMessages: _validationFieldMessages(response?.data),
      );
    }

    if (statusCode == 409) {
      return AppFailure.conflict(
        code: _conflictFailureCode(response?.data),
        statusCode: statusCode,
        validationFields: _validationFields(response?.data),
        detailMessage: detail,
        fieldMessages: _validationFieldMessages(response?.data),
        conflictEntries: _conflictEntries(response?.data),
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
      if (code == 'ACCOUNT_PENDING' || code == 'EMAIL_VERIFICATION_REQUIRED') {
        return AppFailure.forbidden(
          code: 'auth.account_pending',
          statusCode: statusCode,
        );
      }
      if (code == 'ACCOUNT_PENDING_APPROVAL') {
        return AppFailure.forbidden(
          code: 'auth.account_pending_approval',
          statusCode: statusCode,
          detailMessage: _platformAdminContactDetail(response?.data),
        );
      }
      if (code == 'TENANT_DEACTIVATED') {
        return AppFailure.forbidden(
          code: 'auth.tenant_deactivated',
          statusCode: statusCode,
          detailMessage: _platformAdminContactDetail(response?.data),
        );
      }
      if (code == 'FACILITY_DEACTIVATED') {
        return AppFailure.forbidden(
          code: 'auth.facility_deactivated',
          statusCode: statusCode,
          detailMessage: _platformAdminContactDetail(response?.data),
        );
      }
      if (_isCsrfFailure(response?.data)) {
        // A stale or unbound CSRF token is a transport-level problem, not a
        // rejected identity. Classifying it as `unauthorized` made a signed-in
        // user see "Sign-in required" (and, on the refresh path, ended the
        // session outright) whenever the backend could not match the token.
        // It is retryable: the interceptor refetches a token and replays.
        return AppFailure.network(
          code: 'auth.csrf_token',
          statusCode: statusCode,
        );
      }
      return AppFailure.forbidden(
        statusCode: statusCode,
        detailMessage: detail,
      );
    }

    if (statusCode == 404) {
      return AppFailure.notFound(
        statusCode: statusCode,
        detailMessage: detail,
      );
    }

    if (statusCode == 429) {
      return AppFailure.network(
        code: 'network.rate_limited',
        statusCode: statusCode,
        detailMessage: _rateLimitResetAt(response),
      );
    }

    if (statusCode >= 500) {
      return AppFailure.unexpectedResponse(
        statusCode: statusCode,
        detailMessage:
            detail ??
            'The server failed to process this request (HTTP $statusCode).',
      );
    }

    return AppFailure.unexpectedResponse(
      statusCode: statusCode,
      detailMessage:
          detail ??
          'Unexpected HTTP $statusCode response from the server.',
    );
  }

  AppFailure _mapUnknownDioException(DioException error) {
    final innerError = error.error;

    if (innerError is TimeoutException) {
      return const AppFailure.timeout();
    }

    if (innerError is FormatException || innerError is TypeError) {
      final String detail = innerError is FormatException
          ? (innerError.message.trim().isEmpty
                ? innerError.toString()
                : innerError.message.trim())
          : innerError.toString();
      return AppFailure.unexpectedResponse(detailMessage: detail);
    }

    final String? message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return AppFailure.unexpectedResponse(detailMessage: message);
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
          .map(
            (Map<Object?, Object?> entry) => entry['field']?.toString().trim(),
          )
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
      if (field == null ||
          field.isEmpty ||
          message == null ||
          message.isEmpty) {
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

    final Object? errors = data['errors'];
    if (errors is List<Object?>) {
      for (final Object? entry in errors) {
        if (entry is! Map<Object?, Object?>) {
          continue;
        }
        final String? message = entry['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
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

  String _conflictFailureCode(Object? data) {
    final String? code = _responseCode(data);
    if (code == null || code.isEmpty || code == 'CONFLICT') {
      return 'network.conflict';
    }
    return code;
  }

  List<Map<String, Object?>> _conflictEntries(Object? data) {
    if (data is! Map<Object?, Object?>) {
      return const <Map<String, Object?>>[];
    }

    final Object? errors = data['errors'];
    if (errors is! List<Object?>) {
      return const <Map<String, Object?>>[];
    }

    final List<Map<String, Object?>> matches = <Map<String, Object?>>[];
    for (final Object? entry in errors) {
      if (entry is! Map<Object?, Object?>) {
        continue;
      }
      final Object? nested = entry['matches'];
      if (nested is! List<Object?>) {
        continue;
      }
      for (final Object? match in nested) {
        if (match is! Map<Object?, Object?>) {
          continue;
        }
        matches.add(<String, Object?>{
          for (final MapEntry<Object?, Object?> item in match.entries)
            if (item.key != null) item.key.toString(): item.value,
        });
      }
    }
    return matches;
  }

  /// Encodes platform admin contact(s) from pending-approval error details.
  ///
  /// Stored as JSON in [AppFailure.detailMessage] for localized presentation.
  String? _platformAdminContactDetail(Object? data) {
    if (data is! Map<Object?, Object?>) {
      return null;
    }

    Map<Object?, Object?>? contactMap;
    List<Object?>? contactsList;
    final Object? topLevelContacts =
        data['platform_admin_contacts'] ?? data['platformAdminContacts'];
    if (topLevelContacts is List<Object?>) {
      contactsList = topLevelContacts;
    }

    final Object? topLevel =
        data['platform_admin_contact'] ?? data['platformAdminContact'];
    if (topLevel is Map<Object?, Object?>) {
      contactMap = topLevel;
    } else {
      final Object? errors = data['errors'];
      if (errors is List<Object?>) {
        for (final Object? entry in errors) {
          if (entry is! Map<Object?, Object?>) {
            continue;
          }
          final Object? nestedContacts =
              entry['platform_admin_contacts'] ?? entry['platformAdminContacts'];
          if (nestedContacts is List<Object?> && contactsList == null) {
            contactsList = nestedContacts;
          }
          final Object? nested =
              entry['platform_admin_contact'] ?? entry['platformAdminContact'];
          if (nested is Map<Object?, Object?>) {
            contactMap = nested;
            break;
          }
        }
      }
    }

    final List<Map<String, String>> contacts = <Map<String, String>>[];
    if (contactsList != null) {
      for (final Object? entry in contactsList) {
        if (entry is! Map<Object?, Object?>) {
          continue;
        }
        final Map<String, String>? normalized = _normalizeContactMap(entry);
        if (normalized != null) {
          contacts.add(normalized);
        }
      }
    }

    if (contacts.isEmpty && contactMap != null) {
      final Map<String, String>? normalized = _normalizeContactMap(contactMap);
      if (normalized != null) {
        contacts.add(normalized);
      }
    }

    if (contacts.isEmpty) {
      return null;
    }

    return jsonEncode(<String, Object?>{
      'email': contacts.first['email'],
      'phone': contacts.first['phone'],
      'contacts': contacts,
    });
  }

  Map<String, String>? _normalizeContactMap(Map<Object?, Object?> contactMap) {
    final String? email = contactMap['email']?.toString().trim();
    final String? phone = contactMap['phone']?.toString().trim();
    final String? fullName =
        (contactMap['full_name'] ?? contactMap['fullName'] ?? contactMap['name'])
            ?.toString()
            .trim();
    final bool hasEmail = email != null && email.isNotEmpty;
    final bool hasPhone = phone != null && phone.isNotEmpty;
    if (!hasEmail && !hasPhone) {
      return null;
    }

    return <String, String>{
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      if (hasEmail) 'email': email,
      if (hasPhone) 'phone': phone,
    };
  }

  String _unauthorizedFailureCode(Object? data) {
    return switch (_responseCode(data)) {
      'USER_NOT_FOUND' => 'auth.account_not_found',
      'WRONG_PASSWORD' => 'auth.wrong_password',
      'INVALID_CREDENTIALS' => 'auth.invalid_credentials',
      _ => 'auth.unauthorized',
    };
  }

  bool _isCsrfFailure(Object? data) {
    if (data is! Map<Object?, Object?>) {
      return false;
    }

    final String? code = _responseCode(data);
    if (code == 'CSRF_MISSING' || code == 'CSRF_INVALID') {
      return true;
    }

    // Legacy backends derived the problem code from the last segment of the
    // message key, so `errors.csrf.missing` arrived as a bare `MISSING`. Kept
    // for mixed-version deploys; current backends send the explicit codes above.
    if (code == 'MISSING' || code == 'INVALID') {
      return true;
    }

    final Object? type = data['type'];
    if (type is String && type.toLowerCase().contains('csrf')) {
      return true;
    }

    final Object? messageKey = data['messageKey'];
    if (messageKey is String && messageKey.toLowerCase().contains('csrf')) {
      return true;
    }

    return false;
  }

  /// Prefer body `errors[].reset_at`, then `X-RateLimit-Reset` (unix seconds).
  String? _rateLimitResetAt(Response<dynamic>? response) {
    final Object? data = response?.data;
    if (data is Map<Object?, Object?>) {
      final Object? errors = data['errors'];
      if (errors is List<Object?>) {
        for (final Object? entry in errors) {
          if (entry is! Map<Object?, Object?>) {
            continue;
          }
          final Object? resetAt = entry['reset_at'];
          if (resetAt is String && resetAt.trim().isNotEmpty) {
            return resetAt.trim();
          }
        }
      }
    }

    final Object? header = response?.headers.value('x-ratelimit-reset');
    if (header is! String || header.trim().isEmpty) {
      return null;
    }

    final int? unixSeconds = int.tryParse(header.trim());
    if (unixSeconds == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    ).toIso8601String();
  }
}
