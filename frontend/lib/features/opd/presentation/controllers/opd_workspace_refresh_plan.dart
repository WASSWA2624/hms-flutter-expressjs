import 'package:hosspi_hms/core/realtime/realtime_crud_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

/// Maps OPD realtime events to the smallest HTTP refresh needed for live UI.
abstract final class OpdWorkspaceRefreshPlan {
  static WorkspaceRefreshPlan forMessage(RealtimeMessage message) {
    return forEvent(message.event);
  }

  static WorkspaceRefreshPlan forEvent(String event) {
    if (RealtimeEventGroups.appointments.contains(event)) {
      return const WorkspaceRefreshPlan(
        appointments: true,
        summaryCounts: true,
      );
    }
    if (RealtimeEventGroups.visitQueue.contains(event)) {
      return WorkspaceRefreshPlan.flowWorkspace.merge(
        const WorkspaceRefreshPlan(queue: true),
      );
    }
    if (RealtimeEventGroups.opdFlow.contains(event) ||
        RealtimeEventGroups.encounters.contains(event)) {
      return WorkspaceRefreshPlan.flowWorkspace;
    }
    if (RealtimeEventGroups.diagnostics.contains(event)) {
      return WorkspaceRefreshPlan.flowWorkspace;
    }
    if (RealtimeEventGroups.pharmacy.contains(event) ||
        RealtimeEventGroups.billing.contains(event) ||
        RealtimeEventGroups.payments.contains(event)) {
      return const WorkspaceRefreshPlan(
        flows: true,
        summaryCounts: true,
        selectedDetail: true,
      );
    }
    if (RealtimeEventGroups.criticalAlerts.contains(event) ||
        RealtimeEventGroups.emergency.contains(event) ||
        RealtimeEventGroups.admissions.contains(event)) {
      return const WorkspaceRefreshPlan(
        flows: true,
        summaryCounts: true,
        selectedDetail: true,
      );
    }
    if (RealtimeCrudEvents.matches(event)) {
      return WorkspaceRefreshPlan.flowWorkspace;
    }
    return WorkspaceRefreshPlan.none;
  }
}
