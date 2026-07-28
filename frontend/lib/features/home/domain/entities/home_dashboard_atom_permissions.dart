import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

/// Permission gates for home dashboard atoms, aligned with `Dashboard.md`.
///
/// Semantics are **all-of**: a widget renders only when
/// `policy.grantsAll(requiredPermissions)` is true.
///
/// Empty lists after resolution mean **deny** for KPIs, queues, alerts, and
/// activity — never silently public.
abstract final class HomeDashboardAtomPermissions {
  /// Status / KPI card ids → required permissions.
  static const Map<String, List<AppPermission>> statusCards =
      <String, List<AppPermission>>{
        // System admin (Dashboard.md §1)
        'tenants_active': <AppPermission>[AppPermissions.systemAdmin],
        // facilities_active is shared with tenant admin — declare on templates.
        'subscriptions_health': <AppPermission>[
          AppPermissions.subscriptionsRead,
        ],
        'module_entitlement_issues': <AppPermission>[AppPermissions.systemAdmin],
        // Gap: platform_users / system_health — no live metric source yet.

        // Tenant admin (Dashboard.md §2)
        'active_users': <AppPermission>[AppPermissions.tenantAdmin],
        'module_adoption': <AppPermission>[AppPermissions.reportsRead],
        'subscription_health': <AppPermission>[AppPermissions.subscriptionsRead],
        // Gap: total_patients / clinical_activity / hr_summary / roster_status /
        // operations_summary / compliance_alerts — no dedicated KPI payloads yet.

        // Facility admin (Dashboard.md §3)
        'patient_flow_today': <AppPermission>[AppPermissions.patientRead],
        'appointments_today': <AppPermission>[AppPermissions.patientRead],
        'active_admissions': <AppPermission>[AppPermissions.patientRead],
        'bed_occupancy': <AppPermission>[AppPermissions.patientRead],
        'billing_exceptions': <AppPermission>[AppPermissions.billingRead],
        'operational_blockers': <AppPermission>[AppPermissions.operationsRead],
        'opd_notifications_attention': <AppPermission>[
          AppPermissions.patientRead,
        ],

        // Doctor (Dashboard.md §4)
        'assigned': <AppPermission>[AppPermissions.clinicalRead],
        'in_progress': <AppPermission>[AppPermissions.clinicalRead],
        'results_pending_review': <AppPermission>[AppPermissions.labRead],
        'follow_ups_due': <AppPermission>[AppPermissions.clinicalRead],
        'completed': <AppPermission>[AppPermissions.clinicalRead],
        'critical_labs': <AppPermission>[AppPermissions.labRead],
        // Gap: radiology_results / prescriptions_pending / emergency_calls /
        // my_schedule — no dedicated doctor KPI payloads yet.

        // Nurse (Dashboard.md §5)
        'inpatient_flow': <AppPermission>[AppPermissions.clinicalRead],
        'med_admin_today': <AppPermission>[AppPermissions.pharmacyRead],
        'transfer_queue': <AppPermission>[AppPermissions.patientRead],
        'discharge_pressure': <AppPermission>[AppPermissions.clinicalRead],
        'emergency_cases_today': <AppPermission>[AppPermissions.emergencyRead],
        'theatre_cases_today': <AppPermission>[AppPermissions.clinicalRead],
        'radiology_pending': <AppPermission>[AppPermissions.radiologyRead],
        // Gap: vitals_due / nursing_tasks / shift_schedule as named KPIs.

        // Lab (Dashboard.md §6)
        // Note: orders_today / in_process / completed_orders are shared ids across
        // lab, radiology, and pharmacy packs — declare on profile templates.
        'pending_results': <AppPermission>[AppPermissions.labWrite],
        'critical_results': <AppPermission>[AppPermissions.labRead],
        // Gap: samples_awaiting_collection / equipment_alerts as named KPIs.

        // Radiology (imaging worklist; not a Dashboard.md persona table, but live)
        'draft_reports': <AppPermission>[AppPermissions.radiologyRead],
        'final_reports': <AppPermission>[AppPermissions.radiologyRead],

        // Pharmacy (Dashboard.md §7)
        'pending_dispense': <AppPermission>[AppPermissions.pharmacyWrite],
        'dispensed_today': <AppPermission>[AppPermissions.pharmacyRead],
        'low_stock': <AppPermission>[AppPermissions.pharmacyRead],
        'critical_stock': <AppPermission>[AppPermissions.pharmacyRead],
        'billing_pending': <AppPermission>[AppPermissions.billingRead],
        // Gap: expiring_medicines / controlled_drugs — no live metric source yet.

        // Reception (Dashboard.md §8)
        'desk_queue': <AppPermission>[AppPermissions.patientRead],
        'turnaround_pressure': <AppPermission>[AppPermissions.patientRead],
        'no_show_pressure': <AppPermission>[AppPermissions.patientRead],
        'registrations_today': <AppPermission>[AppPermissions.patientWrite],
        'pending_payments': <AppPermission>[AppPermissions.billingRead],
        // pending_balance_amount is on billing + reception templates (billing:read).
        // Gap: admissions (write) as a named reception KPI — use active_admissions
        // when patient:write is granted via profile overlay if added later.

        // Billing (Dashboard.md §9)
        'collections_today': <AppPermission>[AppPermissions.billingRead],
        'overdue_balance_amount': <AppPermission>[AppPermissions.billingRead],
        'pending_balance_amount': <AppPermission>[AppPermissions.billingRead],
        'invoices_today': <AppPermission>[AppPermissions.billingRead],
        'overdue_invoices': <AppPermission>[AppPermissions.billingRead],
        'open_balances': <AppPermission>[AppPermissions.billingRead],
        'refunds_today': <AppPermission>[AppPermissions.billingWrite],
        'pending_approvals': <AppPermission>[AppPermissions.financialApprove],
        'pending_insurance_claims': <AppPermission>[AppPermissions.billingRead],

        // Operations (Dashboard.md §10)
        'occupied_beds': <AppPermission>[AppPermissions.operationsRead],
        'total_beds': <AppPermission>[AppPermissions.operationsRead],
        'maintenance_open': <AppPermission>[AppPermissions.operationsRead],
        'low_stock_pressure': <AppPermission>[AppPermissions.operationsRead],
        'housekeeping_backlog': <AppPermission>[AppPermissions.operationsRead],
        'facility_readiness': <AppPermission>[AppPermissions.operationsRead],
        // Gap: security_incidents / utilities_status — no live KPI source yet.
        // Daily operations KPIs chart gated via [charts].

        // HR (Dashboard.md §11)
        'active_staff': <AppPermission>[AppPermissions.hrRead],
        'shifts_today': <AppPermission>[AppPermissions.rosterRead],
        'pending_leaves': <AppPermission>[AppPermissions.hrRead],
        'on_leave_today': <AppPermission>[AppPermissions.hrRead],
        'unassigned_shifts': <AppPermission>[AppPermissions.rosterRead],
        'attended_today': <AppPermission>[AppPermissions.hrRead],
        'missed_shifts_today': <AppPermission>[AppPermissions.rosterRead],
        'payroll_pending': <AppPermission>[AppPermissions.hrRead],
        'payroll_processed': <AppPermission>[AppPermissions.hrRead],
        'staffing_backlog': <AppPermission>[AppPermissions.hrRead],
        'attendance_rate': <AppPermission>[AppPermissions.hrRead],
        'roster_approvals': <AppPermission>[AppPermissions.rosterApprove],
        'department_staffing': <AppPermission>[AppPermissions.unitRead],

        // Biomed (Dashboard.md §12)
        'open_work_orders': <AppPermission>[AppPermissions.biomedWrite],
        'open_incidents': <AppPermission>[AppPermissions.biomedRead],
        'active_downtime': <AppPermission>[AppPermissions.biomedRead],
        'critical_service_risk': <AppPermission>[AppPermissions.biomedRead],
        'high_priority': <AppPermission>[AppPermissions.biomedRead],
        'assets_operational': <AppPermission>[AppPermissions.biomedRead],
        'high_priority_work_orders': <AppPermission>[AppPermissions.biomedWrite],
        'overdue_maintenance': <AppPermission>[AppPermissions.biomedRead],
        'technician_load': <AppPermission>[AppPermissions.biomedRead],

        // Housekeeping (Dashboard.md §13)
        'pending_tasks': <AppPermission>[AppPermissions.operationsRead],
        'in_progress_tasks': <AppPermission>[AppPermissions.operationsRead],
        'overdue_tasks': <AppPermission>[AppPermissions.operationsRead],
        'completed_today': <AppPermission>[AppPermissions.operationsRead],
        'throughput': <AppPermission>[AppPermissions.operationsRead],
        'pending_cleaning_tasks': <AppPermission>[AppPermissions.operationsRead],
        'unassigned_cleaning_tasks': <AppPermission>[
          AppPermissions.operationsRead,
        ],
        'in_progress_cleaning_tasks': <AppPermission>[
          AppPermissions.operationsRead,
        ],
        'overdue_cleaning_tasks': <AppPermission>[AppPermissions.operationsRead],
        'rooms_ready': <AppPermission>[AppPermissions.operationsRead],
        'housekeeping_staff_on_shift': <AppPermission>[AppPermissions.hrRead],

        // Ambulance (Dashboard.md §14)
        'dispatches_today': <AppPermission>[AppPermissions.emergencyRead],
        'active_trips': <AppPermission>[AppPermissions.emergencyRead],
        'critical_cases': <AppPermission>[AppPermissions.emergencyRead],
        'fleet_available': <AppPermission>[AppPermissions.emergencyRead],
        'fleet_out': <AppPermission>[AppPermissions.operationsRead],

        // Patient portal (Dashboard.md §15)
        'my_upcoming_appointments': <AppPermission>[AppPermissions.patientRead],
        'my_open_bills': <AppPermission>[AppPermissions.billingRead],
        'my_prescriptions': <AppPermission>[AppPermissions.pharmacyRead],
        'my_released_results': <AppPermission>[AppPermissions.labRead],
        'my_messages': <AppPermission>[AppPermissions.communicationsRead],
        'my_profile_status': <AppPermission>[AppPermissions.profileRead],
        // Gap: medical_history / radiology_reports as named portal KPIs.

        // Manager / specialty overlays (live packs; not separate Dashboard.md apps)
        'unit_census': <AppPermission>[AppPermissions.unitRead],
        'staff_on_shift': <AppPermission>[AppPermissions.hrRead],
        'open_roster_gaps': <AppPermission>[AppPermissions.rosterRead],
        'pending_leave_requests': <AppPermission>[AppPermissions.hrRead],
        'coverage_risk': <AppPermission>[AppPermissions.rosterRead],
        'unit_blockers': <AppPermission>[AppPermissions.unitRead],
        'ward_census': <AppPermission>[AppPermissions.clinicalRead],
        'pending_nursing_tasks': <AppPermission>[AppPermissions.clinicalRead],
        'handover_risks': <AppPermission>[AppPermissions.clinicalRead],
        'discharge_delays': <AppPermission>[AppPermissions.clinicalRead],
        'icu_census': <AppPermission>[AppPermissions.clinicalRead],
        'critical_patient_alerts': <AppPermission>[AppPermissions.clinicalRead],
        'icu_beds_occupied': <AppPermission>[AppPermissions.clinicalRead],
        'transfer_readiness': <AppPermission>[AppPermissions.patientRead],
        'staff_coverage': <AppPermission>[AppPermissions.hrRead],
        'open_escalations': <AppPermission>[AppPermissions.clinicalRead],
        'procedures_today': <AppPermission>[AppPermissions.clinicalRead],
        'ready_for_theatre': <AppPermission>[AppPermissions.clinicalRead],
        'in_theatre': <AppPermission>[AppPermissions.clinicalRead],
        'post_op_handovers_pending': <AppPermission>[
          AppPermissions.clinicalRead,
        ],
        'cancellations_or_delays': <AppPermission>[AppPermissions.clinicalRead],
        'theatre_staff_coverage': <AppPermission>[AppPermissions.hrRead],
        'active_mortuary_cases': <AppPermission>[AppPermissions.mortuaryRead],
        'storage_assignments': <AppPermission>[AppPermissions.mortuaryRead],
        'viewings_today': <AppPermission>[AppPermissions.mortuaryRead],
        'post_mortem_requests': <AppPermission>[AppPermissions.mortuaryRead],
        'custody_events_due': <AppPermission>[AppPermissions.mortuaryRead],
        'billable_events_to_capture': <AppPermission>[
          AppPermissions.mortuaryBillingEvent,
        ],
        'storage_occupancy': <AppPermission>[AppPermissions.mortuaryRead],
        'releases_awaiting_approval': <AppPermission>[
          AppPermissions.mortuaryApprove,
        ],
        'pending_post_mortem_requests': <AppPermission>[
          AppPermissions.mortuaryRead,
        ],
        'custody_exceptions': <AppPermission>[AppPermissions.mortuaryRead],
        'audit_exports_due': <AppPermission>[AppPermissions.mortuaryAudit],

        // Integration admin
        'active_integrations': <AppPermission>[AppPermissions.integrationRead],
        'failed_deliveries': <AppPermission>[AppPermissions.integrationRead],
        'pending_webhooks': <AppPermission>[AppPermissions.integrationRead],
        'api_keys_expiring': <AppPermission>[AppPermissions.integrationRead],

        // Limited / other
        'profile_status': <AppPermission>[AppPermissions.profileRead],
        'assigned_links': <AppPermission>[AppPermissions.profileRead],
        'unread_messages': <AppPermission>[AppPermissions.communicationsRead],
        'facility_notices': <AppPermission>[AppPermissions.profileRead],

        // Generic fallback pack metrics
        'patients_today': <AppPermission>[AppPermissions.patientRead],
        'open_invoices': <AppPermission>[AppPermissions.billingRead],
        'payments_today': <AppPermission>[AppPermissions.billingRead],
      };

