import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_realtime_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

/// Applies realtime sync using local deltas first, then targeted HTTP refresh.
Future<void> handleWorkspaceListRealtimeSync<T>({
  required RealtimeMessage message,
  required WorkspaceRefreshProfile profile,
  required T? currentState,
  required bool isDeferred,
  required WorkspacePendingRefresh pendingRefresh,
  required void Function(T state) emit,
  required Future<void> Function({required WorkspaceRefreshPlan plan}) syncHttp,
  WorkspaceRealtimeDeltaApplier<T>? applyDelta,
}) async {
  if (isDeferred) {
    pendingRefresh.defer(
      WorkspaceEventRefreshPlan.forMessage(message, profile: profile),
    );
    return;
  }

  final WorkspaceSyncOutcome outcome = resolveWorkspaceRealtime<T>(
    message: message,
    profile: profile,
    currentState: currentState,
    applyDelta: applyDelta,
  );

  if (outcome is WorkspaceSyncIgnored) {
    return;
  }
  if (outcome is WorkspaceSyncPatched<T>) {
    emit(outcome.state);
    if (!outcome.residualPlan.isEmpty) {
      await syncHttp(plan: outcome.residualPlan);
    }
    return;
  }
  if (outcome is WorkspaceSyncNeedsHttp) {
    if (outcome.plan.isEmpty) {
      return;
    }
    await syncHttp(plan: outcome.plan);
  }
}
