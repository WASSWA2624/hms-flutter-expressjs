import 'package:flutter_template/core/permissions/app_permission.dart';
import 'package:flutter_template/core/security/auth_session.dart';

enum SessionStatus {
  unknown,
  unauthenticated,
  authenticated,
  expired,
  forbidden,
}

class SessionState {
  const SessionState.ready()
    : status = SessionStatus.unauthenticated,
      session = null;

  const SessionState.notReady()
    : status = SessionStatus.unknown,
      session = null;

  const SessionState.unauthenticated()
    : status = SessionStatus.unauthenticated,
      session = null;

  const SessionState.authenticated({this.session})
    : status = SessionStatus.authenticated;

  const SessionState.expired() : status = SessionStatus.expired, session = null;

  const SessionState.forbidden({this.session})
    : status = SessionStatus.forbidden;

  final SessionStatus status;
  final AuthSession? session;

  bool get isReady => status != SessionStatus.unknown;

  bool get hasRestoredSession => status == SessionStatus.authenticated;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  Set<AppPermission> get permissions {
    return session?.permissions ?? const <AppPermission>{};
  }

  bool hasPermission(AppPermission permission) {
    return permissions.grants(permission);
  }

  bool hasAllPermissions(Iterable<AppPermission> requiredPermissions) {
    return permissions.grantsAll(requiredPermissions);
  }
}
