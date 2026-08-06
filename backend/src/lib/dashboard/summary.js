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
    'secondary_value',
    'hint',
    'format',
    'required_permissions',
    'required_modules',
    'allowed_roles',
    'scope',
    'route_target',
  ],
  trendPoints: ['id', 'date', 'value', 'label'],
  distributionSegments: ['id', 'label', 'value', 'amount', 'color'],
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

const DASHBOARD_MANAGER_OVERLAY_ROLES = new Set([
  ROLES.UNIT_MANAGER,
  ROLES.WARD_MANAGER,
  ROLES.ICU_MANAGER,
  ROLES.THEATRE_MANAGER,
  ROLES.HOUSEKEEPING_MANAGER,
  ROLES.BIOMED_MANAGER,
  ROLES.MORTUARY_MANAGER,
]);

const pickHighestRankedRole = (roleNames = []) => {
  const unique = Array.from(new Set(roleNames.filter(Boolean)));
  if (!unique.length) return null;

  return unique.reduce((winner, roleName) => {
    if (!winner) return roleName;
    const winnerRank = ROLE_HIERARCHY[winner] || 0;
    const challengerRank = ROLE_HIERARCHY[roleName] || 0;
    return challengerRank > winnerRank ? roleName : winner;
  }, null);
};

const collectRoleCandidates = (user = {}) => {
  const roleCandidates = [];
  const roleSource = Array.isArray(user.roles) ? user.roles : [];

  for (const roleValue of roleSource) {
    const normalized = extractRole(roleValue);
    if (normalized) roleCandidates.push(normalized);
  }

  const directRole = extractRole(user.role || user.role_name);
  if (directRole) roleCandidates.push(directRole);

  return roleCandidates;
};

const resolveEffectiveRole = (user = {}) => {
  const roleCandidates = collectRoleCandidates(user);
  return pickHighestRankedRole(roleCandidates) || ROLES.OTHER;
};

const resolveDashboardRole = (user = {}) => {
  const roleCandidates = collectRoleCandidates(user);
  const operationalRoles = roleCandidates.filter(
    (roleName) => !DASHBOARD_MANAGER_OVERLAY_ROLES.has(roleName)
  );
  const candidates = operationalRoles.length ? operationalRoles : roleCandidates;
  return pickHighestRankedRole(candidates) || ROLES.OTHER;
};

const resolveProfileId = (effectiveRole) => ROLE_PROFILE_IDS[effectiveRole] || 'other';
const resolvePackId = (profileId) => PROFILE_TO_PACK[profileId] || ROLE_PACKS.OPERATIONS;

