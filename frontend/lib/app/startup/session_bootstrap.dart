import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_token_provider.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_session_isolation.dart';

/// Refreshes expired access tokens on startup so users stay signed in.
///
/// Also re-runs `/auth/me` enrichment when a tenant JWT restore is missing the
/// module catalog (common after hot reload resets [SessionController]).
class SessionBootstrap extends ConsumerStatefulWidget {
  const SessionBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SessionBootstrap> createState() => _SessionBootstrapState();
}

class _SessionBootstrapState extends ConsumerState<SessionBootstrap> {
  bool _enrichInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreSessionIfNeeded());
    });
  }

  Future<void> _restoreSessionIfNeeded() async {
    if (_enrichInFlight || !mounted) {
      return;
    }

    final sessionState = ref.read(sessionStateProvider);
    if (!sessionState.isAuthenticated) {
      return;
    }

    final AuthSession? session = sessionState.session;
    final tokens = session?.tokens;
    if (session == null || tokens == null) {
      return;
    }

    final bool needsEnrichment = session.needsMeEnrichment;
    final bool accessExpired = tokens.isAccessTokenExpired(
      DateTime.now().toUtc(),
    );
    if (!needsEnrichment && !(accessExpired && tokens.hasRefreshToken)) {
      return;
    }

    _enrichInFlight = true;
    try {
      final tokenProvider = ref.read(sessionTokenProvider);
      if (accessExpired && tokens.hasRefreshToken) {
        await tokenProvider.refreshStoredSession();
      }

      final AuthSession? current = ref.read(sessionStateProvider).session;
      if (current != null && current.needsMeEnrichment) {
        await tokenProvider.enrichAuthenticatedSession();
      }
    } finally {
      _enrichInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Drop keep-alive home dashboard payloads on logout / account switch.
    ref.watch(homeSessionIsolationBinderProvider);

    ref.listen(sessionStateProvider, (previous, next) {
      final AuthSession? session = next.session;
      if (next.isAuthenticated &&
          session != null &&
          session.needsMeEnrichment) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_restoreSessionIfNeeded());
        });
      }
    });

    final AuthSession? session = ref.watch(
      sessionStateProvider.select((state) => state.session),
    );
    if (session != null && session.needsMeEnrichment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_restoreSessionIfNeeded());
      });
    }

    return widget.child;
  }
}
