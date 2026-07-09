import 'package:hosspi_hms/core/realtime/realtime_crud_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

/// Maps realtime events to the smallest HTTP refresh plan per workspace profile.
abstract final class WorkspaceEventRefreshPlan {
  static WorkspaceRefreshPlan forMessage(
    RealtimeMessage message, {
    required WorkspaceRefreshProfile profile,
  }) {
    return forEvent(message.event, profile: profile);
  }

  static WorkspaceRefreshPlan forEvent(
    String event, {
    required WorkspaceRefreshProfile profile,
  }) {
    return switch (profile) {
      WorkspaceRefreshProfile.clinicalFlow => forClinicalFlow(event),
      WorkspaceRefreshProfile.admissions => forAdmissions(event),
      WorkspaceRefreshProfile.patientRegistry => forPatientRegistry(event),
      WorkspaceRefreshProfile.lab => forLab(event),
      WorkspaceRefreshProfile.pharmacy => forPharmacy(event),
      WorkspaceRefreshProfile.radiology => forRadiology(event),
      WorkspaceRefreshProfile.emergency => forEmergency(event),
      WorkspaceRefreshProfile.biomedical => forBiomedical(event),
      WorkspaceRefreshProfile.operations => forOperations(event),
      WorkspaceRefreshProfile.hr => forHr(event),
      WorkspaceRefreshProfile.fullOnMatch => forFullOnMatch(event),
    };
  }

  static WorkspaceRefreshPlan forClinicalFlow(String event) {
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

  static WorkspaceRefreshPlan forAdmissions(String event) {
    if (RealtimeEventGroups.admissions.contains(event) ||
        RealtimeEventGroups.diagnostics.contains(event) ||
        RealtimeEventGroups.pharmacy.contains(event) ||
        RealtimeEventGroups.billing.contains(event) ||
        RealtimeEventGroups.criticalAlerts.contains(event) ||
        RealtimeEventGroups.encounters.contains(event)) {
      return WorkspaceRefreshPlan.admissionWorkspace;
    }
    if (RealtimeEventGroups.visitQueue.contains(event) ||
        RealtimeEventGroups.opdFlow.contains(event)) {
      return const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      );
    }
    if (RealtimeCrudEvents.matches(event)) {
      return WorkspaceRefreshPlan.admissionWorkspace;
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forPatientRegistry(String event) {
    if (RealtimeEventGroups.patients.contains(event)) {
      return const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
        summaryCounts: true,
      );
    }
    if (RealtimeEventGroups.appointments.contains(event) ||
        RealtimeEventGroups.opdFlow.contains(event) ||
        RealtimeEventGroups.admissions.contains(event) ||
        RealtimeEventGroups.diagnostics.contains(event) ||
        RealtimeEventGroups.pharmacy.contains(event) ||
        RealtimeEventGroups.billing.contains(event) ||
        RealtimeEventGroups.emergency.contains(event) ||
        RealtimeEventGroups.criticalAlerts.contains(event)) {
      return const WorkspaceRefreshPlan(primaryList: true, summaryCounts: true);
    }
    if (RealtimeCrudEvents.matches(event)) {
      return const WorkspaceRefreshPlan(primaryList: true, summaryCounts: true);
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forLab(String event) {
    if (event == RealtimeEvents.labCatalogUpdated) {
      return const WorkspaceRefreshPlan(catalogs: true);
    }
    if (RealtimeEventGroups.lab.contains(event) ||
        RealtimeEventGroups.billing.contains(event) ||
        RealtimeCrudEvents.matches(event)) {
      return const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      );
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forPharmacy(String event) {
    if (RealtimeEventGroups.pharmacy.contains(event) ||
        RealtimeEventGroups.billing.contains(event) ||
        RealtimeCrudEvents.matches(event)) {
      final bool inventoryEvent =
          event == RealtimeEvents.inventoryStockUpdated ||
          event == RealtimeEvents.inventoryLowStock ||
          event == RealtimeEvents.inventoryStockAdjusted;
      return WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
        inventory: inventoryEvent,
      );
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forRadiology(String event) {
    if (RealtimeEventGroups.radiology.contains(event) ||
        RealtimeEventGroups.billing.contains(event) ||
        RealtimeCrudEvents.matches(event)) {
      return const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      );
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forEmergency(String event) {
    if (RealtimeEventGroups.emergencyWorkspace.contains(event) ||
        RealtimeCrudEvents.matches(event)) {
      final bool refreshReference =
          event == RealtimeEvents.ambulanceDispatched ||
          event == RealtimeEvents.ambulanceArrivalUpdated;
      return WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
        referenceData: refreshReference,
      );
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forBiomedical(String event) {
    if (RealtimeEventGroups.biomedical.contains(event) ||
        RealtimeCrudEvents.matches(event)) {
      return const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      );
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forOperations(String event) {
    if (RealtimeEventGroups.operations.contains(event) ||
        RealtimeEventGroups.admissions.contains(event) ||
        RealtimeCrudEvents.matches(event)) {
      return const WorkspaceRefreshPlan(
        primaryList: true,
        selectedDetail: true,
      );
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forHr(String event) {
    if (RealtimeEventGroups.hr.contains(event) ||
        RealtimeCrudEvents.matches(event)) {
      return WorkspaceRefreshPlan.full;
    }
    return WorkspaceRefreshPlan.none;
  }

  static WorkspaceRefreshPlan forFullOnMatch(String event) {
    if (RealtimeCrudEvents.matches(event)) {
      return WorkspaceRefreshPlan.full;
    }
    return WorkspaceRefreshPlan.full;
  }
}

enum WorkspaceRefreshProfile {
  clinicalFlow,
  admissions,
  patientRegistry,
  lab,
  pharmacy,
  radiology,
  emergency,
  biomedical,
  operations,
  hr,
  fullOnMatch,
}
