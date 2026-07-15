import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';

/// Visual / contextual placement for permission-aware actions.
enum AppActionPlacement {
  /// Rendered inline in the action row/panel.
  inline,

  /// Rendered inside an overflow / "more actions" menu.
  overflow,

  /// Intended for workspace/toolbars (treated as inline by lists).
  toolbar,
}

/// Lifecycle phases for permission-aware async actions.
enum AppActionPhase {
  idle,
  prerequisiteDisabled,
  confirming,
  inFlight,
  success,
  failure,
}

/// Context passed to repository-bound mutation callbacks.
@immutable
final class AppActionMutationContext {
  const AppActionMutationContext({
    required this.idempotencyKey,
    required this.isRetry,
  });

  /// Stable key for this logical mutation (reused on retry).
  final String idempotencyKey;

  /// True when this invocation is a retry of a prior failed attempt.
  final bool isRetry;

  /// Dio options with the [Idempotency-Key] header for retryable mutations.
  Options toRequestOptions({Map<String, dynamic>? headers}) {
    return idempotentRequestOptions(
      idempotencyKey: idempotencyKey,
      headers: headers,
    );
  }
}

/// Immutable snapshot of an [AppActionRunner] lifecycle.
@immutable
final class AppActionLifecycleSnapshot {
  const AppActionLifecycleSnapshot({
    required this.phase,
    this.failure,
    this.idempotencyKey,
  });

  static const AppActionLifecycleSnapshot idle = AppActionLifecycleSnapshot(
    phase: AppActionPhase.idle,
  );

  final AppActionPhase phase;
  final AppFailure? failure;
  final String? idempotencyKey;

  bool get isIdle => phase == AppActionPhase.idle;
  bool get isInFlight => phase == AppActionPhase.inFlight;
  bool get isBusy =>
      phase == AppActionPhase.inFlight || phase == AppActionPhase.confirming;
  bool get isSuccess => phase == AppActionPhase.success;
  bool get isFailure => phase == AppActionPhase.failure;

  bool get canRetry =>
      phase == AppActionPhase.failure && (failure?.isRetryable ?? false);

  AppActionLifecycleSnapshot copyWith({
    AppActionPhase? phase,
    AppFailure? failure,
    String? idempotencyKey,
    bool clearFailure = false,
    bool clearIdempotencyKey = false,
  }) {
    return AppActionLifecycleSnapshot(
      phase: phase ?? this.phase,
      failure: clearFailure ? null : (failure ?? this.failure),
      idempotencyKey: clearIdempotencyKey
          ? null
          : (idempotencyKey ?? this.idempotencyKey),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppActionLifecycleSnapshot &&
            other.phase == phase &&
            other.failure == failure &&
            other.idempotencyKey == idempotencyKey;
  }

  @override
  int get hashCode => Object.hash(phase, failure, idempotencyKey);
}

typedef AppActionMutate =
    Future<AppFailure?> Function(AppActionMutationContext context);

/// Runs mutations with double-submit prevention and idempotent retries.
///
/// Controllers invoke repositories over HTTP; widgets only trigger [run] /
/// [retry]. On success callers patch Riverpod; on cancel/failure they must not.
///
/// Online-only actions (payments, refunds, break-glass, etc.) set
/// [onlineOnly] and pass [isOnline] — the runner never queues them.
final class AppActionRunner extends ChangeNotifier {
  AppActionRunner({this.onlineOnly = false, String Function()? createKey})
    : _createKey = createKey ?? createIdempotencyKey;

  /// When true, mutations are refused while offline (never queued).
  final bool onlineOnly;

  final String Function() _createKey;

  AppActionLifecycleSnapshot _snapshot = AppActionLifecycleSnapshot.idle;

  AppActionLifecycleSnapshot get snapshot => _snapshot;

  AppActionPhase get phase => _snapshot.phase;

  AppFailure? get failure => _snapshot.failure;

  String? get idempotencyKey => _snapshot.idempotencyKey;

  bool get isInFlight => _snapshot.isInFlight;

  bool get canRetry => _snapshot.canRetry;

  /// Marks the action as blocked by a prerequisite/workflow capability.
  void markPrerequisiteDisabled() {
    _setSnapshot(
      const AppActionLifecycleSnapshot(
        phase: AppActionPhase.prerequisiteDisabled,
      ),
    );
  }

  /// Marks that a confirmation dialog is open (optional UI hint).
  void markConfirming() {
    if (_snapshot.isInFlight) {
      return;
    }
    _setSnapshot(
      _snapshot.copyWith(phase: AppActionPhase.confirming, clearFailure: true),
    );
  }

  /// Clears confirming state when the user cancels a confirmation dialog.
  void cancelConfirmation() {
    if (_snapshot.phase != AppActionPhase.confirming) {
      return;
    }
    _setSnapshot(AppActionLifecycleSnapshot.idle);
  }

  /// Executes [mutate] once. Concurrent calls while in-flight are ignored.
  ///
  /// Returns `null` on success. Returns [AppFailure.cancelled] when a duplicate
  /// in-flight submission is ignored. On cancel/failure the domain state must
  /// remain unchanged (caller responsibility).
  Future<AppFailure?> run(AppActionMutate mutate, {bool? isOnline}) {
    return _execute(mutate, reuseKey: false, isOnline: isOnline);
  }

  /// Retries the last failed mutation using the same idempotency key.
  ///
  /// If there is no prior key (first attempt), behaves like [run].
  Future<AppFailure?> retry(AppActionMutate mutate, {bool? isOnline}) {
    return _execute(mutate, reuseKey: true, isOnline: isOnline);
  }

  /// Resets to idle and clears any idempotency key / failure.
  void reset() {
    _setSnapshot(AppActionLifecycleSnapshot.idle);
  }

  Future<AppFailure?> _execute(
    AppActionMutate mutate, {
    required bool reuseKey,
    bool? isOnline,
  }) async {
    if (_snapshot.isInFlight) {
      return const AppFailure.cancelled();
    }

    if (onlineOnly && isOnline == false) {
      const AppFailure offline = AppFailure.offline();
      _setSnapshot(
        AppActionLifecycleSnapshot(
          phase: AppActionPhase.failure,
          failure: offline,
          idempotencyKey: _snapshot.idempotencyKey,
        ),
      );
      return offline;
    }

    final String key =
        reuseKey && (_snapshot.idempotencyKey?.isNotEmpty ?? false)
        ? _snapshot.idempotencyKey!
        : _createKey();

    _setSnapshot(
      AppActionLifecycleSnapshot(
        phase: AppActionPhase.inFlight,
        idempotencyKey: key,
      ),
    );

    final AppFailure? result = await mutate(
      AppActionMutationContext(idempotencyKey: key, isRetry: reuseKey),
    );

    if (result == null) {
      _setSnapshot(
        AppActionLifecycleSnapshot(
          phase: AppActionPhase.success,
          idempotencyKey: key,
        ),
      );
      return null;
    }

    if (result.category == AppFailureCategory.cancelled) {
      // Cancel leaves domain state unchanged; runner returns to idle.
      _setSnapshot(
        AppActionLifecycleSnapshot(
          phase: AppActionPhase.idle,
          idempotencyKey: key,
        ),
      );
      return result;
    }

    _setSnapshot(
      AppActionLifecycleSnapshot(
        phase: AppActionPhase.failure,
        failure: result,
        idempotencyKey: key,
      ),
    );
    return result;
  }

  void _setSnapshot(AppActionLifecycleSnapshot next) {
    if (next == _snapshot) {
      return;
    }
    _snapshot = next;
    notifyListeners();
  }
}