  /// Queue / results / follow-up item ids (typed catalog for API-only rows).
  static const Map<String, List<AppPermission>> queueItems =
      <String, List<AppPermission>>{
        'guided_appointments_queue': <AppPermission>[AppPermissions.patientRead],
        'guided_appointments': <AppPermission>[AppPermissions.patientRead],
        'guided_walk_in_queue': <AppPermission>[AppPermissions.patientRead],
        'guided_waiting_patients': <AppPermission>[AppPermissions.patientRead],
        'guided_opd_front_desk': <AppPermission>[AppPermissions.patientRead],
        'guided_opd_flow': <AppPermission>[AppPermissions.patientRead],
        'guided_doctor_assignment': <AppPermission>[AppPermissions.patientRead],
        'guided_emergency_arrivals': <AppPermission>[
          AppPermissions.emergencyRead,
        ],
        'guided_emergency_intake': <AppPermission>[AppPermissions.emergencyRead],
        'guided_emergency_cases': <AppPermission>[AppPermissions.emergencyRead],
        'guided_clinical_queue': <AppPermission>[AppPermissions.clinicalRead],
        'guided_nursing_tasks': <AppPermission>[AppPermissions.clinicalRead],
        'guided_nursing_queue': <AppPermission>[AppPermissions.clinicalRead],
        'guided_ipd_admissions': <AppPermission>[AppPermissions.clinicalRead],
        'guided_transfer_queue': <AppPermission>[AppPermissions.patientRead],
        'guided_lab_queue': <AppPermission>[AppPermissions.labRead],
        'guided_lab_results': <AppPermission>[AppPermissions.labRead],
        'guided_radiology_queue': <AppPermission>[AppPermissions.radiologyRead],
        'guided_radiology_results': <AppPermission>[AppPermissions.radiologyRead],
        'guided_pharmacy_queue': <AppPermission>[AppPermissions.pharmacyRead],
        'guided_pharmacy_orders': <AppPermission>[AppPermissions.pharmacyRead],
        'guided_billing_queue': <AppPermission>[AppPermissions.billingRead],
        'guided_billing_follow_up': <AppPermission>[AppPermissions.billingRead],
        'guided_hr_queue': <AppPermission>[AppPermissions.hrRead],
        'guided_staff_leaves': <AppPermission>[AppPermissions.hrRead],
        'guided_ambulance_queue': <AppPermission>[AppPermissions.emergencyRead],
        'guided_mortuary_queue': <AppPermission>[AppPermissions.mortuaryRead],
        'guided_mortuary_cases': <AppPermission>[AppPermissions.mortuaryRead],
        'guided_platform_queue': <AppPermission>[AppPermissions.systemAdmin],
        // Do not fall back to settings→profile:read for governance setup rows.
        'guided_create_facility': <AppPermission>[AppPermissions.tenantAdmin],
        'guided_tenant_setup': <AppPermission>[AppPermissions.tenantAdmin],
      };

