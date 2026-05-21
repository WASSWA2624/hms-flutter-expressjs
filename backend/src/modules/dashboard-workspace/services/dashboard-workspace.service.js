const dashboardWorkspaceRepository = require('@repositories/dashboard-workspace/dashboard-workspace.repository');
const dashboardWidgetRepository = require('@repositories/dashboard-widget/dashboard-widget.repository');
const {
  ROLE_PACKS,
  buildDashboardSummary,
  resolveEffectiveRole,
  resolvePackId,
  resolveProfileId,
} = require('@lib/dashboard/summary');
const {
  buildDateWindowFilter,
  buildPagination,
  normalizeString,
  safeUpper,
} = require('@lib/reports/api');
const { ROLES, normalizeRoleName } = require('@config/roles');
const { getUserPermissions } = require('@middlewares/auth.middleware');

const ADMIN_ROLES = new Set([ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN]);
const DEFAULT_LIMIT = 20;
const GUIDE_SIGNAL_ID = 'guide_signal';

const DATE_PRESET_LOOKUPS = Object.freeze([
  { id: 'today', label_key: 'dashboard.filters.datePresets.today' },
  { id: 'last_7_days', label_key: 'dashboard.filters.datePresets.last7Days' },
  { id: 'last_30_days', label_key: 'dashboard.filters.datePresets.last30Days' },
  { id: 'last_90_days', label_key: 'dashboard.filters.datePresets.last90Days' },
]);

const MODULE_LOOKUPS = Object.freeze([
  { id: 'patients', label_key: 'dashboard.modules.patients' },
  { id: 'scheduling', label_key: 'dashboard.modules.scheduling' },
  { id: 'ipd', label_key: 'dashboard.modules.ipd' },
  { id: 'lab', label_key: 'dashboard.modules.lab' },
  { id: 'radiology', label_key: 'dashboard.modules.radiology' },
  { id: 'pharmacy', label_key: 'dashboard.modules.pharmacy' },
  { id: 'billing', label_key: 'dashboard.modules.billing' },
  { id: 'housekeeping', label_key: 'dashboard.modules.housekeeping' },
  { id: 'biomedical', label_key: 'dashboard.modules.biomedical' },
  { id: 'hr', label_key: 'dashboard.modules.hr' },
  { id: 'emergency', label_key: 'dashboard.modules.emergency' },
  { id: 'subscriptions', label_key: 'dashboard.modules.subscriptions' },
]);

const EVENT_TYPE_LOOKUPS = Object.freeze([
  { id: 'appointment_updated', label_key: 'dashboard.activity.eventTypes.appointmentUpdated' },
  { id: 'admission_updated', label_key: 'dashboard.activity.eventTypes.admissionUpdated' },
  { id: 'invoice_updated', label_key: 'dashboard.activity.eventTypes.invoiceUpdated' },
  { id: 'lab_result_updated', label_key: 'dashboard.activity.eventTypes.labResultUpdated' },
  { id: 'radiology_result_updated', label_key: 'dashboard.activity.eventTypes.radiologyResultUpdated' },
  { id: 'pharmacy_order_updated', label_key: 'dashboard.activity.eventTypes.pharmacyOrderUpdated' },
  { id: 'maintenance_request_updated', label_key: 'dashboard.activity.eventTypes.maintenanceRequestUpdated' },
  { id: 'housekeeping_task_updated', label_key: 'dashboard.activity.eventTypes.housekeepingTaskUpdated' },
  { id: 'equipment_work_order_updated', label_key: 'dashboard.activity.eventTypes.workOrderUpdated' },
  { id: 'staff_leave_updated', label_key: 'dashboard.activity.eventTypes.staffLeaveUpdated' },
  { id: 'emergency_case_updated', label_key: 'dashboard.activity.eventTypes.emergencyCaseUpdated' },
]);

const QUEUE_LOOKUPS = Object.freeze([
  { id: 'appointments', label_key: 'dashboard.queue.filters.queueTypes.appointments' },
  { id: 'admissions', label_key: 'dashboard.queue.filters.queueTypes.admissions' },
  { id: 'billing_follow_up', label_key: 'dashboard.queue.filters.queueTypes.billingFollowUp' },
  { id: 'lab_results', label_key: 'dashboard.queue.filters.queueTypes.labResults' },
  { id: 'radiology_results', label_key: 'dashboard.queue.filters.queueTypes.radiologyResults' },
  { id: 'pharmacy_orders', label_key: 'dashboard.queue.filters.queueTypes.pharmacyOrders' },
  { id: 'maintenance_requests', label_key: 'dashboard.queue.filters.queueTypes.maintenanceRequests' },
  { id: 'housekeeping_tasks', label_key: 'dashboard.queue.filters.queueTypes.housekeepingTasks' },
  { id: 'equipment_work_orders', label_key: 'dashboard.queue.filters.queueTypes.equipmentWorkOrders' },
  { id: 'staff_leaves', label_key: 'dashboard.queue.filters.queueTypes.staffLeaves' },
  { id: 'emergency_cases', label_key: 'dashboard.queue.filters.queueTypes.emergencyCases' },
]);

const STATUS_LABEL_KEYS = Object.freeze({
  SCHEDULED: 'dashboard.statusValues.scheduled',
  CONFIRMED: 'dashboard.statusValues.confirmed',
  IN_PROGRESS: 'dashboard.statusValues.inProgress',
  ADMITTED: 'dashboard.statusValues.admitted',
  SENT: 'dashboard.statusValues.sent',
  OVERDUE: 'dashboard.statusValues.overdue',
  DRAFT: 'dashboard.statusValues.draft',
  ISSUED: 'dashboard.statusValues.issued',
  PARTIAL: 'dashboard.statusValues.partial',
  PENDING: 'dashboard.statusValues.pending',
  CRITICAL: 'dashboard.statusValues.critical',
  ABNORMAL: 'dashboard.statusValues.abnormal',
  FINAL: 'dashboard.statusValues.final',
  AMENDED: 'dashboard.statusValues.amended',
  ORDERED: 'dashboard.statusValues.ordered',
  PARTIALLY_DISPENSED: 'dashboard.statusValues.partiallyDispensed',
  OPEN: 'dashboard.statusValues.open',
  ACKNOWLEDGED: 'dashboard.statusValues.acknowledged',
  REQUESTED: 'dashboard.statusValues.requested',
});

const buildStatusLookups = (statusIds = []) =>
  statusIds
    .map((id) => ({
      id,
      label_key: STATUS_LABEL_KEYS[id] || null,
    }))
    .filter((entry) => entry.label_key);

const QUEUE_STATUS_LOOKUPS = Object.freeze(
  buildStatusLookups([
    'SCHEDULED',
    'CONFIRMED',
    'IN_PROGRESS',
    'ADMITTED',
    'SENT',
    'OVERDUE',
    'DRAFT',
    'ISSUED',
    'PARTIAL',
    'PENDING',
    'CRITICAL',
    'ABNORMAL',
    'FINAL',
    'AMENDED',
    'ORDERED',
    'PARTIALLY_DISPENSED',
    'OPEN',
    'ACKNOWLEDGED',
    'REQUESTED',
  ])
);

const ACTIVITY_STATUS_LOOKUPS = Object.freeze(QUEUE_STATUS_LOOKUPS);

const actionTarget = (moduleSlug, resource, action = 'open') => ({
  module_slug: moduleSlug,
  resource,
  public_id: null,
  action,
});

const actionDefinition = ({
  id,
  label,
  allowedRoles,
  requiredPermissions = [],
  requiredAnyPermissions = [],
  requiredModules = [],
  scope = 'assigned_scope',
  target,
}) => Object.freeze({
  id,
  label,
  allowed_roles: allowedRoles,
  required_permissions: requiredPermissions,
  required_any_permissions: requiredAnyPermissions,
  required_modules: requiredModules,
  scope,
  route_target: target,
});

