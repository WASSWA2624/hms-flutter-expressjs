import 'dart:collection';
import 'dart:math' as math;

import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

const Set<AppRole> _homeDashboardManagerOverlayRoles = <AppRole>{
  AppRole.unitManager,
  AppRole.wardManager,
  AppRole.icuManager,
  AppRole.theatreManager,
  AppRole.housekeepingManager,
  AppRole.biomedManager,
  AppRole.mortuaryManager,
};

const Map<AppRole, int> _homeRoleRanks = <AppRole, int>{
  AppRole.other: 0,
  AppRole.patient: 1,
  AppRole.houseKeeper: 2,
  AppRole.receptionist: 3,
  AppRole.billing: 4,
  AppRole.operations: 5,
  AppRole.ambulanceOperator: 6,
  AppRole.labTech: 7,
  AppRole.radiologyTech: 8,
  AppRole.pharmacist: 9,
  AppRole.biomed: 10,
  AppRole.mortuaryStaff: 11,
  AppRole.nurse: 12,
  AppRole.doctor: 13,
  AppRole.hr: 14,
  AppRole.integrationAdmin: 15,
  AppRole.unitManager: 16,
  AppRole.wardManager: 17,
  AppRole.icuManager: 18,
  AppRole.theatreManager: 19,
  AppRole.housekeepingManager: 20,
  AppRole.biomedManager: 21,
  AppRole.mortuaryManager: 22,
  AppRole.facilityAdmin: 23,
  AppRole.tenantAdmin: 24,
  AppRole.superAdmin: 25,
};

