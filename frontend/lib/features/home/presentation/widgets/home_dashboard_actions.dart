import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_dialogs.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_mutation.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_report_admins_dialog.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_upgrade_dialog.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:intl/intl.dart' hide TextDirection;

final class HomeActionDefinition {
  const HomeActionDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    this.routeQuery = const <String, String>{},
    this.allowedRoles = const <AppRole>[],
    this.requiredPermissions = const <AppPermission>[],
    this.requiredAnyPermissions = const <AppPermission>[],
    this.requiredModules = const <String>[],
  });

  final String id;
  final String label;
  final IconData icon;
  final AppRouteData route;
  final Map<String, String> routeQuery;
  final List<AppRole> allowedRoles;
  final List<AppPermission> requiredPermissions;
  final List<AppPermission> requiredAnyPermissions;
  final List<String> requiredModules;

  bool isAllowed(AppAccessPolicy policy) {
    // Authority order: Plan (modules) → Role → Rights, then route requirement.
    // Custom roles: when permission requirements are present, they can satisfy
    // the action even if the role name is not a canonical AppRole.
    if (!policy.hasAllActiveModules(requiredModules)) {
      return false;
    }

    final bool hasPermissionRequirements =
        requiredPermissions.isNotEmpty || requiredAnyPermissions.isNotEmpty;
    if (allowedRoles.isNotEmpty && !allowedRoles.any(policy.hasRole)) {
      if (!hasPermissionRequirements) {
        return false;
      }
    }
    if (!policy.grantsAll(requiredPermissions)) {
      return false;
    }
    if (requiredAnyPermissions.isNotEmpty &&
        !policy.grantsAny(requiredAnyPermissions)) {
      return false;
    }
    return route.accessRequirement.isAllowed(policy);
  }
}

final class HomeShortcutDefinition {
  const HomeShortcutDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });

  final String id;
  final String label;
  final IconData icon;
  final AppRouteData route;

  bool isAllowed(AppAccessPolicy policy) {
    return route.accessRequirement.isAllowed(policy);
  }
}