  /// Alert ids.
  static const Map<String, List<AppPermission>> alerts =
      <String, List<AppPermission>>{
        'guided_critical_labs': <AppPermission>[AppPermissions.labRead],
        'guided_critical_results': <AppPermission>[AppPermissions.labRead],
        'guided_bed_pressure': <AppPermission>[AppPermissions.clinicalRead],
        'guided_bed_occupancy': <AppPermission>[AppPermissions.patientRead],
        'guided_billing_exceptions': <AppPermission>[AppPermissions.billingRead],
        'guided_no_show_pressure': <AppPermission>[AppPermissions.patientRead],
        'guided_no_show_follow_up': <AppPermission>[AppPermissions.patientRead],
        'guided_opd_notifications': <AppPermission>[AppPermissions.patientRead],
        'guided_desk_follow_up': <AppPermission>[AppPermissions.patientRead],
        'guided_overdue_invoices': <AppPermission>[AppPermissions.billingRead],
        'guided_lab_critical': <AppPermission>[AppPermissions.labRead],
        'guided_pharmacy_stock': <AppPermission>[AppPermissions.pharmacyRead],
        'guided_pharmacy_orders': <AppPermission>[AppPermissions.pharmacyRead],
        'guided_patient_messages': <AppPermission>[
          AppPermissions.communicationsRead,
        ],
        'guided_my_messages': <AppPermission>[
          AppPermissions.communicationsRead,
        ],
        'overdue_invoices': <AppPermission>[AppPermissions.billingRead],
        'critical_labs': <AppPermission>[AppPermissions.labRead],
        'radiology_results_ready': <AppPermission>[AppPermissions.radiologyRead],
        'bed_occupancy_pressure': <AppPermission>[AppPermissions.patientRead],
        'plan_limit_pressure': <AppPermission>[AppPermissions.subscriptionsRead],
        'security_alerts': <AppPermission>[
          AppPermissions.complianceRead,
          AppPermissions.breakGlassReview,
        ],
        'compliance_alerts': <AppPermission>[AppPermissions.complianceRead],
        'audit_summary': <AppPermission>[AppPermissions.complianceRead],
        'integration_status': <AppPermission>[AppPermissions.integrationRead],
      };

