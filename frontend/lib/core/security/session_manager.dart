import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/security/auth_session.dart';
import 'package:flutter_template/core/security/secure_session_storage.dart';
import 'package:flutter_template/core/security/session_state.dart';
import 'package:flutter_template/core/security/session_tokens.dart';

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(
    sessionStorage: ref.watch(secureSessionStorageProvider),
  );
});

final class SessionManager {
  const SessionManager({
    required SecureSessionStorage sessionStorage,
    DateTimeReader now = DateTime.now,
  }) : _sessionStorage = sessionStorage,
       _now = now;

  final SecureSessionStorage _sessionStorage;
  final DateTimeReader _now;

  Future<SessionState> restore() async {
    final tokens = await _sessionStorage.readTokens();
    if (tokens == null) {
      return const SessionState.unauthenticated();
    }

    if (tokens.isAccessTokenExpired(_now())) {
      await clearSession();
      return const SessionState.expired();
    }

    return SessionState.authenticated(session: AuthSession(tokens: tokens));
  }

  Future<String?> readAccessToken() async {
    final tokens = await _sessionStorage.readTokens();
    if (tokens == null) {
      return null;
    }

    if (tokens.isAccessTokenExpired(_now())) {
      await clearSession();
      return null;
    }

    return tokens.accessToken;
  }

  Future<void> persistAccessToken(String accessToken) async {
    await persistTokens(SessionTokens(accessToken: accessToken));
  }

  Future<void> persistTokens(SessionTokens tokens) {
    return _sessionStorage.writeTokens(tokens);
  }

  Future<void> persistSession(AuthSession session) {
    return persistTokens(session.tokens);
  }

  Future<void> clearSession() async {
    await _sessionStorage.clear();
  }

  Future<void> logout() {
    return clearSession();
  }

  Future<void> handleUnauthorizedResponse() {
    return clearSession();
  }
}