const Map<String, HomeActionDefinition>
homeActionLibrary = <String, HomeActionDefinition>{
  'register_patient': HomeActionDefinition(
    id: 'register_patient',
    label: 'Register patient',
    icon: Icons.person_add_alt_1_outlined,
    route: AppRoutes.patients,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['patients'],
  ),
  'book_appointment': HomeActionDefinition(
    id: 'book_appointment',
    label: 'Book appointment',
    icon: Icons.event_available_outlined,
    route: AppRoutes.opd,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['scheduling'],
  ),
  'check_in_patient': HomeActionDefinition(
    id: 'check_in_patient',
    label: 'Check in patient',
    icon: Icons.fact_check_outlined,
    route: AppRoutes.opd,
    allowedRoles: <AppRole>[
      AppRole.facilityAdmin,
      AppRole.receptionist,
      AppRole.nurse,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['scheduling'],
  ),
  'route_patient': HomeActionDefinition(
    id: 'route_patient',
    label: 'Route patient',
    icon: Icons.alt_route_outlined,
    route: AppRoutes.opd,
    allowedRoles: <AppRole>[AppRole.receptionist, AppRole.nurse],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['scheduling'],
  ),
  'start_consultation': HomeActionDefinition(
    id: 'start_consultation',
    label: 'Start consultation',
    icon: Icons.medical_services_outlined,
    route: AppRoutes.clinical,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['clinical'],
  ),
  'continue_consultation': HomeActionDefinition(
    id: 'continue_consultation',
    label: 'Continue consultation',
    icon: Icons.medical_information_outlined,
    route: AppRoutes.clinical,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['clinical'],
  ),
  'write_clinical_note': HomeActionDefinition(
    id: 'write_clinical_note',
    label: 'Write clinical note',
    icon: Icons.note_add_outlined,
    route: AppRoutes.clinical,
    allowedRoles: <AppRole>[
      AppRole.doctor,
      AppRole.nurse,
      AppRole.icuManager,
      AppRole.theatreManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['clinical'],
  ),
  'record_vitals': HomeActionDefinition(
    id: 'record_vitals',
    label: 'Record vitals',
    icon: Icons.monitor_heart_outlined,
    route: AppRoutes.nursing,
    allowedRoles: <AppRole>[AppRole.nurse, AppRole.doctor, AppRole.icuManager],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['nursing'],
  ),
  'mark_med_administered': HomeActionDefinition(
    id: 'mark_med_administered',
    label: 'Mark medication administered',
    icon: Icons.medication_outlined,
    route: AppRoutes.nursing,
    allowedRoles: <AppRole>[AppRole.nurse],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['nursing'],
  ),
  'create_handover': HomeActionDefinition(
    id: 'create_handover',
    label: 'Create handover',
    icon: Icons.swap_horiz_outlined,
    route: AppRoutes.nursing,
    allowedRoles: <AppRole>[
      AppRole.nurse,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalWrite,
      AppPermissions.unitManage,
    ],
    requiredModules: <String>['nursing'],
  ),
  'order_lab': HomeActionDefinition(
    id: 'order_lab',
    label: 'Order lab test',
    icon: Icons.biotech_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['lab'],
  ),
  'order_radiology': HomeActionDefinition(
    id: 'order_radiology',
    label: 'Order imaging',
    icon: Icons.camera_outdoor_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['radiology'],
  ),
  'receive_sample': HomeActionDefinition(
    id: 'receive_sample',
    label: 'Receive sample',
    icon: Icons.science_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.labTech],
    requiredPermissions: <AppPermission>[AppPermissions.labWrite],
    requiredModules: <String>['lab'],
  ),
  'enter_lab_result': HomeActionDefinition(
    id: 'enter_lab_result',
    label: 'Enter lab result',
    icon: Icons.edit_note_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.labTech],
    requiredPermissions: <AppPermission>[AppPermissions.labWrite],
    requiredModules: <String>['lab'],
  ),
  'flag_critical_lab': HomeActionDefinition(
    id: 'flag_critical_lab',
    label: 'Flag critical result',
    icon: Icons.priority_high_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.labTech],
    requiredPermissions: <AppPermission>[AppPermissions.labWrite],
    requiredModules: <String>['lab'],
  ),
  'start_imaging_study': HomeActionDefinition(
    id: 'start_imaging_study',
    label: 'Start imaging study',
    icon: Icons.camera_outdoor_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.radiologyTech],
    requiredPermissions: <AppPermission>[AppPermissions.radiologyWrite],
    requiredModules: <String>['radiology'],
  ),
  'update_imaging_status': HomeActionDefinition(
    id: 'update_imaging_status',
    label: 'Update imaging status',
    icon: Icons.update_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.radiologyTech],
    requiredPermissions: <AppPermission>[AppPermissions.radiologyWrite],
    requiredModules: <String>['radiology'],
  ),
  'add_radiology_report': HomeActionDefinition(
    id: 'add_radiology_report',
    label: 'Add imaging report',
    icon: Icons.post_add_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.radiologyTech],
    requiredPermissions: <AppPermission>[AppPermissions.radiologyWrite],
    requiredModules: <String>['radiology'],
  ),
  'create_invoice': HomeActionDefinition(
    id: 'create_invoice',
    label: 'Create invoice',
    icon: Icons.receipt_long_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'receive_payment': HomeActionDefinition(
    id: 'receive_payment',
    label: 'Receive payment',
    icon: Icons.payments_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'process_refund': HomeActionDefinition(
    id: 'process_refund',
    label: 'Process refund',
    icon: Icons.undo_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'close_shift': HomeActionDefinition(
    id: 'close_shift',
    label: 'Close shift',
    icon: Icons.lock_clock_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'dispense_medication': HomeActionDefinition(
    id: 'dispense_medication',
    label: 'Dispense medication',
    icon: Icons.medication_liquid_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'record_pharmacy_sale': HomeActionDefinition(
    id: 'record_pharmacy_sale',
    label: 'Record pharmacy sale',
    icon: Icons.point_of_sale_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'receive_pharmacy_stock': HomeActionDefinition(
    id: 'receive_pharmacy_stock',
    label: 'Receive pharmacy stock',
    icon: Icons.inventory_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'adjust_pharmacy_stock': HomeActionDefinition(
    id: 'adjust_pharmacy_stock',
    label: 'Adjust pharmacy stock',
    icon: Icons.tune_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'add_staff_profile': HomeActionDefinition(
    id: 'add_staff_profile',
    label: 'Add staff profile',
    icon: Icons.badge_outlined,
    route: AppRoutes.hr,
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.hrWrite,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
    ],
    requiredModules: <String>['hr'],
  ),
  'review_leave': HomeActionDefinition(
    id: 'review_leave',
    label: 'Review leave',
    icon: Icons.approval_outlined,
    route: AppRoutes.hr,
    routeQuery: <String, String>{'queue': 'LEAVE_REQUESTS'},
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.biomedManager,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.hrWrite,
      AppPermissions.rosterApprove,
    ],
    requiredModules: <String>['hr'],
  ),
  'create_shift': HomeActionDefinition(
    id: 'create_shift',
    label: 'Create shift',
    icon: Icons.add_alarm_outlined,
    route: AppRoutes.hr,
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.biomedManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.rosterWrite],
    requiredModules: <String>['hr'],
  ),
  'publish_roster': HomeActionDefinition(
    id: 'publish_roster',
    label: 'Publish roster',
    icon: Icons.calendar_month_outlined,
    route: AppRoutes.hr,
    routeQuery: <String, String>{'queue': 'ROSTER_DRAFTS'},
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.rosterPublish],
    requiredModules: <String>['hr'],
  ),
  'approve_roster': HomeActionDefinition(
    id: 'approve_roster',
    label: 'Approve roster',
    icon: Icons.verified_outlined,
    route: AppRoutes.hr,
    routeQuery: <String, String>{'queue': 'ROSTER_DRAFTS'},
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.rosterApprove],
    requiredModules: <String>['hr'],
  ),
  'create_maintenance_request': HomeActionDefinition(
    id: 'create_maintenance_request',
    label: 'Create maintenance request',
    icon: Icons.handyman_outlined,
    route: AppRoutes.operations,
    allowedRoles: <AppRole>[AppRole.operations, AppRole.facilityAdmin],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['operations'],
  ),
  'assign_maintenance': HomeActionDefinition(
    id: 'assign_maintenance',
    label: 'Assign maintenance',
    icon: Icons.assignment_ind_outlined,
    route: AppRoutes.operations,
    allowedRoles: <AppRole>[AppRole.operations],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['operations'],
  ),
  'update_bed_readiness': HomeActionDefinition(
    id: 'update_bed_readiness',
    label: 'Update bed readiness',
    icon: Icons.bed_outlined,
    route: AppRoutes.roomsBeds,
    allowedRoles: <AppRole>[AppRole.operations, AppRole.housekeepingManager],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['rooms_beds'],
  ),
  'report_equipment_issue': HomeActionDefinition(
    id: 'report_equipment_issue',
    label: 'Report equipment issue',
    icon: Icons.precision_manufacturing_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[
      AppRole.biomed,
      AppRole.biomedManager,
      AppRole.facilityAdmin,
      AppRole.operations,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.biomedWrite,
      AppPermissions.facilityAdmin,
      AppPermissions.operationsWrite,
    ],
    requiredModules: <String>['biomedical'],
  ),
  'acknowledge_work_order': HomeActionDefinition(
    id: 'acknowledge_work_order',
    label: 'Acknowledge work order',
    icon: Icons.task_alt_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomed],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'update_work_order': HomeActionDefinition(
    id: 'update_work_order',
    label: 'Update work order',
    icon: Icons.build_circle_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomed, AppRole.biomedManager],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'log_calibration': HomeActionDefinition(
    id: 'log_calibration',
    label: 'Log calibration',
    icon: Icons.fact_check_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomed, AppRole.biomedManager],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'schedule_maintenance': HomeActionDefinition(
    id: 'schedule_maintenance',
    label: 'Schedule maintenance',
    icon: Icons.event_repeat_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomed, AppRole.biomedManager],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'assign_technician': HomeActionDefinition(
    id: 'assign_technician',
    label: 'Assign technician',
    icon: Icons.engineering_outlined,
    route: AppRoutes.biomedical,
    allowedRoles: <AppRole>[AppRole.biomedManager],
    requiredPermissions: <AppPermission>[AppPermissions.biomedWrite],
    requiredModules: <String>['biomedical'],
  ),
  'create_cleaning_task': HomeActionDefinition(
    id: 'create_cleaning_task',
    label: 'Create cleaning task',
    icon: Icons.cleaning_services_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.housekeepingManager, AppRole.operations],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['housekeeping'],
  ),
  'assign_cleaning_task': HomeActionDefinition(
    id: 'assign_cleaning_task',
    label: 'Assign cleaning task',
    icon: Icons.assignment_turned_in_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.housekeepingManager],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['housekeeping'],
  ),
  'start_cleaning_task': HomeActionDefinition(
    id: 'start_cleaning_task',
    label: 'Start cleaning task',
    icon: Icons.play_arrow_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.houseKeeper],
    requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
    requiredModules: <String>['housekeeping'],
  ),
  'complete_cleaning_task': HomeActionDefinition(
    id: 'complete_cleaning_task',
    label: 'Complete cleaning task',
    icon: Icons.check_circle_outline,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.houseKeeper],
    requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
    requiredModules: <String>['housekeeping'],
  ),
  'mark_cleaning_blocked': HomeActionDefinition(
    id: 'mark_cleaning_blocked',
    label: 'Mark cleaning blocked',
    icon: Icons.block_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.houseKeeper, AppRole.housekeepingManager],
    requiredPermissions: <AppPermission>[AppPermissions.operationsRead],
    requiredModules: <String>['housekeeping'],
  ),
  'dispatch_ambulance': HomeActionDefinition(
    id: 'dispatch_ambulance',
    label: 'Dispatch ambulance',
    icon: Icons.emergency_share_outlined,
    route: AppRoutes.emergency,
    allowedRoles: <AppRole>[AppRole.ambulanceOperator],
    requiredPermissions: <AppPermission>[AppPermissions.emergencyWrite],
    requiredModules: <String>['emergency'],
  ),
  'update_trip_status': HomeActionDefinition(
    id: 'update_trip_status',
    label: 'Update trip status',
    icon: Icons.route_outlined,
    route: AppRoutes.emergency,
    allowedRoles: <AppRole>[AppRole.ambulanceOperator],
    requiredPermissions: <AppPermission>[AppPermissions.emergencyWrite],
    requiredModules: <String>['emergency'],
  ),
  'record_emergency_handover': HomeActionDefinition(
    id: 'record_emergency_handover',
    label: 'Record handover',
    icon: Icons.swap_calls_outlined,
    route: AppRoutes.emergency,
    allowedRoles: <AppRole>[AppRole.ambulanceOperator],
    requiredPermissions: <AppPermission>[AppPermissions.emergencyWrite],
    requiredModules: <String>['emergency'],
  ),
  'open_mortuary_case': HomeActionDefinition(
    id: 'open_mortuary_case',
    label: 'Open mortuary case',
    icon: Icons.inventory_2_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
    requiredModules: <String>['mortuary'],
  ),
  'assign_storage_slot': HomeActionDefinition(
    id: 'assign_storage_slot',
    label: 'Assign storage slot',
    icon: Icons.grid_view_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryManageStorage],
    requiredModules: <String>['mortuary'],
  ),
  'record_custody_event': HomeActionDefinition(
    id: 'record_custody_event',
    label: 'Record custody event',
    icon: Icons.history_edu_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
    requiredModules: <String>['mortuary'],
  ),
  'schedule_viewing': HomeActionDefinition(
    id: 'schedule_viewing',
    label: 'Schedule viewing',
    icon: Icons.event_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
    requiredModules: <String>['mortuary'],
  ),
  'add_mortuary_billable_event': HomeActionDefinition(
    id: 'add_mortuary_billable_event',
    label: 'Add billable event',
    icon: Icons.add_card_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryBillingEvent],
    requiredModules: <String>['mortuary'],
  ),
  'review_release_authorization': HomeActionDefinition(
    id: 'review_release_authorization',
    label: 'Review release authorization',
    icon: Icons.verified_user_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryManager],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.mortuaryRelease,
      AppPermissions.mortuaryApprove,
    ],
    requiredModules: <String>['mortuary'],
  ),
  'approve_release': HomeActionDefinition(
    id: 'approve_release',
    label: 'Approve release',
    icon: Icons.verified_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryApprove],
    requiredModules: <String>['mortuary'],
  ),
  'export_mortuary_evidence': HomeActionDefinition(
    id: 'export_mortuary_evidence',
    label: 'Export evidence',
    icon: Icons.file_download_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryManager],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.mortuaryExport,
      AppPermissions.evidenceExport,
    ],
    requiredModules: <String>['mortuary'],
  ),
  'run_report': HomeActionDefinition(
    id: 'run_report',
    label: 'Run report',
    icon: Icons.analytics_outlined,
    route: AppRoutes.reports,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.billing,
      AppRole.operations,
      AppRole.hr,
      AppRole.labTech,
      AppRole.radiologyTech,
      AppRole.pharmacist,
      AppRole.unitManager,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.biomedManager,
      AppRole.mortuaryManager,
    ],
    requiredPermissions: <AppPermission>[AppPermissions.reportsRead],
    requiredModules: <String>['reports'],
  ),
  'manage_subscription': HomeActionDefinition(
    id: 'manage_subscription',
    label: 'Manage subscription',
    icon: Icons.workspace_premium_outlined,
    route: AppRoutes.subscriptions,
    allowedRoles: <AppRole>[AppRole.superAdmin],
    requiredPermissions: <AppPermission>[AppPermissions.systemAdmin],
  ),
  'select_context': HomeActionDefinition(
    id: 'select_context',
    label: 'Select tenant/facility',
    icon: Icons.account_tree_outlined,
    route: AppRoutes.tenantFacilitySetup,
    allowedRoles: <AppRole>[AppRole.superAdmin, AppRole.tenantAdmin],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
    ],
  ),
  'create_tenant': HomeActionDefinition(
    id: 'create_tenant',
    label: 'Create tenant',
    icon: Icons.add_business_outlined,
    route: AppRoutes.tenantFacilitySetup,
    allowedRoles: <AppRole>[AppRole.superAdmin],
    requiredPermissions: <AppPermission>[AppPermissions.systemAdmin],
  ),
  'create_facility': HomeActionDefinition(
    id: 'create_facility',
    label: 'Create facility',
    icon: Icons.apartment_outlined,
    route: AppRoutes.tenantFacilitySetup,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
    ],
  ),
  'create_role': HomeActionDefinition(
    id: 'create_role',
    label: 'Create role',
    icon: Icons.add_moderator_outlined,
    route: AppRoutes.accessAdmin,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.hrWrite,
    ],
  ),
  'create_user': HomeActionDefinition(
    id: 'create_user',
    label: 'Create user',
    icon: Icons.person_add_alt_1_outlined,
    route: AppRoutes.accessAdmin,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.hrWrite,
    ],
  ),
  'manage_tenants': HomeActionDefinition(
    id: 'manage_tenants',
    label: 'Manage tenants',
    icon: Icons.corporate_fare_outlined,
    route: AppRoutes.tenantFacilitySetup,
    allowedRoles: <AppRole>[AppRole.superAdmin],
    requiredPermissions: <AppPermission>[AppPermissions.systemAdmin],
  ),
  'manage_facilities': HomeActionDefinition(
    id: 'manage_facilities',
    label: 'Manage facilities',
    icon: Icons.domain_outlined,
    route: AppRoutes.tenantFacilitySetup,
    allowedRoles: <AppRole>[AppRole.superAdmin, AppRole.tenantAdmin],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
    ],
  ),
  'manage_roles_access': HomeActionDefinition(
    id: 'manage_roles_access',
    label: 'Manage roles and permissions',
    icon: Icons.admin_panel_settings_outlined,
    route: AppRoutes.accessAdmin,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.hrWrite,
    ],
  ),
  'manage_users': HomeActionDefinition(
    id: 'manage_users',
    label: 'Manage users',
    icon: Icons.people_outline,
    route: AppRoutes.accessAdmin,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.systemAdmin,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.hrWrite,
    ],
  ),
  'manage_users_roles': HomeActionDefinition(
    id: 'manage_users_roles',
    label: 'Manage users and roles',
    icon: Icons.manage_accounts_outlined,
    route: AppRoutes.accessAdmin,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.operations,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.systemAdmin,
    ],
  ),
  'manage_staff_access': HomeActionDefinition(
    id: 'manage_staff_access',
    label: 'Manage users and roles',
    icon: Icons.manage_accounts_outlined,
    route: AppRoutes.hr,
    allowedRoles: <AppRole>[AppRole.hr],
    requiredAnyPermissions: <AppPermission>[AppPermissions.hrWrite],
    requiredModules: <String>['hr-rosters'],
  ),
  'review_audit': HomeActionDefinition(
    id: 'review_audit',
    label: 'Review audit',
    icon: Icons.policy_outlined,
    route: AppRoutes.reports,
    allowedRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.operations,
      AppRole.mortuaryManager,
      AppRole.biomedManager,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.complianceReview,
      AppPermissions.evidenceExport,
    ],
  ),
  'update_own_profile': HomeActionDefinition(
    id: 'update_own_profile',
    label: 'Update my profile',
    icon: Icons.account_circle_outlined,
    route: AppRoutes.profile,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.profileUpdate,
      AppPermissions.profileRead,
    ],
  ),
  'view_my_care': HomeActionDefinition(
    id: 'view_my_care',
    label: 'View my care',
    icon: Icons.favorite_border_outlined,
    route: AppRoutes.profile,
    allowedRoles: <AppRole>[AppRole.patient],
    requiredPermissions: <AppPermission>[AppPermissions.profileRead],
  ),
  'contact_facility': HomeActionDefinition(
    id: 'contact_facility',
    label: 'Contact facility',
    icon: Icons.forum_outlined,
    route: AppRoutes.communications,
    allowedRoles: <AppRole>[AppRole.patient, AppRole.other],
    requiredPermissions: <AppPermission>[AppPermissions.profileRead],
  ),
  'open_profile': HomeActionDefinition(
    id: 'open_profile',
    label: 'Open profile',
    icon: Icons.account_circle_outlined,
    route: AppRoutes.profile,
    requiredPermissions: <AppPermission>[AppPermissions.profileRead],
  ),
  'new_patient': HomeActionDefinition(
    id: 'new_patient',
    label: 'Register patient',
    icon: Icons.person_add_alt_1_outlined,
    route: AppRoutes.patients,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['patients'],
  ),
  'appointment': HomeActionDefinition(
    id: 'appointment',
    label: 'Book appointment',
    icon: Icons.event_available_outlined,
    route: AppRoutes.opd,
    allowedRoles: <AppRole>[AppRole.facilityAdmin, AppRole.receptionist],
    requiredPermissions: <AppPermission>[AppPermissions.patientWrite],
    requiredModules: <String>['scheduling'],
  ),
  'lab_order': HomeActionDefinition(
    id: 'lab_order',
    label: 'Order lab test',
    icon: Icons.biotech_outlined,
    route: AppRoutes.lab,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['lab'],
  ),
  'radiology_order': HomeActionDefinition(
    id: 'radiology_order',
    label: 'Order imaging',
    icon: Icons.camera_outdoor_outlined,
    route: AppRoutes.radiology,
    allowedRoles: <AppRole>[AppRole.doctor],
    requiredPermissions: <AppPermission>[AppPermissions.clinicalWrite],
    requiredModules: <String>['radiology'],
  ),
  'invoice': HomeActionDefinition(
    id: 'invoice',
    label: 'Create invoice',
    icon: Icons.receipt_long_outlined,
    route: AppRoutes.billing,
    allowedRoles: <AppRole>[AppRole.billing],
    requiredPermissions: <AppPermission>[AppPermissions.billingWrite],
    requiredModules: <String>['billing'],
  ),
  'sale': HomeActionDefinition(
    id: 'sale',
    label: 'Pharmacy sale',
    icon: Icons.medication_liquid_outlined,
    route: AppRoutes.pharmacy,
    allowedRoles: <AppRole>[AppRole.pharmacist],
    requiredPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
    requiredModules: <String>['pharmacy'],
  ),
  'staff_profile': HomeActionDefinition(
    id: 'staff_profile',
    label: 'Add staff profile',
    icon: Icons.badge_outlined,
    route: AppRoutes.hr,
    allowedRoles: <AppRole>[
      AppRole.hr,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
    ],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.hrWrite,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
    ],
    requiredModules: <String>['hr'],
  ),
  'report_maintenance_issue': HomeActionDefinition(
    id: 'report_maintenance_issue',
    label: 'Create maintenance request',
    icon: Icons.handyman_outlined,
    route: AppRoutes.operations,
    allowedRoles: <AppRole>[AppRole.operations, AppRole.facilityAdmin],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['operations'],
  ),
  'cleaning_task': HomeActionDefinition(
    id: 'cleaning_task',
    label: 'Create cleaning task',
    icon: Icons.cleaning_services_outlined,
    route: AppRoutes.housekeeping,
    allowedRoles: <AppRole>[AppRole.housekeepingManager, AppRole.operations],
    requiredPermissions: <AppPermission>[AppPermissions.operationsWrite],
    requiredModules: <String>['housekeeping'],
  ),
  'mortuary_case': HomeActionDefinition(
    id: 'mortuary_case',
    label: 'Open mortuary case',
    icon: Icons.inventory_2_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryStaff, AppRole.mortuaryManager],
    requiredPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
    requiredModules: <String>['mortuary'],
  ),
  'release_authorisation': HomeActionDefinition(
    id: 'release_authorisation',
    label: 'Review release authorization',
    icon: Icons.verified_user_outlined,
    route: AppRoutes.mortuary,
    allowedRoles: <AppRole>[AppRole.mortuaryManager],
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.mortuaryRelease,
      AppPermissions.mortuaryApprove,
    ],
    requiredModules: <String>['mortuary'],
  ),
};

