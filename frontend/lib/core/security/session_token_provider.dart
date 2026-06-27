import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';
import 'package:hosspi_hms/core/network/api_interceptors.dart';
import 'package:hosspi_hms/core/network/api_response.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_refresh_service.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/data/dtos/auth_session_dto.dart';

final sessionTokenProvider = Provider<SessionTokenProvider>((ref) {
  return SessionTokenProvider(ref);
});

final class SessionTokenProvider {
  SessionTokenProvider(this._ref, {DateTimeReader now = DateTime.now})
    : _now = now;

  final Ref _ref;
  final DateTimeReader _now;

  SessionManager get _sessionManager => _ref.read(sessionManagerProvider);

  SessionRefreshService get _refreshService =>
      _ref.read(sessionRefreshServiceProvider);

  Future<String?> readAccessToken() async {
    final SessionTokens? tokens = await _sessionManager.readTokens();
    if (tokens == null) {
      return null;
    }

    if (!_needsRefresh(tokens)) {
      return tokens.accessToken;
    }

    if (!tokens.hasRefreshToken) {
      return null;
    }

    final AuthSession? session = await _refreshStoredSession();
    return session?.tokens.accessToken;
  }

  Future<AuthSession?> refreshStoredSession() {
    return _refreshStoredSession();
  }

  Future<AuthSession?> restorePersistedSession() async {
    final result = await _refreshService.restoreSession();
    return result.when(
      success: (AuthSession? session) async {
        if (session != null) {
          final enriched = await _enrichSession(session);
          await _ref
              .read(sessionStateProvider.notifier)
              .persistSession(enriched);
          return enriched;
        }
        return session;
      },
      failure: (_) async {
        await _ref
            .read(sessionStateProvider.notifier)
            .handleUnauthorizedResponse();
        return null;
      },
    );
  }

  Future<void> enrichAuthenticatedSession() async {
    final AuthSession? session = _ref.read(sessionStateProvider).session;
    if (session == null) {
      return;
    }

    final enriched = await _enrichSession(session);
    if (!identical(enriched, session)) {
      await _ref.read(sessionStateProvider.notifier).persistSession(enriched);
    }
  }

  Future<AuthSession?> _refreshStoredSession() async {
    final SessionTokens? tokens = await _sessionManager.readTokens();
    if (tokens == null || !tokens.hasRefreshToken) {
      return null;
    }

    final refreshResult = await _refreshService.refreshSession(tokens);
    return refreshResult.when(
      success: (AuthSession session) async {
        final enriched = await _enrichSession(session);
        await _sessionManager.persistSession(enriched);
        await _ref.read(sessionStateProvider.notifier).persistSession(enriched);
        return enriched;
      },
      failure: (_) async {
        await _ref
            .read(sessionStateProvider.notifier)
            .handleUnauthorizedResponse();
        return null;
      },
    );
  }

  bool _needsRefresh(SessionTokens tokens) {
    return tokens.isAccessTokenExpired(_now().toUtc());
  }

  Future<AuthSession> _enrichSession(AuthSession session) async {
    final String accessToken = session.tokens.accessToken.trim();
    if (accessToken.isEmpty) {
      return session;
    }

    // Use the public client with an explicit bearer token to avoid a circular
    // provider chain through authRepositoryProvider -> apiClientProvider.
    final result = await _ref.read(publicApiClientProvider).get<AuthSession>(
      ApiEndpoints.auth(AuthEndpoint.me),
      options: Options(
        headers: <String, Object?>{
          authorizationHeaderName: 'Bearer $accessToken',
        },
      ),
      decoder: (Object? data) => ApiResponseEnvelope.decodeData<AuthSession>(
        data,
        decoder: (Object? payload) {
          final profile = AuthSessionDto.userProfileFromResponseData(payload);
          final permissions = AuthSessionDto.permissionsFromResponseData(
            payload,
          );
          var enriched = session;
          if (profile != null) {
            enriched = enriched.enrichFromUserProfile(profile);
          }
          if (permissions.isNotEmpty) {
            enriched = enriched.copyWith(permissions: permissions);
          }
          return enriched;
        },
      ),
    );
    return result.when(
      success: (AuthSession enriched) => enriched,
      failure: (_) => session,
    );
  }
}
