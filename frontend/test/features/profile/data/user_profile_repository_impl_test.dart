import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';
import 'package:hosspi_hms/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';

void main() {
  group('UserProfileRepositoryImpl.loadCurrentProfile', () {
    late _FakeAuthRepository authRepository;
    late _FakeApiClient apiClient;
    late UserProfileRepositoryImpl repository;

    setUp(() {
      authRepository = _FakeAuthRepository();
      apiClient = _FakeApiClient();
      repository = UserProfileRepositoryImpl(
        apiClient: apiClient,
        authRepository: authRepository,
      );
    });

    test('falls back to session profile when /auth/me is unreachable', () async {
      authRepository.fetchCurrentUserResult =
          const Result<AuthSession>.failure(AppFailure.network());
      final AuthSession session = _sessionWithProfile();

      final Result<UserProfileView> result = await repository.loadCurrentProfile(
        session,
      );

      expect(result.isSuccess, isTrue);
      result.when(
        success: (UserProfileView view) {
          expect(view.profile.displayName, 'Alex Demo');
          expect(view.session.user?.id, 'user-1');
        },
        failure: (_) => fail('expected fallback success'),
      );
      expect(apiClient.getCount, 1);
    });

    test('still fails hard when /auth/me is unauthorized', () async {
      authRepository.fetchCurrentUserResult =
          const Result<AuthSession>.failure(AppFailure.unauthorized());
      final AuthSession session = _sessionWithProfile();

      final Result<UserProfileView> result = await repository.loadCurrentProfile(
        session,
      );

      expect(result.isFailure, isTrue);
      result.when(
        success: (_) => fail('expected unauthorized failure'),
        failure: (AppFailure failure) {
          expect(failure.category, AppFailureCategory.unauthorized);
        },
      );
      expect(apiClient.getCount, 0);
    });

    test('still fails when session has no displayable profile', () async {
      authRepository.fetchCurrentUserResult =
          const Result<AuthSession>.failure(AppFailure.network());
      final AuthSession session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
      );

      final Result<UserProfileView> result = await repository.loadCurrentProfile(
        session,
      );

      expect(result.isFailure, isTrue);
      expect(apiClient.getCount, 0);
    });
  });
}

AuthSession _sessionWithProfile() {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    user: const AuthUserProfile(
      id: 'user-1',
      email: 'alex@example.com',
      firstName: 'Alex',
      lastName: 'Demo',
    ),
  );
}

final class _FakeAuthRepository implements AuthRepository {
  Result<AuthSession> fetchCurrentUserResult = const Result<AuthSession>.failure(
    AppFailure.network(),
  );

  @override
  Future<Result<AuthSession>> fetchCurrentUser(AuthSession session) async {
    return fetchCurrentUserResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeApiClient implements ApiClient {
  int getCount = 0;

  @override
  Uri get baseUri => Uri.parse('http://localhost:3000');

  @override
  Future<Result<T>> get<T>(
    Uri endpoint, {
    required T Function(Object? data) decoder,
    Map<String, Object?>? queryParameters,
    Object? cancelToken,
    Object? options,
  }) async {
    getCount += 1;
    return Result<T>.success(
      decoder(<String, Object?>{
        'success': true,
        'data': <Object?>[],
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