const QUICK_ACTION_LIBRARY = Object.freeze([
  actionDefinition({ id: 'select_context', label: 'Select tenant/facility context', allowedRoles: [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN], requiredAnyPermissions: ['system:admin', 'tenant:admin'], scope: 'platform_or_tenant', target: actionTarget('settings', 'tenant-facility-context') }),
  actionDefinition({ id: 'create_tenant', label: 'Create tenant', allowedRoles: [ROLES.SUPER_ADMIN], requiredPermissions: ['system:admin'], scope: 'platform', target: actionTarget('settings', 'tenants', 'create') }),
  actionDefinition({ id: 'create_facility', label: 'Create facility', allowedRoles: [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN], requiredAnyPermissions: ['tenant:admin', 'facility:admin'], scope: 'tenant_or_facility', target: actionTarget('settings', 'facilities', 'create') }),
  actionDefinition({ id: 'manage_subscription', label: 'Manage subscription', allowedRoles: [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN], requiredAnyPermissions: ['subscriptions:write', 'subscriptions:read'], requiredModules: ['subscriptions'], scope: 'tenant_or_facility', target: actionTarget('subscriptions', 'subscriptions') }),
  actionDefinition({ id: 'manage_users_roles', label: 'Manage users and roles', allowedRoles: [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.HR], requiredAnyPermissions: ['tenant:admin', 'facility:admin', 'hr:write'], scope: 'tenant_or_facility', target: actionTarget('settings', 'users-roles') }),
  actionDefinition({ id: 'run_report', label: 'Run report', allowedRoles: [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.BILLING, ROLES.OPERATIONS, ROLES.HR, ROLES.UNIT_MANAGER, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER, ROLES.THEATRE_MANAGER, ROLES.HOUSEKEEPING_MANAGER, ROLES.BIOMED_MANAGER, ROLES.MORTUARY_MANAGER, ROLES.LAB_TECH, ROLES.RADIOLOGY_TECH, ROLES.PHARMACIST], requiredPermissions: ['reports:read'], requiredModules: ['reports'], scope: 'assigned_scope', target: actionTarget('reports', 'reports') }),
  actionDefinition({ id: 'review_audit', label: 'Review audit/compliance', allowedRoles: [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.OPERATIONS, ROLES.MORTUARY_MANAGER, ROLES.BIOMED_MANAGER], requiredAnyPermissions: ['compliance:review', 'evidence:export'], scope: 'assigned_scope', target: actionTarget('reports', 'audit') }),
  actionDefinition({ id: 'register_patient', label: 'Register patient', allowedRoles: [ROLES.FACILITY_ADMIN, ROLES.RECEPTIONIST], requiredPermissions: ['patient:write'], requiredModules: ['patients'], scope: 'facility', target: actionTarget('patients', 'patients', 'create') }),
  actionDefinition({ id: 'book_appointment', label: 'Book appointment', allowedRoles: [ROLES.FACILITY_ADMIN, ROLES.RECEPTIONIST], requiredPermissions: ['patient:write'], requiredModules: ['scheduling'], scope: 'facility', target: actionTarget('scheduling', 'appointments', 'create') }),
  actionDefinition({ id: 'check_in_patient', label: 'Check in patient', allowedRoles: [ROLES.FACILITY_ADMIN, ROLES.RECEPTIONIST], requiredPermissions: ['patient:write'], requiredModules: ['scheduling'], scope: 'facility', target: actionTarget('scheduling', 'opd-flows') }),
  actionDefinition({ id: 'route_patient', label: 'Route patient to service', allowedRoles: [ROLES.RECEPTIONIST, ROLES.NURSE], requiredPermissions: ['patient:write'], requiredModules: ['scheduling'], scope: 'patient_flow', target: actionTarget('scheduling', 'opd-flows') }),
  actionDefinition({ id: 'start_consultation', label: 'Start consultation', allowedRoles: [ROLES.DOCTOR], requiredPermissions: ['clinical:write'], requiredModules: ['clinical'], scope: 'assigned_clinical', target: actionTarget('clinical', 'consultations') }),
  actionDefinition({ id: 'continue_consultation', label: 'Continue consultation', allowedRoles: [ROLES.DOCTOR], requiredPermissions: ['clinical:write'], requiredModules: ['clinical'], scope: 'assigned_clinical', target: actionTarget('clinical', 'consultations') }),
  actionDefinition({ id: 'write_clinical_note', label: 'Write clinical note', allowedRoles: [ROLES.DOCTOR, ROLES.NURSE, ROLES.ICU_MANAGER, ROLES.THEATRE_MANAGER], requiredPermissions: ['clinical:write'], requiredModules: ['clinical'], scope: 'clinical_scope', target: actionTarget('clinical', 'notes', 'create') }),
  actionDefinition({ id: 'order_lab', label: 'Order lab test', allowedRoles: [ROLES.DOCTOR], requiredPermissions: ['clinical:write'], requiredModules: ['lab'], scope: 'assigned_clinical', target: actionTarget('lab', 'orders', 'create') }),
  actionDefinition({ id: 'order_radiology', label: 'Order imaging', allowedRoles: [ROLES.DOCTOR], requiredPermissions: ['clinical:write'], requiredModules: ['radiology'], scope: 'assigned_clinical', target: actionTarget('radiology', 'orders', 'create') }),
  actionDefinition({ id: 'record_vitals', label: 'Record vitals', allowedRoles: [ROLES.NURSE, ROLES.DOCTOR, ROLES.ICU_MANAGER], requiredPermissions: ['clinical:write'], requiredModules: ['nursing'], scope: 'clinical_scope', target: actionTarget('nursing', 'vitals', 'create') }),
  actionDefinition({ id: 'mark_med_administered', label: 'Mark medication administered', allowedRoles: [ROLES.NURSE], requiredPermissions: ['clinical:write'], requiredModules: ['nursing'], scope: 'assigned_nursing', target: actionTarget('nursing', 'medications') }),
  actionDefinition({ id: 'create_handover', label: 'Create handover', allowedRoles: [ROLES.NURSE, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER, ROLES.THEATRE_MANAGER], requiredAnyPermissions: ['clinical:write', 'unit:manage'], requiredModules: ['nursing'], scope: 'assigned_unit', target: actionTarget('nursing', 'handovers', 'create') }),
  actionDefinition({ id: 'receive_sample', label: 'Receive sample', allowedRoles: [ROLES.LAB_TECH], requiredPermissions: ['lab:write'], requiredModules: ['lab'], scope: 'lab', target: actionTarget('lab', 'samples') }),
  actionDefinition({ id: 'enter_lab_result', label: 'Enter lab result', allowedRoles: [ROLES.LAB_TECH], requiredPermissions: ['lab:write'], requiredModules: ['lab'], scope: 'lab', target: actionTarget('lab', 'results', 'create') }),
  actionDefinition({ id: 'flag_critical_lab', label: 'Flag critical lab result', allowedRoles: [ROLES.LAB_TECH], requiredPermissions: ['lab:write'], requiredModules: ['lab'], scope: 'lab', target: actionTarget('lab', 'results') }),
  actionDefinition({ id: 'start_imaging_study', label: 'Start imaging study', allowedRoles: [ROLES.RADIOLOGY_TECH], requiredPermissions: ['radiology:write'], requiredModules: ['radiology'], scope: 'radiology', target: actionTarget('radiology', 'studies') }),
  actionDefinition({ id: 'update_imaging_status', label: 'Update imaging status', allowedRoles: [ROLES.RADIOLOGY_TECH], requiredPermissions: ['radiology:write'], requiredModules: ['radiology'], scope: 'radiology', target: actionTarget('radiology', 'studies') }),
  actionDefinition({ id: 'add_radiology_report', label: 'Add imaging report', allowedRoles: [ROLES.RADIOLOGY_TECH], requiredPermissions: ['radiology:write'], requiredModules: ['radiology'], scope: 'radiology', target: actionTarget('radiology', 'reports', 'create') }),
  actionDefinition({ id: 'dispense_medication', label: 'Dispense medication', allowedRoles: [ROLES.PHARMACIST], requiredPermissions: ['pharmacy:write'], requiredModules: ['pharmacy'], scope: 'pharmacy', target: actionTarget('pharmacy', 'orders') }),
  actionDefinition({ id: 'record_pharmacy_sale', label: 'Record pharmacy sale', allowedRoles: [ROLES.PHARMACIST], requiredPermissions: ['pharmacy:write'], requiredModules: ['pharmacy'], scope: 'pharmacy', target: actionTarget('pharmacy', 'sales', 'create') }),
  actionDefinition({ id: 'receive_pharmacy_stock', label: 'Receive pharmacy stock', allowedRoles: [ROLES.PHARMACIST], requiredPermissions: ['pharmacy:write'], requiredModules: ['pharmacy'], scope: 'pharmacy', target: actionTarget('pharmacy', 'stock') }),
  actionDefinition({ id: 'adjust_pharmacy_stock', label: 'Adjust pharmacy stock', allowedRoles: [ROLES.PHARMACIST], requiredPermissions: ['pharmacy:write'], requiredModules: ['pharmacy'], scope: 'pharmacy', target: actionTarget('pharmacy', 'stock') }),
  actionDefinition({ id: 'create_invoice', label: 'Create invoice', allowedRoles: [ROLES.BILLING], requiredPermissions: ['billing:write'], requiredModules: ['billing'], scope: 'billing', target: actionTarget('billing', 'invoices', 'create') }),
  actionDefinition({ id: 'receive_payment', label: 'Receive payment', allowedRoles: [ROLES.BILLING], requiredPermissions: ['billing:write'], requiredModules: ['billing'], scope: 'billing', target: actionTarget('billing', 'payments', 'create') }),
  actionDefinition({ id: 'process_refund', label: 'Process refund', allowedRoles: [ROLES.BILLING], requiredPermissions: ['billing:write'], requiredModules: ['billing'], scope: 'billing', target: actionTarget('billing', 'refunds') }),
  actionDefinition({ id: 'close_shift', label: 'Close shift/day', allowedRoles: [ROLES.BILLING], requiredPermissions: ['billing:write'], requiredModules: ['billing'], scope: 'billing', target: actionTarget('billing', 'closeout') }),
  actionDefinition({ id: 'create_maintenance_request', label: 'Create maintenance request', allowedRoles: [ROLES.OPERATIONS, ROLES.FACILITY_ADMIN], requiredPermissions: ['operations:write'], requiredModules: ['operations'], scope: 'operations', target: actionTarget('operations', 'maintenance-requests', 'create') }),
  actionDefinition({ id: 'assign_maintenance', label: 'Assign maintenance', allowedRoles: [ROLES.OPERATIONS], requiredPermissions: ['operations:write'], requiredModules: ['operations'], scope: 'operations', target: actionTarget('operations', 'maintenance-requests') }),
  actionDefinition({ id: 'update_bed_readiness', label: 'Update bed/room readiness', allowedRoles: [ROLES.OPERATIONS, ROLES.HOUSEKEEPING_MANAGER], requiredPermissions: ['operations:write'], requiredModules: ['rooms_beds'], scope: 'facility', target: actionTarget('rooms_beds', 'beds') }),
  actionDefinition({ id: 'create_cleaning_task', label: 'Create cleaning task', allowedRoles: [ROLES.HOUSEKEEPING_MANAGER, ROLES.OPERATIONS], requiredPermissions: ['operations:write'], requiredModules: ['housekeeping'], scope: 'housekeeping', target: actionTarget('housekeeping', 'tasks', 'create') }),
  actionDefinition({ id: 'assign_cleaning_task', label: 'Assign cleaning task', allowedRoles: [ROLES.HOUSEKEEPING_MANAGER], requiredPermissions: ['operations:write'], requiredModules: ['housekeeping'], scope: 'housekeeping', target: actionTarget('housekeeping', 'tasks') }),
  actionDefinition({ id: 'start_cleaning_task', label: 'Start assigned cleaning task', allowedRoles: [ROLES.HOUSE_KEEPER], requiredPermissions: ['operations:read'], requiredModules: ['housekeeping'], scope: 'assigned_tasks', target: actionTarget('housekeeping', 'tasks') }),
  actionDefinition({ id: 'complete_cleaning_task', label: 'Complete assigned cleaning task', allowedRoles: [ROLES.HOUSE_KEEPER], requiredPermissions: ['operations:read'], requiredModules: ['housekeeping'], scope: 'assigned_tasks', target: actionTarget('housekeeping', 'tasks') }),
  actionDefinition({ id: 'mark_cleaning_blocked', label: 'Mark cleaning task blocked', allowedRoles: [ROLES.HOUSE_KEEPER, ROLES.HOUSEKEEPING_MANAGER], requiredPermissions: ['operations:read'], requiredModules: ['housekeeping'], scope: 'housekeeping', target: actionTarget('housekeeping', 'tasks') }),
  actionDefinition({ id: 'add_staff_profile', label: 'Add staff profile', allowedRoles: [ROLES.HR, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN], requiredAnyPermissions: ['hr:write', 'tenant:admin', 'facility:admin'], requiredModules: ['hr'], scope: 'tenant_or_facility', target: actionTarget('hr', 'staff-profiles', 'create') }),
  actionDefinition({ id: 'review_leave', label: 'Review leave request', allowedRoles: [ROLES.HR, ROLES.UNIT_MANAGER, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER, ROLES.THEATRE_MANAGER, ROLES.HOUSEKEEPING_MANAGER, ROLES.BIOMED_MANAGER], requiredAnyPermissions: ['hr:write', 'roster:approve'], requiredModules: ['hr'], scope: 'assigned_team', target: actionTarget('hr', 'leave') }),
  actionDefinition({ id: 'create_shift', label: 'Create shift', allowedRoles: [ROLES.HR, ROLES.UNIT_MANAGER, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER, ROLES.THEATRE_MANAGER, ROLES.HOUSEKEEPING_MANAGER, ROLES.BIOMED_MANAGER], requiredPermissions: ['roster:write'], requiredModules: ['hr'], scope: 'assigned_team', target: actionTarget('hr', 'shifts', 'create') }),
  actionDefinition({ id: 'publish_roster', label: 'Publish roster', allowedRoles: [ROLES.HR, ROLES.UNIT_MANAGER, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER, ROLES.THEATRE_MANAGER], requiredPermissions: ['roster:publish'], requiredModules: ['hr'], scope: 'assigned_team', target: actionTarget('hr', 'rosters') }),
  actionDefinition({ id: 'approve_roster', label: 'Approve roster', allowedRoles: [ROLES.HR, ROLES.UNIT_MANAGER, ROLES.WARD_MANAGER, ROLES.ICU_MANAGER, ROLES.THEATRE_MANAGER], requiredPermissions: ['roster:approve'], requiredModules: ['hr'], scope: 'assigned_team', target: actionTarget('hr', 'rosters') }),
  actionDefinition({ id: 'report_equipment_issue', label: 'Report equipment issue', allowedRoles: [ROLES.BIOMED, ROLES.BIOMED_MANAGER, ROLES.FACILITY_ADMIN, ROLES.OPERATIONS], requiredAnyPermissions: ['biomed:write', 'facility:admin', 'operations:write'], requiredModules: ['biomedical'], scope: 'biomed', target: actionTarget('biomedical', 'work-orders', 'create') }),
  actionDefinition({ id: 'acknowledge_work_order', label: 'Acknowledge work order', allowedRoles: [ROLES.BIOMED], requiredPermissions: ['biomed:write'], requiredModules: ['biomedical'], scope: 'biomed', target: actionTarget('biomedical', 'work-orders') }),
  actionDefinition({ id: 'update_work_order', label: 'Update work order', allowedRoles: [ROLES.BIOMED, ROLES.BIOMED_MANAGER], requiredPermissions: ['biomed:write'], requiredModules: ['biomedical'], scope: 'biomed', target: actionTarget('biomedical', 'work-orders') }),
  actionDefinition({ id: 'assign_technician', label: 'Assign technician', allowedRoles: [ROLES.BIOMED_MANAGER], requiredPermissions: ['biomed:write'], requiredModules: ['biomedical'], scope: 'biomed_management', target: actionTarget('biomedical', 'work-orders') }),
  actionDefinition({ id: 'dispatch_ambulance', label: 'Dispatch ambulance', allowedRoles: [ROLES.AMBULANCE_OPERATOR], requiredPermissions: ['emergency:write'], requiredModules: ['emergency'], scope: 'ambulance', target: actionTarget('emergency', 'ambulance-dispatches', 'create') }),
  actionDefinition({ id: 'update_trip_status', label: 'Update trip status', allowedRoles: [ROLES.AMBULANCE_OPERATOR], requiredPermissions: ['emergency:write'], requiredModules: ['emergency'], scope: 'ambulance', target: actionTarget('emergency', 'ambulance-trips') }),
  actionDefinition({ id: 'record_emergency_handover', label: 'Record emergency handover', allowedRoles: [ROLES.AMBULANCE_OPERATOR], requiredPermissions: ['emergency:write'], requiredModules: ['emergency'], scope: 'ambulance', target: actionTarget('emergency', 'handovers') }),
  actionDefinition({ id: 'open_mortuary_case', label: 'Open mortuary case', allowedRoles: [ROLES.MORTUARY_STAFF, ROLES.MORTUARY_MANAGER], requiredPermissions: ['mortuary:write'], requiredModules: ['mortuary'], scope: 'mortuary', target: actionTarget('mortuary', 'cases', 'create') }),
  actionDefinition({ id: 'assign_storage_slot', label: 'Assign storage slot', allowedRoles: [ROLES.MORTUARY_STAFF, ROLES.MORTUARY_MANAGER], requiredPermissions: ['mortuary:manage_storage'], requiredModules: ['mortuary'], scope: 'mortuary', target: actionTarget('mortuary', 'storage') }),
  actionDefinition({ id: 'record_custody_event', label: 'Record custody event', allowedRoles: [ROLES.MORTUARY_STAFF, ROLES.MORTUARY_MANAGER], requiredPermissions: ['mortuary:write'], requiredModules: ['mortuary'], scope: 'mortuary', target: actionTarget('mortuary', 'custody-events', 'create') }),
  actionDefinition({ id: 'schedule_viewing', label: 'Schedule viewing', allowedRoles: [ROLES.MORTUARY_STAFF, ROLES.MORTUARY_MANAGER], requiredPermissions: ['mortuary:write'], requiredModules: ['mortuary'], scope: 'mortuary', target: actionTarget('mortuary', 'viewings', 'create') }),
  actionDefinition({ id: 'add_mortuary_billable_event', label: 'Add mortuary billable event', allowedRoles: [ROLES.MORTUARY_STAFF, ROLES.MORTUARY_MANAGER], requiredPermissions: ['mortuary:billing_event'], requiredModules: ['mortuary'], scope: 'mortuary', target: actionTarget('mortuary', 'billable-events', 'create') }),
  actionDefinition({ id: 'review_release_authorization', label: 'Review release authorization', allowedRoles: [ROLES.MORTUARY_MANAGER], requiredAnyPermissions: ['mortuary:release', 'mortuary:approve'], requiredModules: ['mortuary'], scope: 'mortuary_management', target: actionTarget('mortuary', 'release-authorisations') }),
  actionDefinition({ id: 'approve_release', label: 'Approve release', allowedRoles: [ROLES.MORTUARY_MANAGER], requiredPermissions: ['mortuary:approve'], requiredModules: ['mortuary'], scope: 'mortuary_management', target: actionTarget('mortuary', 'release-authorisations') }),
  actionDefinition({ id: 'export_mortuary_evidence', label: 'Export mortuary evidence', allowedRoles: [ROLES.MORTUARY_MANAGER], requiredAnyPermissions: ['mortuary:export', 'evidence:export'], requiredModules: ['mortuary'], scope: 'mortuary_management', target: actionTarget('mortuary', 'exports') }),
  actionDefinition({ id: 'update_own_profile', label: 'Update my profile', allowedRoles: [ROLES.PATIENT, ROLES.OTHER, ROLES.RECEPTIONIST, ROLES.DOCTOR, ROLES.NURSE, ROLES.BILLING, ROLES.HR, ROLES.OPERATIONS], requiredAnyPermissions: ['profile:update', 'profile:read'], scope: 'self', target: actionTarget('profile', 'profile') }),
  actionDefinition({ id: 'view_my_care', label: 'View my care information', allowedRoles: [ROLES.PATIENT], requiredPermissions: ['profile:read'], scope: 'self', target: actionTarget('profile', 'care') }),
  actionDefinition({ id: 'contact_facility', label: 'Contact facility', allowedRoles: [ROLES.PATIENT, ROLES.OTHER], requiredPermissions: ['profile:read'], scope: 'self', target: actionTarget('communications', 'messages') }),
]);

