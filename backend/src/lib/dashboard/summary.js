const { HttpError } = require('@lib/errors');
const { ROLES, ROLE_HIERARCHY, normalizeRoleName } = require('@config/roles');

const ROLE_PACKS = Object.freeze({
  ADMIN: 'admin',
  SUPER_ADMIN: 'super_admin',
  TENANT_ADMIN: 'tenant_admin',
  FACILITY_ADMIN: 'facility_admin',
  DOCTOR: 'doctor',
  NURSE: 'nurse',
  LAB_TECH: 'lab_tech',
  RADIOLOGY_TECH: 'radiology_tech',
  PHARMACIST: 'pharmacist',
  RECEPTIONIST: 'receptionist',
  BILLING: 'billing',
  OPERATIONS: 'operations',
  HR: 'hr',
  BIOMED: 'biomed',
  HOUSE_KEEPER: 'house_keeper',
  AMBULANCE_OPERATOR: 'ambulance_operator',
  UNIT_MANAGER: 'unit_manager',
  WARD_MANAGER: 'ward_manager',
  ICU_MANAGER: 'icu_manager',
  THEATRE_MANAGER: 'theatre_manager',
  HOUSEKEEPING_MANAGER: 'housekeeping_manager',
  BIOMED_MANAGER: 'biomed_manager',
  MORTUARY_STAFF: 'mortuary_staff',
  MORTUARY_MANAGER: 'mortuary_manager',
  PATIENT_SAFE: 'patient_safe',
  LIMITED: 'limited',
});

const ROLE_PROFILE_IDS = Object.freeze({
  [ROLES.SUPER_ADMIN]: 'super_admin',
  [ROLES.TENANT_ADMIN]: 'tenant_admin',
  [ROLES.FACILITY_ADMIN]: 'facility_admin',
  [ROLES.DOCTOR]: 'doctor',
  [ROLES.NURSE]: 'nurse',
  [ROLES.LAB_TECH]: 'lab_tech',
  [ROLES.RADIOLOGY_TECH]: 'radiology_tech',
  [ROLES.PHARMACIST]: 'pharmacist',
  [ROLES.RECEPTIONIST]: 'receptionist',
  [ROLES.BILLING]: 'billing',
  [ROLES.OPERATIONS]: 'operations',
  [ROLES.HR]: 'hr',
  [ROLES.BIOMED]: 'biomed',
  [ROLES.HOUSE_KEEPER]: 'house_keeper',
  [ROLES.AMBULANCE_OPERATOR]: 'ambulance_operator',
  [ROLES.UNIT_MANAGER]: 'unit_manager',
  [ROLES.WARD_MANAGER]: 'ward_manager',
  [ROLES.ICU_MANAGER]: 'icu_manager',
  [ROLES.THEATRE_MANAGER]: 'theatre_manager',
  [ROLES.HOUSEKEEPING_MANAGER]: 'housekeeping_manager',
  [ROLES.BIOMED_MANAGER]: 'biomed_manager',
  [ROLES.MORTUARY_STAFF]: 'mortuary_staff',
  [ROLES.MORTUARY_MANAGER]: 'mortuary_manager',
  [ROLES.PATIENT]: 'patient',
  [ROLES.OTHER]: 'other',
});

const PROFILE_TO_PACK = Object.freeze({
  super_admin: ROLE_PACKS.SUPER_ADMIN,
  tenant_admin: ROLE_PACKS.TENANT_ADMIN,
  facility_admin: ROLE_PACKS.FACILITY_ADMIN,
  doctor: ROLE_PACKS.DOCTOR,
  nurse: ROLE_PACKS.NURSE,
  lab_tech: ROLE_PACKS.LAB_TECH,
  radiology_tech: ROLE_PACKS.RADIOLOGY_TECH,
  pharmacist: ROLE_PACKS.PHARMACIST,
  receptionist: ROLE_PACKS.RECEPTIONIST,
  billing: ROLE_PACKS.BILLING,
  operations: ROLE_PACKS.OPERATIONS,
  hr: ROLE_PACKS.HR,
  biomed: ROLE_PACKS.BIOMED,
  house_keeper: ROLE_PACKS.HOUSE_KEEPER,
  ambulance_operator: ROLE_PACKS.AMBULANCE_OPERATOR,
  unit_manager: ROLE_PACKS.UNIT_MANAGER,
  ward_manager: ROLE_PACKS.WARD_MANAGER,
  icu_manager: ROLE_PACKS.ICU_MANAGER,
  theatre_manager: ROLE_PACKS.THEATRE_MANAGER,
  housekeeping_manager: ROLE_PACKS.HOUSEKEEPING_MANAGER,
  biomed_manager: ROLE_PACKS.BIOMED_MANAGER,
  mortuary_staff: ROLE_PACKS.MORTUARY_STAFF,
  mortuary_manager: ROLE_PACKS.MORTUARY_MANAGER,
  patient: ROLE_PACKS.PATIENT_SAFE,
  other: ROLE_PACKS.LIMITED,
});

const DASHBOARD_ALLOWLIST = Object.freeze({
  summaryCards: [
    'id',
    'label',
    'value',
    'format',
    'required_permissions',
    'required_modules',
    'allowed_roles',
    'scope',
    'route_target',
  ],
  trendPoints: ['id', 'date', 'value'],
  distributionSegments: ['id', 'label', 'value', 'color'],
  highlights: ['id', 'label', 'value', 'context', 'variant'],
  queue: ['id', 'title', 'meta', 'statusLabel', 'statusVariant'],
  alerts: ['id', 'title', 'meta', 'severityLabel', 'severityVariant'],
  activity: ['id', 'title', 'meta', 'timeLabel'],
});

