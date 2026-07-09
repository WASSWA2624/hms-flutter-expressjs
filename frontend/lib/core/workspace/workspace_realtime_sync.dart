import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_sync_engine.dart';
import 'package:hosspi_hms/core/workspace/workspace_sync_outcome.dart';

export 'package:hosspi_hms/core/workspace/workspace_disconnect_poll_plan.dart'
    show WorkspaceDisconnectPollPlan;
export 'package:hosspi_hms/core/workspace/workspace_sync_engine.dart'
    show WorkspaceSyncEngine;
export 'package:hosspi_hms/core/workspace/workspace_sync_outcome.dart'
    show
        WorkspaceSyncIgnored,
        WorkspaceSyncNeedsHttp,
        WorkspaceSyncOutcome,
        WorkspaceSyncPatched;

typedef WorkspaceRealtimeDeltaApplier<T> =
    T? Function(T state, RealtimeDelta delta);

/// Resolves a realtime message into a local patch and/or HTTP refresh plan.
WorkspaceSyncOutcome resolveWorkspaceRealtime<T>({
  required RealtimeMessage message,
  required WorkspaceRefreshProfile profile,
  required T? currentState,
  WorkspaceRealtimeDeltaApplier<T>? applyDelta,
}) {
  return WorkspaceSyncEngine.resolve<T>(
    message: message,
    profile: profile,
    currentState: currentState,
    applyDelta: applyDelta,
  );
}

/// Merges [plan] into [pending] for deferred realtime refresh coalescing.
WorkspaceRefreshPlan mergeWorkspaceRefreshPlan(
  WorkspaceRefreshPlan? pending,
  WorkspaceRefreshPlan plan,
) {
  if (pending == null) {
    return plan;
  }
  return pending.merge(plan);
}
