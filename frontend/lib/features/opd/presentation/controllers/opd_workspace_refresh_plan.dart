import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

/// @deprecated Use [WorkspaceEventRefreshPlan.forClinicalFlow].
abstract final class OpdWorkspaceRefreshPlan {
  static WorkspaceRefreshPlan forMessage(RealtimeMessage message) {
    return WorkspaceEventRefreshPlan.forClinicalFlow(message.event);
  }

  static WorkspaceRefreshPlan forEvent(String event) {
    return WorkspaceEventRefreshPlan.forClinicalFlow(event);
  }
}