const Map<String, HomeShortcutDefinition> homeShortcutLibrary =
    <String, HomeShortcutDefinition>{
      'patients': HomeShortcutDefinition(
        id: 'patients',
        label: 'Patients',
        icon: Icons.people_alt_outlined,
        route: AppRoutes.patients,
      ),
      'opd': HomeShortcutDefinition(
        id: 'opd',
        label: 'OPD',
        icon: Icons.event_note_outlined,
        route: AppRoutes.opd,
      ),
      'emergency': HomeShortcutDefinition(
        id: 'emergency',
        label: 'Emergency',
        icon: Icons.emergency_outlined,
        route: AppRoutes.emergency,
      ),
      'ipd': HomeShortcutDefinition(
        id: 'ipd',
        label: 'IPD',
        icon: Icons.local_hospital_outlined,
        route: AppRoutes.ipd,
      ),
      'rooms_beds': HomeShortcutDefinition(
        id: 'rooms_beds',
        label: 'Rooms and beds',
        icon: Icons.bed_outlined,
        route: AppRoutes.roomsBeds,
      ),
      'icu': HomeShortcutDefinition(
        id: 'icu',
        label: 'ICU',
        icon: Icons.monitor_heart_outlined,
        route: AppRoutes.icu,
      ),
      'nursing': HomeShortcutDefinition(
        id: 'nursing',
        label: 'Nursing',
        icon: Icons.health_and_safety_outlined,
        route: AppRoutes.nursing,
      ),
      'clinical': HomeShortcutDefinition(
        id: 'clinical',
        label: 'Clinical',
        icon: Icons.medical_services_outlined,
        route: AppRoutes.clinical,
      ),
      'lab': HomeShortcutDefinition(
        id: 'lab',
        label: 'Laboratory',
        icon: Icons.biotech_outlined,
        route: AppRoutes.lab,
      ),
      'radiology': HomeShortcutDefinition(
        id: 'radiology',
        label: 'Radiology',
        icon: Icons.camera_outdoor_outlined,
        route: AppRoutes.radiology,
      ),
      'pharmacy': HomeShortcutDefinition(
        id: 'pharmacy',
        label: 'Pharmacy',
        icon: Icons.local_pharmacy_outlined,
        route: AppRoutes.pharmacy,
      ),
      'billing': HomeShortcutDefinition(
        id: 'billing',
        label: 'Billing',
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.billing,
      ),
      'claims': HomeShortcutDefinition(
        id: 'claims',
        label: 'Claims',
        icon: Icons.assignment_turned_in_outlined,
        route: AppRoutes.claims,
      ),
      'hr': HomeShortcutDefinition(
        id: 'hr',
        label: 'HR',
        icon: Icons.badge_outlined,
        route: AppRoutes.hr,
      ),
      'operations': HomeShortcutDefinition(
        id: 'operations',
        label: 'Operations',
        icon: Icons.handyman_outlined,
        route: AppRoutes.operations,
      ),
      'housekeeping': HomeShortcutDefinition(
        id: 'housekeeping',
        label: 'Housekeeping',
        icon: Icons.cleaning_services_outlined,
        route: AppRoutes.housekeeping,
      ),
      'biomedical': HomeShortcutDefinition(
        id: 'biomedical',
        label: 'Biomedical',
        icon: Icons.precision_manufacturing_outlined,
        route: AppRoutes.biomedical,
      ),
      'communications': HomeShortcutDefinition(
        id: 'communications',
        label: 'Communications',
        icon: Icons.forum_outlined,
        route: AppRoutes.communications,
      ),
      'integrations': HomeShortcutDefinition(
        id: 'integrations',
        label: 'Integrations',
        icon: Icons.hub_outlined,
        route: AppRoutes.integrations,
      ),
      'discharge': HomeShortcutDefinition(
        id: 'discharge',
        label: 'Discharge',
        icon: Icons.output_outlined,
        route: AppRoutes.discharge,
      ),
      'mortuary': HomeShortcutDefinition(
        id: 'mortuary',
        label: 'Mortuary',
        icon: Icons.inventory_2_outlined,
        route: AppRoutes.mortuary,
      ),
      'theater': HomeShortcutDefinition(
        id: 'theater',
        label: 'Theatre',
        icon: Icons.fact_check_outlined,
        route: AppRoutes.theater,
      ),
      'reports': HomeShortcutDefinition(
        id: 'reports',
        label: 'Reports',
        icon: Icons.analytics_outlined,
        route: AppRoutes.reports,
      ),
      'subscriptions': HomeShortcutDefinition(
        id: 'subscriptions',
        label: 'Subscriptions',
        icon: Icons.workspace_premium_outlined,
        route: AppRoutes.subscriptions,
      ),
      'tenant_facility_setup': HomeShortcutDefinition(
        id: 'tenant_facility_setup',
        label: 'Tenant and facility setup',
        icon: Icons.account_tree_outlined,
        route: AppRoutes.tenantFacilitySetup,
      ),
      'settings': HomeShortcutDefinition(
        id: 'settings',
        label: 'Settings',
        icon: Icons.settings_outlined,
        route: AppRoutes.settings,
      ),
      'profile': HomeShortcutDefinition(
        id: 'profile',
        label: 'Profile',
        icon: Icons.account_circle_outlined,
        route: AppRoutes.profile,
      ),
    };

