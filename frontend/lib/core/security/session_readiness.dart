import 'package:flutter_template/core/security/session_state.dart';

export 'package:flutter_template/core/security/session_state.dart'
    show SessionState, SessionStatus;

@Deprecated('Use SessionState instead.')
final class SessionReadiness extends SessionState {
  const SessionReadiness.ready() : super.ready();

  const SessionReadiness.notReady() : super.notReady();

  const SessionReadiness.unauthenticated() : super.unauthenticated();

  const SessionReadiness.authenticated() : super.authenticated();

  const SessionReadiness.expired() : super.expired();

  const SessionReadiness.forbidden() : super.forbidden();
}
