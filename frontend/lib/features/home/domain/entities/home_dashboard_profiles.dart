import 'dart:collection';

import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

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
    homeTitle: 'Platform command center',
    homeSubtitle:
        'Select a tenant or review system-wide items that need attention.',
    emptyMessage: 'Choose a tenant to view operational dashboards.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'tenants_active', label: 'Tenants active'),
      HomeStatusCardTemplate(
        id: 'facilities_active',
        label: 'Facilities active',
      ),
      HomeStatusCardTemplate(
        id: 'subscriptions_review',
        label: 'Subscriptions needing review',
      ),
      HomeStatusCardTemplate(
        id: 'plan_limit_warnings',
        label: 'Plan-limit warnings',
      ),
      HomeStatusCardTemplate(
        id: 'integration_errors',
        label: 'Integration/API errors',
      ),
    ],
    quickActionIds: <String>[
      'select_context',
      'manage_subscription',
      'run_report',
    ],
    shortcutIds: <String>[
      'tenant_facility_setup',
      'subscriptions',
      'reports',
      'integrations',
      'settings',
    ],
    emptyActionIds: <String>['select_context', 'manage_subscription'],
  ),
  AppRole.tenantAdmin: HomeDashboardProfile(
    id: 'tenant_admin',
    role: AppRole.tenantAdmin,
    roleLabel: 'Organization administrator',
    homeTitle: 'Organization overview',
    homeSubtitle:
        'Monitor patient flow, revenue, staffing, module readiness, and subscription health across your organization.',
    emptyMessage: 'Start by setting up patients, staff, services, and billing.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'patients_today',
        label: 'Patients registered today',
      ),
      HomeStatusCardTemplate(
        id: 'appointments_today',
        label: 'Appointments today',
      ),
      HomeStatusCardTemplate(
        id: 'active_admissions',
        label: 'Active admissions',
      ),
      HomeStatusCardTemplate(id: 'open_invoices', label: 'Open invoices'),
      HomeStatusCardTemplate(
        id: 'payments_today',
        label: 'Payments received today',
        format: 'currency',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>[
      'new_patient',
      'appointment',
      'invoice',
      'start_admission',
      'lab_order',
      'sale',
      'report_equipment_issue',
      'run_report',
    ],
    shortcutIds: <String>[
      'patients',
      'opd',
      'ipd',
      'clinical',
      'lab',
      'radiology',
      'pharmacy',
      'billing',
      'claims',
      'hr',
      'operations',
      'reports',
      'subscriptions',
      'settings',
    ],
    emptyActionIds: <String>['new_patient', 'staff_profile', 'select_context'],
  ),
  AppRole.facilityAdmin: HomeDashboardProfile(
    id: 'facility_admin',
    role: AppRole.facilityAdmin,
    roleLabel: 'Facility administrator',
    homeTitle: 'Facility operations dashboard',
    homeSubtitle:
        'Track today\'s flow, bed readiness, staffing, revenue, and operational blockers for this facility.',
    emptyMessage:
        'Facility setup is ready for daily work once patients, services, beds, and staff are configured.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'patients_today',
        label: 'Patients added today',
      ),
      HomeStatusCardTemplate(
        id: 'appointments_today',
        label: 'Appointments today',
      ),
      HomeStatusCardTemplate(
        id: 'active_admissions',
        label: 'Active admissions',
      ),
      HomeStatusCardTemplate(id: 'occupied_beds', label: 'Occupied beds'),
      HomeStatusCardTemplate(id: 'open_invoices', label: 'Open invoices'),
      HomeStatusCardTemplate(
        id: 'payments_today',
        label: 'Payments received today',
        format: 'currency',
      ),
    ],
    quickActionIds: <String>[
      'new_patient',
      'appointment',
      'invoice',
      'start_admission',
      'report_maintenance_issue',
      'report_equipment_issue',
      'run_report',
    ],
    shortcutIds: <String>[
      'opd',
      'patients',
      'ipd',
      'nursing',
      'clinical',
      'billing',
      'pharmacy',
      'lab',
      'radiology',
      'housekeeping',
      'biomedical',
      'reports',
      'settings',
    ],
    emptyActionIds: <String>['new_patient', 'staff_profile'],
  ),
  AppRole.doctor: HomeDashboardProfile(
    id: 'doctor',
    role: AppRole.doctor,
    roleLabel: 'Doctor / clinician',
    homeTitle: 'Clinical worklist',
    homeSubtitle:
        'Review assigned consultations, results, admissions, and urgent follow-up.',
    emptyMessage: 'No assigned clinical work right now.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'assigned', label: 'Assigned consultations'),
      HomeStatusCardTemplate(
        id: 'in_progress',
        label: 'Consultations in progress',
      ),
      HomeStatusCardTemplate(id: 'completed', label: 'Completed consultations'),
      HomeStatusCardTemplate(id: 'admissions', label: 'Active admissions'),
      HomeStatusCardTemplate(
        id: 'critical_labs',
        label: 'Critical lab signals',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>[
      'start_consultation',
      'record_vitals',
      'lab_order',
      'radiology_order',
      'start_admission',
    ],
    shortcutIds: <String>[
      'clinical',
      'opd',
      'nursing',
      'ipd',
      'icu',
      'lab',
      'radiology',
      'discharge',
    ],
    emptyActionIds: <String>['start_consultation', 'lab_order'],
  ),
  AppRole.nurse: HomeDashboardProfile(
    id: 'nurse',
    role: AppRole.nurse,
    roleLabel: 'Nurse',
    homeTitle: 'Nursing work dashboard',
    homeSubtitle:
        'Coordinate patient observations, medications, ward tasks, and handovers.',
    emptyMessage: 'No nursing tasks are assigned right now.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'inpatient_flow', label: 'Active inpatients'),
      HomeStatusCardTemplate(
        id: 'med_admin_today',
        label: 'Medication administrations today',
      ),
      HomeStatusCardTemplate(id: 'transfer_queue', label: 'Transfer queue'),
      HomeStatusCardTemplate(
        id: 'critical_labs',
        label: 'Critical lab signals',
      ),
      HomeStatusCardTemplate(
        id: 'discharge_pressure',
        label: 'Discharge pressure',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['record_vitals', 'start_admission'],
    shortcutIds: <String>[
      'nursing',
      'ipd',
      'icu',
      'opd',
      'clinical',
      'discharge',
      'mortuary',
    ],
    emptyActionIds: <String>['record_vitals', 'start_admission'],
  ),
  AppRole.labTech: HomeDashboardProfile(
    id: 'lab_tech',
    role: AppRole.labTech,
    roleLabel: 'Laboratory technologist',
    homeTitle: 'Laboratory queue',
    homeSubtitle:
        'Process samples, update results, and highlight critical findings.',
    emptyMessage: 'No lab work is pending.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'orders_today', label: 'Lab orders today'),
      HomeStatusCardTemplate(id: 'in_process', label: 'Orders in process'),
      HomeStatusCardTemplate(id: 'pending_results', label: 'Pending results'),
      HomeStatusCardTemplate(id: 'critical_results', label: 'Critical results'),
      HomeStatusCardTemplate(id: 'completed_orders', label: 'Completed orders'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['lab_order', 'run_report'],
    shortcutIds: <String>['lab', 'reports'],
    emptyActionIds: <String>['lab_order'],
  ),
  AppRole.radiologyTech: HomeDashboardProfile(
    id: 'radiology_tech',
    role: AppRole.radiologyTech,
    roleLabel: 'Radiology / imaging technologist',
    homeTitle: 'Imaging worklist',
    homeSubtitle:
        'Track imaging requests, studies in progress, reports, and urgent imaging findings.',
    emptyMessage: 'No imaging work is pending.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'orders_today',
        label: 'Radiology orders today',
      ),
      HomeStatusCardTemplate(id: 'in_process', label: 'Studies in process'),
      HomeStatusCardTemplate(id: 'draft_reports', label: 'Draft reports'),
      HomeStatusCardTemplate(id: 'final_reports', label: 'Final reports'),
      HomeStatusCardTemplate(id: 'completed_orders', label: 'Completed orders'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['radiology_order', 'run_report'],
    shortcutIds: <String>['radiology', 'reports'],
    emptyActionIds: <String>['radiology_order'],
  ),
  AppRole.pharmacist: HomeDashboardProfile(
    id: 'pharmacist',
    role: AppRole.pharmacist,
    roleLabel: 'Pharmacist',
    homeTitle: 'Pharmacy workload',
    homeSubtitle:
        'Dispense medications, manage stock pressure, and review pending orders.',
    emptyMessage: 'No medication orders are waiting.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'orders_today',
        label: 'Medication orders today',
      ),
      HomeStatusCardTemplate(
        id: 'pending_dispense',
        label: 'Pending dispense workload',
      ),
      HomeStatusCardTemplate(id: 'dispensed_today', label: 'Dispensed today'),
      HomeStatusCardTemplate(id: 'low_stock', label: 'Low stock pressure'),
      HomeStatusCardTemplate(
        id: 'critical_stock',
        label: 'Critical stock pressure',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['sale', 'run_report'],
    shortcutIds: <String>['pharmacy', 'billing', 'reports'],
    emptyActionIds: <String>['sale'],
  ),
  AppRole.receptionist: HomeDashboardProfile(
    id: 'receptionist',
    role: AppRole.receptionist,
    roleLabel: 'Reception / front desk',
    homeTitle: 'Front desk dashboard',
    homeSubtitle:
        'Manage registrations, appointments, arrivals, queue movement, and first billing steps.',
    emptyMessage: 'No front-desk queue items right now.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'registrations_today',
        label: 'Registrations today',
      ),
      HomeStatusCardTemplate(id: 'desk_queue', label: 'Appointment desk queue'),
      HomeStatusCardTemplate(id: 'no_show_pressure', label: 'No-show pressure'),
      HomeStatusCardTemplate(
        id: 'front_billing_queue',
        label: 'Front billing queue',
      ),
      HomeStatusCardTemplate(
        id: 'appointments_today',
        label: 'Appointments today',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['new_patient', 'appointment', 'invoice'],
    shortcutIds: <String>['patients', 'opd', 'billing', 'profile'],
    emptyActionIds: <String>['new_patient', 'appointment'],
  ),
  AppRole.billing: HomeDashboardProfile(
    id: 'billing',
    role: AppRole.billing,
    roleLabel: 'Billing / cashier',
    homeTitle: 'Billing workbench',
    homeSubtitle:
        'Manage invoices, payments, overdue balances, claims, and day close.',
    emptyMessage: 'No billing items need action right now.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'invoices_today',
        label: 'Invoices issued today',
      ),
      HomeStatusCardTemplate(id: 'overdue_invoices', label: 'Overdue invoices'),
      HomeStatusCardTemplate(id: 'open_balances', label: 'Open balances'),
      HomeStatusCardTemplate(
        id: 'collections_today',
        label: 'Collections today',
        format: 'currency',
      ),
      HomeStatusCardTemplate(
        id: 'refunds_today',
        label: 'Refunds today',
        format: 'currency',
      ),
      HomeStatusCardTemplate(id: 'reports_ready', label: 'Reports ready'),
    ],
    quickActionIds: <String>['invoice', 'receive_payment', 'run_report'],
    shortcutIds: <String>['billing', 'claims', 'reports'],
    emptyActionIds: <String>['invoice', 'receive_payment'],
  ),
  AppRole.operations: HomeDashboardProfile(
    id: 'operations',
    role: AppRole.operations,
    roleLabel: 'Operations',
    homeTitle: 'Operations readiness dashboard',
    homeSubtitle:
        'Track beds, maintenance, housekeeping backlog, and facility readiness.',
    emptyMessage: 'No operations items need action right now.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'occupied_beds', label: 'Occupied beds'),
      HomeStatusCardTemplate(id: 'total_beds', label: 'Total beds'),
      HomeStatusCardTemplate(
        id: 'maintenance_open',
        label: 'Open maintenance requests',
      ),
      HomeStatusCardTemplate(
        id: 'low_stock_pressure',
        label: 'Low stock pressure',
      ),
      HomeStatusCardTemplate(
        id: 'housekeeping_backlog',
        label: 'Housekeeping backlog',
      ),
      HomeStatusCardTemplate(id: 'critical_alerts', label: 'Critical alerts'),
    ],
    quickActionIds: <String>[
      'report_maintenance_issue',
      'report_equipment_issue',
      'cleaning_task',
      'run_report',
    ],
    shortcutIds: <String>[
      'operations',
      'housekeeping',
      'rooms_beds',
      'biomedical',
      'reports',
    ],
    emptyActionIds: <String>['report_maintenance_issue'],
  ),
  AppRole.hr: HomeDashboardProfile(
    id: 'hr',
    role: AppRole.hr,
    roleLabel: 'HR / workforce',
    homeTitle: 'Workforce dashboard',
    homeSubtitle:
        'Manage staff profiles, leave, shifts, rosters, and staffing gaps.',
    emptyMessage: 'No HR tasks are pending.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'active_staff',
        label: 'Active staff profiles',
      ),
      HomeStatusCardTemplate(id: 'shifts_today', label: 'Shifts today'),
      HomeStatusCardTemplate(
        id: 'pending_leaves',
        label: 'Pending leave approvals',
      ),
      HomeStatusCardTemplate(id: 'staffing_backlog', label: 'Staffing backlog'),
      HomeStatusCardTemplate(
        id: 'unassigned_shifts',
        label: 'Unassigned shifts',
      ),
      HomeStatusCardTemplate(id: 'reports_ready', label: 'Reports ready'),
    ],
    quickActionIds: <String>['staff_profile', 'publish_roster', 'run_report'],
    shortcutIds: <String>['hr', 'reports'],
    emptyActionIds: <String>['staff_profile', 'publish_roster'],
  ),
  AppRole.biomed: HomeDashboardProfile(
    id: 'biomed',
    role: AppRole.biomed,
    roleLabel: 'Biomedical technician',
    homeTitle: 'Biomedical service queue',
    homeSubtitle:
        'Manage equipment work orders, incidents, downtime, and service-risk items.',
    emptyMessage: 'No biomedical work is pending.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'open_work_orders', label: 'Open work orders'),
      HomeStatusCardTemplate(id: 'open_incidents', label: 'Open incidents'),
      HomeStatusCardTemplate(
        id: 'active_downtime',
        label: 'Active downtime events',
      ),
      HomeStatusCardTemplate(
        id: 'critical_service_risk',
        label: 'Critical service-risk indicators',
      ),
      HomeStatusCardTemplate(
        id: 'high_priority',
        label: 'High-priority work orders',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['report_equipment_issue', 'run_report'],
    shortcutIds: <String>['biomedical', 'reports'],
    emptyActionIds: <String>['report_equipment_issue'],
  ),
  AppRole.houseKeeper: HomeDashboardProfile(
    id: 'house_keeper',
    role: AppRole.houseKeeper,
    roleLabel: 'Housekeeping staff',
    homeTitle: 'My cleaning tasks',
    homeSubtitle: 'Complete assigned cleaning, turnover, and sanitation tasks.',
    emptyMessage: 'No cleaning tasks are assigned right now.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'pending_tasks', label: 'Pending tasks'),
      HomeStatusCardTemplate(
        id: 'in_progress_tasks',
        label: 'Tasks in progress',
      ),
      HomeStatusCardTemplate(id: 'overdue_tasks', label: 'Overdue tasks'),
      HomeStatusCardTemplate(
        id: 'completed_today',
        label: 'Tasks completed today',
      ),
      HomeStatusCardTemplate(id: 'throughput', label: 'Completion throughput'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['cleaning_task'],
    shortcutIds: <String>['housekeeping', 'profile'],
    emptyActionIds: <String>['cleaning_task'],
  ),
  AppRole.ambulanceOperator: HomeDashboardProfile(
    id: 'ambulance_operator',
    role: AppRole.ambulanceOperator,
    roleLabel: 'Ambulance / emergency transport',
    homeTitle: 'Ambulance dispatch board',
    homeSubtitle:
        'Track dispatches, active trips, emergency handovers, and fleet availability.',
    emptyMessage: 'No ambulance dispatches are active.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'dispatches_today', label: 'Dispatches today'),
      HomeStatusCardTemplate(id: 'active_trips', label: 'Active trips'),
      HomeStatusCardTemplate(
        id: 'critical_cases',
        label: 'Critical emergencies',
      ),
      HomeStatusCardTemplate(id: 'fleet_available', label: 'Fleet available'),
      HomeStatusCardTemplate(id: 'fleet_out', label: 'Fleet out of service'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['dispatch_ambulance'],
    shortcutIds: <String>['emergency', 'communications'],
    emptyActionIds: <String>['dispatch_ambulance'],
  ),
  AppRole.unitManager: HomeDashboardProfile(
    id: 'unit_manager',
    role: AppRole.unitManager,
    roleLabel: 'Unit manager',
    homeTitle: 'Unit management dashboard',
    homeSubtitle:
        'Monitor unit workload, staff coverage, rosters, and operational blockers.',
    emptyMessage: 'No unit management items need action.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'unit_census', label: 'Unit census'),
      HomeStatusCardTemplate(id: 'staff_on_shift', label: 'Staff on shift'),
      HomeStatusCardTemplate(
        id: 'unassigned_shifts',
        label: 'Unassigned shifts',
      ),
      HomeStatusCardTemplate(
        id: 'pending_leaves',
        label: 'Pending leave requests',
      ),
      HomeStatusCardTemplate(id: 'unit_blockers', label: 'Unit blockers'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['publish_roster', 'run_report'],
    shortcutIds: <String>['hr', 'nursing', 'ipd', 'reports'],
    emptyActionIds: <String>['publish_roster', 'run_report'],
  ),
  AppRole.wardManager: HomeDashboardProfile(
    id: 'ward_manager',
    role: AppRole.wardManager,
    roleLabel: 'Ward manager / charge nurse',
    homeTitle: 'Ward command view',
    homeSubtitle:
        'Track ward census, bed movement, nursing work, handovers, and staffing coverage.',
    emptyMessage: 'No ward issues are currently pending.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'ward_census', label: 'Ward census'),
      HomeStatusCardTemplate(id: 'occupied_beds', label: 'Occupied beds'),
      HomeStatusCardTemplate(
        id: 'pending_nursing_tasks',
        label: 'Pending nursing tasks',
      ),
      HomeStatusCardTemplate(id: 'handover_risks', label: 'Handover risks'),
      HomeStatusCardTemplate(id: 'staff_on_shift', label: 'Staff on shift'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['record_vitals', 'publish_roster', 'run_report'],
    shortcutIds: <String>[
      'nursing',
      'ipd',
      'rooms_beds',
      'discharge',
      'hr',
      'reports',
    ],
    emptyActionIds: <String>['record_vitals', 'publish_roster'],
  ),
  AppRole.icuManager: HomeDashboardProfile(
    id: 'icu_manager',
    role: AppRole.icuManager,
    roleLabel: 'ICU manager',
    homeTitle: 'ICU oversight dashboard',
    homeSubtitle:
        'Monitor critical patients, ICU bed pressure, staffing, escalations, and transfer readiness.',
    emptyMessage: 'No ICU oversight items need action.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'icu_census', label: 'ICU census'),
      HomeStatusCardTemplate(
        id: 'critical_patients',
        label: 'Critical patients',
      ),
      HomeStatusCardTemplate(
        id: 'icu_beds_occupied',
        label: 'ICU beds occupied',
      ),
      HomeStatusCardTemplate(id: 'escalations_open', label: 'Escalations open'),
      HomeStatusCardTemplate(id: 'staff_coverage', label: 'Staff coverage'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>[
      'record_vitals',
      'report_equipment_issue',
      'run_report',
    ],
    shortcutIds: <String>[
      'icu',
      'nursing',
      'clinical',
      'rooms_beds',
      'biomedical',
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
    homeSubtitle:
        'Coordinate procedure readiness, theatre flow, staffing, and post-operative handovers.',
    emptyMessage: 'No theatre cases need action.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'procedures_today', label: 'Procedures today'),
      HomeStatusCardTemplate(
        id: 'ready_for_theatre',
        label: 'Ready for theatre',
      ),
      HomeStatusCardTemplate(id: 'in_theatre', label: 'In theatre'),
      HomeStatusCardTemplate(
        id: 'post_op_handovers',
        label: 'Post-op handovers pending',
      ),
      HomeStatusCardTemplate(
        id: 'cancellations_delays',
        label: 'Cancellations/delays',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>[
      'publish_roster',
      'report_equipment_issue',
      'run_report',
    ],
    shortcutIds: <String>[
      'theater',
      'clinical',
      'nursing',
      'ipd',
      'icu',
      'biomedical',
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
    homeSubtitle:
        'Manage cleaning workload, turnover readiness, staff coverage, and blocked rooms.',
    emptyMessage: 'No housekeeping backlog is pending.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'pending_cleaning_tasks',
        label: 'Pending cleaning tasks',
      ),
      HomeStatusCardTemplate(
        id: 'in_progress_tasks',
        label: 'In-progress tasks',
      ),
      HomeStatusCardTemplate(id: 'overdue_tasks', label: 'Overdue tasks'),
      HomeStatusCardTemplate(id: 'rooms_ready', label: 'Rooms ready'),
      HomeStatusCardTemplate(id: 'staff_on_shift', label: 'Staff on shift'),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['cleaning_task', 'publish_roster', 'run_report'],
    shortcutIds: <String>[
      'housekeeping',
      'rooms_beds',
      'operations',
      'hr',
      'reports',
    ],
    emptyActionIds: <String>['cleaning_task'],
  ),
  AppRole.biomedManager: HomeDashboardProfile(
    id: 'biomed_manager',
    role: AppRole.biomedManager,
    roleLabel: 'Biomedical manager',
    homeTitle: 'Biomedical risk dashboard',
    homeSubtitle:
        'Oversee equipment risk, technician workload, incidents, downtime, and maintenance compliance.',
    emptyMessage: 'No biomedical risk items need action.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'open_work_orders', label: 'Open work orders'),
      HomeStatusCardTemplate(
        id: 'high_priority',
        label: 'High-priority work orders',
      ),
      HomeStatusCardTemplate(id: 'active_downtime', label: 'Active downtime'),
      HomeStatusCardTemplate(id: 'open_incidents', label: 'Open incidents'),
      HomeStatusCardTemplate(
        id: 'overdue_maintenance',
        label: 'Overdue maintenance/calibration',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['report_equipment_issue', 'run_report'],
    shortcutIds: <String>['biomedical', 'reports'],
    emptyActionIds: <String>['report_equipment_issue'],
  ),
  AppRole.mortuaryStaff: HomeDashboardProfile(
    id: 'mortuary_staff',
    role: AppRole.mortuaryStaff,
    roleLabel: 'Mortuary staff',
    homeTitle: 'Mortuary work queue',
    homeSubtitle:
        'Manage custody, storage, viewings, post-mortem requests, and billable events.',
    emptyMessage: 'No mortuary tasks are pending.',
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
        id: 'release_tasks_pending',
        label: 'Release tasks pending',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>['mortuary_case'],
    shortcutIds: <String>['mortuary'],
    emptyActionIds: <String>['mortuary_case'],
  ),
  AppRole.mortuaryManager: HomeDashboardProfile(
    id: 'mortuary_manager',
    role: AppRole.mortuaryManager,
    roleLabel: 'Mortuary manager',
    homeTitle: 'Mortuary oversight dashboard',
    homeSubtitle:
        'Oversee custody compliance, storage capacity, release authorization, audit, and export readiness.',
    emptyMessage: 'No mortuary approvals need action.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'active_cases', label: 'Active cases'),
      HomeStatusCardTemplate(
        id: 'storage_occupancy',
        label: 'Storage occupancy',
      ),
      HomeStatusCardTemplate(
        id: 'release_approvals',
        label: 'Releases awaiting approval',
      ),
      HomeStatusCardTemplate(
        id: 'pending_post_mortem',
        label: 'Pending post-mortem requests',
      ),
      HomeStatusCardTemplate(
        id: 'custody_exceptions',
        label: 'Custody exceptions',
      ),
      HomeStatusCardTemplate(
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
      ),
    ],
    quickActionIds: <String>[
      'release_authorisation',
      'mortuary_case',
      'run_report',
    ],
    shortcutIds: <String>['mortuary', 'reports'],
    emptyActionIds: <String>['release_authorisation', 'mortuary_case'],
  ),
  AppRole.patient: HomeDashboardProfile(
    id: 'patient',
    role: AppRole.patient,
    roleLabel: 'Patient portal account',
    homeTitle: 'My care dashboard',
    homeSubtitle:
        'View upcoming visits, care updates, bills, prescriptions, and personal profile information.',
    emptyMessage: 'Your care updates will appear here.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(
        id: 'upcoming_appointments',
        label: 'Upcoming appointments',
      ),
      HomeStatusCardTemplate(id: 'open_bills', label: 'Open bills'),
      HomeStatusCardTemplate(
        id: 'prescriptions',
        label: 'Prescriptions/medications',
      ),
      HomeStatusCardTemplate(
        id: 'released_results',
        label: 'Results available',
      ),
      HomeStatusCardTemplate(
        id: 'messages_unread',
        label: 'Messages/notifications',
      ),
    ],
    quickActionIds: <String>['open_profile'],
    shortcutIds: <String>['profile', 'settings'],
    emptyActionIds: <String>['open_profile'],
  ),
  AppRole.other: HomeDashboardProfile(
    id: 'other',
    role: AppRole.other,
    roleLabel: 'Limited account',
    homeTitle: 'Account home',
    homeSubtitle: 'Access the areas assigned to your account.',
    emptyMessage:
        'Your account has limited access. Contact an administrator if you need more modules.',
    statusCards: <HomeStatusCardTemplate>[
      HomeStatusCardTemplate(id: 'profile_status', label: 'Profile status'),
      HomeStatusCardTemplate(id: 'assigned_links', label: 'Assigned links'),
      HomeStatusCardTemplate(id: 'messages_unread', label: 'Unread messages'),
      HomeStatusCardTemplate(id: 'facility_notices', label: 'Facility notices'),
    ],
    quickActionIds: <String>['open_profile'],
    shortcutIds: <String>['profile', 'settings'],
    emptyActionIds: <String>['open_profile'],
  ),
};

HomeDashboardProfile homeProfileForRoles(Iterable<AppRole> roles) {
  final List<AppRole> normalizedRoles = roles.toSet().toList(growable: false);
  if (normalizedRoles.isEmpty) {
    return homeDashboardProfiles[AppRole.other]!;
  }

  normalizedRoles.sort((AppRole left, AppRole right) {
    return (_homeRoleRanks[right] ?? 0).compareTo(_homeRoleRanks[left] ?? 0);
  });

  return homeDashboardProfiles[normalizedRoles.first] ??
      homeDashboardProfiles[AppRole.other]!;
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
