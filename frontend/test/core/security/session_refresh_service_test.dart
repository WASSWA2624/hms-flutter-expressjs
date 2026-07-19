import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_refresh_coordinator.dart';
import 'package:hosspi_hms/core/security/session_refresh_service.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_token_provider.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

final class _MockApiClient extends Mock implements ApiClient {}

_MemorySecureStorage _expiredSessionStorage() {
  return _MemorySecureStorage()
    ..values[SecureStorageKeys.accessToken] = 'expired-access-token'
    ..values[SecureStorageKeys.refreshToken] = 'refresh-token'
    ..values[SecureStorageKeys.accessTokenExpiresAt] = DateTime.utc(
      2024,
    ).toIso8601String();
}

void _stubRefreshFailure(_MockApiClient apiClient, AppFailure failure) {
  when(
    () => apiClient.post<AuthSession>(
      any(),
      data: any(named: 'data'),
      decoder: any(named: 'decoder'),
      queryParameters: any(named: 'queryParameters'),
      cancelToken: any(named: 'cancelToken'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => Result<AuthSession>.failure(failure));
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('SessionRefreshService.restoreSession', () {
    test(
      'keeps stored tokens when refresh fails from a backend outage',
      () async {
        final storage = _expiredSessionStorage();
        final apiClient = _MockApiClient();
        _stubRefreshFailure(apiClient, const AppFailure.network());
        final service = SessionRefreshService(
          apiClient: apiClient,
          sessionManager: SessionManager(
            sessionStorage: SecureAppSessionStorage(storage),
          ),
          refreshCoordinator: SessionRefreshCoordinator(),
        );

        final result = await service.restoreSession();

        expect(result.isFailure, isTrue);
        expect(storage.values[SecureStorageKeys.refreshToken], 'refresh-token');
      },
    );

    test('clears stored tokens when the backend rejects the refresh', () async {
      final storage = _expiredSessionStorage();
      final apiClient = _MockApiClient();
      _stubRefreshFailure(apiClient, const AppFailure.unauthorized());
      final service = SessionRefreshService(
        apiClient: apiClient,
        sessionManager: SessionManager(
          sessionStorage: SecureAppSessionStorage(storage),
        ),
        refreshCoordinator: SessionRefreshCoordinator(),
      );

      final result = await service.restoreSession();

      expect(result.isFailure, isTrue);
      expect(storage.values, isEmpty);
    });
  });

  group('SessionTokenProvider.refreshStoredSession', () {
    ProviderContainer buildContainer({
      required _MemorySecureStorage storage,
      required _MockApiClient apiClient,
    }) {
      final container = ProviderContainer(
        overrides: [
          secureSessionStorageProvider.overrideWithValue(
            SecureAppSessionStorage(storage),
          ),
          publicApiClientProvider.overrideWithValue(apiClient),
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(
              session: AuthSession(
                tokens: SessionTokens(
                  accessToken: 'expired-access-token',
                  refreshToken: 'refresh-token',
                  accessTokenExpiresAt: DateTime.utc(2024),
                ),
              ),
            ),
          ),
          sessionIsolationServiceProvider.overrideWith(
            (Ref ref) => _NoopSessionIsolation(ref),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'keeps the active session when refresh fails from an outage',
      () async {
        final storage = _expiredSessionStorage();
        final apiClient = _MockApiClient();
        _stubRefreshFailure(apiClient, const AppFailure.timeout());
        final container = buildContainer(
          storage: storage,
          apiClient: apiClient,
        );

        final session = await container
            .read(sessionTokenProvider)
            .refreshStoredSession();

        expect(session, isNull);
        expect(
          container.read(sessionStateProvider).status,
          SessionStatus.authenticated,
        );
        expect(storage.values[SecureStorageKeys.refreshToken], 'refresh-token');
      },
    );

    test('expires the session when the backend rejects the refresh', () async {
      final storage = _expiredSessionStorage();
      final apiClient = _MockApiClient();
      _stubRefreshFailure(apiClient, const AppFailure.unauthorized());
      final container = buildContainer(storage: storage, apiClient: apiClient);

      final session = await container
          .read(sessionTokenProvider)
          .refreshStoredSession();

      expect(session, isNull);
      expect(
        container.read(sessionStateProvider).status,
        SessionStatus.expired,
      );
      expect(storage.values, isEmpty);
    });
  });
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

final class _NoopSessionIsolation extends SessionIsolationService {
  _NoopSessionIsolation(super.ref);

  @override
  Future<void> disposeAuthenticatedState({
    bool closeNetwork = true,
    bool clearLocalCaches = true,
  }) async {
    ref.read(sessionEpochProvider.notifier).bump();
  }
}