List<HomeActionDefinition> homeVisibleActions(
  List<String> ids,
  AppAccessPolicy policy, {
  int? maxCount,
}) {
  final List<HomeActionDefinition> actions = ids
      .map((String id) => homeActionLibrary[id])
      .whereType<HomeActionDefinition>()
      .where((HomeActionDefinition action) => action.isAllowed(policy))
      .toList(growable: false);
  if (maxCount == null || maxCount <= 0) {
    return actions;
  }
  return actions.take(maxCount).toList(growable: false);
}

List<HomeShortcutDefinition> homeShortcutsExcludingQuickActions(
  List<HomeShortcutDefinition> shortcuts,
  List<HomeActionDefinition> actions,
  HomeDashboardProfile profile,
) {
  if (!profile.showShortcutsSection(quickActionCount: actions.length)) {
    return const <HomeShortcutDefinition>[];
  }
  final Set<String> actionRoutes = actions
      .map((HomeActionDefinition action) => action.route.path)
      .toSet();
  return shortcuts
      .where(
        (HomeShortcutDefinition shortcut) =>
            !actionRoutes.contains(shortcut.route.path),
      )
      .toList(growable: false);
}

List<HomeShortcutDefinition> homeVisibleShortcuts(
  List<String> ids,
  AppAccessPolicy policy,
) {
  return ids
      .map((String id) => homeShortcutLibrary[id])
      .whereType<HomeShortcutDefinition>()
      .where((HomeShortcutDefinition shortcut) => shortcut.isAllowed(policy))
      .toList(growable: false);
}

