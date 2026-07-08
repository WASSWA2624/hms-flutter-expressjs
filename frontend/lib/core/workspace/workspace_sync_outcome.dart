import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

/// Result of attempting to apply a realtime message without HTTP.
sealed class WorkspaceSyncOutcome {
  const WorkspaceSyncOutcome();
}

/// Local state was updated; [residualPlan] may request a small HTTP follow-up.
final class WorkspaceSyncPatched extends WorkspaceSyncOutcome {
  const WorkspaceSyncPatched({this.residualPlan = WorkspaceRefreshPlan.none});

  final WorkspaceRefreshPlan residualPlan;
}

/// Local patch was not possible; run HTTP sync for [plan].
final class WorkspaceSyncNeedsHttp extends WorkspaceSyncOutcome {
  const WorkspaceSyncNeedsHttp(this.plan);

  final WorkspaceRefreshPlan plan;
}

/// Event does not map to any refresh work.
final class WorkspaceSyncIgnored extends WorkspaceSyncOutcome {
  const WorkspaceSyncIgnored();
}