const Map<AppRole, HomeDashboardProfile>
homeDashboardProfiles = <AppRole, HomeDashboardProfile>{
  AppRole.superAdmin: HomeDashboardProfile(
    id: 'super_admin',
    role: AppRole.superAdmin,
    roleLabel: 'Platform administrator',
    homeTitle: 'Platform',
    emptyMessage: '',
    maxStatusCards: 5,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'tenants_active',
        label: 'Tenants',
        format: 'ratio',
        requiredPermissions: <AppPermission>[AppPermissions.systemAdmin],
      ),
      HomeStatusCardTemplate(
        id: 'facilities_active',
        label: 'Facilities',
        requiredPermissions: <AppPermission>[AppPermissions.systemAdmin],
      ),
      HomeStatusCardTemplate(
        id: 'subscriptions_health',
        label: 'Subscriptions',
        format: 'ratio',
        requiredPermissions: <AppPermission>[AppPermissions.subscriptionsRead],
      ),
      HomeStatusCardTemplate(
        id: 'pending_registration_approvals',
        label: 'Approvals',
        requiredPermissions: <AppPermission>[AppPermissions.systemAdmin],
      ),
      HomeStatusCardTemplate(
        id: 'module_entitlement_issues',
        label: 'Entitlements',
        requiredPermissions: <AppPermission>[AppPermissions.systemAdmin],
      ),
    ],
    // Create intents are covered by Platform management Manage hubs.
    quickActionIds: const <String>[],
    shortcutIds: <String>[
      'subscriptions',
      'tenant_facility_setup',
      'integrations',
      'settings',
      'reports',
    ],
    emptyActionIds: <String>[
      'manage_tenants',
      'manage_facilities',
      'manage_roles_access',
      'manage_users',
    ],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'pending_registration_approvals': HomeMetricRouteTarget(
        queryParameters: <String, String>{
          'section': 'subscription-approvals',
        },
      ),
      'tenants_active': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'tenants'},
      ),
      'facilities_active': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'facility'},
      ),
    },
  ),
  AppRole.tenantAdmin: HomeDashboardProfile(
    id: 'tenant_admin',
    role: AppRole.tenantAdmin,
    roleLabel: 'Organization administrator',
    homeTitle: 'Organization',
    emptyMessage: '',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'facilities_active',
        label: 'Facilities',
        format: 'ratio',
        requiredPermissions: <AppPermission>[AppPermissions.tenantAdmin],
      ),
      HomeStatusCardTemplate(
        id: 'active_users',
        label: 'Users',
        requiredPermissions: <AppPermission>[AppPermissions.tenantAdmin],
      ),
      HomeStatusCardTemplate(
        id: 'module_adoption',
        label: 'Adoption',
        format: 'percent',
        requiredPermissions: <AppPermission>[AppPermissions.reportsRead],
      ),
      HomeStatusCardTemplate(
        id: 'subscription_health',
        label: 'Subscription',
        format: 'percent',
        requiredPermissions: <AppPermission>[AppPermissions.subscriptionsRead],
      ),
    ],
    // Create facility/role/user covered by Facility management Manage hubs.
    quickActionIds: const <String>[],
    shortcutIds: <String>[
      'tenant_facility_setup',
      'settings',
      'reports',
      'subscriptions',
      'hr',
    ],
    emptyActionIds: <String>[
      'manage_facilities',
      'manage_roles_access',
      'manage_users',
      'add_staff_profile',
    ],
  ),
  AppRole.facilityAdmin: HomeDashboardProfile(
    id: 'facility_admin',
    role: AppRole.facilityAdmin,
    roleLabel: 'Facility administrator',
    homeTitle: 'Facility ops',
    emptyMessage: 'No facility items need action right now.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'patient_flow_today',
        label: 'Flow today',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'appointments_today',
        label: 'Appointments',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'active_admissions',
        label: 'Admissions',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'bed_occupancy',
        label: 'Occupied',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'emergency_cases_today',
        label: 'Emergency',
        requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
      ),
      HomeStatusCardTemplate(
        id: 'collections_today',
        label: 'Revenue',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'billing_exceptions',
        label: 'Billing',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'low_stock',
        label: 'Pharmacy',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'critical_labs',
        label: 'Lab critical',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'pending_leaves',
        label: 'HR leave',
        requiredPermissions: <AppPermission>[AppPermissions.hrRead],
      ),
      HomeStatusCardTemplate(
        id: 'open_incidents',
        label: 'Equipment',
        requiredPermissions: <AppPermission>[AppPermissions.biomedRead],
      ),
      HomeStatusCardTemplate(
        id: 'operational_blockers',
        label: 'Blockers',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
    ],
    quickActionIds: <String>[
      'register_patient',
      'book_appointment',
    ],
    shortcutIds: <String>[
      'opd',
      'patients',
      'emergency',
      'billing',
      'reports',
      'settings',
      'hr',
    ],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'collections_today': HomeMetricRouteTarget(),
      'billing_exceptions': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'overdue'},
      ),
    },
  ),
  AppRole.doctor: HomeDashboardProfile(
    id: 'doctor',
    role: AppRole.doctor,
    roleLabel: 'Doctor / clinician',
    homeTitle: 'Clinical',
    emptyMessage: 'No assigned clinical work right now.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'assigned',
        label: 'Assigned today',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'in_progress',
        label: 'In progress',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'results_pending_review',
        label: 'Results to review',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'follow_ups_due',
        label: 'Follow-ups due',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'completed',
        label: 'Completed',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'critical_labs',
        label: 'Critical labs',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'radiology_pending',
        label: 'Radiology results',
        requiredPermissions: <AppPermission>[AppPermissions.radiologyRead],
      ),
      HomeStatusCardTemplate(
        id: 'prescriptions_pending',
        label: 'Prescriptions pending',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'emergency_cases_today',
        label: 'Emergency calls',
        requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
      ),
      HomeStatusCardTemplate(
        id: 'shifts_today',
        label: 'My schedule',
        requiredPermissions: <AppPermission>[AppPermissions.rosterRead],
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      // Gap: recent clinical notes as a named KPI — no dedicated metric yet.
    ],
    quickActionIds: <String>[
      'continue_consultation',
      'order_lab',
      'order_radiology',
      'write_clinical_note',
    ],
    shortcutIds: <String>[
      'clinical',
      'opd',
      'emergency',
      'lab',
      'radiology',
      'pharmacy',
      'ipd',
    ],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'assigned': HomeMetricRouteTarget(),
      'in_progress': HomeMetricRouteTarget(),
      'results_pending_review': HomeMetricRouteTarget(),
      'follow_ups_due': HomeMetricRouteTarget(),
      'radiology_pending': HomeMetricRouteTarget(),
      'prescriptions_pending': HomeMetricRouteTarget(),
      'emergency_cases_today': HomeMetricRouteTarget(),
      'shifts_today': HomeMetricRouteTarget(),
    },
  ),
  AppRole.nurse: HomeDashboardProfile(
    id: 'nurse',
    role: AppRole.nurse,
    roleLabel: 'Nurse',
    homeTitle: 'Nursing',
    emptyMessage: 'No nursing tasks are assigned right now.',
    maxStatusCards: 5,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'inpatient_flow',
        label: 'Inpatients',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'med_admin_today',
        label: 'Med admin',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'transfer_queue',
        label: 'Transfers',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'critical_labs',
        label: 'Critical labs',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'discharge_pressure',
        label: 'Discharge',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'appointments_today',
        label: 'OPD queue',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'emergency_cases_today',
        label: 'Emergency cases',
        requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
      ),
      HomeStatusCardTemplate(
        id: 'theatre_cases_today',
        label: 'Theatre cases',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'radiology_pending',
        label: 'Imaging pending',
        requiredPermissions: <AppPermission>[AppPermissions.radiologyRead],
      ),
      // Gap: vitals_due / nursing_tasks / shift_schedule — no dedicated KPI
      // payloads yet (Dashboard.md §5).
    ],
    quickActionIds: <String>[
      'record_vitals',
      'mark_med_administered',
      'create_handover',
      'write_clinical_note',
      'route_patient',
      'check_in_patient',
    ],
    shortcutIds: <String>[
      'nursing',
      'ipd',
      'lab',
      'opd',
      'emergency',
      'radiology',
      'theater',
      'icu',
      'clinical',
    ],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'inpatient_flow': HomeMetricRouteTarget(),
      'med_admin_today': HomeMetricRouteTarget(),
      'transfer_queue': HomeMetricRouteTarget(),
      'critical_labs': HomeMetricRouteTarget(),
      'discharge_pressure': HomeMetricRouteTarget(),
      'opd_notifications_attention': HomeMetricRouteTarget(),
      'appointments_today': HomeMetricRouteTarget(),
      'emergency_cases_today': HomeMetricRouteTarget(),
      'theatre_cases_today': HomeMetricRouteTarget(),
      'radiology_pending': HomeMetricRouteTarget(),
    },
  ),
  AppRole.labTech: HomeDashboardProfile(
    id: 'lab_tech',
    role: AppRole.labTech,
    roleLabel: 'Laboratory technologist',
    homeTitle: 'Laboratory',
    emptyMessage: 'No lab work is pending.',
    // Match Lab desk tabs, plus week/month order volume KPIs.
    maxStatusCards: 6,
    suppressHomeQuickActions: true,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'lab_pending',
        label: 'Pending',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'critical_results',
        label: 'Critical',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'completed_orders',
        label: 'Completed',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'lab_all_patients',
        label: 'All patients',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'lab_orders_week',
        label: 'Orders this week',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'lab_orders_month',
        label: 'Orders this month',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
    ],
    quickActionIds: const <String>[],
    shortcutIds: <String>['lab', 'patients', 'communications', 'settings', 'reports'],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'lab_pending': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'pending'},
      ),
      'critical_results': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'critical'},
      ),
      'completed_orders': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'completed-today'},
      ),
      'lab_all_patients': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'worklist'},
      ),
      // Week/month volume KPIs are informational only (no desk filter).
    },
  ),
  AppRole.radiologyTech: HomeDashboardProfile(
    id: 'radiology_tech',
    role: AppRole.radiologyTech,
    roleLabel: 'Radiology / imaging technologist',
    homeTitle: 'Imaging worklist',
    emptyMessage: 'No imaging work is pending.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'orders_today',
        label: 'Radiology orders today',
        requiredPermissions: <AppPermission>[AppPermissions.radiologyRead],
      ),
      HomeStatusCardTemplate(
        id: 'in_process',
        label: 'Studies in process',
        requiredPermissions: <AppPermission>[AppPermissions.radiologyRead],
      ),
      HomeStatusCardTemplate(
        id: 'draft_reports',
        label: 'Draft reports',
        requiredPermissions: <AppPermission>[AppPermissions.radiologyRead],
      ),
      HomeStatusCardTemplate(
        id: 'final_reports',
        label: 'Final reports',
        requiredPermissions: <AppPermission>[AppPermissions.radiologyRead],
      ),
      HomeStatusCardTemplate(
        id: 'completed_orders',
        label: 'Completed',
        requiredPermissions: <AppPermission>[AppPermissions.radiologyRead],
      ),
    ],
    quickActionIds: <String>[
      'start_imaging_study',
      'update_imaging_status',
      'add_radiology_report',
      'run_report',
    ],
    shortcutIds: <String>[
      'radiology',
      'patients',
      'reports',
      'settings',
      'communications',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.pharmacist: HomeDashboardProfile(
    id: 'pharmacist',
    role: AppRole.pharmacist,
    roleLabel: 'Pharmacist',
    homeTitle: 'Pharmacy',
    emptyMessage: 'No pending orders.',
    maxStatusCards: 6,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'orders_today',
        label: 'Orders today',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'pending_dispense',
        label: 'Pending',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
      ),
      HomeStatusCardTemplate(
        id: 'dispensed_today',
        label: 'Dispensed today',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'low_stock',
        label: 'Low stock',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'sales_today',
        label: 'Total sales today',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.pricingPharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'sales_this_week',
        label: 'Total sales (last 7 days)',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.pricingPharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'critical_stock',
        label: 'Critical stock',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      ),
      // Dashboard.md §7 Billing Pending — live open invoice balances.
      HomeStatusCardTemplate(
        id: 'billing_pending',
        label: 'Billing pending',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
    ],
    quickActionIds: <String>[
      'dispense_medication',
      'record_pharmacy_sale',
      'receive_pharmacy_stock',
      'adjust_pharmacy_stock',
    ],
    // Focused shell: pharmacy/comms/reports/settings (not patients registry).
    shortcutIds: <String>[
      'pharmacy',
      'communications',
      'settings',
      'billing',
      'reports',
    ],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'orders_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'all'},
      ),
      'pending_dispense': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'queue'},
      ),
      'dispensed_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'completed'},
      ),
      'low_stock': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'low-stock'},
      ),
      'sales_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'completed'},
      ),
      'sales_this_week': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'completed'},
      ),
      'critical_stock': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'low-stock'},
      ),
      'billing_pending': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'pendingPayment'},
      ),
    },
  ),
  AppRole.receptionist: HomeDashboardProfile(
    id: 'receptionist',
    role: AppRole.receptionist,
    roleLabel: 'Reception / front desk',
    homeTitle: 'Front desk',
    emptyMessage: 'No desk queue items right now.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'appointments_today',
        label: 'Meetings',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'desk_queue',
        label: 'Desk queue',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'turnaround_pressure',
        label: 'In progress',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'no_show_pressure',
        label: 'Follow-ups',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'registrations_today',
        label: 'Registrations',
        requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
      ),
      HomeStatusCardTemplate(
        id: 'emergency_cases_today',
        label: 'Emergency intake',
        requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      // Dashboard.md §8 Pending Payments — reuse live billing pending balances.
      HomeStatusCardTemplate(
        id: 'pending_balance_amount',
        label: 'Pending payments',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      // Gap: admissions (patient:write) as a named reception KPI — use
      // active_admissions via expand when patient:write + clinical pack data exist.
    ],
    quickActionIds: <String>[
      'register_patient',
      'book_appointment',
      'route_patient',
    ],
    shortcutIds: <String>[
      'reception',
      'patients',
      'communications',
      'reports',
      'settings',
    ],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'appointments_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'appointments'},
      ),
      'desk_queue': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'queue'},
      ),
      'turnaround_pressure': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'in-progress'},
      ),
      'no_show_pressure': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'follow-up'},
      ),
      'registrations_today': HomeMetricRouteTarget(),
      'emergency_cases_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'high-priority'},
      ),
      'opd_notifications_attention': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'desk-queue'},
      ),
      'pending_balance_amount': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'pendingPayment'},
      ),
    },
  ),
  AppRole.billing: HomeDashboardProfile(
    id: 'billing',
    role: AppRole.billing,
    roleLabel: 'Billing / cashier',
    homeTitle: 'Billing',
    emptyMessage: '',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'collections_today',
        label: 'Collected today',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'overdue_balance_amount',
        label: 'Overdue amount',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'pending_balance_amount',
        label: 'Pending balances',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'invoices_today',
        label: 'Invoices today',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'overdue_invoices',
        label: 'Overdue',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'open_balances',
        label: 'Open accounts',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'refunds_today',
        label: 'Refunds',
        format: 'currency',
        requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
      ),
      HomeStatusCardTemplate(
        id: 'pending_approvals',
        label: 'Approvals',
        requiredPermissions: <AppPermission>[AppPermissions.financialApprove],
      ),
      HomeStatusCardTemplate(
        id: 'pending_insurance_claims',
        label: 'Claims',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
    ],
    quickActionIds: <String>[
      'create_invoice',
      'receive_payment',
      'process_refund',
      'close_shift',
    ],
    // Hubs are reached via shell navigation / quick actions — not a second
    // review strip on the dashboard.
    shortcutIds: <String>[
      'billing',
      'patients',
      'claims',
      'reports',
      'settings',
    ],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      // Collections KPI opens Billing workspace (live payments) — not pending queue.
      'collections_today': HomeMetricRouteTarget(),
      'overdue_balance_amount': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'overdue'},
      ),
      'pending_balance_amount': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'pendingPayment'},
      ),
      'invoices_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'needsIssue'},
      ),
      'overdue_invoices': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'overdue'},
      ),
      'open_balances': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'pendingPayment'},
      ),
      'refunds_today': HomeMetricRouteTarget(),
      'pending_approvals': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'needsApproval'},
      ),
      'pending_insurance_claims': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'claimsPending'},
      ),
    },
  ),
  AppRole.operations: HomeDashboardProfile(
    id: 'operations',
    role: AppRole.operations,
    roleLabel: 'Operations',
    homeTitle: 'Operations',
    emptyMessage: 'No operations items need action right now.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'occupied_beds',
        label: 'Occupied',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'total_beds',
        label: 'Total beds',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'maintenance_open',
        label: 'Maintenance',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'low_stock_pressure',
        label: 'Low stock',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'housekeeping_backlog',
        label: 'Housekeeping',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'facility_readiness',
        label: 'Readiness',
        format: 'percent',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      // Gap: security_incidents / utilities_status — no live KPI source yet.
      // Daily operations KPIs chart gated via reports:read on trend/distribution.
    ],
    quickActionIds: <String>[
      'create_maintenance_request',
      'assign_maintenance',
      'update_bed_readiness',
    ],
    shortcutIds: <String>[
      'operations',
      'rooms_beds',
      'housekeeping',
      'reports',
      'settings',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.hr: HomeDashboardProfile(
    id: 'hr',
    role: AppRole.hr,
    roleLabel: 'HR / workforce',
    homeTitle: 'Workforce',
    emptyMessage: 'No HR tasks are pending.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'active_staff',
        label: 'Staff',
        requiredPermissions: <AppPermission>[AppPermissions.hrRead],
      ),
      HomeStatusCardTemplate(
        id: 'shifts_today',
        label: 'Shifts',
        requiredPermissions: <AppPermission>[AppPermissions.rosterRead],
      ),
      HomeStatusCardTemplate(
        id: 'pending_leaves',
        label: 'Leave',
        requiredPermissions: <AppPermission>[AppPermissions.hrRead],
      ),
      HomeStatusCardTemplate(
        id: 'on_leave_today',
        label: 'On leave',
        requiredPermissions: <AppPermission>[AppPermissions.hrRead],
      ),
      HomeStatusCardTemplate(
        id: 'unassigned_shifts',
        label: 'Unassigned',
        requiredPermissions: <AppPermission>[AppPermissions.rosterRead],
      ),
      HomeStatusCardTemplate(
        id: 'attended_today',
        label: 'Attended',
        requiredPermissions: <AppPermission>[AppPermissions.hrRead],
      ),
      HomeStatusCardTemplate(
        id: 'missed_shifts_today',
        label: 'Missed',
        requiredPermissions: <AppPermission>[AppPermissions.rosterRead],
      ),
      HomeStatusCardTemplate(
        id: 'payroll_pending',
        label: 'Payroll',
        requiredPermissions: <AppPermission>[AppPermissions.hrRead],
      ),
      HomeStatusCardTemplate(
        id: 'roster_approvals',
        label: 'Roster approvals',
        requiredPermissions: <AppPermission>[AppPermissions.rosterApprove],
      ),
      HomeStatusCardTemplate(
        id: 'department_staffing',
        label: 'Dept staffing',
        requiredPermissions: <AppPermission>[AppPermissions.unitRead],
      ),
    ],
    quickActionIds: <String>[],
    // Prefer destinations HR can open with role defaults (hr/comms/reports/
    // profile). tenant_facility_setup needs tenant:admin and is not a floor tile.
    shortcutIds: <String>[
      'hr',
      'communications',
      'reports',
      'settings',
      'profile',
    ],
    suppressHomeQuickActions: true,
    toolbarActionIds: <HomeToolbarActionId>[
      HomeToolbarActionId.openHrWorkspace,
    ],
    metricActionTargets: <String, HomeMetricActionTarget>{
      'active_staff': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrStaffDirectory,
        staffStatusFilter: 'ACTIVE',
      ),
      'shifts_today': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrTodayShifts,
      ),
      'pending_leaves': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrWorkQueue,
        hrQueue: 'LEAVE_REQUESTS',
      ),
      'on_leave_today': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrOnLeaveToday,
      ),
      'unassigned_shifts': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrWorkQueue,
        hrQueue: 'UNASSIGNED_SHIFTS',
      ),
      'attended_today': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrAttendedToday,
      ),
      'missed_shifts_today': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrWorkQueue,
        hrQueue: 'OVERDUE_SHIFTS',
      ),
      'payroll_pending': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrWorkQueue,
        hrQueue: 'PAYROLL_DRAFTS',
      ),
      'roster_approvals': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrWorkQueue,
        hrQueue: 'ROSTER_DRAFTS',
      ),
      'department_staffing': HomeMetricActionTarget(
        kind: HomeMetricActionKind.hrStaffDirectory,
        staffStatusFilter: 'ACTIVE',
      ),
    },
  ),
  AppRole.biomed: HomeDashboardProfile(
    id: 'biomed',
    role: AppRole.biomed,
    roleLabel: 'Biomedical technician',
    homeTitle: 'Biomedical',
    emptyMessage: 'No biomedical work is pending.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'open_work_orders',
        label: 'Work orders',
        requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
      ),
      HomeStatusCardTemplate(
        id: 'open_incidents',
        label: 'Incidents',
        requiredPermissions: <AppPermission>[AppPermissions.biomedRead],
      ),
      HomeStatusCardTemplate(
        id: 'active_downtime',
        label: 'Downtime',
        requiredPermissions: <AppPermission>[AppPermissions.biomedRead],
      ),
      HomeStatusCardTemplate(
        id: 'critical_service_risk',
        label: 'Risk',
        requiredPermissions: <AppPermission>[AppPermissions.biomedRead],
      ),
      HomeStatusCardTemplate(
        id: 'high_priority',
        label: 'Priority',
        requiredPermissions: <AppPermission>[AppPermissions.biomedRead],
      ),
      HomeStatusCardTemplate(
        id: 'assets_operational',
        label: 'Operational',
        format: 'percent',
        requiredPermissions: <AppPermission>[AppPermissions.biomedRead],
      ),
    ],
    quickActionIds: <String>['acknowledge_work_order', 'update_work_order'],
    shortcutIds: <String>[
      'biomedical',
      'operations',
      'reports',
      'settings',
      'communications',
    ],
    emptyActionIds: <String>['report_equipment_issue'],
  ),
  AppRole.houseKeeper: HomeDashboardProfile(
    id: 'house_keeper',
    role: AppRole.houseKeeper,
    roleLabel: 'Housekeeping staff',
    homeTitle: 'Cleaning',
    emptyMessage: 'No cleaning tasks are assigned right now.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'pending_tasks',
        label: 'Pending',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'in_progress_tasks',
        label: 'In progress',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'overdue_tasks',
        label: 'Overdue',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'completed_today',
        label: 'Done today',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'throughput',
        label: 'Throughput',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
    ],
    quickActionIds: <String>['start_cleaning_task', 'complete_cleaning_task'],
    shortcutIds: <String>[
      'housekeeping',
      'rooms_beds',
      'reports',
      'settings',
      'operations',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.ambulanceOperator: HomeDashboardProfile(
    id: 'ambulance_operator',
    role: AppRole.ambulanceOperator,
    roleLabel: 'Ambulance / emergency transport',
    homeTitle: 'Ambulance',
    emptyMessage: 'No ambulance dispatches are active.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'dispatches_today',
        label: 'Dispatches',
        requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
      ),
      HomeStatusCardTemplate(
        id: 'active_trips',
        label: 'Active trips',
        requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
      ),
      HomeStatusCardTemplate(
        id: 'critical_cases',
        label: 'Emergencies',
        requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
      ),
      HomeStatusCardTemplate(
        id: 'fleet_available',
        label: 'Available',
        requiredPermissions: <AppPermission>[AppPermissions.emergencyRead],
      ),
      HomeStatusCardTemplate(
        id: 'fleet_out',
        label: 'Out of service',
        requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
      ),
    ],
    quickActionIds: <String>['dispatch_ambulance', 'update_trip_status'],
    // operations needs operations:read (not on ambulance defaults).
    shortcutIds: <String>[
      'emergency',
      'reports',
      'settings',
      'communications',
      'profile',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.unitManager: HomeDashboardProfile(
    id: 'unit_manager',
    role: AppRole.unitManager,
    roleLabel: 'Unit manager',
    homeTitle: 'Unit management dashboard',
    emptyMessage: 'No unit management items need action.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'unit_census', label: 'Unit census'),
      HomeStatusCardTemplate(id: 'staff_on_shift', label: 'Staff on shift'),
      HomeStatusCardTemplate(id: 'open_roster_gaps', label: 'Open roster gaps'),
      HomeStatusCardTemplate(
        id: 'pending_leave_requests',
        label: 'Pending leave requests',
      ),
      HomeStatusCardTemplate(id: 'coverage_risk', label: 'Coverage risk'),
      HomeStatusCardTemplate(id: 'unit_blockers', label: 'Unit blockers'),
    ],
    quickActionIds: <String>[
      'review_leave',
      'create_shift',
      'publish_roster',
      'approve_roster',
      'run_report',
    ],
    // Unit managers lack clinical:read by default — keep HR/report/settings hubs.
    shortcutIds: <String>['hr', 'reports', 'settings', 'profile'],
    emptyActionIds: const <String>[],
  ),
  AppRole.wardManager: HomeDashboardProfile(
    id: 'ward_manager',
    role: AppRole.wardManager,
    roleLabel: 'Ward manager / charge nurse',
    homeTitle: 'Ward command view',
    emptyMessage: 'No ward issues are currently pending.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'ward_census', label: 'Ward census'),
      HomeStatusCardTemplate(
        id: 'occupied_beds',
        label: 'Occupied',
        requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
      ),
      HomeStatusCardTemplate(
        id: 'pending_nursing_tasks',
        label: 'Pending nursing tasks',
      ),
      HomeStatusCardTemplate(id: 'handover_risks', label: 'Handover risks'),
      HomeStatusCardTemplate(id: 'staff_on_shift', label: 'Staff on shift'),
      HomeStatusCardTemplate(id: 'discharge_delays', label: 'Discharge delays'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
      ),
    ],
    quickActionIds: <String>[
      'create_handover',
      'review_leave',
      'publish_roster',
      'run_report',
    ],
    shortcutIds: <String>[
      'nursing',
      'ipd',
      'rooms_beds',
      'discharge',
      'hr',
      'reports',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.icuManager: HomeDashboardProfile(
    id: 'icu_manager',
    role: AppRole.icuManager,
    roleLabel: 'ICU manager',
    homeTitle: 'ICU oversight dashboard',
    emptyMessage: 'No ICU oversight items need action.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'icu_census', label: 'ICU census'),
      HomeStatusCardTemplate(
        id: 'critical_patient_alerts',
        label: 'Critical patient alerts',
      ),
      HomeStatusCardTemplate(
        id: 'icu_beds_occupied',
        label: 'ICU beds occupied',
      ),
      HomeStatusCardTemplate(
        id: 'transfer_readiness',
        label: 'Transfer readiness',
      ),
      HomeStatusCardTemplate(id: 'staff_coverage', label: 'Staff coverage'),
      HomeStatusCardTemplate(id: 'open_escalations', label: 'Open escalations'),
    ],
    quickActionIds: <String>[
      'record_vitals',
      'create_handover',
      'publish_roster',
      'run_report',
    ],
    shortcutIds: <String>[
      'icu',
      'nursing',
      'clinical',
      'rooms_beds',
      'hr',
      'reports',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.theatreManager: HomeDashboardProfile(
    id: 'theatre_manager',
    role: AppRole.theatreManager,
    roleLabel: 'Theatre manager',
    homeTitle: 'Theatre schedule dashboard',
    emptyMessage: 'No theatre cases need action.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'procedures_today', label: 'Procedures today'),
      HomeStatusCardTemplate(
        id: 'ready_for_theatre',
        label: 'Ready for theatre',
      ),
      HomeStatusCardTemplate(id: 'in_theatre', label: 'In theatre'),
      HomeStatusCardTemplate(
        id: 'post_op_handovers_pending',
        label: 'Post-op handovers pending',
      ),
      HomeStatusCardTemplate(
        id: 'cancellations_or_delays',
        label: 'Cancellations/delays',
      ),
      HomeStatusCardTemplate(
        id: 'theatre_staff_coverage',
        label: 'Theatre staff coverage',
      ),
    ],
    quickActionIds: <String>['publish_roster', 'create_handover', 'run_report'],
    shortcutIds: <String>[
      'theater',
      'clinical',
      'nursing',
      'ipd',
      'icu',
      'hr',
      'reports',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.housekeepingManager: HomeDashboardProfile(
    id: 'housekeeping_manager',
    role: AppRole.housekeepingManager,
    roleLabel: 'Housekeeping manager',
    homeTitle: 'Housekeeping control dashboard',
    emptyMessage: 'No housekeeping backlog is pending.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'pending_cleaning_tasks',
        label: 'Pending cleaning tasks',
      ),
      HomeStatusCardTemplate(
        id: 'unassigned_cleaning_tasks',
        label: 'Unassigned cleaning tasks',
      ),
      HomeStatusCardTemplate(
        id: 'in_progress_cleaning_tasks',
        label: 'In-progress cleaning tasks',
      ),
      HomeStatusCardTemplate(
        id: 'overdue_cleaning_tasks',
        label: 'Overdue cleaning tasks',
      ),
      HomeStatusCardTemplate(id: 'rooms_ready', label: 'Rooms ready'),
      HomeStatusCardTemplate(
        id: 'housekeeping_staff_on_shift',
        label: 'Housekeeping staff on shift',
      ),
    ],
    quickActionIds: <String>[
      'create_cleaning_task',
      'assign_cleaning_task',
      'mark_cleaning_blocked',
      'update_bed_readiness',
      'create_shift',
      'run_report',
    ],
    shortcutIds: <String>[
      'housekeeping',
      'rooms_beds',
      'operations',
      'hr',
      'reports',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.biomedManager: HomeDashboardProfile(
    id: 'biomed_manager',
    role: AppRole.biomedManager,
    roleLabel: 'Biomedical manager',
    homeTitle: 'Biomedical risk dashboard',
    emptyMessage: 'No biomedical risk items need action.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'open_work_orders', label: 'Work orders'),
      HomeStatusCardTemplate(
        id: 'high_priority_work_orders',
        label: 'Priority',
      ),
      HomeStatusCardTemplate(id: 'active_downtime', label: 'Active downtime'),
      HomeStatusCardTemplate(id: 'open_incidents', label: 'Incidents'),
      HomeStatusCardTemplate(
        id: 'overdue_maintenance',
        label: 'Overdue maintenance/calibration',
      ),
      HomeStatusCardTemplate(id: 'technician_load', label: 'Technician load'),
    ],
    quickActionIds: <String>[
      'assign_technician',
      'update_work_order',
      'report_equipment_issue',
      'review_audit',
      'run_report',
    ],
    shortcutIds: <String>[
      'biomedical',
      'operations',
      'reports',
      'settings',
      'communications',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.mortuaryStaff: HomeDashboardProfile(
    id: 'mortuary_staff',
    role: AppRole.mortuaryStaff,
    roleLabel: 'Mortuary staff',
    homeTitle: 'Mortuary work queue',
    emptyMessage: 'No mortuary tasks are pending.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'active_mortuary_cases',
        label: 'Active mortuary cases',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'storage_assignments',
        label: 'Storage assignments',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'viewings_today',
        label: 'Viewings today',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'post_mortem_requests',
        label: 'Post-mortem requests',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'custody_events_due',
        label: 'Custody events due',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'billable_events_to_capture',
        label: 'Billable events to capture',
        requiredPermissions: <AppPermission>[
          AppPermissions.mortuaryBillingEvent,
        ],
      ),
    ],
    quickActionIds: <String>[
      'open_mortuary_case',
      'assign_storage_slot',
      'record_custody_event',
      'schedule_viewing',
      'add_mortuary_billable_event',
    ],
    // patients (not communications) matches mortuary staff default grants.
    shortcutIds: <String>['mortuary', 'patients', 'reports', 'settings'],
    emptyActionIds: const <String>[],
  ),
  AppRole.mortuaryManager: HomeDashboardProfile(
    id: 'mortuary_manager',
    role: AppRole.mortuaryManager,
    roleLabel: 'Mortuary manager',
    homeTitle: 'Mortuary oversight dashboard',
    emptyMessage: 'No mortuary approvals need action.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'active_mortuary_cases',
        label: 'Active mortuary cases',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'storage_occupancy',
        label: 'Storage occupancy',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'releases_awaiting_approval',
        label: 'Releases awaiting approval',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryApprove],
      ),
      HomeStatusCardTemplate(
        id: 'pending_post_mortem_requests',
        label: 'Pending post-mortem requests',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'custody_exceptions',
        label: 'Custody exceptions',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryRead],
      ),
      HomeStatusCardTemplate(
        id: 'audit_exports_due',
        label: 'Audit exports due',
        requiredPermissions: <AppPermission>[AppPermissions.mortuaryAudit],
      ),
    ],
    quickActionIds: <String>[
      'review_release_authorization',
      'approve_release',
      'export_mortuary_evidence',
      'open_mortuary_case',
      'run_report',
    ],
    shortcutIds: <String>['mortuary', 'patients', 'reports', 'settings'],
    emptyActionIds: const <String>[],
  ),
  AppRole.patient: HomeDashboardProfile(
    id: 'patient',
    role: AppRole.patient,
    roleLabel: 'Patient portal account',
    homeTitle: 'My care',
    emptyMessage: 'Your care updates will appear here.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'my_upcoming_appointments',
        label: 'Appointments',
        requiredPermissions: <AppPermission>[AppPermissions.patientRead],
      ),
      HomeStatusCardTemplate(
        id: 'my_open_bills',
        label: 'Bills',
        requiredPermissions: <AppPermission>[AppPermissions.billingRead],
      ),
      HomeStatusCardTemplate(
        id: 'my_prescriptions',
        label: 'Rx',
        requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      ),
      HomeStatusCardTemplate(
        id: 'my_released_results',
        label: 'Results',
        requiredPermissions: <AppPermission>[AppPermissions.labRead],
      ),
      HomeStatusCardTemplate(
        id: 'my_messages',
        label: 'Messages',
        requiredPermissions: <AppPermission>[AppPermissions.communicationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'my_profile_status',
        label: 'Profile',
        format: 'percent',
        requiredPermissions: <AppPermission>[AppPermissions.profileRead],
      ),
      // Gap: medical_history (clinical:read) / radiology_reports
      // (radiology:read) — no dedicated portal KPI payloads yet.
    ],
    quickActionIds: <String>['update_own_profile', 'contact_facility'],
    shortcutIds: <String>['reports', 'settings', 'profile'],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'my_open_bills': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'pendingPayment'},
      ),
      'my_upcoming_appointments': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'appointments'},
      ),
    },
  ),
  AppRole.integrationAdmin: HomeDashboardProfile(
    id: 'integration_admin',
    role: AppRole.integrationAdmin,
    roleLabel: 'Integration administrator',
    homeTitle: 'Integrations',
    emptyMessage: 'No integration work is pending.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'active_integrations',
        label: 'Active',
        requiredPermissions: <AppPermission>[AppPermissions.integrationRead],
      ),
      HomeStatusCardTemplate(
        id: 'failed_deliveries',
        label: 'Failures',
        requiredPermissions: <AppPermission>[AppPermissions.integrationRead],
      ),
      HomeStatusCardTemplate(
        id: 'pending_webhooks',
        label: 'Webhooks',
        requiredPermissions: <AppPermission>[AppPermissions.integrationRead],
      ),
      HomeStatusCardTemplate(
        id: 'api_keys_expiring',
        label: 'Keys',
        requiredPermissions: <AppPermission>[AppPermissions.integrationRead],
      ),
    ],
    quickActionIds: const <String>[],
    // subscriptions needs subscriptions:read (not on role defaults); profile fills the floor.
    shortcutIds: <String>[
      'integrations',
      'reports',
      'settings',
      'profile',
      'subscriptions',
    ],
    emptyActionIds: const <String>[],
  ),
  AppRole.other: HomeDashboardProfile(
    id: 'other',
    role: AppRole.other,
    roleLabel: 'Limited account',
    homeTitle: 'Account dashboard',
    emptyMessage:
        'Your account has limited access. Contact an administrator if you need more modules.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'profile_status',
        label: 'Profile status',
        requiredPermissions: <AppPermission>[AppPermissions.profileRead],
      ),
      HomeStatusCardTemplate(
        id: 'assigned_links',
        label: 'Assigned links',
        requiredPermissions: <AppPermission>[AppPermissions.profileRead],
      ),
      HomeStatusCardTemplate(
        id: 'unread_messages',
        label: 'Unread messages',
        requiredPermissions: <AppPermission>[AppPermissions.communicationsRead],
      ),
      HomeStatusCardTemplate(
        id: 'facility_notices',
        label: 'Facility notices',
        requiredPermissions: <AppPermission>[AppPermissions.profileRead],
      ),
    ],
    quickActionIds: <String>['update_own_profile', 'contact_facility'],
    shortcutIds: <String>['reports', 'profile', 'settings'],
    emptyActionIds: const <String>[],
  ),
};

