import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/api_response.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_refresh_coordinator.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/data/dtos/auth_session_dto.dart';

final sessionRefreshServiceProvider = Provider<SessionRefreshService>((ref) {
  return SessionRefreshService(
    apiClient: ref.watch(publicApiClientProvider),
    sessionManager: ref.watch(sessionManagerProvider),
    refreshCoordinator: ref.watch(sessionRefreshCoordinatorProvider),
    failureMapper: ref.watch(networkFailureMapperProvider),
  );
});

/// True when the backend definitively rejected the credentials, meaning the
/// stored session is unusable. Transient transport failures (network, timeout,
/// offline, server errors) must never end the session, or a backend outage
/// would sign users out and strip their permissions.
bool isSessionRejectionFailure(AppFailure failure) {
  return failure.category == AppFailureCategory.unauthorized ||
      failure.category == AppFailureCategory.forbidden;
}

final class SessionRefreshService {
  const SessionRefreshService({
    required ApiClient apiClient,
    required SessionManager sessionManager,
    required SessionRefreshCoordinator refreshCoordinator,
    NetworkFailureMapper failureMapper = const NetworkFailureMapper(),
  }) : _apiClient = apiClient,
       _sessionManager = sessionManager,
       _refreshCoordinator = refreshCoordinator,
       _failureMapper = failureMapper;

  final ApiClient _apiClient;
  final SessionManager _sessionManager;
  final SessionRefreshCoordinator _refreshCoordinator;
  final NetworkFailureMapper _failureMapper;

  Future<Result<AuthSession?>> restoreSession() async {
    try {
      final tokens = await _sessionManager.readTokens();
      if (tokens == null) {
        return const Result<AuthSession?>.success(null);
      }

      if (!tokens.isAccessTokenExpired(DateTime.now().toUtc())) {
        return Result<AuthSession?>.success(AuthSession.fromTokens(tokens));
      }

      if (!tokens.hasRefreshToken) {
        await _sessionManager.clearSession();
        return const Result<AuthSession?>.success(null);
      }

      final refreshResult = await refreshSession(tokens);
      return refreshResult.when(
        success: (AuthSession session) async {
          await _sessionManager.persistSession(session);
          return Result<AuthSession?>.success(session);
        },
        failure: (AppFailure failure) async {
          // Keep tokens on transient failures so the session survives a
          // backend outage and the next refresh attempt can succeed.
          if (isSessionRejectionFailure(failure)) {
            await _sessionManager.clearSession();
          }
          return Result<AuthSession?>.failure(failure);
        },
      );
    } catch (error, stackTrace) {
      return Result<AuthSession?>.failure(
        _failureMapper.map(error, stackTrace),
      );
    }
  }

  Future<Result<AuthSession>> refreshSession(SessionTokens tokens) {
    final refreshToken = tokens.refreshToken;
    if (refreshToken == null) {
      return Future.value(
        const Result<AuthSession>.failure(AppFailure.unauthorized()),
      );
    }

    return _refreshCoordinator.run(() {
      return _apiClient.post<AuthSession>(
        ApiEndpoints.auth(AuthEndpoint.refresh),
        data: <String, Object?>{'refresh_token': refreshToken},
        decoder: (data) => ApiResponseEnvelope.decodeData<AuthSession>(
          data,
          decoder: (payload) =>
              AuthSessionDto.fromResponseData(payload).toEntity(),
        ),
      );
    });
  }
}
