import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

List<HomeAlertItem> guidedFallbackAlerts(HomeDashboardProfile profile) {
  return switch (profile.role) {
    AppRole.doctor || AppRole.nurse => <HomeAlertItem>[
      const HomeAlertItem(
        id: 'guided_critical_labs',
        label: 'Critical lab results',
        severity: 'HIGH',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'lab',
          resource: 'results',
          action: 'list',
        ),
      ),
      const HomeAlertItem(
        id: 'guided_bed_pressure',
        label: 'Inpatient bed pressure',
        severity: 'MEDIUM',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'ipd',
          resource: 'admissions',
          action: 'list',
        ),
      ),
    ],
    AppRole.facilityAdmin || AppRole.operations => <HomeAlertItem>[
      const HomeAlertItem(
        id: 'guided_bed_occupancy',
        label: 'Bed occupancy pressure',
        severity: 'MEDIUM',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'ipd',
          resource: 'admissions',
          action: 'list',
        ),
      ),
      const HomeAlertItem(
        id: 'guided_billing_exceptions',
        label: 'Billing follow-up',
        severity: 'WARNING',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'billing',
          resource: 'invoices',
          action: 'list',
        ),
      ),
    ],
    AppRole.receptionist => <HomeAlertItem>[
      const HomeAlertItem(
        id: 'guided_opd_notifications',
        label: 'OPD notifications',
        severity: 'INFO',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'scheduling',
          resource: 'opd-flows',
          action: 'open',
        ),
      ),
      const HomeAlertItem(
        id: 'guided_no_show_follow_up',
        label: 'No-show follow-ups',
        severity: 'MEDIUM',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'scheduling',
          resource: 'appointments',
          action: 'list',
        ),
      ),
    ],
    AppRole.billing => <HomeAlertItem>[
      const HomeAlertItem(
        id: 'guided_overdue_invoices',
        label: 'Overdue invoices',
        severity: 'HIGH',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'billing',
          resource: 'invoices',
          action: 'list',
        ),
      ),
    ],
    AppRole.labTech => <HomeAlertItem>[
      const HomeAlertItem(
        id: 'guided_critical_results',
        label: 'Critical results queue',
        severity: 'CRITICAL',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'lab',
          resource: 'results',
          action: 'list',
        ),
      ),
    ],
    AppRole.pharmacist => <HomeAlertItem>[
      const HomeAlertItem(
        id: 'guided_pharmacy_orders',
        label: 'Pending dispense orders need attention',
        severity: 'MEDIUM',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'pharmacy',
          resource: 'pharmacy-orders',
          action: 'list',
        ),
      ),
    ],
    AppRole.patient => <HomeAlertItem>[
      const HomeAlertItem(
        id: 'guided_my_messages',
        label: 'Care messages',
        severity: 'INFO',
        count: 0,
        target: HomeRouteTarget(
          moduleSlug: 'communications',
          resource: 'messages',
          action: 'open',
        ),
      ),
    ],
    _ => const <HomeAlertItem>[],
  };
}