List<HomeActionDefinition> homeVisibleEmptyActions(
  List<String> ids,
  AppAccessPolicy policy,
) {
  return ids
      .map((String id) => homeActionLibrary[id])
      .whereType<HomeActionDefinition>()
      .where((HomeActionDefinition action) => action.isAllowed(policy))
      .toList(growable: false);
}

HomeRouteTarget? homeFirstQueueTarget(List<HomeQueueItem> items) {
  for (final HomeQueueItem item in items) {
    if (item.target != null) {
      return item.target;
    }
  }
  return null;
}

AppRouteData? homeRouteForTarget(HomeRouteTarget? target) {
  final String moduleSlug = (target?.moduleSlug ?? '').trim().toLowerCase();
  if (moduleSlug.isEmpty) {
    return null;
  }

  return switch (moduleSlug) {
    'patients' || 'patient' => AppRoutes.patients,
    'scheduling' || 'opd' || 'appointments' => AppRoutes.opd,
    'emergency' => AppRoutes.emergency,
    'clinical' => AppRoutes.clinical,
    'nursing' => AppRoutes.nursing,
    'ipd' => AppRoutes.ipd,
    'icu' => AppRoutes.icu,
    'theatre' || 'theater' => AppRoutes.theater,
    'lab' || 'laboratory' => AppRoutes.lab,
    'radiology' || 'imaging' => AppRoutes.radiology,
    'pharmacy' => AppRoutes.pharmacy,
    'billing' => AppRoutes.billing,
    'claims' => AppRoutes.claims,
    'hr' || 'roster' => AppRoutes.hr,
    'operations' => AppRoutes.operations,
    'rooms_beds' || 'rooms-beds' => AppRoutes.roomsBeds,
    'housekeeping' => AppRoutes.housekeeping,
    'biomedical' || 'biomed' => AppRoutes.biomedical,
    'mortuary' => AppRoutes.mortuary,
    'communications' => AppRoutes.communications,
    'reports' || 'audit' || 'dashboard' => AppRoutes.reports,
    'subscriptions' => AppRoutes.subscriptions,
    'settings' => AppRoutes.settings,
    'profile' => AppRoutes.profile,
    _ => null,
  };
}