const getUserRoles = (user = {}) => {
  const candidates = [];
  const roleValues = Array.isArray(user.roles) ? user.roles : [];
  for (const role of roleValues) {
    const normalized = normalizeRoleName(role?.name || role?.role_name || role?.role?.name || role);
    if (normalized) candidates.push(normalized);
  }
  const directRole = normalizeRoleName(user.role || user.role_name);
  if (directRole) candidates.push(directRole);
  const roles = Array.from(new Set(candidates));
  return roles.length ? roles : [ROLES.OTHER];
};

const normalizeModuleCode = (value) =>
  normalizeString(value).toLowerCase().replace(/[\s-]+/g, '_');

const normalizeModuleEntitlements = (user = {}) => {
  const source =
    user.module_entitlements ||
    user.moduleEntitlements ||
    user.modules ||
    user.enabled_modules ||
    user.enabledModules;
  if (!source) return null;

  const entries = Array.isArray(source)
    ? source
    : typeof source === 'object'
      ? Object.entries(source).map(([code, value]) => ({ code, value }))
      : [];
  if (!entries.length) return null;

  const enabled = new Set();
  for (const entry of entries) {
    const rawCode = Array.isArray(entry)
      ? entry[0]
      : entry?.code || entry?.module_code || entry?.moduleCode || entry?.slug || entry?.module?.slug;
    const normalizedCode = normalizeModuleCode(rawCode);
    if (!normalizedCode) continue;
    const value = Array.isArray(entry) ? entry[1] : entry?.value ?? entry;
    const disabled =
      value === false ||
      entry?.is_active === false ||
      entry?.isActive === false ||
      entry?.enabled === false ||
      entry?.status === 'DISABLED' ||
      entry?.status === 'EXPIRED';
    if (!disabled) enabled.add(normalizedCode);
  }

  return enabled.size ? enabled : null;
};

const modulesEnabled = (user, modules = []) => {
  if (!modules.length) return true;
  const enabled = normalizeModuleEntitlements(user);
  if (!enabled) return true;
  return modules.every((moduleCode) => enabled.has(normalizeModuleCode(moduleCode)));
};

const hasAllPermissions = (permissions, required = []) =>
  required.every((permission) => permissions.has(permission));

const hasAnyPermission = (permissions, required = []) =>
  !required.length || required.some((permission) => permissions.has(permission));

const sanitizeQuickAction = (action) => ({
  id: action.id,
  label: action.label,
  allowed_roles: action.allowed_roles,
  required_permissions: action.required_permissions,
  required_any_permissions: action.required_any_permissions,
  required_modules: action.required_modules,
  scope: action.scope,
  route_target: action.route_target,
});

const hiddenReasonForAction = (action, roles, permissions, user) => {
  if (!action.allowed_roles.some((role) => roles.includes(role))) {
    return `Requires ${action.allowed_roles.join(' or ')} role`;
  }
  if (!hasAllPermissions(permissions, action.required_permissions)) {
    return `Requires ${action.required_permissions.join(', ')}`;
  }
  if (!hasAnyPermission(permissions, action.required_any_permissions)) {
    return `Requires one of ${action.required_any_permissions.join(', ')}`;
  }
  if (!modulesEnabled(user, action.required_modules)) {
    return 'Module not enabled';
  }
  return null;
};

