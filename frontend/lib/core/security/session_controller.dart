import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/security/auth_session.dart';
import 'package:flutter_template/core/security/session_manager.dart';
import 'package:flutter_template/core/security/session_state.dart';
import 'package:flutter_template/core/security/session_tokens.dart';

final initialSessionStateProvider = Provider<SessionState>((ref) {
  return const SessionState.notReady();
});

final sessionStateProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

final class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    return ref.watch(initialSessionStateProvider);
  }

  Future<SessionState> restoreSession() async {
    state = const SessionState.notReady();
    final restoredState = await ref.read(sessionManagerProvider).restore();
    state = restoredState;

    return restoredState;
  }

  Future<void> persistSession(AuthSession session) async {
    final previousState = state;
    state = SessionState.authenticated(session: session);

    try {
      await ref.read(sessionManagerProvider).persistSession(session);
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> persistTokens(SessionTokens tokens) async {
    await persistSession(AuthSession(tokens: tokens));
  }

  Future<void> logout() async {
    final previousState = state;
    state = const SessionState.unauthenticated();

    try {
      await ref.read(sessionManagerProvider).logout();
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> handleUnauthorizedResponse() async {
    await ref.read(sessionManagerProvider).handleUnauthorizedResponse();
    state = const SessionState.expired();
  }

  void markForbidden() {
    state = SessionState.forbidden(session: state.session);
  }
}