HomeDashboardProfile homeProfileForRoles(Iterable<AppRole> roles) {
  final Set<AppRole> normalizedRoles = roles.toSet();
  if (normalizedRoles.isEmpty) {
    return homeDashboardProfiles[AppRole.other]!;
  }

  final List<AppRole> operationalRoles = normalizedRoles
      .where(
        (AppRole role) => !_homeDashboardManagerOverlayRoles.contains(role),
      )
      .toList(growable: false);
  final List<AppRole> candidates = operationalRoles.isNotEmpty
      ? operationalRoles
      : normalizedRoles.toList(growable: false);

  candidates.sort((AppRole left, AppRole right) {
    return (_homeRoleRanks[right] ?? 0).compareTo(_homeRoleRanks[left] ?? 0);
  });

  return homeDashboardProfiles[candidates.first] ??
      homeDashboardProfiles[AppRole.other]!;
}

/// Prefer canonical roles; for custom roles, infer a dashboard from permissions.
///
/// Ranked roles keep layout chrome. [expandHomeProfileForPermissions] unions
/// grantable KPI/shortcut atoms from other domains so extra grants (e.g. doctor +
/// `billing:read`) surface without inventing a new [AppRole]. Visibility still
/// requires `grantsAll` via [filterHomeDashboardForAccess] / action libraries.
HomeDashboardProfile homeProfileForAccessPolicy(AppAccessPolicy policy) {
  final HomeDashboardProfile fromRoles = homeProfileForRoles(policy.roles);
  if (fromRoles.role != AppRole.other) {
    return expandHomeProfileForPermissions(fromRoles, policy);
  }

  final Set<AppPermission> permissions = policy.permissions;
  if (permissions.isEmpty) {
    return fromRoles;
  }

  bool has(AppPermission permission) => permissions.contains(permission);

  if (policy.isElevated || has(AppPermissions.systemAdmin)) {
    return expandHomeProfileForPermissions(
      homeDashboardProfiles[AppRole.superAdmin]!,
      policy,
    );
  }
  if (has(AppPermissions.tenantAdmin)) {
    return expandHomeProfileForPermissions(
      homeDashboardProfiles[AppRole.tenantAdmin]!,
      policy,
    );
  }
  if (has(AppPermissions.facilityAdmin)) {
    return expandHomeProfileForPermissions(
      homeDashboardProfiles[AppRole.facilityAdmin]!,
      policy,
    );
  }

  // Pick a layout base from the primary domain; expand unions grantable atoms.
  final HomeDashboardProfile inferred;
  if (has(AppPermissions.clinicalWrite) || has(AppPermissions.clinicalRead)) {
    inferred = homeDashboardProfiles[AppRole.doctor]!;
  } else if (has(AppPermissions.labWrite) || has(AppPermissions.labRead)) {
    inferred = homeDashboardProfiles[AppRole.labTech]!;
  } else if (has(AppPermissions.pharmacyWrite) ||
      has(AppPermissions.pharmacyRead)) {
    inferred = homeDashboardProfiles[AppRole.pharmacist]!;
  } else if (has(AppPermissions.radiologyWrite) ||
      has(AppPermissions.radiologyRead)) {
    inferred = homeDashboardProfiles[AppRole.radiologyTech]!;
  } else if (has(AppPermissions.billingWrite) ||
      has(AppPermissions.billingRead)) {
    inferred = homeDashboardProfiles[AppRole.billing]!;
  } else if (has(AppPermissions.hrWrite) || has(AppPermissions.hrRead)) {
    inferred = homeDashboardProfiles[AppRole.hr]!;
  } else if (has(AppPermissions.operationsWrite) ||
      has(AppPermissions.operationsRead)) {
    inferred = homeDashboardProfiles[AppRole.operations]!;
  } else if (has(AppPermissions.patientWrite) ||
      has(AppPermissions.patientRead)) {
    inferred = homeDashboardProfiles[AppRole.receptionist]!;
  } else if (permissions.length >= 8) {
    // Broad custom packs: facility-command chrome, then permission filter.
    inferred = homeDashboardProfiles[AppRole.facilityAdmin]!;
  } else {
    return fromRoles;
  }

  return expandHomeProfileForPermissions(inferred, policy);
}

