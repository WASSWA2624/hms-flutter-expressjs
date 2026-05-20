abstract final class RealtimeEvents {
  static const String authenticated = 'authenticated';
  static const String ping = 'ping';
  static const String pong = 'pong';

  static const String appointmentCreated = 'appointment.created';
  static const String appointmentRescheduled = 'appointment.rescheduled';
  static const String appointmentCanceled = 'appointment.canceled';

  static const String opdFlowUpdated = 'opd.flow.updated';
  static const String ipdFlowUpdated = 'ipd.flow.updated';

  static const String visitQueuePositionChanged =
      'visit_queue.position_changed';
  static const String visitQueueTriageUpdated = 'visit_queue.triage_updated';

  static const String patientAdmitted = 'admission.patient_admitted';
  static const String patientTransferred = 'admission.patient_transferred';
  static const String patientDischarged = 'admission.patient_discharged';
  static const String bedAssignmentChanged = 'admission.bed_assignment_changed';

  static const String criticalAlertRaised = 'critical_alert.raised';
  static const String criticalAlertResolved = 'critical_alert.resolved';

  static const String labWorkflowUpdated = 'diagnostic.lab_workflow_updated';
  static const String labResultReady = 'diagnostic.lab_result_ready';
  static const String labResultUpdated = 'diagnostic.lab_result_updated';
  static const String radiologyWorkflowUpdated =
      'diagnostic.radiology_workflow_updated';
  static const String radiologyResultReady =
      'diagnostic.radiology_result_ready';
  static const String radiologyResultUpdated =
      'diagnostic.radiology_result_updated';

  static const String pharmacyWorkspaceUpdated = 'pharmacy.workspace_updated';
  static const String pharmacyOrderUpdated = 'pharmacy.order_updated';
  static const String pharmacyOrderCreated = 'pharmacy.order_created';
  static const String pharmacyOrderDispensed = 'pharmacy.order_dispensed';
  static const String pharmacyOrderCanceled = 'pharmacy.order_canceled';

  static const String hrWorkspaceUpdated = 'hr.workspace_updated';

  static const String inventoryStockUpdated = 'inventory.stock_updated';
  static const String inventoryLowStock = 'inventory.low_stock';
  static const String inventoryStockAdjusted = 'inventory.stock_adjusted';

  static const String biomedicalWorkspaceUpdated =
      'biomedical.workspace_updated';
  static const String biomedicalFaultReported = 'biomedical.fault_reported';
  static const String biomedicalWorkOrderAssigned =
      'biomedical.work_order_assigned';
  static const String biomedicalWorkOrderStarted =
      'biomedical.work_order_started';
  static const String biomedicalWorkOrderReturnedToService =
      'biomedical.work_order_returned_to_service';
  static const String biomedicalOverdueChanged = 'biomedical.overdue_changed';

  static const String billingInvoiceIssued = 'billing.invoice_issued';
  static const String billingPaymentReceived = 'billing.payment_received';
  static const String billingRefundProcessed = 'billing.refund_processed';

  static const String emergencyCaseAssigned = 'emergency.case_assigned';
  static const String ambulanceDispatched = 'emergency.ambulance_dispatched';
  static const String ambulanceArrivalUpdated =
      'emergency.ambulance_arrival_updated';

  static const String housekeepingWorkspaceUpdated =
      'housekeeping.workspace_updated';
  static const String housekeepingTaskUpdated = 'housekeeping.task_updated';
  static const String maintenanceRequestTriaged =
      'housekeeping.maintenance_request_triaged';
  static const String maintenanceRequestConverted =
      'housekeeping.maintenance_request_converted';

  static const String notificationCreated = 'notification.created';
  static const String notificationDeliveryUpdated =
      'notification.delivery_updated';
  static const String conversationMessageCreated =
      'conversation.message_created';
  static const String conversationThreadUpdated = 'conversation.thread_updated';
  static const String conversationReadStateUpdated =
      'conversation.read_state_updated';
}
