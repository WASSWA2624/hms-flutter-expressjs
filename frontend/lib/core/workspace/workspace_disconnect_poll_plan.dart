import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

/// Targeted HTTP refresh plans used when WebSocket transport is unavailable.
abstract final class WorkspaceDisconnectPollPlan {
  static WorkspaceRefreshPlan forProfile(WorkspaceRefreshProfile profile) {
    return switch (profile) {
      WorkspaceRefreshProfile.clinicalFlow => WorkspaceRefreshPlan.flowWorkspace
          .merge(
            const WorkspaceRefreshPlan(
              appointments: true,
              queue: true,
            ),
          ),
      WorkspaceRefreshProfile.admissions =>
        WorkspaceRefreshPlan.admissionWorkspace,
      WorkspaceRefreshProfile.patientRegistry => const WorkspaceRefreshPlan(
        primaryList: true,
        summaryCounts: true,
      ),
      WorkspaceRefreshProfile.lab => const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      ),
      WorkspaceRefreshProfile.pharmacy => const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
        inventory: true,
      ),
      WorkspaceRefreshProfile.radiology => const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      ),
      WorkspaceRefreshProfile.emergency => const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
        referenceData: true,
      ),
      WorkspaceRefreshProfile.biomedical => const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      ),
      WorkspaceRefreshProfile.operations => const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      ),
      WorkspaceRefreshProfile.hr => WorkspaceRefreshPlan.full,
      WorkspaceRefreshProfile.fullOnMatch => WorkspaceRefreshPlan.full,
    };
  }
}