  /// Activity row ids / kinds.
  static const Map<String, List<AppPermission>> activity =
      <String, List<AppPermission>>{
        'platform_activity': <AppPermission>[AppPermissions.systemAdmin],
        'recent_activities': <AppPermission>[AppPermissions.systemAdmin],
        'billing_events': <AppPermission>[AppPermissions.billingRead],
      };

  /// Module slug → default read permission for API-only queue/activity rows.
  static const Map<String, List<AppPermission>> moduleSlug =
      <String, List<AppPermission>>{
        'patients': <AppPermission>[AppPermissions.patientRead],
        'patient-registry': <AppPermission>[AppPermissions.patientRead],
        'scheduling': <AppPermission>[AppPermissions.patientRead],
        'opd': <AppPermission>[AppPermissions.patientRead],
        'reception': <AppPermission>[AppPermissions.patientRead],
        'clinical': <AppPermission>[AppPermissions.clinicalRead],
        'nursing': <AppPermission>[AppPermissions.clinicalRead],
        'ipd': <AppPermission>[AppPermissions.clinicalRead],
        'icu': <AppPermission>[AppPermissions.clinicalRead],
        'theater': <AppPermission>[AppPermissions.clinicalRead],
        'theatre': <AppPermission>[AppPermissions.clinicalRead],
        'lab': <AppPermission>[AppPermissions.labRead],
        'radiology': <AppPermission>[AppPermissions.radiologyRead],
        'pharmacy': <AppPermission>[AppPermissions.pharmacyRead],
        'billing': <AppPermission>[AppPermissions.billingRead],
        'claims': <AppPermission>[AppPermissions.billingRead],
        'emergency': <AppPermission>[AppPermissions.emergencyRead],
        'operations': <AppPermission>[AppPermissions.operationsRead],
        'housekeeping': <AppPermission>[AppPermissions.operationsRead],
        'hr': <AppPermission>[AppPermissions.hrRead],
        'biomedical': <AppPermission>[AppPermissions.biomedRead],
        'biomed': <AppPermission>[AppPermissions.biomedRead],
        'mortuary': <AppPermission>[AppPermissions.mortuaryRead],
        'communications': <AppPermission>[AppPermissions.communicationsRead],
        'integrations': <AppPermission>[AppPermissions.integrationRead],
        'reports': <AppPermission>[AppPermissions.reportsRead],
        'subscriptions': <AppPermission>[AppPermissions.subscriptionsRead],
        'settings': <AppPermission>[AppPermissions.profileRead],
        'profile': <AppPermission>[AppPermissions.profileRead],
      };

