import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta_decoder.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_sync_outcome.dart';

/// Applies realtime deltas when possible and falls back to HTTP refresh plans.
abstract final class WorkspaceSyncEngine {
  static WorkspaceSyncOutcome resolve<T>({
    required RealtimeMessage message,
    required WorkspaceRefreshProfile profile,
    required T? currentState,
    required T? Function(T state, RealtimeDelta delta)? applyDelta,
  }) {
    final WorkspaceRefreshPlan httpPlan = WorkspaceEventRefreshPlan.forMessage(
      message,
      profile: profile,
    );

    if (currentState == null || applyDelta == null) {
      if (httpPlan.isEmpty) {
        return const WorkspaceSyncIgnored();
      }
      return WorkspaceSyncNeedsHttp(httpPlan);
    }

    final RealtimeDelta? delta = RealtimeDeltaDecoder.tryDecode(message);
    if (delta == null || !delta.canApplyLocally) {
      if (httpPlan.isEmpty) {
        return const WorkspaceSyncIgnored();
      }
      return WorkspaceSyncNeedsHttp(httpPlan);
    }

    final T? patched = applyDelta(currentState, delta);
    if (patched == null) {
      if (httpPlan.isEmpty) {
        return const WorkspaceSyncIgnored();
      }
      return WorkspaceSyncNeedsHttp(httpPlan);
    }

    final WorkspaceRefreshPlan residualPlan = RealtimeDeltaDecoder.residualPlan(
      message,
      httpPlan,
    );
    return WorkspaceSyncPatched<T>(
      state: patched,
      residualPlan: residualPlan,
    );
  }
}