const pickFields = (value, allowedFields = []) => {
  const source = value && typeof value === 'object' ? value : {};
  return allowedFields.reduce((accumulator, field) => {
    if (source[field] !== undefined) accumulator[field] = source[field];
    return accumulator;
  }, {});
};

const sanitizeSummaryPayload = (value = {}) => ({
  summaryCards: (Array.isArray(value.summaryCards) ? value.summaryCards : []).map((item) =>
    pickFields(item, DASHBOARD_ALLOWLIST.summaryCards)
  ),
  trend: {
    title: value?.trend?.title || '',
    subtitle: value?.trend?.subtitle || '',
    points: (Array.isArray(value?.trend?.points) ? value.trend.points : []).map((item) =>
      pickFields(item, DASHBOARD_ALLOWLIST.trendPoints)
    ),
  },
  distribution: {
    title: value?.distribution?.title || '',
    subtitle: value?.distribution?.subtitle || '',
    total: Number(value?.distribution?.total || 0),
    segments: (Array.isArray(value?.distribution?.segments) ? value.distribution.segments : []).map((item) =>
      pickFields(item, DASHBOARD_ALLOWLIST.distributionSegments)
    ),
  },
  highlights: (Array.isArray(value.highlights) ? value.highlights : []).map((item) =>
    pickFields(item, DASHBOARD_ALLOWLIST.highlights)
  ),
  queue: (Array.isArray(value.queue) ? value.queue : []).map((item) =>
    pickFields(item, DASHBOARD_ALLOWLIST.queue)
  ),
  alerts: (Array.isArray(value.alerts) ? value.alerts : []).map((item) =>
    pickFields(item, DASHBOARD_ALLOWLIST.alerts)
  ),
  activity: (Array.isArray(value.activity) ? value.activity : []).map((item) =>
    pickFields(item, DASHBOARD_ALLOWLIST.activity)
  ),
});

const extractRole = (value) => {
  if (!value) return null;
  if (typeof value === 'string') return normalizeRoleName(value);
  if (typeof value === 'object') {
    return (
      normalizeRoleName(value.name) ||
      normalizeRoleName(value.role_name) ||
      normalizeRoleName(value.roleName) ||
      normalizeRoleName(value.role?.name)
    );
  }
  return null;
};

const resolveEffectiveRole = (user = {}) => {
  const roleCandidates = [];
  const roleSource = Array.isArray(user.roles) ? user.roles : [];

  for (const roleValue of roleSource) {
    const normalized = extractRole(roleValue);
    if (normalized) roleCandidates.push(normalized);
  }

  const directRole = extractRole(user.role || user.role_name);
  if (directRole) roleCandidates.push(directRole);

  const unique = Array.from(new Set(roleCandidates));
  if (!unique.length) return ROLES.OTHER;

  return unique.reduce((winner, roleName) => {
    if (!winner) return roleName;
    const winnerRank = ROLE_HIERARCHY[winner] || 0;
    const challengerRank = ROLE_HIERARCHY[roleName] || 0;
    return challengerRank > winnerRank ? roleName : winner;
  }, null);
};

const resolveProfileId = (effectiveRole) => ROLE_PROFILE_IDS[effectiveRole] || 'other';
const resolvePackId = (profileId) => PROFILE_TO_PACK[profileId] || ROLE_PACKS.OPERATIONS;

const resolveScope = async (query = {}, user = {}, effectiveRole = null, repository = null) => {
  const userScope = {
    tenant_id: user.tenant_id || user.tenantId || null,
    facility_id: user.facility_id || user.facilityId || null,
    branch_id: user.branch_id || user.branchId || null,
  };

  if (effectiveRole === ROLES.SUPER_ADMIN) {
    const tenantId = query.tenant_id || userScope.tenant_id || null;
    const facilityId = query.facility_id || userScope.facility_id || null;
    const branchId = query.branch_id || userScope.branch_id || null;

    if (!tenantId) {
      throw new HttpError('errors.validation.field.required', 422, [{ field: 'tenant_id' }]);
    }

    let resolvedFacilityId = facilityId;
    if (branchId && repository?.resolveBranchFacilityScope) {
      const branchFacilityId = await repository.resolveBranchFacilityScope(tenantId, branchId);
      if (resolvedFacilityId && branchFacilityId && resolvedFacilityId !== branchFacilityId) {
        throw new HttpError('errors.validation.invalid', 422, [{ field: 'branch_id' }]);
      }
      if (!resolvedFacilityId) resolvedFacilityId = branchFacilityId;
    }

    return {
      tenant_id: tenantId,
      facility_id: resolvedFacilityId || null,
      branch_id: branchId || null,
    };
  }

  if (!userScope.tenant_id) {
    throw new HttpError('errors.auth.scope_mismatch', 403);
  }

  return userScope;
};

const buildTrendPoints = (dateValues = [], days = 7) => {
  const end = new Date();
  end.setHours(0, 0, 0, 0);
  const dates = Array.from({ length: days }).map((_, index) => {
    const day = new Date(end);
    day.setDate(end.getDate() - (days - 1 - index));
    return day;
  });
  const indexMap = new Map(dates.map((day) => [day.toISOString().slice(0, 10), 0]));

  for (const item of dateValues) {
    const parsed = new Date(item);
    if (Number.isNaN(parsed.getTime())) continue;
    const key = parsed.toISOString().slice(0, 10);
    if (!indexMap.has(key)) continue;
    indexMap.set(key, (indexMap.get(key) || 0) + 1);
  }

  return dates.map((day) => {
    const key = day.toISOString().slice(0, 10);
    return {
      id: key,
      date: key,
      value: indexMap.get(key) || 0,
    };
  });
};