const resolveQuickActions = (user = {}, limit = 8) => {
  const roles = getUserRoles(user);
  const permissions = new Set(getUserPermissions({ ...user, roles }));
  const hiddenReasonMap = {};
  const quickActions = [];
  const seen = new Set();

  for (const action of QUICK_ACTION_LIBRARY) {
    const reason = hiddenReasonForAction(action, roles, permissions, user);
    if (reason) {
      hiddenReasonMap[action.id] = reason;
      continue;
    }
    if (!seen.has(action.id)) {
      quickActions.push(sanitizeQuickAction(action));
      seen.add(action.id);
    }
  }

  return {
    quickActions: quickActions.slice(0, limit),
    hiddenReasonMap,
  };
};

const startOfDay = (value = new Date()) => {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date;
};

const shiftDays = (value, dayOffset) => {
  const date = new Date(value);
  date.setDate(date.getDate() + dayOffset);
  return date;
};

const toNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const percentOf = (used, limit) => {
  const safeLimit = toNumber(limit);
  if (safeLimit <= 0) return 0;
  return Math.min(100, Math.round((toNumber(used) / safeLimit) * 100));
};

const directScope = (scope = {}, options = {}) => {
  const { includeTenant = true, includeFacility = true } = options;
  const where = { deleted_at: null };
  if (includeTenant && scope.tenant_id) where.tenant_id = scope.tenant_id;
  if (includeFacility && scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const patientRelationScope = (scope = {}) => {
  const where = { deleted_at: null };
  if (scope.tenant_id) where.tenant_id = scope.tenant_id;
  if (scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const buildLabResultScopeWhere = (scope = {}) => ({
  deleted_at: null,
  lab_order_item: {
    deleted_at: null,
    lab_order: {
      deleted_at: null,
      patient: patientRelationScope(scope),
    },
  },
});

const buildRadiologyResultScopeWhere = (scope = {}) => ({
  deleted_at: null,
  radiology_order: {
    deleted_at: null,
    patient: patientRelationScope(scope),
  },
});

const buildPharmacyOrderScopeWhere = (scope = {}) => ({
  deleted_at: null,
  patient: patientRelationScope(scope),
});

const buildHousekeepingWhere = (scope = {}) => ({
  deleted_at: null,
  ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  ...(scope.tenant_id
    ? { facility: { is: { deleted_at: null, tenant_id: scope.tenant_id } } }
    : {}),
});

const buildMaintenanceWhere = (scope = {}) => ({
  deleted_at: null,
  ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  ...(scope.tenant_id
    ? { facility: { is: { deleted_at: null, tenant_id: scope.tenant_id } } }
    : {}),
});

const activeQueueDefinitions = Object.freeze({
  appointments: {
    id: 'appointments',
    queue_key: 'appointments',
    kind: 'appointment',
    module_slug: 'scheduling',
    resource: 'appointments',
    model: 'appointment',
    time_field: 'scheduled_start',
    default_sort: 'scheduled_start',
    select: { id: true, human_friendly_id: true, status: true, scheduled_start: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...directScope(scope),
      status: { in: ['SCHEDULED', 'CONFIRMED', 'IN_PROGRESS'] },
    }),
    buildSeverity: (row) => (String(row?.status || '').toUpperCase() === 'IN_PROGRESS' ? 'high' : 'medium'),
    activity_event_type: 'appointment_updated',
  },
  admissions: {
    id: 'admissions',
    queue_key: 'admissions',
    kind: 'admission',
    module_slug: 'ipd',
    resource: 'admissions',
    model: 'admission',
    time_field: 'updated_at',
    default_sort: 'updated_at',
    select: { id: true, human_friendly_id: true, status: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...directScope(scope),
      status: 'ADMITTED',
    }),
    buildSeverity: () => 'high',
    activity_event_type: 'admission_updated',
  },
  billing_follow_up: {
    id: 'billing_follow_up',
    queue_key: 'billing_follow_up',
    kind: 'invoice',
    module_slug: 'billing',
    resource: 'invoices',
    model: 'invoice',
    time_field: 'issued_at',
    default_sort: 'issued_at',
    select: {
      id: true,
      human_friendly_id: true,
      status: true,
      billing_status: true,
      issued_at: true,
      updated_at: true,
      total_amount: true,
      currency: true,
    },
    buildWhere: (scope) => ({
      ...directScope(scope),
      OR: [
        { status: { in: ['SENT', 'OVERDUE'] } },
        { billing_status: { in: ['DRAFT', 'ISSUED', 'PARTIAL'] } },
      ],
    }),
    buildSeverity: (row) =>
      String(row?.status || '').toUpperCase() === 'OVERDUE' ? 'critical' : 'medium',
    activity_event_type: 'invoice_updated',
  },
  lab_results: {
    id: 'lab_results',
    queue_key: 'lab_results',
    kind: 'lab_result',
    module_slug: 'lab',
    resource: 'results',
    model: 'lab_result',
    time_field: 'updated_at',
    default_sort: 'updated_at',
    select: { id: true, human_friendly_id: true, status: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...buildLabResultScopeWhere(scope),
      status: { in: ['PENDING', 'CRITICAL', 'ABNORMAL'] },
    }),
    buildSeverity: (row) => {
      const status = String(row?.status || '').toUpperCase();
      if (status === 'CRITICAL') return 'critical';
      if (status === 'ABNORMAL') return 'high';
      return 'medium';
    },
    activity_event_type: 'lab_result_updated',
  },
  radiology_results: {
    id: 'radiology_results',
    queue_key: 'radiology_results',
    kind: 'radiology_result',
    module_slug: 'radiology',
    resource: 'results',
    model: 'radiology_result',
    time_field: 'updated_at',
    default_sort: 'updated_at',
    select: { id: true, human_friendly_id: true, status: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...buildRadiologyResultScopeWhere(scope),
      status: { in: ['DRAFT', 'AMENDED'] },
    }),
    buildSeverity: (row) => {
      const status = String(row?.status || '').toUpperCase();
      if (status === 'AMENDED') return 'high';
      return 'medium';
    },
    activity_event_type: 'radiology_result_updated',
  },
  pharmacy_orders: {
    id: 'pharmacy_orders',
    queue_key: 'pharmacy_orders',
    kind: 'pharmacy_order',
    module_slug: 'pharmacy',
    resource: 'pharmacy-orders',
    model: 'pharmacy_order',
    time_field: 'ordered_at',
    default_sort: 'ordered_at',
    select: { id: true, human_friendly_id: true, status: true, ordered_at: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...buildPharmacyOrderScopeWhere(scope),
      status: { in: ['ORDERED', 'PARTIALLY_DISPENSED'] },
    }),
    buildSeverity: () => 'medium',
    activity_event_type: 'pharmacy_order_updated',
  },
  maintenance_requests: {
    id: 'maintenance_requests',
    queue_key: 'maintenance_requests',
    kind: 'maintenance_request',
    module_slug: 'housekeeping',
    resource: 'maintenance-requests',
    model: 'maintenance_request',
    time_field: 'reported_at',
    default_sort: 'reported_at',
    select: { id: true, human_friendly_id: true, status: true, reported_at: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...buildMaintenanceWhere(scope),
      status: { in: ['OPEN', 'IN_PROGRESS'] },
    }),
    buildSeverity: (row) => {
      const status = normalizeString(row?.status).toUpperCase();
      if (status === 'OPEN') return 'high';
      return 'medium';
    },
    activity_event_type: 'maintenance_request_updated',
  },
  housekeeping_tasks: {
    id: 'housekeeping_tasks',
    queue_key: 'housekeeping_tasks',
    kind: 'housekeeping_task',
    module_slug: 'housekeeping',
    resource: 'housekeeping-tasks',
    model: 'housekeeping_task',
    time_field: 'scheduled_at',
    default_sort: 'scheduled_at',
    select: { id: true, human_friendly_id: true, status: true, scheduled_at: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...buildHousekeepingWhere(scope),
      status: { in: ['PENDING', 'IN_PROGRESS'] },
    }),
    buildSeverity: (row) => {
      const scheduledAt = row?.scheduled_at ? new Date(row.scheduled_at) : null;
      if (scheduledAt && scheduledAt.getTime() < Date.now()) return 'high';
      return 'medium';
    },
    activity_event_type: 'housekeeping_task_updated',
  },
  equipment_work_orders: {
    id: 'equipment_work_orders',
    queue_key: 'equipment_work_orders',
    kind: 'equipment_work_order',
    module_slug: 'biomedical',
    resource: 'equipment-work-orders',
    model: 'equipment_work_order',
    time_field: 'opened_at',
    default_sort: 'opened_at',
    select: { id: true, human_friendly_id: true, status: true, priority: true, opened_at: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      deleted_at: null,
      ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
      status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] },
    }),
    buildSeverity: (row) => {
      const priority = String(row?.priority || '').toUpperCase();
      if (['CRITICAL', 'URGENT', 'HIGH'].includes(priority)) return 'critical';
      return 'high';
    },
    activity_event_type: 'equipment_work_order_updated',
  },
  staff_leaves: {
    id: 'staff_leaves',
    queue_key: 'staff_leaves',
    kind: 'staff_leave',
    module_slug: 'hr',
    resource: 'staff-leaves',
    model: 'staff_leave',
    time_field: 'created_at',
    default_sort: 'created_at',
    select: { id: true, human_friendly_id: true, status: true, created_at: true, updated_at: true },
    buildWhere: (scope) => ({
      deleted_at: null,
      staff_profile: {
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
      },
      status: 'REQUESTED',
    }),
    buildSeverity: () => 'medium',
    activity_event_type: 'staff_leave_updated',
  },
  emergency_cases: {
    id: 'emergency_cases',
    queue_key: 'emergency_cases',
    kind: 'emergency_case',
    module_slug: 'emergency',
    resource: 'emergency-cases',
    model: 'emergency_case',
    time_field: 'created_at',
    default_sort: 'created_at',
    select: { id: true, human_friendly_id: true, status: true, severity: true, created_at: true, updated_at: true },
    buildWhere: (scope) => ({
      ...directScope(scope),
      status: 'OPEN',
    }),
    buildSeverity: (row) => {
      const severity = String(row?.severity || '').toUpperCase();
      if (['CRITICAL', 'HIGH'].includes(severity)) return 'critical';
      return 'high';
    },
    activity_event_type: 'emergency_case_updated',
  },
  mortuary_cases: {
    id: 'mortuary_cases',
    queue_key: 'mortuary_cases',
    kind: 'mortuary_case',
    module_slug: 'mortuary',
    resource: 'cases',
    model: 'mortuary_case',
    time_field: 'received_at',
    default_sort: 'received_at',
    select: { id: true, human_friendly_id: true, status: true, received_at: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...directScope(scope),
      status: { in: ['RECEIVED', 'IDENTIFICATION_PENDING', 'IN_STORAGE', 'POST_MORTEM_PENDING', 'READY_FOR_RELEASE'] },
    }),
    buildSeverity: (row) => {
      const status = normalizeString(row?.status).toUpperCase();
      if (['IDENTIFICATION_PENDING', 'POST_MORTEM_PENDING'].includes(status)) return 'high';
      return 'medium';
    },
    activity_event_type: 'mortuary_case_updated',
  },
  mortuary_releases: {
    id: 'mortuary_releases',
    queue_key: 'mortuary_releases',
    kind: 'mortuary_release_authorisation',
    module_slug: 'mortuary',
    resource: 'release-authorisations',
    model: 'mortuary_release_authorisation',
    time_field: 'created_at',
    default_sort: 'created_at',
    select: { id: true, human_friendly_id: true, status: true, created_at: true, updated_at: true },
    buildWhere: (scope) => ({
      ...directScope(scope),
      status: 'DRAFT',
    }),
    buildSeverity: () => 'high',
    activity_event_type: 'mortuary_release_updated',
  },
  mortuary_viewings: {
    id: 'mortuary_viewings',
    queue_key: 'mortuary_viewings',
    kind: 'mortuary_viewing',
    module_slug: 'mortuary',
    resource: 'viewings',
    model: 'mortuary_viewing',
    time_field: 'scheduled_at',
    default_sort: 'scheduled_at',
    select: { id: true, human_friendly_id: true, status: true, scheduled_at: true, updated_at: true, created_at: true },
    buildWhere: (scope) => ({
      ...directScope(scope),
      status: { in: ['SCHEDULED', 'IN_PROGRESS'] },
    }),
    buildSeverity: (row) => {
      const scheduledAt = row?.scheduled_at ? new Date(row.scheduled_at) : null;
      if (scheduledAt && scheduledAt.getTime() < Date.now()) return 'high';
      return 'medium';
    },
    activity_event_type: 'mortuary_viewing_updated',
  },
  mortuary_post_mortems: {
    id: 'mortuary_post_mortems',
    queue_key: 'mortuary_post_mortems',
    kind: 'mortuary_post_mortem_request',
    module_slug: 'mortuary',
    resource: 'post-mortem-requests',
    model: 'mortuary_post_mortem_request',
    time_field: 'created_at',
    default_sort: 'created_at',
    select: { id: true, human_friendly_id: true, status: true, created_at: true, updated_at: true },
    buildWhere: (scope) => ({
      ...directScope(scope),
      status: { in: ['REQUESTED', 'APPROVED', 'SCHEDULED', 'IN_PROGRESS'] },
    }),
    buildSeverity: () => 'medium',
    activity_event_type: 'mortuary_post_mortem_updated',
  },
});

