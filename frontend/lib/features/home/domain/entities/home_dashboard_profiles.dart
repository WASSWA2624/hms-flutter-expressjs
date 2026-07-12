import 'dart:collection';

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
  AppRole.unitManager: 15,
  AppRole.wardManager: 16,
  AppRole.icuManager: 17,
  AppRole.theatreManager: 18,
  AppRole.housekeepingManager: 19,
  AppRole.biomedManager: 20,
  AppRole.mortuaryManager: 21,
  AppRole.facilityAdmin: 22,
  AppRole.tenantAdmin: 23,
  AppRole.superAdmin: 24,
};

const Map<AppRole, HomeDashboardProfile>
homeDashboardProfiles = <AppRole, HomeDashboardProfile>{
  AppRole.superAdmin: HomeDashboardProfile(
    id: 'super_admin',
    role: AppRole.superAdmin,
    roleLabel: 'Platform administrator',
    homeTitle: 'Platform',
    emptyMessage: '',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'tenants_active',
        label: 'Tenants',
        format: 'ratio',
      ),
      HomeStatusCardTemplate(id: 'facilities_active', label: 'Facilities'),
      HomeStatusCardTemplate(
        id: 'subscriptions_health',
        label: 'Subscriptions',
        format: 'ratio',
      ),
      HomeStatusCardTemplate(
        id: 'module_entitlement_issues',
        label: 'Entitlements',
      ),
    ],
    quickActionIds: <String>[
      'create_tenant',
      'create_facility',
      'manage_tenants',
      'manage_facilities',
      'manage_roles_access',
      'manage_users',
      'create_role',
      'create_user',
    ],
    shortcutIds: <String>[
      'subscriptions',
      'tenant_facility_setup',
      'settings',
      'reports',
    ],
    emptyActionIds: <String>[
      'manage_tenants',
      'manage_facilities',
      'manage_roles_access',
      'manage_users',
    ],
  ),
  AppRole.tenantAdmin: HomeDashboardProfile(
    id: 'tenant_admin',
    role: AppRole.tenantAdmin,
    roleLabel: 'Organization administrator',
    homeTitle: 'Organization',
    emptyMessage:
        'Create facilities, assign roles, and onboard users across your organization.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'facilities_active',
        label: 'Facilities',
        format: 'ratio',
      ),
      HomeStatusCardTemplate(id: 'active_users', label: 'Users'),
      HomeStatusCardTemplate(
        id: 'module_adoption',
        label: 'Adoption',
        format: 'percent',
      ),
      HomeStatusCardTemplate(
        id: 'subscription_health',
        label: 'Subscription',
        format: 'percent',
      ),
    ],
    quickActionIds: <String>[
      'create_facility',
      'create_role',
      'create_user',
      'add_staff_profile',
      'manage_facilities',
      'manage_roles_access',
      'manage_users_roles',
      'manage_users',
    ],
    shortcutIds: <String>[
      'tenant_facility_setup',
      'settings',
      'reports',
      'subscriptions',
    ],
    emptyActionIds: <String>[
      'manage_facilities',
      'manage_roles_access',
      'manage_users_roles',
      'manage_users',
    ],
  ),
  AppRole.facilityAdmin: HomeDashboardProfile(
    id: 'facility_admin',
    role: AppRole.facilityAdmin,
    roleLabel: 'Facility administrator',
    homeTitle: 'Facility ops',
    emptyMessage:
        'Facility setup is ready for daily work once patients, services, beds, and staff are configured.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'patient_flow_today', label: 'Flow today'),
      HomeStatusCardTemplate(id: 'appointments_today', label: 'Appointments'),
      HomeStatusCardTemplate(id: 'active_admissions', label: 'Admissions'),
      HomeStatusCardTemplate(id: 'bed_occupancy', label: 'Occupied'),
      HomeStatusCardTemplate(id: 'billing_exceptions', label: 'Billing'),
      HomeStatusCardTemplate(id: 'operational_blockers', label: 'Blockers'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
      ),
    ],
    quickActionIds: <String>[
      'register_patient',
      'book_appointment',
      'check_in_patient',
    ],
    shortcutIds: <String>['opd', 'patients'],
    emptyActionIds: <String>['register_patient', 'book_appointment'],
  ),
  AppRole.doctor: HomeDashboardProfile(
    id: 'doctor',
    role: AppRole.doctor,
    roleLabel: 'Doctor / clinician',
    homeTitle: 'Clinical',
    emptyMessage: 'No assigned clinical work right now.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'assigned', label: 'Assigned today'),
      HomeStatusCardTemplate(id: 'in_progress', label: 'In progress'),
      HomeStatusCardTemplate(
        id: 'results_pending_review',
        label: 'Results to review',
      ),
      HomeStatusCardTemplate(id: 'follow_ups_due', label: 'Follow-ups due'),
      HomeStatusCardTemplate(id: 'completed', label: 'Completed'),
      HomeStatusCardTemplate(id: 'critical_labs', label: 'Critical labs'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
      ),
    ],
    quickActionIds: <String>[
      'start_consultation',
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
      'ipd',
    ],
    emptyActionIds: <String>[
      'start_consultation',
      'order_lab',
      'write_clinical_note',
    ],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'assigned': HomeMetricRouteTarget(),
      'in_progress': HomeMetricRouteTarget(),
      'results_pending_review': HomeMetricRouteTarget(),
      'follow_ups_due': HomeMetricRouteTarget(),
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
      HomeStatusCardTemplate(id: 'inpatient_flow', label: 'Inpatients'),
      HomeStatusCardTemplate(id: 'med_admin_today', label: 'Med admin'),
      HomeStatusCardTemplate(id: 'transfer_queue', label: 'Transfers'),
      HomeStatusCardTemplate(id: 'critical_labs', label: 'Critical labs'),
      HomeStatusCardTemplate(id: 'discharge_pressure', label: 'Discharge'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
      ),
      HomeStatusCardTemplate(id: 'appointments_today', label: 'OPD queue'),
      HomeStatusCardTemplate(
        id: 'emergency_cases_today',
        label: 'Emergency cases',
      ),
      HomeStatusCardTemplate(
        id: 'theatre_cases_today',
        label: 'Theatre cases',
      ),
      HomeStatusCardTemplate(
        id: 'radiology_pending',
        label: 'Imaging pending',
      ),
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
    emptyActionIds: <String>['record_vitals', 'create_handover'],
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
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'orders_today', label: 'Orders'),
      HomeStatusCardTemplate(id: 'in_process', label: 'In process'),
      HomeStatusCardTemplate(id: 'pending_results', label: 'Results queue'),
      HomeStatusCardTemplate(id: 'critical_results', label: 'Critical'),
      HomeStatusCardTemplate(id: 'completed_orders', label: 'Completed'),
    ],
    quickActionIds: <String>[
      'receive_sample',
      'enter_lab_result',
      'flag_critical_lab',
    ],
    shortcutIds: <String>['lab'],
    emptyActionIds: <String>[
      'receive_sample',
      'enter_lab_result',
      'flag_critical_lab',
    ],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'orders_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'scope': 'all'},
      ),
      'in_process': HomeMetricRouteTarget(
        queryParameters: <String, String>{'scope': 'processing'},
      ),
      'pending_results': HomeMetricRouteTarget(
        queryParameters: <String, String>{'scope': 'results'},
      ),
      'critical_results': HomeMetricRouteTarget(
        queryParameters: <String, String>{'scope': 'critical'},
      ),
      'completed_orders': HomeMetricRouteTarget(
        queryParameters: <String, String>{'scope': 'completed'},
      ),
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
      ),
      HomeStatusCardTemplate(id: 'in_process', label: 'Studies in process'),
      HomeStatusCardTemplate(id: 'draft_reports', label: 'Draft reports'),
      HomeStatusCardTemplate(id: 'final_reports', label: 'Final reports'),
      HomeStatusCardTemplate(id: 'completed_orders', label: 'Completed'),
    ],
    quickActionIds: <String>[
      'start_imaging_study',
      'update_imaging_status',
      'add_radiology_report',
      'run_report',
    ],
    shortcutIds: <String>['radiology', 'reports'],
    emptyActionIds: <String>['start_imaging_study'],
  ),
  AppRole.pharmacist: HomeDashboardProfile(
    id: 'pharmacist',
    role: AppRole.pharmacist,
    roleLabel: 'Pharmacist',
    homeTitle: 'Pharmacy',
    emptyMessage:
        'No pending orders. Check stock levels or review today\'s dispensing activity.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'orders_today', label: 'Orders'),
      HomeStatusCardTemplate(id: 'pending_dispense', label: 'Pending'),
      HomeStatusCardTemplate(id: 'dispensed_today', label: 'Dispensed'),
      HomeStatusCardTemplate(id: 'low_stock', label: 'Low stock'),
      HomeStatusCardTemplate(id: 'critical_stock', label: 'Critical stock'),
    ],
    quickActionIds: <String>[
      'dispense_medication',
      'record_pharmacy_sale',
      'receive_pharmacy_stock',
      'adjust_pharmacy_stock',
    ],
    shortcutIds: <String>['pharmacy', 'patients'],
    emptyActionIds: const <String>[],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'orders_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'orders'},
      ),
      'pending_dispense': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'orders'},
      ),
      'dispensed_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'orders'},
      ),
      'low_stock': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'inventory'},
      ),
      'critical_stock': HomeMetricRouteTarget(
        queryParameters: <String, String>{'section': 'inventory'},
      ),
    },
  ),
  AppRole.receptionist: HomeDashboardProfile(
    id: 'receptionist',
    role: AppRole.receptionist,
    roleLabel: 'Reception / front desk',
    homeTitle: 'Front desk',
    emptyMessage:
        'No desk queue items right now. Use quick links for registry, OPD, emergency, or follow-ups.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'appointments_today', label: 'Meetings'),
      HomeStatusCardTemplate(id: 'desk_queue', label: 'Desk queue'),
      HomeStatusCardTemplate(id: 'turnaround_pressure', label: 'In progress'),
      HomeStatusCardTemplate(id: 'no_show_pressure', label: 'Follow-ups'),
      HomeStatusCardTemplate(id: 'registrations_today', label: 'Registrations'),
      HomeStatusCardTemplate(
        id: 'emergency_cases_today',
        label: 'Emergency intake',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD alerts',
      ),
    ],
    quickActionIds: <String>[
      'register_patient',
      'book_appointment',
      'check_in_patient',
      'route_patient',
    ],
    shortcutIds: <String>[
      'patients',
      'opd',
      'emergency',
      'communications',
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
      'emergency_cases_today': HomeMetricRouteTarget(),
      'opd_notifications_attention': HomeMetricRouteTarget(),
    },
  ),
  AppRole.billing: HomeDashboardProfile(
    id: 'billing',
    role: AppRole.billing,
    roleLabel: 'Billing / cashier',
    homeTitle: 'Billing',
    emptyMessage:
        'No billing queue items right now. Jump into overdue invoices, open balances, claims, or patient accounts.',
    maxStatusCards: 4,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'collections_today',
        label: 'Collected today',
        format: 'currency',
      ),
      HomeStatusCardTemplate(
        id: 'overdue_balance_amount',
        label: 'Overdue amount',
        format: 'currency',
      ),
      HomeStatusCardTemplate(
        id: 'pending_balance_amount',
        label: 'Pending balances',
        format: 'currency',
      ),
      HomeStatusCardTemplate(id: 'invoices_today', label: 'Invoices today'),
      HomeStatusCardTemplate(id: 'overdue_invoices', label: 'Overdue'),
      HomeStatusCardTemplate(id: 'open_balances', label: 'Open accounts'),
      HomeStatusCardTemplate(
        id: 'refunds_today',
        label: 'Refunds',
        format: 'currency',
      ),
    ],
    quickActionIds: <String>[
      'create_invoice',
      'receive_payment',
      'process_refund',
      'close_shift',
    ],
    shortcutIds: <String>[
      'patients',
      'claims',
      'communications',
      'reports',
      'settings',
    ],
    emptyActionIds: <String>[
      'review_overdue_invoices',
      'review_pending_payments',
      'review_claims_pending',
      'review_open_patient_balances',
    ],
    metricRouteTargets: <String, HomeMetricRouteTarget>{
      'collections_today': HomeMetricRouteTarget(
        queryParameters: <String, String>{'queue': 'pendingPayment'},
      ),
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
      'refunds_today': const HomeMetricRouteTarget(),
    },
  ),
  AppRole.operations: HomeDashboardProfile(
    id: 'operations',
    role: AppRole.operations,
    roleLabel: 'Operations',
    homeTitle: 'Operations',
    emptyMessage: 'No operations items need action right now.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'occupied_beds', label: 'Occupied'),
      HomeStatusCardTemplate(id: 'total_beds', label: 'Total beds'),
      HomeStatusCardTemplate(id: 'maintenance_open', label: 'Maintenance'),
      HomeStatusCardTemplate(id: 'low_stock_pressure', label: 'Low stock'),
      HomeStatusCardTemplate(id: 'housekeeping_backlog', label: 'Housekeeping'),
      HomeStatusCardTemplate(
        id: 'facility_readiness',
        label: 'Readiness',
        format: 'percent',
      ),
    ],
    quickActionIds: <String>[
      'create_maintenance_request',
      'assign_maintenance',
      'update_bed_readiness',
    ],
    shortcutIds: <String>['operations'],
    emptyActionIds: <String>['create_maintenance_request'],
  ),
  AppRole.hr: HomeDashboardProfile(
    id: 'hr',
    role: AppRole.hr,
    roleLabel: 'HR / workforce',
    homeTitle: 'Workforce',
    emptyMessage: 'No HR tasks are pending.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'active_staff', label: 'Staff'),
      HomeStatusCardTemplate(id: 'shifts_today', label: 'Shifts'),
      HomeStatusCardTemplate(id: 'pending_leaves', label: 'Leave'),
      HomeStatusCardTemplate(id: 'on_leave_today', label: 'On leave'),
      HomeStatusCardTemplate(id: 'unassigned_shifts', label: 'Unassigned'),
      HomeStatusCardTemplate(id: 'attended_today', label: 'Attended'),
      HomeStatusCardTemplate(id: 'missed_shifts_today', label: 'Missed'),
      HomeStatusCardTemplate(id: 'payroll_pending', label: 'Payroll'),
    ],
    quickActionIds: <String>[],
    shortcutIds: <String>['hr', 'tenant_facility_setup', 'reports'],
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
      HomeStatusCardTemplate(id: 'open_work_orders', label: 'Work orders'),
      HomeStatusCardTemplate(id: 'open_incidents', label: 'Incidents'),
      HomeStatusCardTemplate(id: 'active_downtime', label: 'Downtime'),
      HomeStatusCardTemplate(id: 'critical_service_risk', label: 'Risk'),
      HomeStatusCardTemplate(id: 'high_priority', label: 'Priority'),
      HomeStatusCardTemplate(
        id: 'assets_operational',
        label: 'Operational',
        format: 'percent',
      ),
    ],
    quickActionIds: <String>['acknowledge_work_order', 'update_work_order'],
    shortcutIds: <String>['biomedical', 'reports'],
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
      HomeStatusCardTemplate(id: 'pending_tasks', label: 'Pending'),
      HomeStatusCardTemplate(id: 'in_progress_tasks', label: 'In progress'),
      HomeStatusCardTemplate(id: 'overdue_tasks', label: 'Overdue'),
      HomeStatusCardTemplate(id: 'completed_today', label: 'Done today'),
      HomeStatusCardTemplate(id: 'throughput', label: 'Throughput'),
    ],
    quickActionIds: <String>['start_cleaning_task', 'complete_cleaning_task'],
    shortcutIds: <String>['housekeeping', 'reports'],
    emptyActionIds: <String>['start_cleaning_task'],
  ),
  AppRole.ambulanceOperator: HomeDashboardProfile(
    id: 'ambulance_operator',
    role: AppRole.ambulanceOperator,
    roleLabel: 'Ambulance / emergency transport',
    homeTitle: 'Ambulance',
    emptyMessage: 'No ambulance dispatches are active.',
    maxStatusCards: 3,
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'dispatches_today', label: 'Dispatches'),
      HomeStatusCardTemplate(id: 'active_trips', label: 'Active trips'),
      HomeStatusCardTemplate(id: 'critical_cases', label: 'Emergencies'),
      HomeStatusCardTemplate(id: 'fleet_available', label: 'Available'),
      HomeStatusCardTemplate(id: 'fleet_out', label: 'Out of service'),
    ],
    quickActionIds: <String>['dispatch_ambulance', 'update_trip_status'],
    shortcutIds: <String>['emergency', 'reports'],
    emptyActionIds: <String>['dispatch_ambulance'],
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
    shortcutIds: <String>['hr', 'nursing', 'ipd', 'reports'],
    emptyActionIds: <String>['publish_roster', 'run_report'],
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
      HomeStatusCardTemplate(id: 'occupied_beds', label: 'Occupied'),
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
    emptyActionIds: <String>['create_handover', 'publish_roster'],
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
    emptyActionIds: <String>['record_vitals', 'run_report'],
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
    emptyActionIds: <String>['run_report'],
  ),
  AppRole.housekeepingManager: HomeDashboardProfile(
    id: 'housekeeping_manager',
    role: AppRole.housekeepingManager,
    roleLabel: 'Housekeeping manager',
    homeTitle: 'Housekeeping control dashboard',
    emptyMessage: 'No housekeeping backlog is pending.',
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
    emptyActionIds: <String>['create_cleaning_task'],
  ),
  AppRole.biomedManager: HomeDashboardProfile(
    id: 'biomed_manager',
    role: AppRole.biomedManager,
    roleLabel: 'Biomedical manager',
    homeTitle: 'Biomedical risk dashboard',
    emptyMessage: 'No biomedical risk items need action.',
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
    shortcutIds: <String>['biomedical', 'reports'],
    emptyActionIds: <String>['report_equipment_issue'],
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
      ),
      HomeStatusCardTemplate(
        id: 'storage_assignments',
        label: 'Storage assignments',
      ),
      HomeStatusCardTemplate(id: 'viewings_today', label: 'Viewings today'),
      HomeStatusCardTemplate(
        id: 'post_mortem_requests',
        label: 'Post-mortem requests',
      ),
      HomeStatusCardTemplate(
        id: 'custody_events_due',
        label: 'Custody events due',
      ),
      HomeStatusCardTemplate(
        id: 'billable_events_to_capture',
        label: 'Billable events to capture',
      ),
    ],
    quickActionIds: <String>[
      'open_mortuary_case',
      'assign_storage_slot',
      'record_custody_event',
      'schedule_viewing',
      'add_mortuary_billable_event',
    ],
    shortcutIds: <String>['mortuary'],
    emptyActionIds: <String>['open_mortuary_case', 'record_custody_event'],
  ),
  AppRole.mortuaryManager: HomeDashboardProfile(
    id: 'mortuary_manager',
    role: AppRole.mortuaryManager,
    roleLabel: 'Mortuary manager',
    homeTitle: 'Mortuary oversight dashboard',
    emptyMessage: 'No mortuary approvals need action.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'active_mortuary_cases',
        label: 'Active mortuary cases',
      ),
      HomeStatusCardTemplate(
        id: 'storage_occupancy',
        label: 'Storage occupancy',
      ),
      HomeStatusCardTemplate(
        id: 'releases_awaiting_approval',
        label: 'Releases awaiting approval',
      ),
      HomeStatusCardTemplate(
        id: 'pending_post_mortem_requests',
        label: 'Pending post-mortem requests',
      ),
      HomeStatusCardTemplate(
        id: 'custody_exceptions',
        label: 'Custody exceptions',
      ),
      HomeStatusCardTemplate(
        id: 'audit_exports_due',
        label: 'Audit exports due',
      ),
    ],
    quickActionIds: <String>[
      'review_release_authorization',
      'approve_release',
      'export_mortuary_evidence',
      'open_mortuary_case',
      'run_report',
    ],
    shortcutIds: <String>['mortuary', 'reports'],
    emptyActionIds: <String>[
      'review_release_authorization',
      'open_mortuary_case',
    ],
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
      ),
      HomeStatusCardTemplate(id: 'my_open_bills', label: 'Bills'),
      HomeStatusCardTemplate(id: 'my_prescriptions', label: 'Rx'),
      HomeStatusCardTemplate(id: 'my_released_results', label: 'Results'),
      HomeStatusCardTemplate(id: 'my_messages', label: 'Messages'),
      HomeStatusCardTemplate(
        id: 'my_profile_status',
        label: 'Profile',
        format: 'percent',
      ),
    ],
    quickActionIds: <String>['update_own_profile', 'view_my_care'],
    shortcutIds: <String>[],
    emptyActionIds: <String>['update_own_profile', 'contact_facility'],
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
      HomeStatusCardTemplate(id: 'profile_status', label: 'Profile status'),
      HomeStatusCardTemplate(id: 'assigned_links', label: 'Assigned links'),
      HomeStatusCardTemplate(id: 'unread_messages', label: 'Unread messages'),
      HomeStatusCardTemplate(id: 'facility_notices', label: 'Facility notices'),
    ],
    quickActionIds: <String>['update_own_profile', 'contact_facility'],
    shortcutIds: <String>['profile', 'settings'],
    emptyActionIds: <String>['update_own_profile'],
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
HomeDashboardProfile homeProfileForAccessPolicy(AppAccessPolicy policy) {
  final HomeDashboardProfile fromRoles = homeProfileForRoles(policy.roles);
  if (fromRoles.role != AppRole.other) {
    return fromRoles;
  }

  final Set<AppPermission> permissions = policy.permissions;
  if (permissions.isEmpty) {
    return fromRoles;
  }

  bool has(AppPermission permission) => permissions.contains(permission);

  if (policy.isElevated || has(AppPermissions.systemAdmin)) {
    return homeDashboardProfiles[AppRole.superAdmin]!;
  }
  if (has(AppPermissions.tenantAdmin)) {
    return homeDashboardProfiles[AppRole.tenantAdmin]!;
  }
  if (has(AppPermissions.facilityAdmin)) {
    return homeDashboardProfiles[AppRole.facilityAdmin]!;
  }
  if (has(AppPermissions.clinicalWrite) || has(AppPermissions.clinicalRead)) {
    return homeDashboardProfiles[AppRole.doctor]!;
  }
  if (has(AppPermissions.labWrite) || has(AppPermissions.labRead)) {
    return homeDashboardProfiles[AppRole.labTech]!;
  }
  if (has(AppPermissions.pharmacyWrite) || has(AppPermissions.pharmacyRead)) {
    return homeDashboardProfiles[AppRole.pharmacist]!;
  }
  if (has(AppPermissions.radiologyWrite) ||
      has(AppPermissions.radiologyRead)) {
    return homeDashboardProfiles[AppRole.radiologyTech]!;
  }
  if (has(AppPermissions.billingWrite) || has(AppPermissions.billingRead)) {
    return homeDashboardProfiles[AppRole.billing]!;
  }
  if (has(AppPermissions.hrWrite) || has(AppPermissions.hrRead)) {
    return homeDashboardProfiles[AppRole.hr]!;
  }
  if (has(AppPermissions.operationsWrite) ||
      has(AppPermissions.operationsRead)) {
    return homeDashboardProfiles[AppRole.operations]!;
  }
  if (has(AppPermissions.patientWrite) || has(AppPermissions.patientRead)) {
    return homeDashboardProfiles[AppRole.receptionist]!;
  }

  // Broad custom permission packs should not fall back to the empty "other"
  // dashboard when the user clearly has operational rights.
  if (permissions.length >= 8) {
    return homeDashboardProfiles[AppRole.facilityAdmin]!;
  }

  return fromRoles;
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
