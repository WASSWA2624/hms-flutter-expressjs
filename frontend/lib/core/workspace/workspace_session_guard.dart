import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_token_provider.dart';
import 'package:hosspi_hms/core/workspace/workspace_bootstrap_helpers.dart';

/// Waits until the persisted session has finished restoring and a bearer token
/// is available before workspace controllers issue authenticated API calls.
Future<void> awaitAuthenticatedWorkspaceSession(Ref ref) async {
  await _awaitSessionReady(ref);

  final SessionState session = ref.read(sessionStateProvider);
  if (!session.isAuthenticated) {
    return;
  }

  await ref.read(sessionTokenProvider).ensureAccessTokenReady();
}

Future<void> _awaitSessionReady(Ref ref) async {
  final SessionState current = ref.read(sessionStateProvider);
  if (current.isAuthenticated || current.status != SessionStatus.unknown) {
    return;
  }

  final Completer<void> completer = Completer<void>();
  late final ProviderSubscription<SessionState> subscription;
  subscription = ref.listen<SessionState>(sessionStateProvider, (
    SessionState? previous,
    SessionState next,
  ) {
    if (next.isAuthenticated || next.status != SessionStatus.unknown) {
      if (!completer.isCompleted) {
        completer.complete();
      }
      subscription.close();
    }
  });
  ref.onDispose(subscription.close);

  final SessionState latest = ref.read(sessionStateProvider);
  if (latest.isAuthenticated || latest.status != SessionStatus.unknown) {
    subscription.close();
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      subscription.close();
    },
  );
}

/// Runs an initial workspace load with short retries for transient network or
/// auth timing failures that can happen while the shell bootstraps providers.
Future<Result<T>> runWorkspaceInitialLoad<T>(
  Ref ref,
  Future<Result<T>> Function() load, {
  int maxAttempts = 3,
}) async {
  return _runWorkspaceInitialLoadInner(
    ref,
    load,
    maxAttempts: maxAttempts,
  ).timeout(
    const Duration(seconds: 45),
    onTimeout: () => Result<T>.failure(
      _finalizeWorkspaceBootstrapFailure(ref, const AppFailure.timeout()),
    ),
  );
}

Future<Result<T>> _runWorkspaceInitialLoadInner<T>(
  Ref ref,
  Future<Result<T>> Function() load, {
  int maxAttempts = 3,
}) async {
  await awaitAuthenticatedWorkspaceSession(ref);

  AppFailure? lastFailure;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(Duration(milliseconds: 120 * attempt));
      if (ref.read(sessionStateProvider).isAuthenticated) {
        await ref.read(sessionTokenProvider).ensureAccessTokenReady();
      }
    }

    final Result<T> result = await load();
    if (result.isSuccess) {
      return result;
    }

    lastFailure = result.when(
      success: (_) => throw StateError('Expected failure result.'),
      failure: (AppFailure failure) => failure,
    );

    if (!_shouldRetryInitialLoadFailure(ref, lastFailure!) ||
        attempt == maxAttempts - 1) {
      return Result<T>.failure(
        _finalizeWorkspaceBootstrapFailure(ref, lastFailure),
      );
    }
  }

  return Result<T>.failure(
    _finalizeWorkspaceBootstrapFailure(
      ref,
      lastFailure ?? const AppFailure.unexpected(),
    ),
  );
}

bool _shouldRetryInitialLoadFailure(Ref ref, AppFailure failure) {
  if (failure.category == AppFailureCategory.network ||
      failure.category == AppFailureCategory.timeout) {
    return true;
  }

  if (failure.category == AppFailureCategory.unauthorized &&
      ref.read(sessionStateProvider).isAuthenticated) {
    return true;
  }

  return false;
}

AppFailure _finalizeWorkspaceBootstrapFailure(Ref ref, AppFailure failure) {
  if (failure.category == AppFailureCategory.unauthorized &&
      ref.read(sessionStateProvider).isAuthenticated) {
    return normalizeWorkspaceBootstrapFailure(failure);
  }

  return failure;
}
