import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/domain/repositories/auth_repository.dart';

final sessionTokenProvider = Provider<SessionTokenProvider>((ref) {
  return SessionTokenProvider(ref);
});

final class SessionTokenProvider {
  SessionTokenProvider(this._ref, {DateTimeReader now = DateTime.now})
    : _now = now;

  final Ref _ref;
  final DateTimeReader _now;

  SessionManager get _sessionManager => _ref.read(sessionManagerProvider);

  AuthRepository get _authRepository => _ref.read(authRepositoryProvider);

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
    final result = await _authRepository.restoreSession();
    return result.when(
      success: (AuthSession? session) async {
        if (session != null) {
          await _ref.read(sessionStateProvider.notifier).persistSession(session);
        }
        return session;
      },
      failure: (_) async {
        await _ref.read(sessionStateProvider.notifier).handleUnauthorizedResponse();
        return null;
      },
    );
  }

  Future<AuthSession?> _refreshStoredSession() async {
    final SessionTokens? tokens = await _sessionManager.readTokens();
    if (tokens == null || !tokens.hasRefreshToken) {
      return null;
    }

    final refreshResult = await _authRepository.refreshSession(tokens);
    return refreshResult.when(
      success: (AuthSession session) async {
        await _sessionManager.persistSession(session);
        await _ref.read(sessionStateProvider.notifier).persistSession(session);
        return session;
      },
      failure: (_) async {
        await _ref.read(sessionStateProvider.notifier).handleUnauthorizedResponse();
        return null;
      },
    );
  }

  bool _needsRefresh(SessionTokens tokens) {
    return tokens.isAccessTokenExpired(_now().toUtc());
  }
}