/// Unions grantable KPI/shortcut atoms onto [base] layout chrome.
///
/// Roles choose the default profile layout; visibility still requires
/// `grantsAll` via [filterHomeDashboardForAccess] / action libraries.
///
/// Ordering keeps the base role's primary KPI window first, then inserts
/// **cross-domain** grantable cards (permissions not already on the base
/// profile) so extra grants (e.g. `billing:read` on a doctor) surface inside
/// the 4–6 card budget. Same-domain extras follow after.
///
/// Quick actions and empty/management action ids stay on the base profile only
/// so admin Manage hubs are not buried under every department's Create row and
/// clinical next-steps are not mixed into organization/platform summaries.
HomeDashboardProfile expandHomeProfileForPermissions(
  HomeDashboardProfile base,
  AppAccessPolicy policy,
) {
  final LinkedHashSet<String> baseCardIds = LinkedHashSet<String>.of(
    base.statusCards.map((HomeStatusCardTemplate template) => template.id),
  );
  final Set<AppPermission> basePermissionUniverse = <AppPermission>{
    for (final HomeStatusCardTemplate template in base.statusCards)
      ...template.effectiveRequiredPermissions,
  };
  final LinkedHashMap<String, HomeStatusCardTemplate> crossDomainCards =
      LinkedHashMap<String, HomeStatusCardTemplate>();
  final LinkedHashMap<String, HomeStatusCardTemplate> sameDomainCards =
      LinkedHashMap<String, HomeStatusCardTemplate>();

  final LinkedHashSet<String> shortcutIds = LinkedHashSet<String>.of(
    base.shortcutIds,
  );
  final Map<String, HomeMetricRouteTarget> metricRoutes =
      Map<String, HomeMetricRouteTarget>.of(base.metricRouteTargets);
  final Map<String, HomeMetricActionTarget> metricActions =
      Map<String, HomeMetricActionTarget>.of(base.metricActionTargets);

  for (final HomeDashboardProfile profile in homeDashboardProfiles.values) {
    if (profile.id == base.id || profile.role == AppRole.other) {
      continue;
    }
    for (final HomeStatusCardTemplate template in profile.statusCards) {
      if (baseCardIds.contains(template.id) ||
          crossDomainCards.containsKey(template.id) ||
          sameDomainCards.containsKey(template.id)) {
        continue;
      }
      // Receptionist front desk: omit profile KPI cards from portal/other packs.
      if (base.id == 'receptionist' &&
          (template.id == 'profile_status' ||
              template.id == 'my_profile_status')) {
        continue;
      }
      final List<AppPermission> required =
          template.effectiveRequiredPermissions;
      if (required.isEmpty || !policy.grantsAll(required)) {
        continue;
      }
      final bool isCrossDomain = required.any(
        (AppPermission permission) =>
            !basePermissionUniverse.contains(permission),
      );
      // Pharmacist home stays pharmacy-focused — no Admissions/Appointments
      // or other clinical cross-domain KPI cards on the strip.
      if (base.id == 'pharmacist' && isCrossDomain) {
        continue;
      }
      if (isCrossDomain) {
        crossDomainCards[template.id] = template;
      } else {
        sameDomainCards[template.id] = template;
      }
    }
    for (final String id in profile.shortcutIds) {
      // Receptionist shell: no profile tile; OPD/Emergency stay on Reception.
      if (base.id == 'receptionist' &&
          (id == 'profile' || id == 'opd' || id == 'emergency')) {
        continue;
      }
      shortcutIds.add(id);
    }
    for (final MapEntry<String, HomeMetricRouteTarget> entry
        in profile.metricRouteTargets.entries) {
      metricRoutes.putIfAbsent(entry.key, () => entry.value);
    }
    for (final MapEntry<String, HomeMetricActionTarget> entry
        in profile.metricActionTargets.entries) {
      metricActions.putIfAbsent(entry.key, () => entry.value);
    }
  }

  if (crossDomainCards.isEmpty && sameDomainCards.isEmpty) {
    return base.copyWith(
      shortcutIds: shortcutIds.toList(growable: false),
      metricRouteTargets: metricRoutes,
      metricActionTargets: metricActions,
    );
  }

  final int primaryWindow = math.max(1, base.maxStatusCards);
  final List<HomeStatusCardTemplate> prioritizedCrossDomain =
      _prioritizeCrossDomainCards(crossDomainCards.values);
  final List<HomeStatusCardTemplate> ordered = <HomeStatusCardTemplate>[
    ...base.statusCards.take(primaryWindow),
    ...prioritizedCrossDomain,
    ...sameDomainCards.values,
    ...base.statusCards.skip(primaryWindow),
  ];

  return base.copyWith(
    statusCards: ordered,
    shortcutIds: shortcutIds.toList(growable: false),
    metricRouteTargets: metricRoutes,
    metricActionTargets: metricActions,
    // Keep pharmacist strip at the pharmacy KPI window (no clinical expand).
    maxStatusCards: base.id == 'pharmacist'
        ? base.maxStatusCards
        : math.min(6, math.max(base.maxStatusCards, ordered.length)),
  );
}