const ROLE_QUEUE_IDS = Object.freeze({
  [ROLE_PACKS.ADMIN]: ['appointments', 'admissions', 'billing_follow_up', 'maintenance_requests', 'housekeeping_tasks', 'staff_leaves'],
  [ROLE_PACKS.SUPER_ADMIN]: ['billing_follow_up', 'maintenance_requests', 'equipment_work_orders', 'staff_leaves'],
  [ROLE_PACKS.TENANT_ADMIN]: ['admissions', 'billing_follow_up', 'maintenance_requests', 'staff_leaves'],
  [ROLE_PACKS.FACILITY_ADMIN]: ['appointments', 'admissions', 'billing_follow_up', 'maintenance_requests', 'housekeeping_tasks', 'staff_leaves'],
  [ROLE_PACKS.DOCTOR]: ['appointments', 'admissions', 'lab_results', 'radiology_results'],
  [ROLE_PACKS.NURSE]: ['admissions', 'lab_results', 'radiology_results', 'appointments'],
  [ROLE_PACKS.LAB_TECH]: ['lab_results'],
  [ROLE_PACKS.RADIOLOGY_TECH]: ['radiology_results'],
  [ROLE_PACKS.PHARMACIST]: ['pharmacy_orders'],
  [ROLE_PACKS.RECEPTIONIST]: ['appointments', 'billing_follow_up'],
  [ROLE_PACKS.BILLING]: ['billing_follow_up'],
  [ROLE_PACKS.OPERATIONS]: ['admissions', 'maintenance_requests', 'housekeeping_tasks', 'billing_follow_up'],
  [ROLE_PACKS.HR]: ['staff_leaves'],
  [ROLE_PACKS.BIOMED]: ['equipment_work_orders'],
  [ROLE_PACKS.HOUSE_KEEPER]: ['housekeeping_tasks'],
  [ROLE_PACKS.AMBULANCE_OPERATOR]: ['emergency_cases'],
  [ROLE_PACKS.UNIT_MANAGER]: ['staff_leaves', 'admissions'],
  [ROLE_PACKS.WARD_MANAGER]: ['admissions', 'appointments', 'staff_leaves'],
  [ROLE_PACKS.ICU_MANAGER]: ['admissions', 'lab_results', 'staff_leaves'],
  [ROLE_PACKS.THEATRE_MANAGER]: ['admissions', 'staff_leaves'],
  [ROLE_PACKS.HOUSEKEEPING_MANAGER]: ['housekeeping_tasks', 'maintenance_requests'],
  [ROLE_PACKS.BIOMED_MANAGER]: ['equipment_work_orders'],
  [ROLE_PACKS.MORTUARY_STAFF]: ['mortuary_cases', 'mortuary_viewings', 'mortuary_post_mortems'],
  [ROLE_PACKS.MORTUARY_MANAGER]: ['mortuary_releases', 'mortuary_cases', 'mortuary_post_mortems'],
  [ROLE_PACKS.PATIENT_SAFE]: [],
  [ROLE_PACKS.LIMITED]: [],
});

const routeTarget = (moduleSlug, resource, publicId, action = 'view') => ({
  module_slug: moduleSlug,
  resource,
  public_id: publicId || null,
  action,
});

const getDateRange = (filters = {}) => {
  if (filters.from || filters.to) {
    return {
      from: filters.from || null,
      to: filters.to || null,
    };
  }

  const preset = normalizeString(filters.date_preset || filters.datePreset).toLowerCase();
  const now = new Date();
  if (preset === 'today') {
    return { from: startOfDay(now).toISOString(), to: null };
  }
  if (preset === 'last_30_days') {
    return { from: shiftDays(startOfDay(now), -29).toISOString(), to: null };
  }
  if (preset === 'last_90_days') {
    return { from: shiftDays(startOfDay(now), -89).toISOString(), to: null };
  }
  return { from: shiftDays(startOfDay(now), -6).toISOString(), to: null };
};

const buildHumanFriendlySearchWhere = (search) => {
  const normalizedSearch = normalizeString(search);
  if (!normalizedSearch) return null;

  const candidates = Array.from(
    new Set([normalizedSearch, safeUpper(normalizedSearch)].filter(Boolean))
  );

  return {
    OR: candidates.map((candidate) => ({
      human_friendly_id: {
        contains: candidate,
      },
    })),
  };
};

const applyHumanFriendlySearch = (where, search) => {
  const searchWhere = buildHumanFriendlySearchWhere(search);
  if (!searchWhere) return where;
  if (!where || Object.keys(where).length === 0) return searchWhere;
  return {
    AND: [where, searchWhere],
  };
};

const resolveQueueDefinitions = (packId, filters = {}) => {
  const queueIds = ROLE_QUEUE_IDS[packId] || [];
  const normalizedQueue = normalizeString(filters.queue).toLowerCase();
  const normalizedModule = normalizeString(filters.module).toLowerCase();

  return queueIds
    .map((id) => activeQueueDefinitions[id])
    .filter(Boolean)
    .filter((definition) => !normalizedQueue || definition.queue_key === normalizedQueue)
    .filter((definition) => !normalizedModule || definition.module_slug === normalizedModule);
};

const sortByTimestamp = (left, right) =>
  new Date(right.occurred_at || 0).getTime() - new Date(left.occurred_at || 0).getTime();

const normalizeSortDirection = (value) =>
  String(value || '').trim().toLowerCase() === 'asc' ? 'asc' : 'desc';

const normalizeComparableValue = (value) => {
  if (value == null) return '';
  if (typeof value === 'number') return value;

  const normalized = String(value).trim();
  if (!normalized) return '';

  const parsedDate = Date.parse(normalized);
  if (!Number.isNaN(parsedDate) && normalized.includes('-')) {
    return parsedDate;
  }

  return normalized.toLowerCase();
};

const compareSortValues = (left, right, order = 'desc') => {
  const safeOrder = normalizeSortDirection(order);
  const leftValue = normalizeComparableValue(left);
  const rightValue = normalizeComparableValue(right);

  let result = 0;
  if (typeof leftValue === 'number' && typeof rightValue === 'number') {
    result = leftValue - rightValue;
  } else {
    result = String(leftValue).localeCompare(String(rightValue));
  }

  if (result === 0) return 0;
  return safeOrder === 'asc' ? result : result * -1;
};

const sortItemsBy = (items = [], sortBy = 'occurred_at', order = 'desc', resolveValue) =>
  [...items].sort((left, right) => {
    const primary = compareSortValues(
      resolveValue(left, sortBy),
      resolveValue(right, sortBy),
      order
    );
    if (primary !== 0) return primary;

    const timestampFallback = compareSortValues(
      left.occurred_at,
      right.occurred_at,
      'desc'
    );
    if (timestampFallback !== 0) return timestampFallback;

    return compareSortValues(left.id, right.id, 'asc');
  });

const hasDashboardFilters = (filters = {}) =>
  [
    filters.tenant_id,
    filters.tenantId,
    filters.facility_id,
    filters.facilityId,
    filters.branch_id,
    filters.branchId,
    filters.queue,
    filters.search,
    filters.status,
    filters.module,
    filters.event_type,
    filters.eventType,
    filters.date_preset,
    filters.datePreset,
    filters.from,
    filters.to,
  ].some((value) => Boolean(normalizeString(value)));

const buildCollectionEmptyState = ({ target, filters = {} }) => ({
  reason: hasDashboardFilters(filters) ? 'no_matches' : 'guided_setup',
  target,
});

