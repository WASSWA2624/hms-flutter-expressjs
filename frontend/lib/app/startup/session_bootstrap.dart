import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_token_provider.dart';

/// Refreshes expired access tokens on startup so users stay signed in.
class SessionBootstrap extends ConsumerStatefulWidget {
  const SessionBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SessionBootstrap> createState() => _SessionBootstrapState();
}

class _SessionBootstrapState extends ConsumerState<SessionBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreSessionIfNeeded());
    });
  }

  Future<void> _restoreSessionIfNeeded() async {
    final sessionState = ref.read(sessionStateProvider);
    if (!sessionState.isAuthenticated) {
      return;
    }

    final tokens = sessionState.session?.tokens;
    if (tokens == null) {
      return;
    }

    if (tokens.isAccessTokenExpired(DateTime.now().toUtc()) &&
        tokens.hasRefreshToken) {
      await ref.read(sessionTokenProvider).refreshStoredSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