/// Prefer canonical domain KPIs (e.g. billing pack revenue) over aliases from
/// other personas so the 4–6 card window surfaces the strongest grant signal.
List<HomeStatusCardTemplate> _prioritizeCrossDomainCards(
  Iterable<HomeStatusCardTemplate> cards,
) {
  const Map<String, int> preferredOrder = <String, int>{
    // Billing (Dashboard.md §9) — prefer over facility/reception aliases.
    'collections_today': 0,
    'overdue_balance_amount': 1,
    'open_balances': 2,
    'pending_balance_amount': 3,
    'invoices_today': 4,
    'overdue_invoices': 5,
    'billing_exceptions': 6,
    // Clinical / lab extras when granted onto non-clinical bases.
    'assigned': 10,
    'results_pending_review': 11,
    'orders_today': 12,
    'lab_pending': 12,
    'critical_results': 13,
    'lab_all_patients': 13,
    'lab_orders_week': 13,
    'lab_orders_month': 13,
    // Doctor secondary atoms when granted onto clinical bases (Dashboard.md §4).
    'radiology_pending': 14,
    'prescriptions_pending': 15,
    'emergency_cases_today': 16,
    'shifts_today': 17,
  };
  final List<HomeStatusCardTemplate> sorted = cards.toList(growable: false);
  sorted.sort((HomeStatusCardTemplate left, HomeStatusCardTemplate right) {
    final int leftRank = preferredOrder[left.id] ?? 100;
    final int rightRank = preferredOrder[right.id] ?? 100;
    if (leftRank != rightRank) {
      return leftRank.compareTo(rightRank);
    }
    return left.id.compareTo(right.id);
  });
  return sorted;
}

