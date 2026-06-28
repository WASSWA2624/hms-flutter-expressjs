import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';

/// Waits until the persisted session has finished restoring before workspace
/// controllers issue their first authenticated API calls.
Future<void> awaitAuthenticatedWorkspaceSession(Ref ref) {
  final SessionState current = ref.read(sessionStateProvider);
  if (current.isAuthenticated || current.status != SessionStatus.unknown) {
    return Future<void>.value();
  }

  final Completer<void> completer = Completer<void>();
  late final ProviderSubscription<SessionState> subscription;
  subscription = ref.listen<SessionState>(
    sessionStateProvider,
    (SessionState? previous, SessionState next) {
      if (next.isAuthenticated || next.status != SessionStatus.unknown) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        subscription.close();
      }
    },
  );
  ref.onDispose(subscription.close);

  final SessionState latest = ref.read(sessionStateProvider);
  if (latest.isAuthenticated || latest.status != SessionStatus.unknown) {
    subscription.close();
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  return completer.future;
}

/// Runs an initial workspace load with short retries for transient network
/// failures that can happen while the shell bootstraps many providers.
Future<Result<T>> runWorkspaceInitialLoad<T>(
  Ref ref,
  Future<Result<T>> Function() load, {
  int maxAttempts = 3,
}) async {
  await awaitAuthenticatedWorkspaceSession(ref);

  AppFailure? lastFailure;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(Duration(milliseconds: 120 * attempt));
    }

    final Result<T> result = await load();
    if (result.isSuccess) {
      return result;
    }

    lastFailure = result.when(
      success: (_) => throw StateError('Expected failure result.'),
      failure: (AppFailure failure) => failure,
    );
    if (!_isRetryableInitialLoadFailure(lastFailure!) ||
        attempt == maxAttempts - 1) {
      return Result<T>.failure(lastFailure);
    }
  }

  return Result<T>.failure(lastFailure ?? const AppFailure.unexpected());
}

bool _isRetryableInitialLoadFailure(AppFailure failure) {
  return failure.category == AppFailureCategory.network ||
      failure.category == AppFailureCategory.timeout;
}