  /// Shortcut ids → required permissions (all-of; not route-only).
  static const Map<String, List<AppPermission>> shortcuts =
      <String, List<AppPermission>>{
        'reception': <AppPermission>[AppPermissions.patientRead],
        'patients': <AppPermission>[AppPermissions.patientRead],
        'opd': <AppPermission>[AppPermissions.patientRead],
        'emergency': <AppPermission>[AppPermissions.emergencyRead],
        'ipd': <AppPermission>[AppPermissions.clinicalRead],
        'rooms_beds': <AppPermission>[AppPermissions.operationsRead],
        'icu': <AppPermission>[AppPermissions.clinicalRead],
        'nursing': <AppPermission>[AppPermissions.clinicalRead],
        'clinical': <AppPermission>[AppPermissions.clinicalRead],
        'lab': <AppPermission>[AppPermissions.labRead],
        'radiology': <AppPermission>[AppPermissions.radiologyRead],
        'pharmacy': <AppPermission>[AppPermissions.pharmacyRead],
        'billing': <AppPermission>[AppPermissions.billingRead],
        'claims': <AppPermission>[AppPermissions.billingRead],
        'hr': <AppPermission>[AppPermissions.hrRead],
        'operations': <AppPermission>[AppPermissions.operationsRead],
        'housekeeping': <AppPermission>[AppPermissions.operationsRead],
        'biomedical': <AppPermission>[AppPermissions.biomedRead],
        'communications': <AppPermission>[AppPermissions.communicationsRead],
        'integrations': <AppPermission>[AppPermissions.integrationRead],
        'discharge': <AppPermission>[AppPermissions.clinicalRead],
        'mortuary': <AppPermission>[AppPermissions.mortuaryRead],
        'theater': <AppPermission>[AppPermissions.clinicalRead],
        'reports': <AppPermission>[AppPermissions.reportsRead],
        'subscriptions': <AppPermission>[AppPermissions.subscriptionsRead],
        'tenant_facility_setup': <AppPermission>[AppPermissions.tenantAdmin],
        'settings': <AppPermission>[AppPermissions.profileRead],
        'profile': <AppPermission>[AppPermissions.profileRead],
      };