void homeGoToRoute(
  BuildContext context,
  AppRouteData route, {
  Map<String, String> queryParameters = const <String, String>{},
}) {
  context.go(route.location(queryParameters: queryParameters));
}

bool homeTargetUsesTenantSubscriptionFallback(
  AppAccessPolicy policy, {
  HomeRouteTarget? target,
  AppRouteData? route,
}) {
  if (policy.isElevated) {
    return false;
  }

  final String moduleSlug = (target?.moduleSlug ?? '').trim().toLowerCase();
  if (moduleSlug == 'subscriptions') {
    return true;
  }

  return route?.path == AppRoutes.subscriptions.path;
}

Future<void> homeOpenTenantSubscriptionSurface(
  BuildContext context,
  WidgetRef ref,
  AppAccessPolicy policy,
) async {
  final AuthSession? session = ref.read(sessionStateProvider).session;

  if (policy.canManageSubscriptionBilling()) {
    await showSubscriptionUpgradeDialog(
      context,
      initialSummary: session?.subscriptionSummary,
      initialAdminContact: session?.platformAdminContact,
    );
    return;
  }

  final TenantSubscriptionSummary? summary = session?.subscriptionSummary;
  if (summary == null) {
    homeGoToRoute(context, AppRoutes.tenantFacilitySetup);
    return;
  }

  await showSubscriptionReportAdminsDialog(
    context,
    headerState: summary.headerState,
    tenantAdmins: session?.tenantAdminContacts ?? const <OrgAdminContact>[],
    facilityAdmins: session?.facilityAdminContacts ?? const <OrgAdminContact>[],
    platformAdminContact: session?.platformAdminContact,
  );
}

void homeNavigateRouteTarget(
  BuildContext context,
  WidgetRef ref,
  AppAccessPolicy policy, {
  HomeRouteTarget? target,
}) {
  final AppRouteData? route = homeRouteForTarget(target);
  if (homeTargetUsesTenantSubscriptionFallback(policy, target: target, route: route)) {
    unawaited(homeOpenTenantSubscriptionSurface(context, ref, policy));
    return;
  }

  if (route == null) {
    return;
  }

  homeGoToRoute(
    context,
    route,
    queryParameters: homeHrQueryForTarget(target),
  );
}

VoidCallback? homeWorklistTap(
  BuildContext context,
  WidgetRef ref,
  AppAccessPolicy policy,
  HomeRouteTarget? target,
) {
  if (target == null) {
    return null;
  }

  final AppRouteData? route = homeRouteForTarget(target);
  if (route == null &&
      !homeTargetUsesTenantSubscriptionFallback(policy, target: target)) {
    return null;
  }

  return () => homeNavigateRouteTarget(
    context,
    ref,
    policy,
    target: target,
  );
}

void homeNavigateShortcut(
  BuildContext context,
  WidgetRef ref,
  AppAccessPolicy policy,
  HomeShortcutDefinition shortcut,
) {
  if (shortcut.id == 'subscriptions' &&
      homeTargetUsesTenantSubscriptionFallback(policy)) {
    unawaited(homeOpenTenantSubscriptionSurface(context, ref, policy));
    return;
  }

  homeGoToRoute(context, shortcut.route);
}