const resolveQueueSortValue = (item = {}, sortBy = 'occurred_at') => {
  switch (normalizeString(sortBy).toLowerCase()) {
    case 'item':
      return item.human_friendly_id;
    case 'queue':
      return item.queue;
    case 'module':
      return item.module_slug;
    case 'status':
      return item.status;
    case 'priority':
    case 'severity':
      return item.severity || item.priority;
    case 'updated_at':
    case 'occurred_at':
    default:
      return item.occurred_at;
  }
};

const resolveActivitySortValue = (item = {}, sortBy = 'occurred_at') => {
  switch (normalizeString(sortBy).toLowerCase()) {
    case 'event':
      return item.event_type;
    case 'item':
      return item.human_friendly_id;
    case 'module':
      return item.module_slug;
    case 'status':
      return item.status;
    case 'time':
    case 'updated_at':
    case 'occurred_at':
    default:
      return item.occurred_at;
  }
};

const buildQueueItem = (definition, row = {}) => {
  const publicId = dashboardWorkspaceRepository.safePublicId(row.human_friendly_id, row.id);
  if (!publicId) return null;

  return {
    id: `${definition.id}:${publicId}`,
    kind: definition.kind,
    queue: definition.queue_key,
    module_slug: definition.module_slug,
    human_friendly_id: publicId,
    status: normalizeString(row.status || row.billing_status).toUpperCase() || null,
    secondary_status: normalizeString(row.billing_status).toUpperCase() || null,
    priority: normalizeString(row.priority || row.severity).toUpperCase() || null,
    severity: definition.buildSeverity(row),
    occurred_at: row[definition.time_field] || row.updated_at || row.created_at || null,
    updated_at: row.updated_at || null,
    target: routeTarget(definition.module_slug, definition.resource, publicId),
    meta: {
      total_amount: row.total_amount != null ? Number(row.total_amount) : null,
      currency: row.currency || null,
    },
  };
};

const buildActivityItem = (definition, row = {}) => {
  const publicId = dashboardWorkspaceRepository.safePublicId(row.human_friendly_id, row.id);
  if (!publicId) return null;

  return {
    id: `${definition.activity_event_type}:${publicId}`,
    event_type: definition.activity_event_type,
    kind: definition.kind,
    module_slug: definition.module_slug,
    human_friendly_id: publicId,
    status: normalizeString(row.status || row.billing_status).toUpperCase() || null,
    occurred_at: row.updated_at || row[definition.time_field] || row.created_at || null,
    target: routeTarget(definition.module_slug, definition.resource, publicId),
  };
};

const paginate = (items = [], page = 1, limit = DEFAULT_LIMIT) => {
  const safePage = Math.max(1, Number(page || 1));
  const safeLimit = Math.max(1, Number(limit || DEFAULT_LIMIT));
  const start = (safePage - 1) * safeLimit;
  return {
    items: items.slice(start, start + safeLimit),
    pagination: buildPagination(safePage, safeLimit, items.length),
  };
};

const getQueueItems = async ({
  scope,
  packId,
  filters = {},
  page = 1,
  limit = DEFAULT_LIMIT,
  sortBy = 'occurred_at',
  order = 'desc',
}) => {
  const definitions = resolveQueueDefinitions(packId, filters);
  const range = getDateRange(filters);
  const fetchCount = Math.max(20, Number(limit || DEFAULT_LIMIT) * Number(page || 1));

  const rowsByDefinition = await Promise.all(
    definitions.map(async (definition) => {
      let where = definition.buildWhere(scope);
      where = applyHumanFriendlySearch(where, filters.search);
      Object.assign(where, buildDateWindowFilter({ from: range.from, to: range.to, field: definition.time_field }));
      if (filters.status) {
        where = {
          ...where,
          status: safeUpper(filters.status),
        };
      }

      const rows = await dashboardWorkspaceRepository.findRows({
        model: definition.model,
        where,
        select: definition.select,
        orderBy: { [definition.default_sort]: 'desc' },
        take: fetchCount,
      });

      return rows.map((row) => buildQueueItem(definition, row)).filter(Boolean);
    })
  );

  const combined = rowsByDefinition.flat().sort(sortByTimestamp);
  if (!combined.length) {
    return {
      items: [],
      pagination: buildPagination(1, Number(limit || DEFAULT_LIMIT), 0),
      empty_state: buildCollectionEmptyState({
        filters,
        target: routeTarget('dashboard', 'getting-started', null, 'open'),
      }),
    };
  }

  return {
    ...paginate(sortItemsBy(combined, sortBy, order, resolveQueueSortValue), page, limit),
    empty_state: null,
  };
};

const getActivityItems = async ({
  scope,
  packId,
  filters = {},
  page = 1,
  limit = DEFAULT_LIMIT,
  sortBy = 'occurred_at',
  order = 'desc',
}) => {
  const definitions = resolveQueueDefinitions(packId, filters);
  const range = getDateRange(filters);
  const fetchCount = Math.max(20, Number(limit || DEFAULT_LIMIT) * Number(page || 1));

  const rowsByDefinition = await Promise.all(
    definitions.map(async (definition) => {
      let where = definition.buildWhere(scope);
      where = applyHumanFriendlySearch(where, filters.search);
      Object.assign(where, buildDateWindowFilter({ from: range.from, to: range.to, field: 'updated_at' }));
      if (filters.status) {
        where = {
          ...where,
          status: safeUpper(filters.status),
        };
      }

      const rows = await dashboardWorkspaceRepository.findRows({
        model: definition.model,
        where,
        select: definition.select,
        orderBy: { updated_at: 'desc' },
        take: fetchCount,
      });

      return rows.map((row) => buildActivityItem(definition, row)).filter(Boolean);
    })
  );

  let combined = rowsByDefinition.flat().sort(sortByTimestamp);
  const normalizedEventType = normalizeString(
    filters.event_type || filters.eventType
  ).toLowerCase();
  if (normalizedEventType) {
    combined = combined.filter((item) => String(item.event_type || '').toLowerCase() === normalizedEventType);
  }

  if (!combined.length) {
    return {
      items: [],
      pagination: buildPagination(1, Number(limit || DEFAULT_LIMIT), 0),
      empty_state: buildCollectionEmptyState({
        filters,
        target: routeTarget('dashboard', 'getting-started', null, 'open'),
      }),
    };
  }

  return {
    ...paginate(sortItemsBy(combined, sortBy, order, resolveActivitySortValue), page, limit),
    empty_state: null,
  };
};

const buildMetric = ({ id, currentValue, previousValue = null, format = 'number', labelKey, state = 'live' }) => ({
  id,
  label_key: labelKey,
  format,
  state,
  current_value: currentValue,
  previous_value: previousValue,
  delta: previousValue == null ? null : toNumber(currentValue) - toNumber(previousValue),
});