const buildDistribution = (statusCounts = {}) => {
  const colors = ['#2563eb', '#0ea5e9', '#14b8a6', '#f59e0b', '#ef4444', '#8b5cf6'];
  const entries = Object.entries(statusCounts || {}).filter(([, value]) => Number(value || 0) > 0);
  const segments = entries.map(([status, value], index) => ({
    id: String(status).toLowerCase(),
    label: String(status).replace(/_/g, ' '),
    value: Number(value || 0),
    color: colors[index % colors.length],
  }));
  return {
    total: segments.reduce((sum, item) => sum + Number(item.value || 0), 0),
    segments,
  };
};

const average = (values = []) => {
  const series = Array.isArray(values) ? values.map((value) => Number(value || 0)).filter(Number.isFinite) : [];
  if (!series.length) return 0;
  const total = series.reduce((sum, value) => sum + value, 0);
  return Math.round(total / series.length);
};

const queueItem = (id, title, count, statusLabel, statusVariant, noun) => ({
  id,
  title,
  meta: `${Number(count || 0)} ${noun}`,
  statusLabel,
  statusVariant,
});

const alertItem = (id, title, count, severityLabel, severityVariant, noun) => ({
  id,
  title,
  meta: `${Number(count || 0)} ${noun}`,
  severityLabel,
  severityVariant,
});

const activityItem = (id, title, count) => ({
  id,
  title,
  meta: `${Number(count || 0)} updates`,
  timeLabel: 'last 24h',
});

const SUMMARY_METADATA_BY_PACK = Object.freeze({
  [ROLE_PACKS.SUPER_ADMIN]: {
    allowed_roles: [ROLES.SUPER_ADMIN],
    required_permissions: ['system:admin'],
    required_modules: [],
    scope: 'platform',
  },
  [ROLE_PACKS.TENANT_ADMIN]: {
    allowed_roles: [ROLES.TENANT_ADMIN],
    required_permissions: ['tenant:admin', 'reports:read'],
    required_modules: [],
    scope: 'tenant',
  },
  [ROLE_PACKS.FACILITY_ADMIN]: {
    allowed_roles: [ROLES.FACILITY_ADMIN],
    required_permissions: ['facility:admin', 'reports:read'],
    required_modules: [],
    scope: 'facility',
  },
  [ROLE_PACKS.DOCTOR]: {
    allowed_roles: [ROLES.DOCTOR],
    required_permissions: ['clinical:read'],
    required_modules: ['clinical'],
    scope: 'assigned_clinical',
  },
  [ROLE_PACKS.NURSE]: {
    allowed_roles: [ROLES.NURSE],
    required_permissions: ['clinical:read'],
    required_modules: ['clinical', 'nursing'],
    scope: 'assigned_nursing',
  },
  [ROLE_PACKS.LAB_TECH]: {
    allowed_roles: [ROLES.LAB_TECH],
    required_permissions: ['lab:read'],
    required_modules: ['lab'],
    scope: 'department',
  },
  [ROLE_PACKS.RADIOLOGY_TECH]: {
    allowed_roles: [ROLES.RADIOLOGY_TECH],
    required_permissions: ['radiology:read'],
    required_modules: ['radiology'],
    scope: 'department',
  },
  [ROLE_PACKS.PHARMACIST]: {
    allowed_roles: [ROLES.PHARMACIST],
    required_permissions: ['pharmacy:read'],
    required_modules: ['pharmacy'],
    scope: 'department',
  },
  [ROLE_PACKS.RECEPTIONIST]: {
    allowed_roles: [ROLES.RECEPTIONIST],
    required_permissions: ['patient:read'],
    required_modules: ['patients', 'scheduling'],
    scope: 'front_desk',
  },
  [ROLE_PACKS.BILLING]: {
    allowed_roles: [ROLES.BILLING],
    required_permissions: ['billing:read'],
    required_modules: ['billing'],
    scope: 'department',
  },
  [ROLE_PACKS.OPERATIONS]: {
    allowed_roles: [ROLES.OPERATIONS],
    required_permissions: ['operations:read'],
    required_modules: ['operations'],
    scope: 'department',
  },
  [ROLE_PACKS.HR]: {
    allowed_roles: [ROLES.HR],
    required_permissions: ['hr:read'],
    required_modules: ['hr'],
    scope: 'department',
  },
  [ROLE_PACKS.BIOMED]: {
    allowed_roles: [ROLES.BIOMED],
    required_permissions: ['biomed:read'],
    required_modules: ['biomedical'],
    scope: 'department',
  },
  [ROLE_PACKS.HOUSE_KEEPER]: {
    allowed_roles: [ROLES.HOUSE_KEEPER],
    required_permissions: ['operations:read'],
    required_modules: ['housekeeping'],
    scope: 'assigned_tasks',
  },
  [ROLE_PACKS.AMBULANCE_OPERATOR]: {
    allowed_roles: [ROLES.AMBULANCE_OPERATOR],
    required_permissions: ['emergency:read'],
    required_modules: ['emergency'],
    scope: 'department',
  },
  [ROLE_PACKS.UNIT_MANAGER]: {
    allowed_roles: [ROLES.UNIT_MANAGER],
    required_permissions: ['unit:read', 'hr:read'],
    required_modules: ['hr'],
    scope: 'assigned_unit',
  },
  [ROLE_PACKS.WARD_MANAGER]: {
    allowed_roles: [ROLES.WARD_MANAGER],
    required_permissions: ['unit:read', 'clinical:read'],
    required_modules: ['ipd', 'nursing'],
    scope: 'assigned_ward',
  },
  [ROLE_PACKS.ICU_MANAGER]: {
    allowed_roles: [ROLES.ICU_MANAGER],
    required_permissions: ['unit:read', 'clinical:read'],
    required_modules: ['icu', 'nursing'],
    scope: 'assigned_icu',
  },
  [ROLE_PACKS.THEATRE_MANAGER]: {
    allowed_roles: [ROLES.THEATRE_MANAGER],
    required_permissions: ['unit:read', 'clinical:read'],
    required_modules: ['theatre'],
    scope: 'assigned_theatre',
  },
  [ROLE_PACKS.HOUSEKEEPING_MANAGER]: {
    allowed_roles: [ROLES.HOUSEKEEPING_MANAGER],
    required_permissions: ['operations:read', 'unit:read'],
    required_modules: ['housekeeping'],
    scope: 'housekeeping',
  },
  [ROLE_PACKS.BIOMED_MANAGER]: {
    allowed_roles: [ROLES.BIOMED_MANAGER],
    required_permissions: ['biomed:read', 'unit:read'],
    required_modules: ['biomedical'],
    scope: 'biomed',
  },
  [ROLE_PACKS.MORTUARY_STAFF]: {
    allowed_roles: [ROLES.MORTUARY_STAFF],
    required_permissions: ['mortuary:read'],
    required_modules: ['mortuary'],
    scope: 'mortuary',
  },
  [ROLE_PACKS.MORTUARY_MANAGER]: {
    allowed_roles: [ROLES.MORTUARY_MANAGER],
    required_permissions: ['mortuary:read', 'mortuary:audit'],
    required_modules: ['mortuary'],
    scope: 'mortuary_management',
  },
  [ROLE_PACKS.PATIENT_SAFE]: {
    allowed_roles: [ROLES.PATIENT],
    required_permissions: ['profile:read'],
    required_modules: [],
    scope: 'self',
  },
  [ROLE_PACKS.LIMITED]: {
    allowed_roles: [ROLES.OTHER],
    required_permissions: ['profile:read'],
    required_modules: [],
    scope: 'limited',
  },
});