List<HomeQueueItem> guidedFallbackQueueHints(HomeDashboardProfile profile) {
  return switch (profile.role) {
    AppRole.receptionist || AppRole.facilityAdmin => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_opd_front_desk',
        label: 'OPD front desk queue',
        moduleSlug: 'scheduling',
        status: 'OPEN',
        severity: 'medium',
        target: HomeRouteTarget(
          moduleSlug: 'scheduling',
          resource: 'opd-flows',
          action: 'open',
        ),
      ),
      const HomeQueueItem(
        id: 'guided_appointments',
        label: 'Today\'s meetings & appointments',
        moduleSlug: 'scheduling',
        status: 'SCHEDULED',
        severity: 'medium',
        target: HomeRouteTarget(
          moduleSlug: 'scheduling',
          resource: 'appointments',
          action: 'list',
        ),
      ),
      const HomeQueueItem(
        id: 'guided_doctor_assignment',
        label: 'Patients waiting for doctor assignment',
        moduleSlug: 'scheduling',
        status: 'WAITING_DOCTOR_ASSIGNMENT',
        severity: 'high',
        target: HomeRouteTarget(
          moduleSlug: 'scheduling',
          resource: 'opd-flows',
          action: 'open',
        ),
      ),
      const HomeQueueItem(
        id: 'guided_emergency_intake',
        label: 'Emergency intake & assignment',
        moduleSlug: 'emergency',
        status: 'OPEN',
        severity: 'high',
        target: HomeRouteTarget(
          moduleSlug: 'emergency',
          resource: 'cases',
          action: 'list',
        ),
      ),
    ],
    AppRole.doctor => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_clinical_queue',
        label: 'Clinical consultation queue',
        moduleSlug: 'clinical',
        status: 'IN_PROGRESS',
        severity: 'high',
        target: HomeRouteTarget(
          moduleSlug: 'clinical',
          resource: 'consultations',
          action: 'open',
        ),
      ),
      const HomeQueueItem(
        id: 'guided_opd_flow',
        label: 'OPD patient flow',
        moduleSlug: 'scheduling',
        status: 'OPEN',
        severity: 'medium',
        target: HomeRouteTarget(
          moduleSlug: 'scheduling',
          resource: 'opd-flows',
          action: 'open',
        ),
      ),
    ],
    AppRole.nurse ||
    AppRole.wardManager ||
    AppRole.icuManager => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_nursing_queue',
        label: 'Nursing action queue',
        moduleSlug: 'nursing',
        status: 'OPEN',
        severity: 'high',
        target: HomeRouteTarget(
          moduleSlug: 'nursing',
          resource: 'tasks',
          action: 'open',
        ),
      ),
      const HomeQueueItem(
        id: 'guided_ipd_admissions',
        label: 'Inpatient admissions',
        moduleSlug: 'ipd',
        status: 'ADMITTED',
        severity: 'high',
        target: HomeRouteTarget(
          moduleSlug: 'ipd',
          resource: 'admissions',
          action: 'list',
        ),
      ),
    ],
    AppRole.labTech => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_lab_results',
        label: 'Laboratory results queue',
        moduleSlug: 'lab',
        status: 'PENDING',
        severity: 'medium',
        target: HomeRouteTarget(
          moduleSlug: 'lab',
          resource: 'results',
          action: 'list',
        ),
      ),
    ],
    AppRole.radiologyTech => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_radiology_results',
        label: 'Imaging results queue',
        moduleSlug: 'radiology',
        status: 'DRAFT',
        severity: 'medium',
        target: HomeRouteTarget(
          moduleSlug: 'radiology',
          resource: 'results',
          action: 'list',
        ),
      ),
    ],
    AppRole.pharmacist => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_pharmacy_orders',
        label: 'Awaiting dispense — open Pharmacy to process orders',
        moduleSlug: 'pharmacy',
        status: 'ORDERED',
        severity: 'medium',
        target: HomeRouteTarget(
          moduleSlug: 'pharmacy',
          resource: 'pharmacy-orders',
          action: 'list',
        ),
      ),
    ],
    AppRole.billing => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_billing_follow_up',
        label: 'Billing follow-up queue',
        moduleSlug: 'billing',
        status: 'OVERDUE',
        severity: 'high',
        target: HomeRouteTarget(
          moduleSlug: 'billing',
          resource: 'invoices',
          action: 'list',
        ),
      ),
    ],
    AppRole.hr || AppRole.unitManager => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_staff_leaves',
        label: 'Leave requests queue',
        moduleSlug: 'hr',
        status: 'REQUESTED',
        severity: 'medium',
        target: HomeRouteTarget(
          moduleSlug: 'hr',
          resource: 'staff-leaves',
          action: 'list',
        ),
      ),
    ],
    AppRole.ambulanceOperator => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_emergency_cases',
        label: 'Emergency cases queue',
        moduleSlug: 'emergency',
        status: 'OPEN',
        severity: 'critical',
        target: HomeRouteTarget(
          moduleSlug: 'emergency',
          resource: 'emergency-cases',
          action: 'list',
        ),
      ),
    ],
    AppRole.mortuaryStaff || AppRole.mortuaryManager => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_mortuary_cases',
        label: 'Mortuary cases queue',
        moduleSlug: 'mortuary',
        status: 'RECEIVED',
        severity: 'medium',
        target: HomeRouteTarget(
          moduleSlug: 'mortuary',
          resource: 'cases',
          action: 'list',
        ),
      ),
    ],
    AppRole.tenantAdmin => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_create_facility',
        label: 'Create your first facility',
        moduleSlug: 'settings',
        status: 'OPEN',
        severity: 'info',
        target: HomeRouteTarget(
          moduleSlug: 'settings',
          resource: 'facilities',
          action: 'create',
        ),
      ),
      const HomeQueueItem(
        id: 'guided_tenant_setup',
        label: 'Tenant and facility setup',
        moduleSlug: 'settings',
        status: 'OPEN',
        severity: 'info',
        target: HomeRouteTarget(
          moduleSlug: 'settings',
          resource: 'tenant-facility-context',
          action: 'open',
        ),
      ),
    ],
    AppRole.superAdmin => <HomeQueueItem>[
      const HomeQueueItem(
        id: 'guided_tenant_setup',
        label: 'Tenant and facility setup',
        moduleSlug: 'settings',
        status: 'OPEN',
        severity: 'info',
        target: HomeRouteTarget(
          moduleSlug: 'settings',
          resource: 'tenant-facility-context',
          action: 'open',
        ),
      ),
    ],
    _ => const <HomeQueueItem>[],
  };
}