  /// Trend / distribution blocks map to reports when Dashboard.md says so.
  static const List<AppPermission> charts = <AppPermission>[
    AppPermissions.reportsRead,
  ];

  static List<AppPermission> forStatusCard(String id) {
    return List<AppPermission>.unmodifiable(
      statusCards[id.trim().toLowerCase()] ?? const <AppPermission>[],
    );
  }

  static List<AppPermission> forQueueItem({
    required String id,
    String? moduleSlug,
  }) {
    final String normalizedId = id.trim().toLowerCase();
    final List<AppPermission>? byId = queueItems[normalizedId];
    if (byId != null) {
      return List<AppPermission>.unmodifiable(byId);
    }
    return forModuleSlug(moduleSlug);
  }

  static List<AppPermission> forAlert({
    required String id,
    String? moduleSlug,
  }) {
    final String normalizedId = id.trim().toLowerCase();
    final List<AppPermission>? byId = alerts[normalizedId];
    if (byId != null) {
      return List<AppPermission>.unmodifiable(byId);
    }
    return forModuleSlug(moduleSlug);
  }

  static List<AppPermission> forActivity({
    required String id,
    String? moduleSlug,
  }) {
    final String normalizedId = id.trim().toLowerCase();
    final List<AppPermission>? byId = activity[normalizedId];
    if (byId != null) {
      return List<AppPermission>.unmodifiable(byId);
    }
    return forModuleSlug(moduleSlug);
  }

  static List<AppPermission> forShortcut(String id) {
    return List<AppPermission>.unmodifiable(
      shortcuts[id.trim().toLowerCase()] ?? const <AppPermission>[],
    );
  }

  static List<AppPermission> forModuleSlug(String? slug) {
    final String normalized = (slug ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <AppPermission>[];
    }
    return List<AppPermission>.unmodifiable(
      moduleSlug[normalized] ?? const <AppPermission>[],
    );
  }

  /// Prefer API/metadata permissions when present; otherwise catalog.
  static List<AppPermission> resolveStatusCard({
    required String id,
    List<AppPermission> declared = const <AppPermission>[],
  }) {
    if (declared.isNotEmpty) {
      return List<AppPermission>.unmodifiable(declared);
    }
    return forStatusCard(id);
  }

  static bool isGranted(
    AppAccessPolicy policy,
    List<AppPermission> requiredPermissions,
  ) {
    if (requiredPermissions.isEmpty) {
      return false;
    }
    return policy.grantsAll(requiredPermissions);
  }
}
