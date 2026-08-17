import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';

void main() {
  group('NetworkFailureMapper', () {
    const mapper = NetworkFailureMapper();

    test('maps Dio timeouts to retryable timeout failures', () {
      final failure = mapper.map(
        DioException(
          requestOptions: RequestOptions(path: '/readiness'),
          type: DioExceptionType.connectionTimeout,
        ),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.timeout);
      expect(failure.isRetryable, isTrue);
    });

    test('maps unauthorized responses to auth failures', () {
      final requestOptions = RequestOptions(path: '/private');
      final failure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.unauthorized);
      expect(failure.statusCode, 401);
      expect(failure.isRetryable, isFalse);
    });

    test(
      'preserves specific login failure codes from unauthorized responses',
      () {
        final requestOptions = RequestOptions(path: '/auth/login');
        final accountNotFoundFailure = mapper.map(
          DioException(
            requestOptions: requestOptions,
            response: Response<Object?>(
              requestOptions: requestOptions,
              statusCode: 401,
              data: <String, Object?>{'code': 'USER_NOT_FOUND'},
            ),
            type: DioExceptionType.badResponse,
          ),
          StackTrace.empty,
        );
        final wrongPasswordFailure = mapper.map(
          DioException(
            requestOptions: requestOptions,
            response: Response<Object?>(
              requestOptions: requestOptions,
              statusCode: 401,
              data: <String, Object?>{'code': 'WRONG_PASSWORD'},
            ),
            type: DioExceptionType.badResponse,
          ),
          StackTrace.empty,
        );

        expect(
          accountNotFoundFailure.category,
          AppFailureCategory.unauthorized,
        );
        expect(accountNotFoundFailure.code, 'auth.account_not_found');
        expect(wrongPasswordFailure.category, AppFailureCategory.unauthorized);
        expect(wrongPasswordFailure.code, 'auth.wrong_password');
      },
    );

    test('maps forbidden and missing responses to typed failures', () {
      final forbiddenRequest = RequestOptions(path: '/admin');
      final notFoundRequest = RequestOptions(path: '/missing');

      final forbiddenFailure = mapper.map(
        DioException(
          requestOptions: forbiddenRequest,
          response: Response<Object?>(
            requestOptions: forbiddenRequest,
            statusCode: 403,
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );
      final notFoundFailure = mapper.map(
        DioException(
          requestOptions: notFoundRequest,
          response: Response<Object?>(
            requestOptions: notFoundRequest,
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );

      expect(forbiddenFailure.category, AppFailureCategory.forbidden);
      expect(notFoundFailure.category, AppFailureCategory.notFound);
    });

    test('maps server errors to unexpected response failures', () {
      final requestOptions = RequestOptions(
        path: '/facility-lab-catalog/tests/STD_LAB_TEST:CBC',
      );
      final failure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 500,
            data: <String, Object?>{
              'detail': 'Database write failed while saving the catalog item.',
            },
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.unexpectedResponse);
      expect(failure.statusCode, 500);
      expect(
        failure.detailMessage,
        'Database write failed while saving the catalog item.',
      );
    });

    test('maps rate limited responses to retryable network failures', () {
      final requestOptions = RequestOptions(path: '/auth/login');
      final failure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 429,
            data: <String, Object?>{
              'code': 'EXCEEDED',
              'errors': <Object?>[
                <String, Object?>{
                  'field': 'rate_limit',
                  'message': 'Limit will reset at {{reset_at}}',
                  'reset_at': '2026-08-04T17:22:52.782Z',
                },
              ],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.network);
      expect(failure.code, 'network.rate_limited');
      expect(failure.statusCode, 429);
      expect(failure.isRetryable, isTrue);
      expect(failure.detailMessage, '2026-08-04T17:22:52.782Z');
    });

    test(
      'preserves pending account forbidden responses for verification flow',
      () {
        final requestOptions = RequestOptions(path: '/auth/login');
        final failure = mapper.map(
          DioException(
            requestOptions: requestOptions,
            response: Response<Object?>(
              requestOptions: requestOptions,
              statusCode: 403,
              data: <String, Object?>{'code': 'ACCOUNT_PENDING'},
            ),
            type: DioExceptionType.badResponse,
          ),
          StackTrace.empty,
        );

        expect(failure.category, AppFailureCategory.forbidden);
        expect(failure.code, 'auth.account_pending');
      },
    );

    test('maps email verification required forbidden responses', () {
      final requestOptions = RequestOptions(path: '/auth/login');
      final failure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 403,
            data: <String, Object?>{'code': 'EMAIL_VERIFICATION_REQUIRED'},
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.forbidden);
      expect(failure.code, 'auth.account_pending');
    });

    test('maps pending approval forbidden responses', () {
      final requestOptions = RequestOptions(path: '/auth/login');
      final failure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 403,
            data: <String, Object?>{
              'code': 'ACCOUNT_PENDING_APPROVAL',
              'errors': <Object?>[
                <String, Object?>{
                  'reason': 'platform_approval_required',
                  'platform_admin_contact': <String, Object?>{
                    'email': 'admin@hosspi.com',
                    'phone': '+256700000000',
                  },
                },
              ],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.forbidden);
      expect(failure.code, 'auth.account_pending_approval');
      expect(
        failure.detailMessage,
        '{"email":"admin@hosspi.com","phone":"+256700000000","contacts":[{"email":"admin@hosspi.com","phone":"+256700000000"}]}',
      );
    });

    test('maps connection and cancellation errors to typed failures', () {
      final requestOptions = RequestOptions(path: '/readiness');

      final offlineFailure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
        ),
        StackTrace.empty,
      );
      final cancelledFailure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.cancel,
        ),
        StackTrace.empty,
      );

      expect(offlineFailure.category, AppFailureCategory.network);
      expect(offlineFailure.code, 'network.connection_failed');
      expect(offlineFailure.isRetryable, isTrue);
      expect(cancelledFailure.category, AppFailureCategory.cancelled);
      expect(cancelledFailure.isRetryable, isFalse);
    });

    test(
      'maps precondition to validation and conflict to conflict failures',
      () {
        final preconditionRequest = RequestOptions(path: '/shift-closes');
        final conflictRequest = RequestOptions(path: '/shift-closes');

        final preconditionFailure = mapper.map(
          DioException(
            requestOptions: preconditionRequest,
            response: Response<Object?>(
              requestOptions: preconditionRequest,
              statusCode: 428,
            ),
            type: DioExceptionType.badResponse,
          ),
          StackTrace.empty,
        );
        final conflictFailure = mapper.map(
          DioException(
            requestOptions: conflictRequest,
            response: Response<Object?>(
              requestOptions: conflictRequest,
              statusCode: 409,
            ),
            type: DioExceptionType.badResponse,
          ),
          StackTrace.empty,
        );

        expect(preconditionFailure.category, AppFailureCategory.validation);
        expect(conflictFailure.category, AppFailureCategory.conflict);
        expect(conflictFailure.statusCode, 409);
        expect(conflictFailure.isRetryable, isTrue);
      },
    );

    test('maps validation responses without exposing server messages', () {
      final requestOptions = RequestOptions(path: '/example-resources');
      final failure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 422,
            data: <String, Object?>{
              'errors': <String, Object?>{
                'email': <String>['Sensitive server message'],
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.validation);
      expect(failure.validationFields, <String>{'email'});
      expect(failure.messageKey, 'errors.validation');
    });

    test('maps problem+json conflict arrays and detail messages', () {
      final requestOptions = RequestOptions(path: '/users');
      final failure = mapper.map(
        DioException(
          requestOptions: requestOptions,
          response: Response<Object?>(
            requestOptions: requestOptions,
            statusCode: 409,
            data: <String, Object?>{
              'detail': 'A user with this email already exists in this tenant',
              'errors': <Object?>[
                <String, Object?>{
                  'field': 'email',
                  'message':
                      'A user with this email already exists in this tenant',
                },
              ],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.conflict);
      expect(failure.validationFields, <String>{'email'});
      expect(
        failure.detailMessage,
        'A user with this email already exists in this tenant',
      );
      expect(
        failure.fieldMessages['email'],
        'A user with this email already exists in this tenant',
      );
    });

    test('maps invalid decoded payloads to unexpected response failures', () {
      final failure = mapper.map(
        const FormatException('Invalid payload.'),
        StackTrace.empty,
      );

      expect(failure.category, AppFailureCategory.unexpectedResponse);
    });

    group('CSRF responses', () {
      AppFailure mapForbidden(Map<String, Object?> body) {
        final requestOptions = RequestOptions(path: '/patients');
        return mapper.map(
          DioException(
            requestOptions: requestOptions,
            response: Response<Object?>(
              requestOptions: requestOptions,
              statusCode: 403,
              data: body,
            ),
            type: DioExceptionType.badResponse,
          ),
          StackTrace.empty,
        );
      }

      for (final String code in <String>['CSRF_MISSING', 'CSRF_INVALID']) {
        test('$code never presents as a rejected session', () {
          final AppFailure failure = mapForbidden(<String, Object?>{
            'code': code,
          });

          // A signed-in user must not be told to sign in again, and the
          // session layer must not treat this as a credential rejection.
          expect(failure.category, isNot(AppFailureCategory.unauthorized));
          expect(failure.code, 'auth.csrf_token');
          expect(failure.isRetryable, isTrue);
        });
      }

      test('legacy bare codes are still recognised', () {
        for (final String code in <String>['MISSING', 'INVALID']) {
          expect(
            mapForbidden(<String, Object?>{'code': code}).code,
            'auth.csrf_token',
          );
        }
      });

      test('a permission denial stays forbidden', () {
        final AppFailure failure = mapForbidden(<String, Object?>{
          'code': 'INSUFFICIENT_PERMISSIONS',
          'detail': 'Insufficient permissions',
        });

        expect(failure.category, AppFailureCategory.forbidden);
        expect(failure.detailMessage, 'Insufficient permissions');
      });

      test('an entitlement denial stays forbidden', () {
        final AppFailure failure = mapForbidden(<String, Object?>{
          'code': 'MODULE_NOT_ENTITLED',
          'detail': 'Your current plan does not include this module',
        });

        expect(failure.category, AppFailureCategory.forbidden);
        expect(
          failure.detailMessage,
          'Your current plan does not include this module',
        );
      });
    });
  });
}