HomeDashboardProfile homeProfileForRole(AppRole? role) {
  return homeDashboardProfiles[role] ?? homeDashboardProfiles[AppRole.other]!;
}

HomeDashboardProfile homeProfileForProfileId(String? profileId) {
  final String normalized = (profileId ?? '').trim().toLowerCase();
  for (final HomeDashboardProfile profile in homeDashboardProfiles.values) {
    if (profile.id == normalized) {
      return profile;
    }
  }

  return homeDashboardProfiles[AppRole.other]!;
}

AppRole? appRoleFromValue(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase().replaceAll(
    RegExp(r'[\s-]+'),
    '_',
  );
  if (normalized.isEmpty) {
    return null;
  }

  for (final AppRole role in AppRole.values) {
    if (role.value == normalized) {
      return role;
    }
  }

  return null;
}

List<String> mergedHomeQuickActions(Iterable<AppRole> roles) {
  return _mergeProfileIds(roles, (HomeDashboardProfile profile) {
    return profile.quickActionIds;
  });
}

List<String> mergedHomeShortcuts(Iterable<AppRole> roles) {
  return _mergeProfileIds(roles, (HomeDashboardProfile profile) {
    return profile.shortcutIds;
  });
}

List<String> _mergeProfileIds(
  Iterable<AppRole> roles,
  List<String> Function(HomeDashboardProfile profile) selector,
) {
  final HomeDashboardProfile main = homeProfileForRoles(roles);
  final List<AppRole> orderedRoles = roles.toSet().toList(growable: false)
    ..sort((AppRole left, AppRole right) {
      return (_homeRoleRanks[right] ?? 0).compareTo(_homeRoleRanks[left] ?? 0);
    });
  final LinkedHashSet<String> ids = LinkedHashSet<String>();

  ids.addAll(selector(main));
  for (final AppRole role in orderedRoles) {
    ids.addAll(selector(homeProfileForRole(role)));
  }

  return ids.toList(growable: false);
}