const resolveScope = async (query = {}, user = {}, effectiveRole = null, repository = null) => {
  const userScope = {
    tenant_id: user.tenant_id || user.tenantId || null,
    facility_id: user.facility_id || user.facilityId || null,
  };

  if (effectiveRole === ROLES.SUPER_ADMIN) {
    const tenantId = query.tenant_id || userScope.tenant_id || null;
    const facilityId = query.facility_id || userScope.facility_id || null;

    if (!tenantId) {
      return {
        tenant_id: null,
        facility_id: null,
        platform: true,
      };
    }

    return {
      tenant_id: tenantId,
      facility_id: facilityId || null,
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

const buildDistribution = (statusCounts = {}, statusAmounts = {}) => {
  const colors = ['#2563eb', '#0ea5e9', '#14b8a6', '#f59e0b', '#ef4444', '#8b5cf6'];
  const statusLabels = {
    ORDERED: 'Ordered',
    PARTIALLY_DISPENSED: 'Partially dispensed',
    DISPENSED: 'Dispensed',
    CANCELLED: 'Cancelled',
  };
  const entries = Object.entries(statusCounts || {}).filter(([, value]) => Number(value || 0) > 0);
  const segments = entries.map(([status, value], index) => {
    const key = String(status || '').toUpperCase();
    const fallbackLabel = String(status)
      .replace(/_/g, ' ')
      .toLowerCase()
      .replace(/\b\w/g, (char) => char.toUpperCase());
    const amount =
      Number(statusAmounts?.[status] ?? statusAmounts?.[key] ?? 0) || 0;
    return {
      id: String(status).toLowerCase(),
      label: statusLabels[key] || fallbackLabel,
      value: Number(value || 0),
      amount,
      color: colors[index % colors.length],
    };
  });
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
    required_modules: ['patients', 'scheduling', 'emergency'],
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
  return cards.map((card) => {
    // Prefer explicit per-card permissions (Dashboard.md). Do not stamp pack-level
    // required_permissions when omitted — clients resolve via their atom catalog.
    const requiredPermissions = Array.isArray(card.required_permissions)
      ? card.required_permissions
      : undefined;
    return {
      ...card,
      ...(requiredPermissions ? { required_permissions: requiredPermissions } : {}),
      required_modules: card.required_modules || metadata.required_modules,
      allowed_roles: card.allowed_roles || metadata.allowed_roles,
      scope: card.scope || metadata.scope,
      route_target: card.route_target || null,
    };
  });
};

const rawMetricsToRoleSummary = (packId, metrics = {}) => {
  if (packId === ROLE_PACKS.SUPER_ADMIN) {
    const tenantsTotal = Number(metrics.tenantsTotal || 0);
    const tenantsWithoutSubscription = Number(metrics.tenantsWithoutSubscription || 0);
    const tenantsWithSubscription = Number.isFinite(Number(metrics.tenantsWithSubscription))
      ? Number(metrics.tenantsWithSubscription)
      : Math.max(0, tenantsTotal - tenantsWithoutSubscription);
    const subscriptionsExpiring = Number(metrics.subscriptionsExpiring || 0);

    return [
      {
        id: 'tenants_active',
        label: 'Tenants',
        value: metrics.tenantsActive || 0,
        secondary_value: tenantsTotal,
        format: 'ratio',
        required_permissions: ['system:admin'],
      },
      {
        id: 'facilities_active',
        label: 'Facilities',
        value: metrics.facilitiesActive ?? metrics.facilitiesTotal ?? 0,
        secondary_value: metrics.facilitiesTotal ?? metrics.facilitiesActive ?? 0,
        format: 'ratio',
        required_permissions: ['system:admin'],
      },
      {
        id: 'subscriptions_health',
        label: 'Subscriptions',
        value: tenantsWithSubscription,
        secondary_value: tenantsTotal,
        format: 'ratio',
        required_permissions: ['subscriptions:read'],
        hint:
          tenantsWithoutSubscription > 0
            ? `${tenantsWithoutSubscription} tenant${tenantsWithoutSubscription === 1 ? '' : 's'} without subscription`
            : subscriptionsExpiring > 0
              ? `${subscriptionsExpiring} expiring soon`
              : null,
      },
      {
        id: 'module_entitlement_issues',
        label: 'Entitlements',
        value: metrics.moduleEntitlementIssues || 0,
        required_permissions: ['system:admin'],
      },
      {
        id: 'pending_registration_approvals',
        label: 'Approvals',
        value: metrics.pendingRegistrationApprovals || 0,
        required_permissions: ['system:admin'],
        hint:
          Number(metrics.pendingRegistrationApprovals || 0) > 0
            ? 'New accounts awaiting platform approval'
            : null,
        route_target: {
          path: '/admin/setup',
          query: { section: 'subscription-approvals' },
        },
      },
    ];
  }

  if (packId === ROLE_PACKS.TENANT_ADMIN) {
    const facilitiesTotal = metrics.facilitiesTotal ?? metrics.facilitiesActive ?? 0;
    const facilitiesActive = metrics.facilitiesActive ?? 0;
    return [
      {
        id: 'facilities_active',
        label: 'Facilities',
        value: facilitiesActive,
        secondary_value: facilitiesTotal,
        format: 'ratio',
        required_permissions: ['tenant:admin'],
        hint:
          facilitiesTotal === 0
            ? 'Create at least one facility to get started'
            : facilitiesActive < facilitiesTotal
              ? `${facilitiesTotal - facilitiesActive} inactive`
              : null,
      },
      {
        id: 'active_users',
        label: 'Users',
        value: metrics.activeUsers || metrics.usersTotal || 0,
        required_permissions: ['tenant:admin'],
      },
      {
        id: 'module_adoption',
        label: 'Adoption',
        value: metrics.moduleAdoption || 0,
        format: 'percent',
        required_permissions: ['reports:read'],
      },
      {
        id: 'subscription_health',
        label: 'Subscription',
        value: metrics.subscriptionHealth || 0,
        format: 'percent',
        required_permissions: ['subscriptions:read'],
      },
    ];
  }

  if (packId === ROLE_PACKS.FACILITY_ADMIN) {
    return [
      { id: 'patient_flow_today', label: 'Patient flow today', value: metrics.patientsToday || metrics.appointmentsToday || 0, required_permissions: ['patient:read'] },
      { id: 'appointments_today', label: 'Appointments today', value: metrics.appointmentsToday || 0, required_permissions: ['patient:read'] },
      { id: 'active_admissions', label: 'Active admissions', value: metrics.activeAdmissions || 0, required_permissions: ['patient:read'] },
      { id: 'bed_occupancy', label: 'Occupied beds', value: metrics.occupiedBeds || 0, required_permissions: ['patient:read'] },
      { id: 'emergency_cases_today', label: 'Emergency queue', value: metrics.emergencyCasesToday || 0, required_permissions: ['emergency:read'] },
      {
        id: 'collections_today',
        label: 'Revenue today',
        value: metrics.collectionsToday || metrics.paymentsToday || 0,
        format: 'currency',
        required_permissions: ['billing:read'],
      },
      { id: 'billing_exceptions', label: 'Billing exceptions', value: metrics.openInvoices || 0, required_permissions: ['billing:read'] },
      { id: 'low_stock', label: 'Pharmacy low stock', value: metrics.lowStock || 0, required_permissions: ['pharmacy:read'] },
      { id: 'critical_labs', label: 'Critical labs', value: metrics.criticalLabs || 0, required_permissions: ['lab:read'] },
      { id: 'pending_leaves', label: 'HR leave requests', value: metrics.pendingLeaves || 0, required_permissions: ['hr:read'] },
      { id: 'open_incidents', label: 'Equipment incidents', value: metrics.openIncidents || 0, required_permissions: ['biomed:read'] },
      { id: 'operational_blockers', label: 'Operational blockers', value: metrics.openMaintenance || 0, required_permissions: ['operations:read'] },
    ];
  }

  if (packId === ROLE_PACKS.DOCTOR) {
    return [
      { id: 'assigned', label: 'Assigned today', value: metrics.assigned || 0, required_permissions: ['clinical:read'] },
      { id: 'in_progress', label: 'Consultations in progress', value: metrics.inProgress || 0, required_permissions: ['clinical:read'] },
      {
        id: 'results_pending_review',
        label: 'Lab results to review',
        value: metrics.resultsPendingReview || 0,
        required_permissions: ['lab:read'],
      },
      { id: 'follow_ups_due', label: 'Follow-ups due', value: metrics.followUpsDue || 0, required_permissions: ['clinical:read'] },
      { id: 'completed', label: 'Completed today', value: metrics.completed || 0, required_permissions: ['clinical:read'] },
      // Dashboard.md §4 — secondary atoms with live provider/facility sources.
      {
        id: 'radiology_pending',
        label: 'Radiology results',
        value: metrics.radiologyPending || 0,
        required_permissions: ['radiology:read'],
      },
      {
        id: 'prescriptions_pending',
        label: 'Prescriptions pending',
        value: metrics.prescriptionsPending || 0,
        required_permissions: ['pharmacy:read'],
      },
      {
        id: 'emergency_cases_today',
        label: 'Emergency calls',
        value: metrics.emergencyCasesToday || 0,
        required_permissions: ['emergency:read'],
      },
      {
        id: 'shifts_today',
        label: 'My schedule',
        value: metrics.shiftsToday || 0,
        required_permissions: ['roster:read'],
      },
    ];
  }

  if (packId === ROLE_PACKS.NURSE) {
    return [
      { id: 'inpatient_flow', label: 'Active inpatients', value: metrics.activeAdmissions || 0, required_permissions: ['clinical:read'] },
      { id: 'med_admin_today', label: 'Medication administrations today', value: metrics.medAdminToday || 0, required_permissions: ['pharmacy:read'] },
      { id: 'transfer_queue', label: 'Transfer queue', value: metrics.transferQueue || 0, required_permissions: ['patient:read'] },
      { id: 'critical_labs', label: 'Critical lab signals', value: metrics.criticalLabs || 0, required_permissions: ['lab:read'] },
      { id: 'discharge_pressure', label: 'Discharge pressure', value: metrics.activeAdmissions || 0, required_permissions: ['clinical:read'] },
      { id: 'appointments_today', label: 'OPD queue', value: metrics.appointmentsToday || 0, required_permissions: ['patient:read'] },
      { id: 'emergency_cases_today', label: 'Emergency cases today', value: metrics.emergencyCasesToday || 0, required_permissions: ['emergency:read'] },
      { id: 'theatre_cases_today', label: 'Theatre cases in progress', value: metrics.theatreCasesToday || 0, required_permissions: ['clinical:read'] },
      { id: 'radiology_pending', label: 'Imaging results pending', value: metrics.radiologyPending || 0, required_permissions: ['radiology:read'] },
    ];
  }

  if (packId === ROLE_PACKS.LAB_TECH) {
    // Align with Lab desk tabs: Pending → Critical → Completed → All patients.
    return [
      { id: 'lab_pending', label: 'Pending', value: metrics.pending || 0, required_permissions: ['lab:read'] },
      { id: 'critical_results', label: 'Critical', value: metrics.critical || 0, required_permissions: ['lab:read'] },
      { id: 'completed_orders', label: 'Completed', value: metrics.completed || 0, required_permissions: ['lab:read'] },
      { id: 'lab_all_patients', label: 'All patients', value: metrics.allPatients || metrics.totalOrders || 0, required_permissions: ['lab:read'] },
    ];
  }

  if (packId === ROLE_PACKS.RADIOLOGY_TECH) {
    return [
      { id: 'orders_today', label: 'Radiology orders today', value: metrics.ordersToday || 0, required_permissions: ['radiology:read'] },
      { id: 'in_process', label: 'Studies in process', value: metrics.inProcess || 0, required_permissions: ['radiology:read'] },
      { id: 'draft_reports', label: 'Draft reports', value: metrics.pending || 0, required_permissions: ['radiology:read'] },
      { id: 'final_reports', label: 'Final reports', value: metrics.final || 0, required_permissions: ['radiology:read'] },
      { id: 'completed_orders', label: 'Completed orders', value: metrics.completed || 0, required_permissions: ['radiology:read'] },
    ];
  }

  if (packId === ROLE_PACKS.PHARMACIST) {
    return [
      { id: 'orders_today', label: 'Orders today', value: metrics.ordersToday || 0, required_permissions: ['pharmacy:read'] },
      { id: 'pending_dispense', label: 'Pending', value: metrics.pendingDispense || 0, required_permissions: ['pharmacy:write'] },
      { id: 'dispensed_today', label: 'Dispensed today', value: metrics.dispensedToday || 0, required_permissions: ['pharmacy:read'] },
      { id: 'low_stock', label: 'Low stock', value: metrics.lowStock || 0, required_permissions: ['pharmacy:read'] },
      { id: 'out_of_stock', label: 'Out of stock', value: metrics.outOfStock || 0, required_permissions: ['pharmacy:read'] },
      { id: 'near_expiry', label: 'Near expiry', value: metrics.nearExpiry || 0, required_permissions: ['pharmacy:read'] },
      { id: 'expired', label: 'Expired', value: metrics.expiredStock || metrics.expired || 0, required_permissions: ['pharmacy:read'] },
      {
        id: 'sales_today',
        label: 'Total sales today',
        value: metrics.salesToday || 0,
        format: 'currency',
        required_permissions: ['pricing:pharmacy_read'],
      },
      {
        id: 'sales_this_week',
        label: 'Total sales (last 7 days)',
        value: metrics.salesThisWeek || 0,
        format: 'currency',
        required_permissions: ['pricing:pharmacy_read'],
      },
      { id: 'critical_stock', label: 'Critical stock', value: metrics.criticalStock || 0, required_permissions: ['pharmacy:read'] },
      // Dashboard.md §7 Billing Pending — live open invoice balances.
      {
        id: 'billing_pending',
        label: 'Billing pending',
        value: metrics.billingPending || metrics.pendingBalanceAmount || 0,
        format: 'currency',
        required_permissions: ['billing:read'],
      },
    ];
  }

  if (packId === ROLE_PACKS.RECEPTIONIST) {
    return [
      { id: 'appointments_today', label: 'Meetings today', value: metrics.appointmentsToday || 0, required_permissions: ['patient:read'] },
      { id: 'desk_queue', label: 'Appointment desk queue', value: metrics.appointmentDeskQueue || 0, required_permissions: ['patient:read'] },
      { id: 'turnaround_pressure', label: 'In-progress turnaround', value: metrics.turnaroundPressure || 0, required_permissions: ['patient:read'] },
      { id: 'no_show_pressure', label: 'No-show follow-ups', value: metrics.noShowPressure || 0, required_permissions: ['patient:read'] },
      { id: 'registrations_today', label: 'Registrations today', value: metrics.registrationsToday || 0, required_permissions: ['patient:write'] },
      { id: 'emergency_cases_today', label: 'Emergency intake today', value: metrics.emergencyCasesToday || 0, required_permissions: ['emergency:read'] },
      // Dashboard.md §8 Pending Payments — live billing pending balances.
      { id: 'pending_balance_amount', label: 'Pending payments', value: metrics.pendingBalanceAmount || 0, format: 'currency', required_permissions: ['billing:read'] },
    ];
  }

  if (packId === ROLE_PACKS.BILLING) {
    return [
      { id: 'collections_today', label: 'Collections today', value: metrics.collectionsToday || 0, format: 'currency', required_permissions: ['billing:read'] },
      { id: 'overdue_balance_amount', label: 'Overdue amount', value: metrics.overdueBalanceAmount || 0, format: 'currency', required_permissions: ['billing:read'] },
      { id: 'pending_balance_amount', label: 'Pending balances', value: metrics.pendingBalanceAmount || 0, format: 'currency', required_permissions: ['billing:read'] },
      { id: 'invoices_today', label: 'Invoices issued today', value: metrics.invoicesToday || 0, required_permissions: ['billing:read'] },
      { id: 'overdue_invoices', label: 'Overdue invoices', value: metrics.overdueInvoices || 0, required_permissions: ['billing:read'] },
      { id: 'open_balances', label: 'Open balances', value: metrics.openBalances || 0, required_permissions: ['billing:read'] },
      { id: 'refunds_today', label: 'Refunds today', value: metrics.refundsToday || 0, format: 'currency', required_permissions: ['billing:write'] },
      { id: 'pending_approvals', label: 'Pending approvals', value: metrics.pendingApprovals || 0, required_permissions: ['financial:approve'] },
      {
        id: 'pending_insurance_claims',
        label: 'Pending insurance claims',
        value: metrics.pendingInsuranceClaims || 0,
        required_permissions: ['billing:read'],
      },
    ];
  }

  if (packId === ROLE_PACKS.OPERATIONS) {
    return [
      { id: 'occupied_beds', label: 'Occupied beds', value: metrics.occupiedBeds || 0, required_permissions: ['operations:read'] },
      { id: 'total_beds', label: 'Total beds', value: metrics.totalBeds || 0, required_permissions: ['operations:read'] },
      { id: 'maintenance_open', label: 'Open maintenance requests', value: metrics.openMaintenance || 0, required_permissions: ['operations:read'] },
      { id: 'low_stock_pressure', label: 'Low stock pressure', value: metrics.lowStockPressure || 0, required_permissions: ['operations:read'] },
      { id: 'housekeeping_backlog', label: 'Housekeeping backlog', value: metrics.housekeepingBacklog || 0, required_permissions: ['operations:read'] },
      { id: 'facility_readiness', label: 'Facility readiness', value: metrics.facilityReadiness || 0, format: 'percent', required_permissions: ['operations:read'] },
      // Gap: security_incidents / utilities_status — no live KPI source yet (Dashboard.md §10).
    ];
  }

  if (packId === ROLE_PACKS.HR) {
    return [
      { id: 'active_staff', label: 'Active staff profiles', value: metrics.activeStaff || 0, required_permissions: ['hr:read'] },
      { id: 'shifts_today', label: 'Shifts today', value: metrics.shiftsToday || 0, required_permissions: ['roster:read'] },
      { id: 'pending_leaves', label: 'Pending leave approvals', value: metrics.pendingLeaves || 0, required_permissions: ['hr:read'] },
      { id: 'on_leave_today', label: 'On leave today', value: metrics.onLeaveToday || 0, required_permissions: ['hr:read'] },
      { id: 'unassigned_shifts', label: 'Unassigned shifts', value: metrics.unassignedShifts || 0, required_permissions: ['roster:read'] },
      { id: 'attended_today', label: 'Attended today', value: metrics.attendedToday || 0, required_permissions: ['hr:read'] },
      { id: 'missed_shifts_today', label: 'Missed shifts today', value: metrics.missedShiftsToday || 0, required_permissions: ['roster:read'] },
      { id: 'payroll_pending', label: 'Payroll pending', value: metrics.payrollPending || 0, required_permissions: ['hr:read'] },
      { id: 'payroll_processed', label: 'Payroll processed', value: metrics.payrollProcessed || 0, required_permissions: ['hr:read'] },
      { id: 'staffing_backlog', label: 'Staffing backlog', value: metrics.staffingBacklog || 0, required_permissions: ['hr:read'] },
      { id: 'attendance_rate', label: 'Attendance rate', value: metrics.attendanceRate || 0, format: 'percent', required_permissions: ['hr:read'] },
      {
        id: 'roster_approvals',
        label: 'Roster approvals',
        value: metrics.rosterApprovals || 0,
        required_permissions: ['roster:approve'],
      },
      {
        id: 'department_staffing',
        label: 'Department staffing',
        value: metrics.departmentStaffing || metrics.staffingBacklog || 0,
        required_permissions: ['unit:read'],
      },
    ];
  }

  if (packId === ROLE_PACKS.BIOMED) {
    return [
      { id: 'open_work_orders', label: 'Open work orders', value: metrics.openWorkOrders || 0, required_permissions: ['biomed:write'] },
      { id: 'open_incidents', label: 'Open incidents', value: metrics.openIncidents || 0, required_permissions: ['biomed:read'] },
      { id: 'active_downtime', label: 'Active downtime events', value: metrics.activeDowntime || 0, required_permissions: ['biomed:read'] },
      { id: 'critical_service_risk', label: 'Critical service-risk indicators', value: metrics.criticalServiceRisk || 0, required_permissions: ['biomed:read'] },
      { id: 'high_priority', label: 'High-priority work orders', value: metrics.highPriority || 0, required_permissions: ['biomed:read'] },
      { id: 'assets_operational', label: 'Assets operational', value: metrics.assetsOperational || 0, format: 'percent', required_permissions: ['biomed:read'] },
    ];
  }

  if (packId === ROLE_PACKS.HOUSE_KEEPER) {
    return [
      { id: 'pending_tasks', label: 'Pending tasks', value: metrics.pendingTasks || 0, required_permissions: ['operations:read'] },
      { id: 'in_progress_tasks', label: 'Tasks in progress', value: metrics.inProgressTasks || 0, required_permissions: ['operations:read'] },
      { id: 'overdue_tasks', label: 'Overdue tasks', value: metrics.overdueTasks || 0, required_permissions: ['operations:read'] },
      { id: 'completed_today', label: 'Tasks completed today', value: metrics.completedToday || 0, required_permissions: ['operations:read'] },
      { id: 'throughput', label: 'Completion throughput', value: metrics.throughput || 0, required_permissions: ['operations:read'] },
    ];
  }

  if (packId === ROLE_PACKS.AMBULANCE_OPERATOR) {
    return [
      { id: 'dispatches_today', label: 'Dispatches today', value: metrics.dispatchesToday || 0, required_permissions: ['emergency:read'] },
      { id: 'active_trips', label: 'Active trips', value: metrics.activeTrips || 0, required_permissions: ['emergency:read'] },
      { id: 'critical_cases', label: 'Critical emergencies', value: metrics.criticalCases || 0, required_permissions: ['emergency:read'] },
      { id: 'fleet_available', label: 'Fleet available', value: metrics.fleetAvailable || 0, required_permissions: ['emergency:read'] },
      { id: 'fleet_out', label: 'Fleet out of service', value: metrics.fleetOut || 0, required_permissions: ['operations:read'] },
    ];
  }

  if (packId === ROLE_PACKS.UNIT_MANAGER) {
    return [
      { id: 'unit_census', label: 'Unit census', value: metrics.unitCensus || metrics.activeAdmissions || 0, required_permissions: ['unit:read'] },
      { id: 'staff_on_shift', label: 'Staff on shift', value: metrics.staffOnShift || metrics.shiftsToday || 0, required_permissions: ['hr:read'] },
      { id: 'open_roster_gaps', label: 'Open roster gaps', value: metrics.openRosterGaps || metrics.unassignedShifts || 0, required_permissions: ['roster:read'] },
      { id: 'pending_leave_requests', label: 'Pending leave requests', value: metrics.pendingLeaves || 0, required_permissions: ['hr:read'] },
      { id: 'coverage_risk', label: 'Coverage risk', value: metrics.coverageRisk || 0, required_permissions: ['roster:read'] },
      { id: 'unit_blockers', label: 'Unit blockers', value: metrics.unitBlockers || 0, required_permissions: ['unit:read'] },
    ];
  }

  if (packId === ROLE_PACKS.WARD_MANAGER) {
    return [
      { id: 'ward_census', label: 'Ward census', value: metrics.wardCensus || metrics.activeAdmissions || 0, required_permissions: ['clinical:read'] },
      { id: 'occupied_beds', label: 'Occupied beds', value: metrics.occupiedBeds || 0, required_permissions: ['operations:read'] },
      { id: 'pending_nursing_tasks', label: 'Pending nursing tasks', value: metrics.pendingNursingTasks || metrics.transferQueue || 0, required_permissions: ['clinical:read'] },
      { id: 'handover_risks', label: 'Handover risks', value: metrics.handoverRisks || 0, required_permissions: ['clinical:read'] },
      { id: 'staff_on_shift', label: 'Staff on shift', value: metrics.staffOnShift || metrics.shiftsToday || 0, required_permissions: ['hr:read'] },
      { id: 'discharge_delays', label: 'Discharge delays', value: metrics.dischargeDelays || 0, required_permissions: ['clinical:read'] },
    ];
  }

  if (packId === ROLE_PACKS.ICU_MANAGER) {
    return [
      { id: 'icu_census', label: 'ICU census', value: metrics.icuCensus || metrics.activeAdmissions || 0, required_permissions: ['clinical:read'] },
      { id: 'critical_patient_alerts', label: 'Critical patient alerts', value: metrics.criticalPatientAlerts || metrics.criticalLabs || 0, required_permissions: ['clinical:read'] },
      { id: 'icu_beds_occupied', label: 'ICU beds occupied', value: metrics.icuBedsOccupied || metrics.occupiedBeds || 0, required_permissions: ['clinical:read'] },
      { id: 'transfer_readiness', label: 'Transfer readiness', value: metrics.transferReadiness || metrics.transferQueue || 0, required_permissions: ['patient:read'] },
      { id: 'staff_coverage', label: 'Staff coverage', value: metrics.staffCoverage || metrics.shiftsToday || 0, required_permissions: ['hr:read'] },
      { id: 'open_escalations', label: 'Open escalations', value: metrics.openEscalations || 0, required_permissions: ['clinical:read'] },
    ];
  }

  if (packId === ROLE_PACKS.THEATRE_MANAGER) {
    return [
      { id: 'procedures_today', label: 'Procedures today', value: metrics.proceduresToday || 0, required_permissions: ['clinical:read'] },
      { id: 'ready_for_theatre', label: 'Ready for theatre', value: metrics.readyForTheatre || 0, required_permissions: ['clinical:read'] },
      { id: 'in_theatre', label: 'In theatre', value: metrics.inTheatre || 0, required_permissions: ['clinical:read'] },
      { id: 'post_op_handovers_pending', label: 'Post-op handovers pending', value: metrics.postOpHandoversPending || 0, required_permissions: ['clinical:read'] },
      { id: 'cancellations_or_delays', label: 'Cancellations or delays', value: metrics.cancellationsOrDelays || 0, required_permissions: ['clinical:read'] },
      { id: 'theatre_staff_coverage', label: 'Theatre staff coverage', value: metrics.theatreStaffCoverage || metrics.shiftsToday || 0, required_permissions: ['hr:read'] },
    ];
  }

  if (packId === ROLE_PACKS.HOUSEKEEPING_MANAGER) {
    return [
      { id: 'pending_cleaning_tasks', label: 'Pending cleaning tasks', value: metrics.pendingCleaningTasks || metrics.pendingTasks || 0, required_permissions: ['operations:read'] },
      { id: 'unassigned_cleaning_tasks', label: 'Unassigned cleaning tasks', value: metrics.unassignedCleaningTasks || 0, required_permissions: ['operations:read'] },
      { id: 'in_progress_cleaning_tasks', label: 'In-progress cleaning tasks', value: metrics.inProgressCleaningTasks || metrics.inProgressTasks || 0, required_permissions: ['operations:read'] },
      { id: 'overdue_cleaning_tasks', label: 'Overdue cleaning tasks', value: metrics.overdueCleaningTasks || metrics.overdueTasks || 0, required_permissions: ['operations:read'] },
      { id: 'rooms_ready', label: 'Rooms ready', value: metrics.roomsReady || 0, required_permissions: ['operations:read'] },
      { id: 'housekeeping_staff_on_shift', label: 'Housekeeping staff on shift', value: metrics.housekeepingStaffOnShift || metrics.shiftsToday || 0, required_permissions: ['hr:read'] },
    ];
  }

  if (packId === ROLE_PACKS.BIOMED_MANAGER) {
    return [
      { id: 'open_work_orders', label: 'Open work orders', value: metrics.openWorkOrders || 0, required_permissions: ['biomed:write'] },
      { id: 'high_priority_work_orders', label: 'High-priority work orders', value: metrics.highPriorityWorkOrders || metrics.highPriority || 0, required_permissions: ['biomed:write'] },
      { id: 'active_downtime', label: 'Active downtime', value: metrics.activeDowntime || 0, required_permissions: ['biomed:read'] },
      { id: 'open_incidents', label: 'Open incidents', value: metrics.openIncidents || 0, required_permissions: ['biomed:read'] },
      { id: 'overdue_maintenance', label: 'Overdue maintenance', value: metrics.overdueMaintenance || 0, required_permissions: ['biomed:read'] },
      { id: 'technician_load', label: 'Technician load', value: metrics.technicianLoad || 0, required_permissions: ['biomed:read'] },
    ];
  }

  if (packId === ROLE_PACKS.MORTUARY_STAFF) {
    return [
      { id: 'active_mortuary_cases', label: 'Active mortuary cases', value: metrics.activeMortuaryCases || 0, required_permissions: ['mortuary:read'] },
      { id: 'storage_assignments', label: 'Storage assignments', value: metrics.storageAssignments || 0, required_permissions: ['mortuary:read'] },
      { id: 'custody_events_due', label: 'Custody events due', value: metrics.custodyEventsDue || 0, required_permissions: ['mortuary:read'] },
      { id: 'viewings_today', label: 'Viewings today', value: metrics.viewingsToday || 0, required_permissions: ['mortuary:read'] },
      { id: 'post_mortem_requests', label: 'Post-mortem requests', value: metrics.postMortemRequests || 0, required_permissions: ['mortuary:read'] },
      { id: 'billable_events_to_capture', label: 'Billable events to capture', value: metrics.billableEventsToCapture || 0, required_permissions: ['mortuary:billing_event'] },
    ];
  }

  if (packId === ROLE_PACKS.MORTUARY_MANAGER) {
    return [
      { id: 'active_mortuary_cases', label: 'Active mortuary cases', value: metrics.activeMortuaryCases || 0, required_permissions: ['mortuary:read'] },
      { id: 'storage_occupancy', label: 'Storage occupancy', value: metrics.storageOccupancy || 0, format: 'percent', required_permissions: ['mortuary:read'] },
      { id: 'releases_awaiting_approval', label: 'Releases awaiting approval', value: metrics.releasesAwaitingApproval || 0, required_permissions: ['mortuary:approve'] },
      { id: 'custody_exceptions', label: 'Custody exceptions', value: metrics.custodyExceptions || 0, required_permissions: ['mortuary:read'] },
      { id: 'pending_post_mortem_requests', label: 'Pending post-mortem requests', value: metrics.pendingPostMortemRequests || 0, required_permissions: ['mortuary:read'] },
      { id: 'audit_exports_due', label: 'Audit exports due', value: metrics.auditExportsDue || 0, required_permissions: ['mortuary:audit'] },
    ];
  }

  if (packId === ROLE_PACKS.PATIENT_SAFE) {
    return [
      { id: 'my_upcoming_appointments', label: 'My upcoming appointments', value: metrics.myUpcomingAppointments || 0, required_permissions: ['patient:read'] },
      { id: 'my_open_bills', label: 'My open bills', value: metrics.myOpenBills || 0, required_permissions: ['billing:read'] },
      { id: 'my_prescriptions', label: 'My prescriptions', value: metrics.myPrescriptions || 0, required_permissions: ['pharmacy:read'] },
      { id: 'my_released_results', label: 'My released results', value: metrics.myReleasedResults || 0, required_permissions: ['lab:read'] },
      { id: 'my_messages', label: 'My messages', value: metrics.myMessages || 0, required_permissions: ['communications:read'] },
      { id: 'my_profile_status', label: 'My profile status', value: metrics.myProfileStatus || 0, format: 'percent', required_permissions: ['profile:read'] },
    ];
  }

  if (packId === ROLE_PACKS.LIMITED) {
    return [
      { id: 'profile_status', label: 'Profile status', value: metrics.profileStatus || 0, required_permissions: ['profile:read'] },
      { id: 'assigned_links', label: 'Assigned links', value: metrics.assignedLinks || 0, required_permissions: ['profile:read'] },
      { id: 'unread_messages', label: 'Unread messages', value: metrics.unreadMessages || 0, required_permissions: ['communications:read'] },
      { id: 'facility_notices', label: 'Facility notices', value: metrics.facilityNotices || 0, required_permissions: ['profile:read'] },
    ];
  }

  return [
    { id: 'patients_today', label: 'Patients added today', value: metrics.patientsToday || 0, required_permissions: ['patient:read'] },
    { id: 'appointments_today', label: 'Appointments today', value: metrics.appointmentsToday || 0, required_permissions: ['patient:read'] },
    { id: 'active_admissions', label: 'Active admissions', value: metrics.activeAdmissions || 0, required_permissions: ['patient:read'] },
    { id: 'open_invoices', label: 'Open invoices', value: metrics.openInvoices || 0, required_permissions: ['billing:read'] },
    { id: 'payments_today', label: 'Payments received today', value: metrics.paymentsToday || 0, format: 'currency', required_permissions: ['billing:read'] },
  ];
};

const metricsToRoleSummary = (packId, metrics = {}) =>
  withSummaryMetadata(packId, rawMetricsToRoleSummary(packId, metrics));

const buildDashboardSummary = async ({ query = {}, user = {}, repository }) => {
  try {
    const days = Number(query.days || 7);
    const mostSoldPeriod = query.most_sold_period || query.mostSoldPeriod || 'today';
    const mostSoldLimit = query.most_sold_limit || query.mostSoldLimit || 5;
    const mostSoldFrom = query.most_sold_from || query.mostSoldFrom || null;
    const mostSoldTo = query.most_sold_to || query.mostSoldTo || null;
    const effectiveRole = resolveDashboardRole(user);
    const roleProfileId = resolveProfileId(effectiveRole);
    const packId = resolvePackId(roleProfileId);
    const scope = await resolveScope(query, user, effectiveRole, repository);
    const resolvedUserId = user.id || user.user_id || user.userId || null;
    let effectiveScope = scope;
    if (packId === ROLE_PACKS.NURSE && resolvedUserId && repository.findNurseStaffContext) {
      const nurseStaffContext = await repository.findNurseStaffContext(
        resolvedUserId,
        scope
      );
      if (nurseStaffContext) {
        effectiveScope = { ...scope, ...nurseStaffContext };
      }
    }
    const includeOpdNotificationSignals = canSeeOpdNotificationSignals(user, effectiveRole);

    const [packData, unreadOpdNotifications] = await Promise.all([
      repository.getDashboardSummaryByPack({
        packId,
        scope: effectiveScope,
        days,
        mostSoldPeriod,
        mostSoldLimit,
        mostSoldFrom,
        mostSoldTo,
        userId: resolvedUserId,
        user,
      }),
      includeOpdNotificationSignals
        ? repository
            .countUnreadOpdNotifications({
              scope: effectiveScope,
              userId: resolvedUserId,
            })
            .catch(() => 0)
        : Promise.resolve(0),
    ]);

    const isPlatformAdmin = packId === ROLE_PACKS.SUPER_ADMIN;
    const isPharmacist = packId === ROLE_PACKS.PHARMACIST;

    const trendPoints = isPharmacist && Array.isArray(packData?.mostSold?.qty) && packData.mostSold.qty.length
      ? packData.mostSold.qty.map((item, index) => ({
          id: item.id || `drug_${index}`,
          label: item.label || item.id || `Drug ${index + 1}`,
          summary_label: item.summary_label || item.label || item.id || `Drug ${index + 1}`,
          value: Number(item.value || 0),
          date: null
        }))
      : buildTrendPoints(packData?.trendDates || [], days);
    const distribution = buildDistribution(
      packData?.statusCounts || {},
      packData?.statusAmounts || {}
    );
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
        title: isPlatformAdmin
          ? 'New tenant signups'
          : isPharmacist
            ? 'Most sold drugs (last month)'
            : `${days}-day trend`,
        subtitle: isPlatformAdmin
          ? 'Tenants registered per day'
          : isPharmacist
            ? 'Top drugs by quantity dispensed'
            : 'Aggregate trend points',
        points: trendPoints,
      },
      distribution: {
        title: isPlatformAdmin
          ? 'Subscription mix'
          : isPharmacist
            ? 'Order status mix'
            : 'Status distribution',
        subtitle: isPlatformAdmin
          ? 'Tenants by subscription status'
          : isPharmacist
            ? 'Pharmacy order pipeline'
            : 'Aggregate status mix',
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
      most_sold: isPharmacist ? (packData?.mostSold || { qty: [], amount: [], profit: [] }) : undefined,
      hasLiveData,
      generatedAt: new Date().toISOString(),
      scope: {
        tenant_id: effectiveScope.tenant_id || null,
        facility_id: effectiveScope.facility_id || null,
        nurse_context: effectiveScope.nurse_context || null,
        department_name: effectiveScope.department_name || null,
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
  resolveDashboardRole,
  resolvePackId,
  resolveProfileId,
  resolveScope,
  sanitizeSummaryPayload,
};
