import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/startup/app_startup_initializer.dart';
import 'package:hosspi_hms/core/config/app_config.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_interceptors.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_refresh_coordinator.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_token_provider.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _MockApiClient extends Mock implements ApiClient {}

AppConfig _testConfig() {
  return AppConfig.fromValues(
    environmentName: 'development',
    apiBaseUrl: 'http://localhost:3000',
    logLevelName: 'error',
  );
}

String _futureExpiry() {
  return DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
}

/// A session whose access token has expired but whose refresh token is still
/// good — the state the app is in every time it reopens after sitting closed
/// for longer than the access-token TTL.
_MemorySecureStorage _expiredAccessTokenStorage() {
  return _MemorySecureStorage()
    ..values[SecureStorageKeys.accessToken] = 'expired-access-token'
    ..values[SecureStorageKeys.refreshToken] = 'refresh-token'
    ..values[SecureStorageKeys.accessTokenExpiresAt] = DateTime.utc(
      2024,
    ).toIso8601String();
}

_MemorySecureStorage _liveSessionStorage() {
  return _MemorySecureStorage()
    ..values[SecureStorageKeys.accessToken] = 'live-access-token'
    ..values[SecureStorageKeys.refreshToken] = 'refresh-token'
    ..values[SecureStorageKeys.accessTokenExpiresAt] = _futureExpiry();
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('cold start', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test(
      'restores a stored session on every launch, with no login prompt',
      () async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{
          SecureStorageKeys.accessToken: 'live-access-token',
          SecureStorageKeys.refreshToken: 'refresh-token',
          SecureStorageKeys.accessTokenExpiresAt: _futureExpiry(),
        });

        // Ten closes and reopens. Each launch goes through the real secure
        // storage layer, so a store that failed to persist would show up here.
        for (var launch = 0; launch < 10; launch++) {
          final result = await const AppStartupInitializer().initialize(
            config: _testConfig(),
          );

          expect(
            result.state.sessionReadiness.status,
            SessionStatus.authenticated,
            reason: 'launch $launch did not restore the session',
          );
        }
      },
    );

    test(
      'resolves the session before the first frame, never leaving it unknown',
      () async {
        final result = await const AppStartupInitializer().initialize(
          config: _testConfig(),
        );

        // `unknown` is what makes a screen flash an unauthenticated view.
        // Startup must hand the app a decided state, authenticated or not.
        expect(result.state.sessionReadiness.isReady, isTrue);
        expect(
          result.state.sessionReadiness.status,
          SessionStatus.unauthenticated,
        );
      },
    );

    test(
      'keeps an expired access token when a refresh token can still renew it',
      () async {
        final storage = _expiredAccessTokenStorage();

        final state = await SessionManager(
          sessionStorage: SecureAppSessionStorage(storage),
        ).restore();

        // Expiry is recoverable: the session stays authenticated so the refresh
        // path can run, instead of being cleared at startup.
        expect(state.status, SessionStatus.authenticated);
        expect(storage.values[SecureStorageKeys.refreshToken], 'refresh-token');
      },
    );
  });

  group('concurrent refresh', () {
    SessionTokenProvider buildTokenProvider({
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
            _NoopSessionIsolation.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(sessionTokenProvider);
    }

    test('five concurrent requests trigger exactly one refresh call', () async {
      final storage = _expiredAccessTokenStorage();
      final apiClient = _MockApiClient();
      var refreshCount = 0;

      when(
        () => apiClient.post<AuthSession>(
          any(),
          data: any(named: 'data'),
          decoder: any(named: 'decoder'),
          queryParameters: any(named: 'queryParameters'),
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async {
        refreshCount += 1;
        // Yield so every caller is queued before the first refresh completes;
        // without single-flight each would start a refresh of its own, and the
        // rotated refresh token would invalidate the others.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return Result<AuthSession>.success(
          AuthSession(
            tokens: SessionTokens(
              accessToken: 'refreshed-access-token',
              refreshToken: 'rotated-refresh-token',
              accessTokenExpiresAt: DateTime.now().toUtc().add(
                const Duration(minutes: 15),
              ),
            ),
          ),
        );
      });
      // `/auth/me` enrichment is not what this test measures; let it fail so
      // the refresh count is the only thing under test.
      when(
        () => apiClient.get<AuthSession>(
          any(),
          decoder: any(named: 'decoder'),
          queryParameters: any(named: 'queryParameters'),
          cancelToken: any(named: 'cancelToken'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => const Result<AuthSession>.failure(AppFailure.network()),
      );

      final tokenProvider = buildTokenProvider(
        storage: storage,
        apiClient: apiClient,
      );
      final List<String?> tokens = await Future.wait(<Future<String?>>[
        for (var request = 0; request < 5; request++)
          tokenProvider.readAccessToken(),
      ]);

      expect(refreshCount, 1);
      expect(tokens, everyElement('refreshed-access-token'));
      expect(
        storage.values[SecureStorageKeys.refreshToken],
        'rotated-refresh-token',
      );
    });

    test('a failed refresh releases the lock for the next attempt', () async {
      final coordinator = SessionRefreshCoordinator();
      var operationCount = 0;

      Future<Result<AuthSession>> refresh() {
        return coordinator.run(() async {
          operationCount += 1;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const Result<AuthSession>.failure(AppFailure.network());
        });
      }

      await Future.wait(<Future<Result<AuthSession>>>[refresh(), refresh()]);

      expect(operationCount, 1);
      // A refresh that failed from an outage must not wedge the coordinator:
      // the next request has to be able to try again.
      expect(coordinator.isRefreshing, isFalse);
      await refresh();
      expect(operationCount, 2);
    });
  });

  group('outage tolerance', () {
    test(
      'a 5xx during an active workflow never clears stored credentials',
      () async {
        var unauthorizedCallCount = 0;
        var refreshCount = 0;
        final adapter = _StaticHttpClientAdapter(
          (_) => ResponseBody.fromString('{}', 503),
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
          ..httpClientAdapter = adapter
          ..interceptors.add(
            AuthInterceptor(
              readAccessToken: () async => 'access-token',
              onTokenRefresh: () async {
                refreshCount += 1;
                return true;
              },
              onUnauthorizedResponse: () async {
                unauthorizedCallCount += 1;
              },
            ),
          );

        await expectLater(
          dio.post<Object?>('/dispenses'),
          throwsA(isA<DioException>()),
        );

        // A backend outage is not a credential rejection. Nothing refreshes and
        // nothing signs the user out; the request fails and can be retried.
        expect(refreshCount, 0);
        expect(unauthorizedCallCount, 0);
      },
    );

    test('a timeout never clears stored credentials', () async {
      var unauthorizedCallCount = 0;
      final storage = _liveSessionStorage();
      final sessionManager = SessionManager(
        sessionStorage: SecureAppSessionStorage(storage),
      );
      final adapter = _ThrowingHttpClientAdapter(
        (RequestOptions options) => DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: options,
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          AuthInterceptor(
            readAccessToken: () async =>
                (await sessionManager.readTokens())?.accessToken,
            onUnauthorizedResponse: () async {
              unauthorizedCallCount += 1;
            },
          ),
        );

      await expectLater(
        dio.get<Object?>('/dispenses'),
        throwsA(isA<DioException>()),
      );

      expect(unauthorizedCallCount, 0);
      expect(storage.values[SecureStorageKeys.refreshToken], 'refresh-token');
      expect((await sessionManager.restore()).isAuthenticated, isTrue);
    });
  });

  group('session teardown', () {
    test('five rejected requests end the session exactly once', () async {
      final storage = _liveSessionStorage();
      final container = ProviderContainer(
        overrides: [
          secureSessionStorageProvider.overrideWithValue(
            SecureAppSessionStorage(storage),
          ),
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(
              session: AuthSession(
                tokens: SessionTokens(accessToken: 'live-access-token'),
              ),
            ),
          ),
          sessionIsolationServiceProvider.overrideWith(
            _CountingSessionIsolation.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final isolation =
          container.read(sessionIsolationServiceProvider)
              as _CountingSessionIsolation;

      await Future.wait(<Future<void>>[
        for (var request = 0; request < 5; request++)
          container.read(sessionStateProvider.notifier)
              .handleUnauthorizedResponse(),
      ]);

      // Five teardowns would dispose providers, close the HTTP clients and
      // clear the local caches five times over, racing each other and any
      // sign-in started in that window.
      expect(isolation.disposeCount, 1);
      expect(container.read(sessionStateProvider).status, SessionStatus.expired);
      expect(storage.values, isEmpty);
    });

    test('a later rejection after signing in again tears down again', () async {
      final container = ProviderContainer(
        overrides: [
          secureSessionStorageProvider.overrideWithValue(
            SecureAppSessionStorage(_liveSessionStorage()),
          ),
          initialSessionStateProvider.overrideWithValue(
            SessionState.authenticated(
              session: AuthSession(
                tokens: SessionTokens(accessToken: 'live-access-token'),
              ),
            ),
          ),
          sessionIsolationServiceProvider.overrideWith(
            _CountingSessionIsolation.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionStateProvider.notifier);
      final isolation =
          container.read(sessionIsolationServiceProvider)
              as _CountingSessionIsolation;

      await controller.handleUnauthorizedResponse();
      await controller.persistSession(
        AuthSession(tokens: SessionTokens(accessToken: 'new-access-token')),
      );
      await controller.handleUnauthorizedResponse();

      // The guard must not latch: it collapses one burst, not every future one.
      expect(isolation.disposeCount, greaterThan(1));
      expect(container.read(sessionStateProvider).status, SessionStatus.expired);
    });
  });

  group('logout', () {
    test('clears every stored session key', () async {
      final storage = _liveSessionStorage();
      final sessionManager = SessionManager(
        sessionStorage: SecureAppSessionStorage(storage),
      );

      await sessionManager.logout();

      expect(storage.values, isEmpty);
      expect(await sessionManager.readTokens(), isNull);
      expect((await sessionManager.restore()).isAuthenticated, isFalse);
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

final class _CountingSessionIsolation extends SessionIsolationService {
  _CountingSessionIsolation(super.ref);

  int disposeCount = 0;

  @override
  Future<void> disposeAuthenticatedState({
    bool closeNetwork = true,
    bool clearLocalCaches = true,
  }) async {
    disposeCount += 1;
    // Yield so concurrent callers overlap, the way five in-flight requests do.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    ref.read(sessionEpochProvider.notifier).bump();
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

final class _StaticHttpClientAdapter implements HttpClientAdapter {
  _StaticHttpClientAdapter(this.responseFactory);

  final ResponseBody Function(RequestOptions options) responseFactory;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return responseFactory(options);
  }

  @override
  void close({bool force = false}) {}
}

final class _ThrowingHttpClientAdapter implements HttpClientAdapter {
  _ThrowingHttpClientAdapter(this.errorFactory);

  final DioException Function(RequestOptions options) errorFactory;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw errorFactory(options);
  }

  @override
  void close({bool force = false}) {}
}
