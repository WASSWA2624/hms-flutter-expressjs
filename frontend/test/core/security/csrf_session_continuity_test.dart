import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';
import 'package:hosspi_hms/core/security/session_refresh_service.dart';
import 'package:hosspi_hms/core/workspace/workspace_bootstrap_helpers.dart';

/// A signed-in clinician submitting a patient registration hit a CSRF failure
/// in production and was shown "Sign-in required". These pin the classification
/// so that cannot happen again.
void main() {
  const NetworkFailureMapper mapper = NetworkFailureMapper();

  AppFailure mapResponse(int statusCode, Map<String, Object?> body) {
    final RequestOptions requestOptions = RequestOptions(path: '/patients');
    return mapper.map(
      DioException(
        requestOptions: requestOptions,
        response: Response<Object?>(
          requestOptions: requestOptions,
          statusCode: statusCode,
          data: body,
        ),
        type: DioExceptionType.badResponse,
      ),
      StackTrace.empty,
    );
  }

  test('a CSRF failure does not end the session', () {
    final AppFailure failure = mapResponse(403, <String, Object?>{
      'code': 'CSRF_MISSING',
    });

    // `isSessionRejectionFailure` drives handleUnauthorizedResponse(), which
    // clears stored tokens and moves the app to SessionStatus.expired.
    expect(isSessionRejectionFailure(failure), isFalse);
  });

  test('a CSRF failure is not treated as denied workspace access', () {
    final AppFailure failure = mapResponse(403, <String, Object?>{
      'code': 'CSRF_INVALID',
    });

    expect(isWorkspaceAccessDeniedFailure(failure), isFalse);
  });

  test('a genuine credential rejection still ends the session', () {
    final AppFailure failure = mapResponse(401, <String, Object?>{
      'code': 'INVALID_TOKEN',
    });

    expect(failure.category, AppFailureCategory.unauthorized);
    expect(isSessionRejectionFailure(failure), isTrue);
  });

  test('a permission denial still reads as access denied, not sign-in', () {
    final AppFailure failure = mapResponse(403, <String, Object?>{
      'code': 'INSUFFICIENT_PERMISSIONS',
    });

    expect(failure.category, AppFailureCategory.forbidden);
    expect(isWorkspaceAccessDeniedFailure(failure), isTrue);
  });
}