void homeInvokeAction(
  BuildContext context,
  WidgetRef ref,
  HomeActionDefinition action, {
  HomeDashboardRequest request = HomeDashboardRequest.empty,
}) {
  if (action.id == 'add_staff_profile' || action.id == 'staff_profile') {
    unawaited(
      showHrStaffOnboardingDialog(context, ref).then((bool? saved) {
        homeOnDashboardDialogClosed(ref, request, saved);
      }),
    );
    return;
  }
  if (action.id == 'select_context') {
    homeGoToRoute(context, AppRoutes.tenantFacilitySetup);
    return;
  }
  if (action.id == 'create_tenant') {
    unawaited(
      showTenantFacilityTenantFormDialog(context, forceCreate: true).then((
        bool? saved,
      ) {
        homeOnDashboardDialogClosed(
          ref,
          request,
          saved,
          patch: saved == true
              ? HomeDashboardOptimisticPatch.tenantCreated()
              : null,
        );
      }),
    );
    return;
  }
  if (action.id == 'create_facility') {
    unawaited(
      showTenantFacilityFacilityFormDialog(
        context,
        requireTenantPicker: true,
        managementMode: true,
      ).then((bool? saved) {
        homeOnDashboardDialogClosed(
          ref,
          request,
          saved,
          patch: saved == true
              ? HomeDashboardOptimisticPatch.facilityCreated()
              : null,
        );
      }),
    );
    return;
  }
  if (action.id == 'create_role') {
    unawaited(
      showAccessAdminCreateRoleDialog(context, ref).then((bool? saved) {
        homeOnDashboardDialogClosed(ref, request, saved);
      }),
    );
    return;
  }
  if (action.id == 'create_user') {
    unawaited(
      showAccessAdminCreateUserDialog(context, ref).then((bool? saved) {
        homeOnDashboardDialogClosed(ref, request, saved);
      }),
    );
    return;
  }
  if (action.id == 'manage_tenants') {
    unawaited(
      showManageTenantsDialog(context, ref).then((bool? saved) {
        homeOnDashboardDialogClosed(ref, request, saved);
      }),
    );
    return;
  }
  if (action.id == 'manage_facilities') {
    unawaited(
      showManageFacilitiesDialog(context, ref).then((bool? saved) {
        homeOnDashboardDialogClosed(ref, request, saved);
      }),
    );
    return;
  }
  if (action.id == 'manage_roles_access') {
    unawaited(
      showManageRolesPermissionsDialog(context, ref).then((bool? saved) {
        homeOnDashboardDialogClosed(ref, request, saved);
      }),
    );
    return;
  }
  if (action.id == 'manage_users' || action.id == 'manage_users_roles') {
    unawaited(
      showManageUsersDialog(context, ref).then((bool? saved) {
        homeOnDashboardDialogClosed(ref, request, saved);
      }),
    );
    return;
  }
  homeGoToRoute(context, action.route, queryParameters: action.routeQuery);
}

String homeQueueItemSubtitle(HomeQueueItem item) {
  if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) {
    final String timeLabel = homeTimeLabel(item.occurredAt);
    if (timeLabel.isEmpty) {
      return item.subtitle!.trim();
    }
    return '${item.subtitle!.trim()} · $timeLabel';
  }
  return homeTimeLabel(item.occurredAt);
}

String homeTrendTitle(AppRole role, String fallback) {
  final String title = switch (role) {
    AppRole.superAdmin => 'New tenant signups',
    AppRole.tenantAdmin => 'Facilities performance trend',
    AppRole.facilityAdmin => 'OPD flow by hour',
    AppRole.doctor => 'Consultation trend',
    AppRole.nurse => 'Medication rounds trend',
    AppRole.labTech => 'Sample throughput trend',
    AppRole.radiologyTech => 'Imaging throughput trend',
    AppRole.pharmacist => 'Dispensing throughput trend',
    AppRole.receptionist => 'Front desk arrivals trend',
    AppRole.billing => 'Collections trend',
    AppRole.operations => 'Facility readiness trend',
    AppRole.hr => 'Staffing coverage trend',
    AppRole.biomed || AppRole.biomedManager => 'Equipment service trend',
    AppRole.houseKeeper ||
    AppRole.housekeepingManager => 'Cleaning throughput trend',
    AppRole.ambulanceOperator => 'Dispatch response trend',
    AppRole.patient => 'Care activity trend',
    AppRole.mortuaryStaff ||
    AppRole.mortuaryManager => 'Mortuary activity trend',
    _ => fallback,
  };
  return title.trim().isEmpty ? 'Dashboard trend' : title;
}

String homeDistributionTitle(AppRole role, String fallback) {
  final String title = switch (role) {
    AppRole.superAdmin => 'Subscription mix',
    AppRole.tenantAdmin => 'Module adoption donut',
    AppRole.facilityAdmin => 'Bed readiness donut',
    AppRole.doctor => 'Patient acuity mix',
    AppRole.nurse => 'Ward distribution',
    AppRole.labTech => 'Test mix donut',
    AppRole.radiologyTech => 'Study mix donut',
    AppRole.pharmacist => 'Stock pressure donut',
    AppRole.receptionist => 'Queue mix donut',
    AppRole.billing => 'Revenue mix donut',
    AppRole.operations => 'Bed readiness mix donut',
    AppRole.hr => 'Workforce mix donut',
    AppRole.biomed || AppRole.biomedManager => 'Asset service status donut',
    AppRole.houseKeeper || AppRole.housekeepingManager => 'Task mix donut',
    AppRole.ambulanceOperator => 'Fleet readiness donut',
    AppRole.patient => 'Care summary donut',
    AppRole.mortuaryStaff || AppRole.mortuaryManager => 'Case status donut',
    _ => fallback,
  };
  return title.trim().isEmpty ? 'Status distribution' : title;
}

String homeQueueTitle(AppRole role) {
  return switch (role) {
    AppRole.superAdmin => 'Follow-up',
    AppRole.tenantAdmin => 'Facility follow-up',
    AppRole.facilityAdmin => 'Operations',
    AppRole.doctor => 'Worklist',
    AppRole.nurse => 'Tasks',
    AppRole.labTech => 'Lab queue',
    AppRole.radiologyTech => 'Imaging',
    AppRole.pharmacist => 'Orders',
    AppRole.receptionist => 'Desk',
    AppRole.billing => 'Billing',
    AppRole.operations => 'Ops queue',
    AppRole.hr => 'Workforce',
    AppRole.biomed || AppRole.biomedManager => 'Service',
    AppRole.houseKeeper || AppRole.housekeepingManager => 'Cleaning',
    AppRole.ambulanceOperator => 'Dispatch',
    AppRole.patient => 'Updates',
    _ => 'Queue',
  };
}

String homeAlertsTitle(AppRole role) {
  return switch (role) {
    AppRole.doctor => 'Critical alerts',
    AppRole.tenantAdmin => 'Facility alerts',
    _ => 'Alerts',
  };
}