const buildSnapshot = async (scope = {}) => {
  const now = new Date();
  const todayStart = startOfDay(now);
  const currentWeekStart = shiftDays(todayStart, -6);
  const previousWeekStart = shiftDays(currentWeekStart, -7);
  const previousWeekEnd = new Date(currentWeekStart.getTime() - 1);
  const trailingMonthStart = shiftDays(todayStart, -29);

  const patientWhere = directScope(scope, { includeTenant: true, includeFacility: true });
  const appointmentWhere = directScope(scope, { includeTenant: true, includeFacility: true });
  const admissionWhere = directScope(scope, { includeTenant: true, includeFacility: true });
  const invoiceWhere = directScope(scope, { includeTenant: true, includeFacility: true });
  const paymentWhere = directScope(scope, { includeTenant: true, includeFacility: true });
  const housekeepingWhere = buildHousekeepingWhere(scope);
  const maintenanceWhere = buildMaintenanceWhere(scope);
  const labResultWhere = buildLabResultScopeWhere(scope);
  const pharmacyOrderWhere = buildPharmacyOrderScopeWhere(scope);

  const [
    patientsTotal,
    appointmentsTotal,
    usersTotal,
    invoicesTotal,
    drugsTotal,
    labTestsTotal,
    admissionsTotal,
    registrationsCurrentWeek,
    registrationsPreviousWeek,
    revenueCurrentWeek,
    revenuePreviousWeek,
    trailingInvoices,
    trailingPaidInvoices,
    occupiedBeds,
    totalBeds,
    criticalLabs,
    overdueInvoices,
    pendingPharmacyOrders,
    openMaintenance,
    pendingHousekeeping,
    openWorkOrders,
    pendingLeaves,
  ] = await Promise.all([
    dashboardWorkspaceRepository.countRows({ model: 'patient', where: patientWhere }),
    dashboardWorkspaceRepository.countRows({ model: 'appointment', where: appointmentWhere }),
    dashboardWorkspaceRepository.countRows({
      model: 'user',
      where: {
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
    }),
    dashboardWorkspaceRepository.countRows({ model: 'invoice', where: invoiceWhere }),
    dashboardWorkspaceRepository.countRows({
      model: 'drug',
      where: {
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'lab_test',
      where: {
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
      },
    }),
    dashboardWorkspaceRepository.countRows({ model: 'admission', where: admissionWhere }),
    dashboardWorkspaceRepository.countRows({
      model: 'patient',
      where: {
        ...patientWhere,
        created_at: { gte: currentWeekStart },
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'patient',
      where: {
        ...patientWhere,
        created_at: { gte: previousWeekStart, lte: previousWeekEnd },
      },
    }),
    dashboardWorkspaceRepository.sumRows({
      model: 'payment',
      where: {
        ...paymentWhere,
        status: 'COMPLETED',
        paid_at: { gte: currentWeekStart },
      },
      field: 'amount',
    }),
    dashboardWorkspaceRepository.sumRows({
      model: 'payment',
      where: {
        ...paymentWhere,
        status: 'COMPLETED',
        paid_at: { gte: previousWeekStart, lte: previousWeekEnd },
      },
      field: 'amount',
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'invoice',
      where: {
        ...invoiceWhere,
        issued_at: { gte: trailingMonthStart },
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'invoice',
      where: {
        ...invoiceWhere,
        issued_at: { gte: trailingMonthStart },
        status: 'PAID',
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'bed',
      where: {
        ...directScope(scope, { includeTenant: true, includeFacility: true }),
        status: 'OCCUPIED',
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'bed',
      where: directScope(scope, { includeTenant: true, includeFacility: true }),
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'lab_result',
      where: {
        ...labResultWhere,
        status: 'CRITICAL',
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'invoice',
      where: {
        ...invoiceWhere,
        status: 'OVERDUE',
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'pharmacy_order',
      where: {
        ...pharmacyOrderWhere,
        status: { in: ['ORDERED', 'PARTIALLY_DISPENSED'] },
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'maintenance_request',
      where: {
        ...maintenanceWhere,
        status: { in: ['OPEN', 'IN_PROGRESS'] },
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'housekeeping_task',
      where: {
        ...housekeepingWhere,
        status: { in: ['PENDING', 'IN_PROGRESS'] },
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'equipment_work_order',
      where: {
        deleted_at: null,
        ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
        status: { in: ['OPEN', 'IN_PROGRESS', 'ACKNOWLEDGED'] },
      },
    }),
    dashboardWorkspaceRepository.countRows({
      model: 'staff_leave',
      where: {
        deleted_at: null,
        staff_profile: {
          deleted_at: null,
          ...(scope.tenant_id ? { tenant_id: scope.tenant_id } : {}),
        },
        status: 'REQUESTED',
      },
    }),
  ]);

  return {
    patients_total: patientsTotal,
    appointments_total: appointmentsTotal,
    users_total: usersTotal,
    invoices_total: invoicesTotal,
    drugs_total: drugsTotal,
    lab_tests_total: labTestsTotal,
    admissions_total: admissionsTotal,
    registrations_current_week: registrationsCurrentWeek,
    registrations_previous_week: registrationsPreviousWeek,
    revenue_current_week: revenueCurrentWeek,
    revenue_previous_week: revenuePreviousWeek,
    trailing_invoices: trailingInvoices,
    trailing_paid_invoices: trailingPaidInvoices,
    occupied_beds: occupiedBeds,
    total_beds: totalBeds,
    critical_labs: criticalLabs,
    overdue_invoices: overdueInvoices,
    pending_pharmacy_orders: pendingPharmacyOrders,
    open_maintenance: openMaintenance,
    pending_housekeeping: pendingHousekeeping,
    open_work_orders: openWorkOrders,
    pending_leaves: pendingLeaves,
  };
};

const buildPlanUsage = (subscription = null, canManageSubscriptions = false) => {
  if (!subscription?.plan) {
    return {
      state: 'unavailable',
      manage_action_allowed: false,
      target: routeTarget('subscriptions', 'subscription-plans', null, 'open'),
      metrics: [],
    };
  }

  const warningPercent = toNumber(subscription.plan?.plan_fit_warning_percent, 80);
  const metrics = [
    {
      id: 'users',
      used: toNumber(subscription.users_used),
      limit: toNumber(subscription.plan?.max_users),
      percent: percentOf(subscription.users_used, subscription.plan?.max_users),
    },
    {
      id: 'facilities',
      used: toNumber(subscription.facilities_used),
      limit: toNumber(subscription.plan?.max_facilities),
      percent: percentOf(subscription.facilities_used, subscription.plan?.max_facilities),
    },
    {
      id: 'storage_mb',
      used: toNumber(subscription.storage_used_mb),
      limit: toNumber(subscription.plan?.max_storage_mb),
      percent: percentOf(subscription.storage_used_mb, subscription.plan?.max_storage_mb),
    },
    {
      id: 'modules',
      used: toNumber(subscription.modules_used || subscription.module_subscriptions?.length || 0),
      limit: toNumber(subscription.plan?.max_modules),
      percent: percentOf(subscription.modules_used || subscription.module_subscriptions?.length || 0, subscription.plan?.max_modules),
    },
  ];

  return {
    state: 'active',
    manage_action_allowed: canManageSubscriptions,
    subscription_id: dashboardWorkspaceRepository.safePublicId(subscription.human_friendly_id, subscription.id),
    plan: {
      id: dashboardWorkspaceRepository.safePublicId(subscription.plan?.human_friendly_id, subscription.plan?.id),
      name: subscription.plan?.name || null,
      tier_code: subscription.plan?.tier_code || null,
      billing_cycle: subscription.plan?.billing_cycle || null,
    },
    status: subscription.status || null,
    change_status: subscription.change_status || null,
    fit_status: subscription.plan_fit_status || null,
    warning_percent: warningPercent,
    target: routeTarget('subscriptions', 'subscriptions', dashboardWorkspaceRepository.safePublicId(subscription.human_friendly_id, subscription.id), 'view'),
    metrics,
  };
};

const ALERT_MODULES_BY_PACK = Object.freeze({
  [ROLE_PACKS.SUPER_ADMIN]: ['subscriptions', 'billing', 'operations', 'biomedical'],
  [ROLE_PACKS.TENANT_ADMIN]: ['subscriptions', 'billing', 'operations', 'hr'],
  [ROLE_PACKS.FACILITY_ADMIN]: ['billing', 'lab', 'ipd', 'operations', 'subscriptions'],
  [ROLE_PACKS.DOCTOR]: ['lab', 'ipd'],
  [ROLE_PACKS.NURSE]: ['lab', 'ipd'],
  [ROLE_PACKS.LAB_TECH]: ['lab'],
  [ROLE_PACKS.RADIOLOGY_TECH]: ['radiology'],
  [ROLE_PACKS.PHARMACIST]: ['pharmacy'],
  [ROLE_PACKS.RECEPTIONIST]: ['scheduling'],
  [ROLE_PACKS.BILLING]: ['billing'],
  [ROLE_PACKS.OPERATIONS]: ['operations', 'ipd'],
  [ROLE_PACKS.HR]: ['hr'],
  [ROLE_PACKS.BIOMED]: ['biomedical'],
  [ROLE_PACKS.HOUSE_KEEPER]: ['housekeeping'],
  [ROLE_PACKS.AMBULANCE_OPERATOR]: ['emergency'],
  [ROLE_PACKS.UNIT_MANAGER]: ['hr'],
  [ROLE_PACKS.WARD_MANAGER]: ['ipd', 'nursing'],
  [ROLE_PACKS.ICU_MANAGER]: ['icu', 'lab', 'ipd'],
  [ROLE_PACKS.THEATRE_MANAGER]: ['theatre'],
  [ROLE_PACKS.HOUSEKEEPING_MANAGER]: ['housekeeping', 'operations'],
  [ROLE_PACKS.BIOMED_MANAGER]: ['biomedical'],
  [ROLE_PACKS.MORTUARY_STAFF]: ['mortuary'],
  [ROLE_PACKS.MORTUARY_MANAGER]: ['mortuary'],
});

const packAllowsAlertModule = (packId, moduleSlug) => {
  const modules = ALERT_MODULES_BY_PACK[packId] || [];
  return modules.includes(moduleSlug);
};

const buildInsights = ({ snapshot, subscription, facilityContext, canManageSubscriptions, packId }) => {
  const signals = [];
  const occupancyPercent = percentOf(snapshot.occupied_beds, snapshot.total_beds);

  if (snapshot.overdue_invoices > 0 && packAllowsAlertModule(packId, 'billing')) {
    signals.push({
      id: 'overdue_invoices',
      kind: 'overdue_invoices',
      module_slug: 'billing',
      severity: 'critical',
      count: snapshot.overdue_invoices,
      target: routeTarget('billing', 'invoices', null, 'list'),
    });
  }
  if (snapshot.critical_labs > 0 && packAllowsAlertModule(packId, 'lab')) {
    signals.push({
      id: 'critical_labs',
      kind: 'critical_labs',
      module_slug: 'lab',
      severity: 'critical',
      count: snapshot.critical_labs,
      target: routeTarget('lab', 'results', null, 'list'),
    });
  }
  if (occupancyPercent >= 85 && packAllowsAlertModule(packId, 'ipd')) {
    signals.push({
      id: 'bed_occupancy',
      kind: 'bed_occupancy_pressure',
      module_slug: 'ipd',
      severity: occupancyPercent >= 95 ? 'critical' : 'high',
      count: occupancyPercent,
      target: routeTarget('ipd', 'admissions', null, 'list'),
    });
  }

  const planUsage = buildPlanUsage(subscription, canManageSubscriptions);
  const approachingLimits = (planUsage.metrics || []).filter(
    (metric) => metric.limit > 0 && metric.percent >= planUsage.warning_percent
  );
  if (approachingLimits.length && canManageSubscriptions) {
    signals.push({
      id: 'plan_limits',
      kind: 'plan_limit_pressure',
      module_slug: 'subscriptions',
      severity: 'high',
      count: approachingLimits.length,
      target: planUsage.target,
    });
  }

  if (!signals.length) {
    signals.push({
      id: GUIDE_SIGNAL_ID,
      kind: 'guide_signal',
      module_slug: 'dashboard',
      severity: 'info',
      count: 0,
      target: routeTarget('dashboard', 'getting-started', null, 'open'),
      meta: { placeholder: true },
    });
  }

  const activeModuleSlugs = new Set(
    (subscription?.module_subscriptions || [])
      .filter((entry) => entry?.is_active)
      .map((entry) => normalizeString(entry?.module?.slug).toLowerCase())
      .filter(Boolean)
  );
  const facilityType = normalizeString(facilityContext?.facility_type).toLowerCase();
  const recommendationCandidates =
    facilityType === 'hospital'
      ? ['biomedical', 'housekeeping', 'subscriptions']
      : ['pharmacy', 'lab', 'subscriptions'];

  const recommendations = canManageSubscriptions
    ? recommendationCandidates
        .filter((slug) => !activeModuleSlugs.has(slug))
        .slice(0, 3)
        .map((slug) => ({
          id: `module:${slug}`,
          module_slug: slug,
          state: 'actionable',
          target: routeTarget('subscriptions', 'modules', null, 'discover'),
        }))
    : [];

  const helpCards = [
    {
      id: 'paperless_playbook',
      kind: 'paperless_playbook',
      target: routeTarget('dashboard', 'getting-started', null, 'open'),
    },
    {
      id: 'operations_queue',
      kind: 'operations_queue',
      target: routeTarget('dashboard', 'queue', null, 'open'),
    },
  ];

  return {
    signals,
    module_recommendations: recommendations,
    plan_usage: planUsage,
    help_cards: helpCards,
  };
};

const buildChecklist = ({ snapshot, facilityContext, packId }) => {
  const isHospital = normalizeString(facilityContext?.facility_type).toLowerCase() === 'hospital';
  const items = [
    {
      id: 'patients',
      kind: 'patients',
      completed: snapshot.patients_total > 0,
      target: routeTarget('patients', 'patients', null, 'create'),
    },
    {
      id: 'appointments',
      kind: 'appointments',
      completed: snapshot.appointments_total > 0,
      target: routeTarget('scheduling', 'appointments', null, 'create'),
    },
    {
      id: 'staff',
      kind: 'staff',
      completed: snapshot.users_total > 0,
      target: routeTarget('hr', 'staff-profiles', null, 'create'),
    },
    {
      id: 'billing',
      kind: 'billing',
      completed: snapshot.invoices_total > 0,
      target: routeTarget('billing', 'invoices', null, 'create'),
    },
    {
      id: 'catalog',
      kind: 'catalog',
      completed: snapshot.drugs_total + snapshot.lab_tests_total > 0,
      target: routeTarget('pharmacy', 'drugs', null, 'create'),
    },
  ];

  if (
    isHospital ||
    [
      ROLE_PACKS.DOCTOR,
      ROLE_PACKS.NURSE,
      ROLE_PACKS.ADMIN,
      ROLE_PACKS.SUPER_ADMIN,
      ROLE_PACKS.TENANT_ADMIN,
      ROLE_PACKS.FACILITY_ADMIN,
    ].includes(packId)
  ) {
    items.push({
      id: 'admissions',
      kind: 'admissions',
      completed: snapshot.admissions_total > 0,
      target: routeTarget('ipd', 'admissions', null, 'start_admission'),
    });
  }

  return {
    completed_count: items.filter((item) => item.completed).length,
    total_count: items.length,
    items,
  };
};

const buildValueProof = (snapshot = {}) => {
  const collectionRate = snapshot.trailing_invoices
    ? Math.round((snapshot.trailing_paid_invoices / snapshot.trailing_invoices) * 100)
    : 0;

  return [
    buildMetric({
      id: 'weekly_revenue',
      currentValue: snapshot.revenue_current_week,
      previousValue: snapshot.revenue_previous_week,
      format: 'currency',
      labelKey: 'dashboard.valueProof.metrics.weeklyRevenue',
    }),
    buildMetric({
      id: 'weekly_registrations',
      currentValue: snapshot.registrations_current_week,
      previousValue: snapshot.registrations_previous_week,
      format: 'number',
      labelKey: 'dashboard.valueProof.metrics.weeklyRegistrations',
    }),
    buildMetric({
      id: 'collection_rate',
      currentValue: collectionRate,
      previousValue: null,
      format: 'percent',
      labelKey: 'dashboard.valueProof.metrics.collectionRate',
    }),
    buildMetric({
      id: 'bed_occupancy',
      currentValue: percentOf(snapshot.occupied_beds, snapshot.total_beds),
      previousValue: null,
      format: 'percent',
      labelKey: 'dashboard.valueProof.metrics.bedOccupancy',
      state: snapshot.total_beds > 0 ? 'live' : 'guide',
    }),
  ];
};

const buildPanelSummaries = ({ queueItems, activityItems, insights, checklist }) => [
  { id: 'overview', count: checklist.total_count },
  { id: 'queue', count: queueItems.pagination?.total || queueItems.items.length },
  { id: 'activity', count: activityItems.pagination?.total || activityItems.items.length },
  { id: 'insights', count: (insights.signals || []).length + (insights.module_recommendations || []).length },
  { id: 'getting-started', count: checklist.total_count - checklist.completed_count },
];

const buildStatusStrip = (dashboardSummary = {}) =>
  (dashboardSummary.summaryCards || []).map((item) => ({
    id: item.id,
    label: item.label,
    value: item.value,
    format: item.format || 'number',
    required_permissions: item.required_permissions || [],
    required_modules: item.required_modules || [],
    allowed_roles: item.allowed_roles || [],
    scope: item.scope || null,
    route_target: item.route_target || null,
  }));

const getWorkspace = async (
  filters = {},
  page = 1,
  limit = DEFAULT_LIMIT,
  sortBy = 'occurred_at',
  order = 'desc',
  user = {}
) => {
  const effectiveRole = resolveEffectiveRole(user);
  const scopeResult = await dashboardWorkspaceRepository.resolveWorkspaceScope({
    filters,
    user,
    effectiveRole,
  });
  const effectiveProfileId = resolveProfileId(effectiveRole);
  const effectivePackId = resolvePackId(effectiveProfileId);
  const tenantContextQuickActions = resolveQuickActions(user, 8);

  if (scopeResult.state === 'tenant_context_required') {
    const lookups = await dashboardWorkspaceRepository.findLookups({ scope: null, includeTenants: true });
    return {
      state: 'tenant_context_required',
      generated_at: new Date().toISOString(),
      role_profile: {
        id: effectiveProfileId,
        role: effectiveRole,
        pack: effectivePackId,
      },
      context: {
        role: {
          id: effectiveProfileId,
          role: effectiveRole,
          pack: effectivePackId,
        },
      },
      panel_summaries: [],
      status_strip: [],
      quick_actions: tenantContextQuickActions.quickActions,
      quick_action_ids: tenantContextQuickActions.quickActions.map((action) => action.id),
      hidden_reason_map: tenantContextQuickActions.hiddenReasonMap,
      overview: {
        checklist: { completed_count: 0, total_count: 0, items: [] },
        alerts: [],
        queue_preview: [],
        value_proof: [],
        insights_preview: [],
        module_recommendations: [],
        plan_usage: { state: 'unavailable', metrics: [] },
        activity_preview: [],
        help_cards: [],
      },
      queue: { items: [], pagination: buildPagination(1, Number(limit || DEFAULT_LIMIT), 0) },
      activity: { items: [], pagination: buildPagination(1, Number(limit || DEFAULT_LIMIT), 0) },
      insights: { signals: [], module_recommendations: [], plan_usage: { state: 'unavailable', metrics: [] }, help_cards: [] },
      getting_started: { completed_count: 0, total_count: 0, items: [] },
      tenant_options: (lookups.tenants || []).map((entry) => ({
        id: dashboardWorkspaceRepository.safePublicId(entry.human_friendly_id, entry.id),
        label: entry.name,
      })),
    };
  }

  const scope = scopeResult.scope;
  const baseSummary = await buildDashboardSummary({
    query: { ...scope, days: 7 },
    user,
    repository: dashboardWidgetRepository,
  });
  const packId = baseSummary.roleProfile?.pack || ROLE_PACKS.ADMIN;
  const canManageSubscriptions = ADMIN_ROLES.has(effectiveRole);
  const quickActionResolution = resolveQuickActions(user, 8);

  const [facilityContext, subscription, queueItems, activityItems, snapshot] = await Promise.all([
    dashboardWorkspaceRepository.findFacilityContext(scope),
    dashboardWorkspaceRepository.findCurrentSubscription(scope),
    getQueueItems({ scope, packId, filters, page, limit, sortBy, order }),
    getActivityItems({ scope, packId, filters, page, limit, sortBy, order }),
    buildSnapshot(scope),
  ]);

  const checklist = buildChecklist({ snapshot, facilityContext, packId });
  const insights = buildInsights({
    snapshot,
    subscription,
    facilityContext,
    canManageSubscriptions,
    packId,
  });
  const valueProof = buildValueProof(snapshot);
  const panelSummaries = buildPanelSummaries({ queueItems, activityItems, insights, checklist });

  const alerts = insights.signals.slice(0, 3).map((entry) => ({
    id: entry.id,
    kind: entry.kind,
    severity: entry.severity,
    count: entry.count,
    target: entry.target,
  }));

  return {
    state: 'ready',
    generated_at: new Date().toISOString(),
    role_profile: baseSummary.roleProfile,
    context: {
      role: baseSummary.roleProfile,
      tenant_id: dashboardWorkspaceRepository.safePublicId(scope.tenant_id),
      facility_id: dashboardWorkspaceRepository.safePublicId(facilityContext?.human_friendly_id, scope.facility_id),
      facility_name: facilityContext?.name || null,
      facility_type: facilityContext?.facility_type || null,
      branch_id: dashboardWorkspaceRepository.safePublicId(scope.branch_id),
    },
    panel_summaries: panelSummaries,
    status_strip: buildStatusStrip(baseSummary),
    summary_cards: buildStatusStrip(baseSummary),
    quick_actions: quickActionResolution.quickActions,
    quick_action_ids: quickActionResolution.quickActions.map((action) => action.id),
    hidden_reason_map: quickActionResolution.hiddenReasonMap,
    overview: {
      hero: {
        role_profile_id: baseSummary.roleProfile?.id || 'operations',
        role: baseSummary.roleProfile?.role || effectiveRole,
        facility_name: facilityContext?.name || null,
        facility_type: facilityContext?.facility_type || null,
      },
      checklist,
      alerts,
      queue_preview: (queueItems.items || []).slice(0, 5),
      value_proof: valueProof,
      insights_preview: (insights.signals || []).slice(0, 4),
      module_recommendations: (insights.module_recommendations || []).slice(0, 3),
      plan_usage: insights.plan_usage,
      activity_preview: (activityItems.items || []).slice(0, 6),
      help_cards: insights.help_cards,
    },
    queue: queueItems,
    activity: activityItems,
    insights,
    getting_started: checklist,
  };
};

const getLookups = async (filters = {}, user = {}) => {
  const effectiveRole = resolveEffectiveRole(user);
  const scopeResult = await dashboardWorkspaceRepository.resolveWorkspaceScope({
    filters,
    user,
    effectiveRole,
  });
  const scope = scopeResult.scope;

  const lookups = await dashboardWorkspaceRepository.findLookups({
    scope,
    includeTenants: effectiveRole === ROLES.SUPER_ADMIN,
  });

  return {
    state: scopeResult.state,
    tenants: (lookups.tenants || []).map((entry) => ({
      id: dashboardWorkspaceRepository.safePublicId(entry.human_friendly_id, entry.id),
      label: entry.name,
    })),
    facilities: (lookups.facilities || []).map((entry) => ({
      id: dashboardWorkspaceRepository.safePublicId(entry.human_friendly_id, entry.id),
      label: entry.name,
      meta: {
        facility_type: entry.facility_type || null,
      },
    })),
    branches: (lookups.branches || []).map((entry) => ({
      id: dashboardWorkspaceRepository.safePublicId(entry.human_friendly_id, entry.id),
      label: entry.name,
      meta: {
        facility_id: dashboardWorkspaceRepository.safePublicId(entry.facility_id),
      },
    })),
    queue_types: QUEUE_LOOKUPS,
    queue_statuses: QUEUE_STATUS_LOOKUPS,
    activity_event_types: EVENT_TYPE_LOOKUPS,
    activity_statuses: ACTIVITY_STATUS_LOOKUPS,
    module_filters: MODULE_LOOKUPS,
    date_presets: DATE_PRESET_LOOKUPS,
  };
};

module.exports = {
  getLookups,
  getWorkspace,
};
