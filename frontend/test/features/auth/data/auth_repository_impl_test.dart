import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_refresh_coordinator.dart';
import 'package:hosspi_hms/core/security/session_refresh_service.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  group('AuthRepositoryImpl password recovery', () {
    late _FakeApiClient apiClient;
    late AuthRepositoryImpl repository;

    setUp(() {
      apiClient = _FakeApiClient();
      repository = AuthRepositoryImpl(
        apiClient: apiClient,
        publicApiClient: apiClient,
        sessionRefreshService: SessionRefreshService(
          apiClient: apiClient,
          sessionManager: SessionManager(
            sessionStorage: SecureAppSessionStorage(_MemorySecureStorage()),
          ),
          refreshCoordinator: SessionRefreshCoordinator(),
        ),
        sessionManager: SessionManager(
          sessionStorage: SecureAppSessionStorage(_MemorySecureStorage()),
        ),
      );
    });

    test('identify rejects empty identifier', () async {
      final result = await repository.identify(identifier: '   ');

      expect(result.isFailure, isTrue);
      expect(
        result.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure.code,
        ),
        'auth.identify.invalid_input',
      );
    });

    test('forgotPassword sends email and tenant id', () async {
      final result = await repository.forgotPassword(
        email: 'admin@example.com',
        tenantId: '11111111-1111-1111-1111-111111111111',
      );

      expect(result.isSuccess, isTrue);
      expect(
        apiClient.lastPostUri,
        ApiEndpoints.auth(AuthEndpoint.forgotPassword),
      );
      expect(apiClient.lastPostData, <String, Object?>{
        'email': 'admin@example.com',
        'tenant_id': '11111111-1111-1111-1111-111111111111',
      });
    });

    test('resetPassword sends token and passwords', () async {
      final result = await repository.resetPassword(
        token: 'reset-token',
        newPassword: 'NewPass1!',
        confirmPassword: 'NewPass1!',
      );

      expect(result.isSuccess, isTrue);
      expect(
        apiClient.lastPostUri,
        ApiEndpoints.auth(AuthEndpoint.resetPassword),
      );
      expect(apiClient.lastPostData?['token'], 'reset-token');
    });

    test('fetchCurrentUser enriches session profile', () async {
      apiClient.getResponse = <String, Object?>{
        'data': <String, Object?>{
          'id': 'user-1',
          'email': 'admin@example.com',
          'tenant_id': 'tenant-1',
          'roles': <String>['TENANT_ADMIN'],
          'profile': <String, Object?>{
            'first_name': 'Ada',
            'last_name': 'Admin',
          },
        },
      };
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
      );

      final result = await repository.fetchCurrentUser(session);

      expect(result.isSuccess, isTrue);
      result.when(
        success: (AuthSession enriched) {
          expect(enriched.user?.email, 'admin@example.com');
          expect(enriched.user?.fullName, 'Ada Admin');
          expect(enriched.user?.tenantId, 'tenant-1');
        },
        failure: (_) => fail('expected success'),
      );
    });
  });
}

final class _FakeApiClient implements ApiClient {
  Map<String, Object?> getResponse = const <String, Object?>{};

  Uri? lastPostUri;
  Map<String, Object?>? lastPostData;

  @override
  Uri get baseUri => Uri.parse('http://localhost:8080');

  @override
  Future<Result<T>> get<T>(
    Uri endpoint, {
    required T Function(Object? data) decoder,
    Map<String, Object?>? queryParameters,
    Object? cancelToken,
    Object? options,
  }) async {
    return Result<T>.success(
      decoder(<String, Object?>{'success': true, 'data': getResponse['data']}),
    );
  }

  @override
  Future<Result<T>> post<T>(
    Uri endpoint, {
    required T Function(Object? data) decoder,
    Object? data,
    Map<String, Object?>? queryParameters,
    Object? cancelToken,
    Object? options,
  }) async {
    lastPostUri = endpoint;
    if (data is Map<String, Object?>) {
      lastPostData = data;
    }
    return Result<T>.success(
      decoder(const <String, Object?>{'success': true, 'data': null}),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MemorySecureStorage implements AppSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
