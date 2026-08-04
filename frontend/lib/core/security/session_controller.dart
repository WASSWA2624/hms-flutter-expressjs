import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
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
    // Seed from startup restore only. Watching the override re-applies the
    // JWT-only session on rebuild/hot reload and wipes /auth/me enrichment.
    return ref.read(initialSessionStateProvider);
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
        (_normalizedContextId(previousSession.user?.id) !=
                _normalizedContextId(session.user?.id) ||
            _normalizedContextId(previousSession.user?.tenantId) !=
                _normalizedContextId(session.user?.tenantId) ||
            _normalizedContextId(previousSession.user?.facilityId) !=
                _normalizedContextId(session.user?.facilityId));
    // Logout/expiry leave keep-alive providers (e.g. home dashboard) holding
    // the prior account. Isolate again when logging into a cleared session so
    // dashboards and workspace caches reload for the new account immediately.
    final bool reauthAfterClearedSession =
        previousSession == null &&
        (previousState.status == SessionStatus.unauthenticated ||
            previousState.status == SessionStatus.expired);

    if (contextChanged || reauthAfterClearedSession) {
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
      await ref
          .read(sessionIsolationServiceProvider)
          .disposeAuthenticatedState();
      await ref.read(sessionManagerProvider).logout();
      state = const SessionState.unauthenticated();
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> handleUnauthorizedResponse() async {
    state = const SessionState.notReady();
    await ref.read(sessionIsolationServiceProvider).disposeAuthenticatedState();
    await ref.read(sessionManagerProvider).handleUnauthorizedResponse();
    state = const SessionState.expired();
  }

  void markForbidden() {
    state = SessionState.forbidden(session: state.session);
  }
}

String? _normalizedContextId(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// Session identity used to invalidate keep-alive dashboard/workspace loads.
///
/// Watches [sessionEpochProvider] plus user/tenant/facility/roles/auth hydration
/// so login, account switch, and `/auth/me` enrichment all reload the dashboard
/// without requiring a browser refresh.
String watchSessionDashboardScope(Ref ref) {
  watchSessionEpoch(ref);
  return ref.watch(
    sessionStateProvider.select((SessionState state) {
      return _dashboardSessionScope(state);
    }),
  );
}

String dashboardSessionScope(SessionState state) => _dashboardSessionScope(state);

String _dashboardSessionScope(SessionState state) {
  final AuthSession? session = state.session;
  final user = session?.user;
  final List<String> roles = List<String>.of(user?.roles ?? const <String>[]);
  roles.sort();
  final List<String> permissionValues =
      (session?.permissions ?? const <AppPermission>{})
          .map((AppPermission permission) => permission.value)
          .toList(growable: true);
  permissionValues.sort();
  final List<String> moduleCodes = List<String>.of(
    session?.moduleEntitlements.keys ?? const <String>[],
  );
  moduleCodes.sort();
  return <String>[
    state.status.name,
    user?.id ?? '',
    user?.tenantId ?? '',
    user?.facilityId ?? '',
    roles.join(','),
    permissionValues.join(','),
    session?.isAuthorizationHydrated == true ? '1' : '0',
    session?.isModuleCatalogHydrated == true ? '1' : '0',
    moduleCodes.join(','),
  ].join('|');
}
