import 'package:hosspi_hms/core/realtime/realtime_events.dart';

/// Reusable event groups used by workspace controllers to keep visible data
/// synchronized without duplicating long event lists across modules.
abstract final class RealtimeEventGroups {
  static const Set<String> appointments = <String>{
    RealtimeEvents.appointmentCreated,
    RealtimeEvents.appointmentRescheduled,
    RealtimeEvents.appointmentCanceled,
  };

  static const Set<String> opdFlow = <String>{
    RealtimeEvents.opdFlowUpdated,
    RealtimeEvents.visitQueuePositionChanged,
    RealtimeEvents.visitQueueTriageUpdated,
  };

  static const Set<String> admissions = <String>{
    RealtimeEvents.ipdFlowUpdated,
    RealtimeEvents.patientAdmitted,
    RealtimeEvents.patientTransferred,
    RealtimeEvents.patientDischarged,
    RealtimeEvents.bedAssignmentChanged,
  };

  static const Set<String> criticalAlerts = <String>{
    RealtimeEvents.criticalAlertRaised,
    RealtimeEvents.criticalAlertResolved,
  };

  static const Set<String> diagnostics = <String>{
    RealtimeEvents.labWorkflowUpdated,
    RealtimeEvents.labResultReady,
    RealtimeEvents.labResultUpdated,
    RealtimeEvents.radiologyWorkflowUpdated,
    RealtimeEvents.radiologyResultReady,
    RealtimeEvents.radiologyResultUpdated,
  };

  static const Set<String> pharmacy = <String>{
    RealtimeEvents.pharmacyWorkspaceUpdated,
    RealtimeEvents.pharmacyOrderCreated,
    RealtimeEvents.pharmacyOrderUpdated,
    RealtimeEvents.pharmacyOrderDispensed,
    RealtimeEvents.pharmacyOrderCanceled,
    RealtimeEvents.inventoryStockUpdated,
    RealtimeEvents.inventoryLowStock,
    RealtimeEvents.inventoryStockAdjusted,
  };

  static const Set<String> billing = <String>{
    RealtimeEvents.billingInvoiceIssued,
    RealtimeEvents.billingPaymentReceived,
    RealtimeEvents.billingRefundProcessed,
  };

  static const Set<String> emergency = <String>{
    RealtimeEvents.emergencyCaseAssigned,
    RealtimeEvents.ambulanceDispatched,
    RealtimeEvents.ambulanceArrivalUpdated,
  };

  static const Set<String> patientRegistry = <String>{
    ...appointments,
    ...opdFlow,
    ...admissions,
    ...criticalAlerts,
    ...diagnostics,
    ...pharmacy,
    ...billing,
    ...emergency,
  };

  static const Set<String> opd = <String>{
    ...appointments,
    ...opdFlow,
    ...admissions,
    ...criticalAlerts,
    ...diagnostics,
    ...pharmacy,
    ...billing,
    ...emergency,
  };

  static const Set<String> clinical = <String>{
    ...opdFlow,
    ...admissions,
    ...criticalAlerts,
    ...diagnostics,
    ...pharmacy,
    ...billing,
  };

  static const Set<String> ipd = <String>{
    ...admissions,
    ...criticalAlerts,
    ...diagnostics,
    ...pharmacy,
    ...billing,
  };

  static const Set<String> icu = <String>{
    ...admissions,
    ...criticalAlerts,
    ...diagnostics,
    ...pharmacy,
  };

  static const Set<String> nursing = <String>{
    ...admissions,
    ...criticalAlerts,
    ...diagnostics,
    ...pharmacy,
    ...billing,
  };

  static const Set<String> lab = <String>{
    RealtimeEvents.labWorkflowUpdated,
    RealtimeEvents.labResultReady,
    RealtimeEvents.labResultUpdated,
  };

  static const Set<String> radiology = <String>{
    RealtimeEvents.radiologyWorkflowUpdated,
    RealtimeEvents.radiologyResultReady,
    RealtimeEvents.radiologyResultUpdated,
  };

  static const Set<String> pharmacyWorkspace = <String>{
    ...pharmacy,
    ...admissions,
    ...criticalAlerts,
    ...billing,
  };

  static const Set<String> emergencyWorkspace = <String>{
    ...emergency,
    ...appointments,
    ...opdFlow,
    ...admissions,
    ...criticalAlerts,
  };

  static const Set<String> billingWorkspace = <String>{
    ...billing,
    ...admissions,
    ...pharmacy,
  };

  static const Set<String> claims = <String>{
    ...billing,
    ...admissions,
  };

  static const Set<String> discharge = <String>{
    ...admissions,
    ...pharmacy,
    ...billing,
  };

  static const Set<String> theater = <String>{
    ...admissions,
    ...criticalAlerts,
  };
}