const OPD_NOTIFICATION_ROLES = new Set([
  ROLES.FACILITY_ADMIN,
  ROLES.RECEPTIONIST,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.WARD_MANAGER,
]);

const getUserRoles = (user = {}) => {
  const roleCandidates = [];
  const sourceRoles = Array.isArray(user.roles) ? user.roles : [];
  for (const roleValue of sourceRoles) {
    const normalized = extractRole(roleValue);
    if (normalized) roleCandidates.push(normalized);
  }
  const directRole = extractRole(user.role || user.role_name);
  if (directRole) roleCandidates.push(directRole);
  return Array.from(new Set(roleCandidates));
};

const hasExplicitOpdDashboardAssignment = (user = {}) => {
  const assignmentSources = [
    user.dashboard_assignments,
    user.dashboardAssignments,
    user.module_assignments,
    user.moduleAssignments,
    user.explicit_modules,
    user.explicitModules,
  ];

  return assignmentSources.some((source) =>
    Array.isArray(source) &&
    source.some((item) =>
      ['opd', 'patient_flow', 'opd_notifications_attention'].includes(
        String(item?.id || item?.code || item || '').trim().toLowerCase()
      )
    )
  );
};

const canSeeOpdNotificationSignals = (user = {}, effectiveRole = null) => {
  const roles = getUserRoles(user);
  if (effectiveRole) roles.push(effectiveRole);
  return roles.some((role) => OPD_NOTIFICATION_ROLES.has(role)) ||
    hasExplicitOpdDashboardAssignment(user);
};

const withSummaryMetadata = (packId, cards = []) => {
  const metadata =
    SUMMARY_METADATA_BY_PACK[packId] ||
    SUMMARY_METADATA_BY_PACK[ROLE_PACKS.LIMITED];
  return cards.map((card) => ({
    ...card,
    required_permissions: card.required_permissions || metadata.required_permissions,
    required_modules: card.required_modules || metadata.required_modules,
    allowed_roles: card.allowed_roles || metadata.allowed_roles,
    scope: card.scope || metadata.scope,
    route_target: card.route_target || null,
  }));
};

