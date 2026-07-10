import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/realtime/realtime_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_service.dart';
import 'package:hosspi_hms/core/workspace/workspace_adaptive_polling.dart';
import 'package:hosspi_hms/core/workspace/workspace_disconnect_poll_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

export 'package:hosspi_hms/core/workspace/primary_list_page_sync.dart'
    show PrimaryListPageSync;
export 'package:hosspi_hms/core/workspace/workspace_list_realtime_sync.dart'
    show handleWorkspaceListRealtimeSync;
export 'package:hosspi_hms/core/workspace/workspace_disconnect_poll_plan.dart'
    show WorkspaceDisconnectPollPlan;
export 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart'
    show WorkspaceRefreshPlan;
export 'package:hosspi_hms/core/workspace/workspace_realtime_sync.dart'
    show
        WorkspaceSyncEngine,
        WorkspaceSyncIgnored,
        WorkspaceSyncNeedsHttp,
        WorkspaceSyncOutcome,
        WorkspaceSyncPatched,
        mergeWorkspaceRefreshPlan,
        resolveWorkspaceRealtime;

/// Wires adaptive polling that runs only while WebSocket transport is down.
void installWorkspaceAdaptivePolling({
  required Ref ref,
  required WorkspaceAdaptivePolling polling,
  required Duration intervalWhenDisconnected,
  required WorkspaceRefreshProfile disconnectProfile,
  required Future<void> Function(WorkspaceRefreshPlan plan) syncOnDisconnect,
}) {
  ref.onDispose(polling.dispose);
  ref.listen<AsyncValue<RealtimeConnectionState>>(
    realtimeConnectionStateProvider,
    (_, _) => polling.onConnectionStateChanged(),
  );
  polling.start(
    intervalWhenDisconnected: intervalWhenDisconnected,
    isRealtimeConnected: () => ref.read(realtimeServiceProvider).isConnected,
    onTick: () => unawaited(
      syncOnDisconnect(
        WorkspaceDisconnectPollPlan.forProfile(disconnectProfile),
      ),
    ),
  );
}

/// Tracks deferred realtime refresh plans while saves or syncs are in flight.
final class WorkspacePendingRefresh {
  bool refreshPending = false;
  WorkspaceRefreshPlan? pendingPlan;

  WorkspaceRefreshPlan merge(WorkspaceRefreshPlan plan) {
    final WorkspaceRefreshPlan? current = pendingPlan;
    if (current == null) {
      return plan;
    }
    return current.merge(plan);
  }

  void defer(WorkspaceRefreshPlan plan) {
    refreshPending = true;
    pendingPlan = merge(plan);
  }

  WorkspaceRefreshPlan takePending({
    WorkspaceRefreshPlan fallback = WorkspaceRefreshPlan.full,
  }) {
    refreshPending = false;
    final WorkspaceRefreshPlan plan = pendingPlan ?? fallback;
    pendingPlan = null;
    return plan;
  }
}

bool workspacePlanRefreshesPrimaryList(WorkspaceRefreshPlan plan) {
  return plan.primaryList ||
      plan.flows ||
      plan.queue ||
      plan.triage ||
      plan.appointments ||
      plan.summaryCounts;
}

bool workspacePlanRefreshesReferenceData(WorkspaceRefreshPlan plan) {
  return plan.referenceData || plan.catalogs;
}
