const { HttpError } = require('@lib/errors');
const { ROLES, ROLE_HIERARCHY, normalizeRoleName } = require('@config/roles');

const ROLE_PACKS = Object.freeze({
  ADMIN: 'admin',
  DOCTOR: 'doctor',
  NURSE: 'nurse',
  LAB_TECH: 'lab_tech',
  PHARMACIST: 'pharmacist',
  RECEPTIONIST: 'receptionist',
  BILLING: 'billing',
  OPERATIONS: 'operations',
  HR: 'hr',
  BIOMED: 'biomed',
  HOUSE_KEEPER: 'house_keeper',
  AMBULANCE_OPERATOR: 'ambulance_operator',
});

const ROLE_PROFILE_IDS = Object.freeze({
  [ROLES.SUPER_ADMIN]: 'super_admin',
  [ROLES.TENANT_ADMIN]: 'tenant_admin',
  [ROLES.FACILITY_ADMIN]: 'facility_admin',
  [ROLES.DOCTOR]: 'doctor',
  [ROLES.NURSE]: 'nurse',
  [ROLES.LAB_TECH]: 'lab_tech',
  [ROLES.PHARMACIST]: 'pharmacist',
  [ROLES.RECEPTIONIST]: 'receptionist',
  [ROLES.BILLING]: 'billing',
  [ROLES.OPERATIONS]: 'operations',
  [ROLES.HR]: 'hr',
  [ROLES.BIOMED]: 'biomed',
  [ROLES.HOUSE_KEEPER]: 'house_keeper',
  [ROLES.AMBULANCE_OPERATOR]: 'ambulance_operator',
});

const PROFILE_TO_PACK = Object.freeze({
  super_admin: ROLE_PACKS.ADMIN,
  tenant_admin: ROLE_PACKS.ADMIN,
  facility_admin: ROLE_PACKS.ADMIN,
  doctor: ROLE_PACKS.DOCTOR,
  nurse: ROLE_PACKS.NURSE,
  lab_tech: ROLE_PACKS.LAB_TECH,
  pharmacist: ROLE_PACKS.PHARMACIST,
  receptionist: ROLE_PACKS.RECEPTIONIST,
  billing: ROLE_PACKS.BILLING,
  operations: ROLE_PACKS.OPERATIONS,
  hr: ROLE_PACKS.HR,
  biomed: ROLE_PACKS.BIOMED,
  house_keeper: ROLE_PACKS.HOUSE_KEEPER,
  ambulance_operator: ROLE_PACKS.AMBULANCE_OPERATOR,
});

const DASHBOARD_ALLOWLIST = Object.freeze({
  summaryCards: ['id', 'label', 'value', 'format'],
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

const resolveProfileId = (effectiveRole) => ROLE_PROFILE_IDS[effectiveRole] || 'operations';
const resolvePackId = (profileId) => PROFILE_TO_PACK[profileId] || ROLE_PACKS.ADMIN;

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

const metricsToRoleSummary = (packId, metrics = {}) => {
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

  return [
    { id: 'patients_today', label: 'Patients added today', value: metrics.patientsToday || 0 },
    { id: 'appointments_today', label: 'Appointments today', value: metrics.appointmentsToday || 0 },
    { id: 'active_admissions', label: 'Active admissions', value: metrics.activeAdmissions || 0 },
    { id: 'open_invoices', label: 'Open invoices', value: metrics.openInvoices || 0 },
    { id: 'payments_today', label: 'Payments received today', value: metrics.paymentsToday || 0, format: 'currency' },
  ];
};

const buildDashboardSummary = async ({ query = {}, user = {}, repository }) => {
  try {
    const days = Number(query.days || 7);
    const effectiveRole = resolveEffectiveRole(user);
    const roleProfileId = resolveProfileId(effectiveRole);
    const packId = resolvePackId(roleProfileId);
    const scope = await resolveScope(query, user, effectiveRole, repository);
    const resolvedUserId = user.id || user.user_id || user.userId || null;

    const [packData, unreadOpdNotifications] = await Promise.all([
      repository.getDashboardSummaryByPack({
        packId,
        scope,
        days,
        userId: resolvedUserId,
      }),
      repository
        .countUnreadOpdNotifications({
          scope,
          userId: resolvedUserId,
        })
        .catch(() => 0),
    ]);

    const trendPoints = buildTrendPoints(packData?.trendDates || [], days);
    const distribution = buildDistribution(packData?.statusCounts || {});
    const summaryCards = metricsToRoleSummary(packId, packData?.metrics || {});
    const opdNotificationsPendingAttention = Number(unreadOpdNotifications || 0);

    summaryCards.push({
      id: 'opd_notifications_attention',
      label: 'OPD notifications pending attention',
      value: opdNotificationsPendingAttention,
    });

    const hasLiveData =
      summaryCards.some((item) => Number(item.value || 0) > 0) ||
      trendPoints.some((item) => Number(item.value || 0) > 0) ||
      Number(distribution.total || 0) > 0 ||
      opdNotificationsPendingAttention > 0;

    const queue = [
      queueItem('queue_primary', 'Primary queue', summaryCards[0]?.value || 0, 'Current', 'primary', 'items'),
      queueItem('queue_secondary', 'Secondary queue', summaryCards[1]?.value || 0, 'Monitor', 'warning', 'items'),
      queueItem(
        'queue_opd_attention',
        'OPD notifications',
        opdNotificationsPendingAttention,
        opdNotificationsPendingAttention > 0 ? 'Pending attention' : 'No pending items',
        opdNotificationsPendingAttention > 0 ? 'error' : 'success',
        'notifications'
      ),
    ];

    const alerts = [
      alertItem('alert_primary', 'Primary alert pressure', summaryCards[2]?.value || 0, 'Monitor', 'warning', 'signals'),
      alertItem('alert_secondary', 'Secondary alert pressure', summaryCards[3]?.value || 0, 'Watch', 'primary', 'signals'),
      alertItem(
        'alert_opd_attention',
        'OPD notifications needing attention',
        opdNotificationsPendingAttention,
        opdNotificationsPendingAttention > 0 ? 'Action required' : 'Stable',
        opdNotificationsPendingAttention > 0 ? 'error' : 'success',
        'notifications'
      ),
    ];

    const activity = [
      ...Object.entries(packData?.activity || {}).map(([key, value]) =>
        activityItem(`activity_${key}`, `${key.replace(/_/g, ' ')} updated`, value)
      ),
      activityItem('activity_opd_attention', 'opd notifications pending attention', opdNotificationsPendingAttention),
    ];

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
      {
        id: 'opd_notification_attention',
        label: 'OPD notification attention',
        value: `${opdNotificationsPendingAttention}`,
        context: 'Unread OPD flow updates requiring attendance',
      },
    ];

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