const rawMetricsToRoleSummary = (packId, metrics = {}) => {
  if (packId === ROLE_PACKS.SUPER_ADMIN) {
    return [
      { id: 'tenants_active', label: 'Tenants active', value: metrics.tenantsActive || 0 },
      { id: 'facilities_active', label: 'Facilities active', value: metrics.facilitiesActive || metrics.totalBeds || 0 },
      { id: 'subscriptions_at_risk', label: 'Subscriptions at risk', value: metrics.subscriptionsAtRisk || 0 },
      { id: 'module_entitlement_issues', label: 'Module entitlement issues', value: metrics.moduleEntitlementIssues || 0 },
      { id: 'security_reviews_due', label: 'Security reviews due', value: metrics.securityReviewsDue || 0 },
      { id: 'integration_errors', label: 'Integration/API errors', value: metrics.integrationErrors || 0 },
    ];
  }

  if (packId === ROLE_PACKS.TENANT_ADMIN) {
    return [
      { id: 'facilities_active', label: 'Facilities active', value: metrics.facilitiesActive || 0 },
      { id: 'active_users', label: 'Active users', value: metrics.activeUsers || metrics.usersTotal || 0 },
      { id: 'module_adoption', label: 'Module adoption', value: metrics.moduleAdoption || 0, format: 'percent' },
      { id: 'organization_patient_flow', label: 'Organization patient flow', value: metrics.patientFlow || metrics.appointmentsToday || 0 },
      { id: 'organization_revenue_summary', label: 'Organization revenue', value: metrics.revenueSummary || metrics.paymentsToday || 0, format: 'currency' },
      { id: 'staffing_exceptions', label: 'Staffing exceptions', value: metrics.staffingExceptions || metrics.pendingLeaves || 0 },
      { id: 'subscription_health', label: 'Subscription health', value: metrics.subscriptionHealth || 0 },
    ];
  }

  if (packId === ROLE_PACKS.FACILITY_ADMIN) {
    return [
      { id: 'patient_flow_today', label: 'Patient flow today', value: metrics.patientsToday || metrics.appointmentsToday || 0 },
      { id: 'appointments_today', label: 'Appointments today', value: metrics.appointmentsToday || 0 },
      { id: 'active_admissions', label: 'Active admissions', value: metrics.activeAdmissions || 0 },
      { id: 'bed_occupancy', label: 'Occupied beds', value: metrics.occupiedBeds || 0 },
      { id: 'billing_exceptions', label: 'Billing exceptions', value: metrics.openInvoices || 0 },
      { id: 'operational_blockers', label: 'Operational blockers', value: metrics.openMaintenance || 0 },
    ];
  }

  if (packId === ROLE_PACKS.DOCTOR) {
    return [
      { id: 'assigned', label: 'Assigned consultations', value: metrics.assigned || 0 },
      { id: 'in_progress', label: 'Consultations in progress', value: metrics.inProgress || 0 },
      { id: 'completed', label: 'Completed consultations', value: metrics.completed || 0 },
      { id: 'admissions', label: 'Active admissions', value: metrics.activeAdmissions || 0 },
      { id: 'critical_labs', label: 'Critical lab signals', value: metrics.criticalLabs || 0 },
    ];
  }

  if (packId === ROLE_PACKS.NURSE) {
    return [
      { id: 'inpatient_flow', label: 'Active inpatients', value: metrics.activeAdmissions || 0 },
      { id: 'med_admin_today', label: 'Medication administrations today', value: metrics.medAdminToday || 0 },
      { id: 'transfer_queue', label: 'Transfer queue', value: metrics.transferQueue || 0 },
      { id: 'critical_labs', label: 'Critical lab signals', value: metrics.criticalLabs || 0 },
      { id: 'discharge_pressure', label: 'Discharge pressure', value: metrics.activeAdmissions || 0 },
    ];
  }

  if (packId === ROLE_PACKS.LAB_TECH) {
    return [
      { id: 'orders_today', label: 'Lab orders today', value: metrics.ordersToday || 0 },
      { id: 'in_process', label: 'Orders in process', value: metrics.inProcess || 0 },
      { id: 'pending_results', label: 'Pending results', value: metrics.pending || 0 },
      { id: 'critical_results', label: 'Critical results', value: metrics.critical || 0 },
      { id: 'completed_orders', label: 'Completed orders', value: metrics.completed || 0 },
    ];
  }

  if (packId === ROLE_PACKS.RADIOLOGY_TECH) {
    return [
      { id: 'orders_today', label: 'Radiology orders today', value: metrics.ordersToday || 0 },
      { id: 'in_process', label: 'Studies in process', value: metrics.inProcess || 0 },
      { id: 'draft_reports', label: 'Draft reports', value: metrics.pending || 0 },
      { id: 'final_reports', label: 'Final reports', value: metrics.final || 0 },
      { id: 'completed_orders', label: 'Completed orders', value: metrics.completed || 0 },
    ];
  }

  if (packId === ROLE_PACKS.PHARMACIST) {
    return [
      { id: 'orders_today', label: 'Medication orders today', value: metrics.ordersToday || 0 },
      { id: 'pending_dispense', label: 'Pending dispense workload', value: metrics.pendingDispense || 0 },
      { id: 'dispensed_today', label: 'Dispensed today', value: metrics.dispensedToday || 0 },
      { id: 'low_stock', label: 'Low stock pressure', value: metrics.lowStock || 0 },
      { id: 'critical_stock', label: 'Critical stock pressure', value: metrics.criticalStock || 0 },
    ];
  }

  if (packId === ROLE_PACKS.RECEPTIONIST) {
    return [
      { id: 'registrations_today', label: 'Registrations today', value: metrics.registrationsToday || 0 },
      { id: 'desk_queue', label: 'Appointment desk queue', value: metrics.appointmentDeskQueue || 0 },
      { id: 'no_show_pressure', label: 'No-show pressure', value: metrics.noShowPressure || 0 },
      { id: 'front_billing_queue', label: 'Front billing queue', value: metrics.frontBillingQueue || 0 },
      { id: 'appointments_today', label: 'Appointments today', value: metrics.appointmentsToday || 0 },
    ];
  }

  if (packId === ROLE_PACKS.BILLING) {
    return [
      { id: 'invoices_today', label: 'Invoices issued today', value: metrics.invoicesToday || 0 },
      { id: 'overdue_invoices', label: 'Overdue invoices', value: metrics.overdueInvoices || 0 },
      { id: 'open_balances', label: 'Open balances', value: metrics.openBalances || 0 },
      { id: 'collections_today', label: 'Collections today', value: metrics.collectionsToday || 0, format: 'currency' },
      { id: 'refunds_today', label: 'Refunds today', value: metrics.refundsToday || 0, format: 'currency' },
    ];
  }

  if (packId === ROLE_PACKS.OPERATIONS) {
    return [
      { id: 'occupied_beds', label: 'Occupied beds', value: metrics.occupiedBeds || 0 },
      { id: 'total_beds', label: 'Total beds', value: metrics.totalBeds || 0 },
      { id: 'maintenance_open', label: 'Open maintenance requests', value: metrics.openMaintenance || 0 },
      { id: 'low_stock_pressure', label: 'Low stock pressure', value: metrics.lowStockPressure || 0 },
      { id: 'housekeeping_backlog', label: 'Housekeeping backlog', value: metrics.housekeepingBacklog || 0 },
    ];
  }

  if (packId === ROLE_PACKS.HR) {
    return [
      { id: 'active_staff', label: 'Active staff profiles', value: metrics.activeStaff || 0 },
      { id: 'shifts_today', label: 'Shifts today', value: metrics.shiftsToday || 0 },
      { id: 'pending_leaves', label: 'Pending leave approvals', value: metrics.pendingLeaves || 0 },
      { id: 'staffing_backlog', label: 'Staffing backlog', value: metrics.staffingBacklog || 0 },
      { id: 'unassigned_shifts', label: 'Unassigned shifts', value: metrics.unassignedShifts || 0 },
    ];
  }

  if (packId === ROLE_PACKS.BIOMED) {
    return [
      { id: 'open_work_orders', label: 'Open work orders', value: metrics.openWorkOrders || 0 },
      { id: 'open_incidents', label: 'Open incidents', value: metrics.openIncidents || 0 },
      { id: 'active_downtime', label: 'Active downtime events', value: metrics.activeDowntime || 0 },
      { id: 'critical_service_risk', label: 'Critical service-risk indicators', value: metrics.criticalServiceRisk || 0 },
      { id: 'high_priority', label: 'High-priority work orders', value: metrics.highPriority || 0 },
    ];
  }

  if (packId === ROLE_PACKS.HOUSE_KEEPER) {
    return [
      { id: 'pending_tasks', label: 'Pending tasks', value: metrics.pendingTasks || 0 },
      { id: 'in_progress_tasks', label: 'Tasks in progress', value: metrics.inProgressTasks || 0 },
      { id: 'overdue_tasks', label: 'Overdue tasks', value: metrics.overdueTasks || 0 },
      { id: 'completed_today', label: 'Tasks completed today', value: metrics.completedToday || 0 },
      { id: 'throughput', label: 'Completion throughput', value: metrics.throughput || 0 },
    ];
  }

  if (packId === ROLE_PACKS.AMBULANCE_OPERATOR) {
    return [
      { id: 'dispatches_today', label: 'Dispatches today', value: metrics.dispatchesToday || 0 },
      { id: 'active_trips', label: 'Active trips', value: metrics.activeTrips || 0 },
      { id: 'critical_cases', label: 'Critical emergencies', value: metrics.criticalCases || 0 },
      { id: 'fleet_available', label: 'Fleet available', value: metrics.fleetAvailable || 0 },
      { id: 'fleet_out', label: 'Fleet out of service', value: metrics.fleetOut || 0 },
    ];
  }

  if (packId === ROLE_PACKS.UNIT_MANAGER) {
    return [
      { id: 'unit_census', label: 'Unit census', value: metrics.unitCensus || metrics.activeAdmissions || 0 },
      { id: 'staff_on_shift', label: 'Staff on shift', value: metrics.staffOnShift || metrics.shiftsToday || 0 },
      { id: 'open_roster_gaps', label: 'Open roster gaps', value: metrics.openRosterGaps || metrics.unassignedShifts || 0 },
      { id: 'pending_leave_requests', label: 'Pending leave requests', value: metrics.pendingLeaves || 0 },
      { id: 'coverage_risk', label: 'Coverage risk', value: metrics.coverageRisk || 0 },
      { id: 'unit_blockers', label: 'Unit blockers', value: metrics.unitBlockers || 0 },
    ];
  }

  if (packId === ROLE_PACKS.WARD_MANAGER) {
    return [
      { id: 'ward_census', label: 'Ward census', value: metrics.wardCensus || metrics.activeAdmissions || 0 },
      { id: 'occupied_beds', label: 'Occupied beds', value: metrics.occupiedBeds || 0 },
      { id: 'pending_nursing_tasks', label: 'Pending nursing tasks', value: metrics.pendingNursingTasks || metrics.transferQueue || 0 },
      { id: 'handover_risks', label: 'Handover risks', value: metrics.handoverRisks || 0 },
      { id: 'staff_on_shift', label: 'Staff on shift', value: metrics.staffOnShift || metrics.shiftsToday || 0 },
      { id: 'discharge_delays', label: 'Discharge delays', value: metrics.dischargeDelays || 0 },
    ];
  }

  if (packId === ROLE_PACKS.ICU_MANAGER) {
    return [
      { id: 'icu_census', label: 'ICU census', value: metrics.icuCensus || metrics.activeAdmissions || 0 },
      { id: 'critical_patient_alerts', label: 'Critical patient alerts', value: metrics.criticalPatientAlerts || metrics.criticalLabs || 0 },
      { id: 'icu_beds_occupied', label: 'ICU beds occupied', value: metrics.icuBedsOccupied || metrics.occupiedBeds || 0 },
      { id: 'transfer_readiness', label: 'Transfer readiness', value: metrics.transferReadiness || metrics.transferQueue || 0 },
      { id: 'staff_coverage', label: 'Staff coverage', value: metrics.staffCoverage || metrics.shiftsToday || 0 },
      { id: 'open_escalations', label: 'Open escalations', value: metrics.openEscalations || 0 },
    ];
  }

  if (packId === ROLE_PACKS.THEATRE_MANAGER) {
    return [
      { id: 'procedures_today', label: 'Procedures today', value: metrics.proceduresToday || 0 },
      { id: 'ready_for_theatre', label: 'Ready for theatre', value: metrics.readyForTheatre || 0 },
      { id: 'in_theatre', label: 'In theatre', value: metrics.inTheatre || 0 },
      { id: 'post_op_handovers_pending', label: 'Post-op handovers pending', value: metrics.postOpHandoversPending || 0 },
      { id: 'cancellations_or_delays', label: 'Cancellations or delays', value: metrics.cancellationsOrDelays || 0 },
      { id: 'theatre_staff_coverage', label: 'Theatre staff coverage', value: metrics.theatreStaffCoverage || metrics.shiftsToday || 0 },
    ];
  }

  if (packId === ROLE_PACKS.HOUSEKEEPING_MANAGER) {
    return [
      { id: 'pending_cleaning_tasks', label: 'Pending cleaning tasks', value: metrics.pendingCleaningTasks || metrics.pendingTasks || 0 },
      { id: 'unassigned_cleaning_tasks', label: 'Unassigned cleaning tasks', value: metrics.unassignedCleaningTasks || 0 },
      { id: 'in_progress_cleaning_tasks', label: 'In-progress cleaning tasks', value: metrics.inProgressCleaningTasks || metrics.inProgressTasks || 0 },
      { id: 'overdue_cleaning_tasks', label: 'Overdue cleaning tasks', value: metrics.overdueCleaningTasks || metrics.overdueTasks || 0 },
      { id: 'rooms_ready', label: 'Rooms ready', value: metrics.roomsReady || 0 },
      { id: 'housekeeping_staff_on_shift', label: 'Housekeeping staff on shift', value: metrics.housekeepingStaffOnShift || metrics.shiftsToday || 0 },
    ];
  }

  if (packId === ROLE_PACKS.BIOMED_MANAGER) {
    return [
      { id: 'open_work_orders', label: 'Open work orders', value: metrics.openWorkOrders || 0 },
      { id: 'high_priority_work_orders', label: 'High-priority work orders', value: metrics.highPriorityWorkOrders || metrics.highPriority || 0 },
      { id: 'active_downtime', label: 'Active downtime', value: metrics.activeDowntime || 0 },
      { id: 'open_incidents', label: 'Open incidents', value: metrics.openIncidents || 0 },
      { id: 'overdue_maintenance', label: 'Overdue maintenance', value: metrics.overdueMaintenance || 0 },
      { id: 'technician_load', label: 'Technician load', value: metrics.technicianLoad || 0 },
    ];
  }

  if (packId === ROLE_PACKS.MORTUARY_STAFF) {
    return [
      { id: 'active_mortuary_cases', label: 'Active mortuary cases', value: metrics.activeMortuaryCases || 0 },
      { id: 'storage_assignments', label: 'Storage assignments', value: metrics.storageAssignments || 0 },
      { id: 'custody_events_due', label: 'Custody events due', value: metrics.custodyEventsDue || 0 },
      { id: 'viewings_today', label: 'Viewings today', value: metrics.viewingsToday || 0 },
      { id: 'post_mortem_requests', label: 'Post-mortem requests', value: metrics.postMortemRequests || 0 },
      { id: 'billable_events_to_capture', label: 'Billable events to capture', value: metrics.billableEventsToCapture || 0 },
    ];
  }

  if (packId === ROLE_PACKS.MORTUARY_MANAGER) {
    return [
      { id: 'active_mortuary_cases', label: 'Active mortuary cases', value: metrics.activeMortuaryCases || 0 },
      { id: 'storage_occupancy', label: 'Storage occupancy', value: metrics.storageOccupancy || 0, format: 'percent' },
      { id: 'releases_awaiting_approval', label: 'Releases awaiting approval', value: metrics.releasesAwaitingApproval || 0 },
      { id: 'custody_exceptions', label: 'Custody exceptions', value: metrics.custodyExceptions || 0 },
      { id: 'pending_post_mortem_requests', label: 'Pending post-mortem requests', value: metrics.pendingPostMortemRequests || 0 },
      { id: 'audit_exports_due', label: 'Audit exports due', value: metrics.auditExportsDue || 0 },
    ];
  }

  if (packId === ROLE_PACKS.PATIENT_SAFE) {
    return [
      { id: 'my_upcoming_appointments', label: 'My upcoming appointments', value: metrics.myUpcomingAppointments || 0 },
      { id: 'my_open_bills', label: 'My open bills', value: metrics.myOpenBills || 0 },
      { id: 'my_prescriptions', label: 'My prescriptions', value: metrics.myPrescriptions || 0 },
      { id: 'my_released_results', label: 'My released results', value: metrics.myReleasedResults || 0 },
      { id: 'my_messages', label: 'My messages', value: metrics.myMessages || 0 },
      { id: 'my_profile_status', label: 'My profile status', value: metrics.myProfileStatus || 0 },
    ];
  }

  if (packId === ROLE_PACKS.LIMITED) {
    return [
      { id: 'profile_status', label: 'Profile status', value: metrics.profileStatus || 0 },
      { id: 'assigned_links', label: 'Assigned links', value: metrics.assignedLinks || 0 },
      { id: 'unread_messages', label: 'Unread messages', value: metrics.unreadMessages || 0 },
      { id: 'facility_notices', label: 'Facility notices', value: metrics.facilityNotices || 0 },
    ];
  }

  return [
    { id: 'patients_today', label: 'Patients added today', value: metrics.patientsToday || 0 },
    { id: 'appointments_today', label: 'Appointments today', value: metrics.appointmentsToday || 0 },
    { id: 'active_admissions', label: 'Active admissions', value: metrics.activeAdmissions || 0 },
    { id: 'open_invoices', label: 'Open invoices', value: metrics.openInvoices || 0 },
    { id: 'payments_today', label: 'Payments received today', value: metrics.paymentsToday || 0, format: 'currency' },
  ];
};