String homeResultsTitle(AppRole role) {
  return switch (role) {
    AppRole.doctor => 'Results ready',
    _ => 'Results',
  };
}

String homeFollowUpTitle(AppRole role) {
  return switch (role) {
    AppRole.doctor => 'Follow-ups',
    _ => 'Follow-ups',
  };
}

Color homeToneColor(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  return switch (tone) {
    AppWorkspaceStatusTone.success => colorScheme.tertiary,
    AppWorkspaceStatusTone.warning => colorScheme.secondary,
    AppWorkspaceStatusTone.error => colorScheme.error,
    AppWorkspaceStatusTone.info => colorScheme.primary,
    AppWorkspaceStatusTone.neutral => colorScheme.onSurfaceVariant,
  };
}

String homeFormatMetricValue(HomeStatusCard card) {
  if (card.format == 'ratio') {
    final num total = card.secondaryValue ?? card.value;
    return '${NumberFormat.compact().format(card.value)} / ${NumberFormat.compact().format(total)}';
  }
  if (card.format == 'currency') {
    return NumberFormat.compactCurrency(symbol: 'UGX ').format(card.value);
  }
  if (card.format == 'percent') {
    final num value = card.value <= 1 && card.value >= 0
        ? card.value * 100
        : card.value;
    return '${NumberFormat.compact().format(value)}%';
  }
  return NumberFormat.compact().format(card.value);
}

String homeStatusLabel(String? value) {
  if (!homeHasText(value)) {
    return 'Open';
  }
  return homeFormatToken(value!);
}

String homeTimeLabel(DateTime? value) {
  if (value == null) {
    return '';
  }
  return DateFormat('MMM d, HH:mm').format(value.toLocal());
}

String homeFormatToken(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

bool homeHasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

AppWorkspaceStatusTone homeMetricTone(HomeStatusCard card) {
  final String id = card.id.toLowerCase();
  if (id.contains('critical') ||
      id.contains('overdue') ||
      id.contains('warning') ||
      id.contains('risk')) {
    return card.numericValue > 0
        ? AppWorkspaceStatusTone.error
        : AppWorkspaceStatusTone.success;
  }
  if (id.contains('results') ||
      id.contains('lab') ||
      id.contains('radiology')) {
    return card.numericValue > 0
        ? AppWorkspaceStatusTone.warning
        : AppWorkspaceStatusTone.neutral;
  }
  if (id.contains('follow_up')) {
    return card.numericValue > 0
        ? AppWorkspaceStatusTone.warning
        : AppWorkspaceStatusTone.success;
  }
  if (id.contains('pending') ||
      id.contains('queue') ||
      id.contains('open') ||
      id.contains('pressure')) {
    return card.numericValue > 0
        ? AppWorkspaceStatusTone.warning
        : AppWorkspaceStatusTone.neutral;
  }
  if (id.contains('completed') ||
      id.contains('available') ||
      id.contains('ready') ||
      id.contains('active')) {
    return AppWorkspaceStatusTone.success;
  }
  if (id.contains('assigned') || id.contains('in_progress')) {
    return AppWorkspaceStatusTone.info;
  }
  return AppWorkspaceStatusTone.info;
}

AppWorkspaceStatusTone homeSeverityTone(String? value) {
  final String normalized = (value ?? '').trim().toUpperCase();
  return switch (normalized) {
    'CRITICAL' ||
    'ERROR' ||
    'HIGH' ||
    'OVERDUE' ||
    'CANCELLED' => AppWorkspaceStatusTone.error,
    'MEDIUM' ||
    'WARNING' ||
    'PENDING' ||
    'OPEN' ||
    'IN_PROGRESS' => AppWorkspaceStatusTone.warning,
    'LOW' ||
    'INFO' ||
    'SCHEDULED' ||
    'CONFIRMED' => AppWorkspaceStatusTone.info,
    'SUCCESS' ||
    'COMPLETED' ||
    'FINAL' ||
    'PAID' => AppWorkspaceStatusTone.success,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

IconData homeMetricIcon(String id) {
  final String normalized = id.toLowerCase();
  if (normalized.contains('patient')) return Icons.people_alt_outlined;
  if (normalized.contains('appointment')) return Icons.event_available_outlined;
  if (normalized.contains('admission') || normalized.contains('bed')) {
    return Icons.local_hospital_outlined;
  }
  if (normalized.contains('invoice') ||
      normalized.contains('payment') ||
      normalized.contains('revenue') ||
      normalized.contains('collection')) {
    return Icons.receipt_long_outlined;
  }
  if (normalized.contains('lab')) return Icons.biotech_outlined;
  if (normalized.contains('radiology')) return Icons.camera_outdoor_outlined;
  if (normalized.contains('stock') || normalized.contains('medication')) {
    return Icons.local_pharmacy_outlined;
  }
  if (normalized.contains('staff') ||
      normalized.contains('shift') ||
      normalized.contains('roster')) {
    return Icons.badge_outlined;
  }
  if (normalized.contains('maintenance') || normalized.contains('work_order')) {
    return Icons.handyman_outlined;
  }
  if (normalized.contains('clean') || normalized.contains('housekeeping')) {
    return Icons.cleaning_services_outlined;
  }
  if (normalized.contains('alert') ||
      normalized.contains('critical') ||
      normalized.contains('risk')) {
    return Icons.warning_amber_outlined;
  }
  return Icons.insights_outlined;
}

IconData homeModuleIcon(String moduleSlug) {
  return switch (moduleSlug.toLowerCase()) {
    'patients' || 'patient' => Icons.people_alt_outlined,
    'scheduling' || 'opd' => Icons.event_note_outlined,
    'clinical' => Icons.medical_services_outlined,
    'nursing' => Icons.health_and_safety_outlined,
    'ipd' => Icons.local_hospital_outlined,
    'rooms_beds' || 'rooms-beds' => Icons.bed_outlined,
    'icu' => Icons.monitor_heart_outlined,
    'lab' => Icons.biotech_outlined,
    'radiology' => Icons.camera_outdoor_outlined,
    'pharmacy' => Icons.local_pharmacy_outlined,
    'billing' => Icons.receipt_long_outlined,
    'housekeeping' => Icons.cleaning_services_outlined,
    'biomedical' => Icons.precision_manufacturing_outlined,
    'hr' => Icons.badge_outlined,
    'emergency' => Icons.emergency_outlined,
    'mortuary' => Icons.inventory_2_outlined,
    'communications' => Icons.forum_outlined,
    'profile' => Icons.account_circle_outlined,
    _ => Icons.insights_outlined,
  };
}
