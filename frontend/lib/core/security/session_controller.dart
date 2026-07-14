import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/security/session_manager.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

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
    final AuthSession? previousSession = previousState.session;
    final bool contextChanged =
        previousSession != null &&
        (previousSession.user?.id != session.user?.id ||
            previousSession.user?.tenantId != session.user?.tenantId ||
            previousSession.user?.facilityId != session.user?.facilityId);

    if (contextChanged) {
      state = const SessionState.notReady();
      await ref
          .read(sessionIsolationServiceProvider)
          .disposeAuthenticatedState();
    }

    try {
      await ref.read(sessionManagerProvider).persistSession(session);
      state = SessionState.authenticated(session: session);
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> persistTokens(SessionTokens tokens) async {
    await persistSession(AuthSession.fromTokens(tokens));
  }

  Future<void> logout() async {
    final previousState = state;
    state = const SessionState.notReady();

    try {
      await ref.read(sessionIsolationServiceProvider).disposeAuthenticatedState();
      await ref.read(sessionManagerProvider).logout();
      state = const SessionState.unauthenticated();
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> handleUnauthorizedResponse() async {
    await ref.read(sessionIsolationServiceProvider).disposeAuthenticatedState();
    await ref.read(sessionManagerProvider).handleUnauthorizedResponse();
    state = const SessionState.expired();
  }

  void markForbidden() {
    state = SessionState.forbidden(session: state.session);
  }
}