const metricsToRoleSummary = (packId, metrics = {}) =>
  withSummaryMetadata(packId, rawMetricsToRoleSummary(packId, metrics));

const buildDashboardSummary = async ({ query = {}, user = {}, repository }) => {
  try {
    const days = Number(query.days || 7);
    const effectiveRole = resolveEffectiveRole(user);
    const roleProfileId = resolveProfileId(effectiveRole);
    const packId = resolvePackId(roleProfileId);
    const scope = await resolveScope(query, user, effectiveRole, repository);
    const resolvedUserId = user.id || user.user_id || user.userId || null;
    const includeOpdNotificationSignals = canSeeOpdNotificationSignals(user, effectiveRole);

    const [packData, unreadOpdNotifications] = await Promise.all([
      repository.getDashboardSummaryByPack({
        packId,
        scope,
        days,
        userId: resolvedUserId,
      }),
      includeOpdNotificationSignals
        ? repository
            .countUnreadOpdNotifications({
              scope,
              userId: resolvedUserId,
            })
            .catch(() => 0)
        : Promise.resolve(0),
    ]);

    const trendPoints = buildTrendPoints(packData?.trendDates || [], days);
    const distribution = buildDistribution(packData?.statusCounts || {});
    const summaryCards = metricsToRoleSummary(packId, packData?.metrics || {});
    const opdNotificationsPendingAttention = Number(unreadOpdNotifications || 0);

    if (includeOpdNotificationSignals) {
      summaryCards.push({
        id: 'opd_notifications_attention',
        label: 'OPD notifications pending attention',
        value: opdNotificationsPendingAttention,
        required_permissions: ['patient:read'],
        required_modules: ['scheduling'],
        allowed_roles: Array.from(OPD_NOTIFICATION_ROLES),
        scope: 'patient_flow',
        route_target: {
          module_slug: 'scheduling',
          resource: 'opd-flows',
          public_id: null,
          action: 'list',
        },
      });
    }

    const hasLiveData =
      summaryCards.some((item) => Number(item.value || 0) > 0) ||
      trendPoints.some((item) => Number(item.value || 0) > 0) ||
      Number(distribution.total || 0) > 0 ||
      (includeOpdNotificationSignals && opdNotificationsPendingAttention > 0);

    const queue = [
      queueItem('queue_primary', 'Primary queue', summaryCards[0]?.value || 0, 'Current', 'primary', 'items'),
      queueItem('queue_secondary', 'Secondary queue', summaryCards[1]?.value || 0, 'Monitor', 'warning', 'items'),
    ];
    if (includeOpdNotificationSignals) {
      queue.push(
        queueItem(
          'queue_opd_attention',
          'OPD notifications',
          opdNotificationsPendingAttention,
          opdNotificationsPendingAttention > 0 ? 'Pending attention' : 'No pending items',
          opdNotificationsPendingAttention > 0 ? 'error' : 'success',
          'notifications'
        )
      );
    }

    const alerts = [
      alertItem('alert_primary', 'Primary alert pressure', summaryCards[2]?.value || 0, 'Monitor', 'warning', 'signals'),
      alertItem('alert_secondary', 'Secondary alert pressure', summaryCards[3]?.value || 0, 'Watch', 'primary', 'signals'),
    ];
    if (includeOpdNotificationSignals) {
      alerts.push(
        alertItem(
          'alert_opd_attention',
          'OPD notifications needing attention',
          opdNotificationsPendingAttention,
          opdNotificationsPendingAttention > 0 ? 'Action required' : 'Stable',
          opdNotificationsPendingAttention > 0 ? 'error' : 'success',
          'notifications'
        )
      );
    }

    const activity = [
      ...Object.entries(packData?.activity || {}).map(([key, value]) =>
        activityItem(`activity_${key}`, `${key.replace(/_/g, ' ')} updated`, value)
      ),
    ];
    if (includeOpdNotificationSignals) {
      activity.push(
        activityItem(
          'activity_opd_attention',
          'opd notifications pending attention',
          opdNotificationsPendingAttention
        )
      );
    }

    const highlights = [
      {
        id: 'live_signal',
        label: 'Live operational signal',
        value: `${summaryCards[0]?.value || 0}`,
        context: 'Role-focused primary metric',
      },
      {
        id: 'trend_average',
        label: 'Trend average',
        value: `${average(trendPoints.map((item) => item.value))}`,
        context: `${days}-day rolling average`,
      },
      {
        id: 'distribution_total',
        label: 'Distribution total',
        value: `${distribution.total || 0}`,
        context: 'Status-distributed records',
      },
    ];
    if (includeOpdNotificationSignals) {
      highlights.push({
        id: 'opd_notification_attention',
        label: 'OPD notification attention',
        value: `${opdNotificationsPendingAttention}`,
        context: 'Unread OPD flow updates requiring attendance',
      });
    }

    const sanitized = sanitizeSummaryPayload({
      summaryCards,
      trend: {
        title: `${days}-day trend`,
        subtitle: 'Aggregate trend points',
        points: trendPoints,
      },
      distribution: {
        title: 'Status distribution',
        subtitle: 'Aggregate status mix',
        total: distribution.total,
        segments: distribution.segments,
      },
      highlights,
      queue,
      alerts,
      activity,
    });

    return {
      roleProfile: {
        id: roleProfileId,
        role: effectiveRole,
        pack: packId,
        scopeType:
          SUMMARY_METADATA_BY_PACK[packId]?.scope ||
          SUMMARY_METADATA_BY_PACK[ROLE_PACKS.LIMITED].scope,
      },
      ...sanitized,
      hasLiveData,
      generatedAt: new Date().toISOString(),
      scope: {
        tenant_id: scope.tenant_id || null,
        facility_id: scope.facility_id || null,
        branch_id: scope.branch_id || null,
        days,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  ROLE_PACKS,
  buildDashboardSummary,
  metricsToRoleSummary,
  resolveEffectiveRole,
  resolvePackId,
  resolveProfileId,
  resolveScope,
  sanitizeSummaryPayload,
};
