/**
 * Dashboard widget service
 *
 * @module modules/dashboard-widget/services
 * @description Business logic layer for dashboard widget operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const dashboardWidgetRepository = require('@repositories/dashboard-widget/dashboard-widget.repository');
const { createAuditLog } = require('@lib/audit');
const {
  buildDashboardSummary: buildSharedDashboardSummary,
  metricsToRoleSummary: sharedMetricsToRoleSummary,
  resolveEffectiveRole: resolveSharedEffectiveRole,
  resolvePackId: resolveSharedPackId,
  resolveProfileId: resolveSharedProfileId,
  resolveScope: resolveSharedScope,
  sanitizeSummaryPayload: sanitizeSharedSummaryPayload,
} = require('@lib/dashboard/summary');
const { HttpError } = require('@lib/errors');
const { ROLES, ROLE_HIERARCHY, normalizeRoleName } = require('@config/roles');
const {
  buildPagination,
  buildSearchWhere,
  buildSinceFilter,
  buildSort,
  createAuditDiff,
  ensureVersionMatch,
  normalizeString,
  resolvePayloadIdentifier,
  resolveScopeIdsForList,
  resolveScopedContext,
  safeUpper,
} = require('@lib/reports/api');
const { serializeDashboardWidget } = require('@lib/reports/serializers');

const ROLE_PACKS = dashboardWidgetRepository.__private__?.ROLE_PACKS || {
  ADMIN: 'admin',
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
  AMBULANCE_OPERATOR: 'ambulance_operator'
};

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
  [ROLES.AMBULANCE_OPERATOR]: 'ambulance_operator'
});

const PROFILE_TO_PACK = Object.freeze({
  super_admin: ROLE_PACKS.ADMIN,
  tenant_admin: ROLE_PACKS.ADMIN,
  facility_admin: ROLE_PACKS.ADMIN,
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
  ambulance_operator: ROLE_PACKS.AMBULANCE_OPERATOR
});

const DASHBOARD_ALLOWLIST = Object.freeze({
  summaryCards: ['id', 'label', 'value', 'format'],
  trendPoints: ['id', 'date', 'value'],
  distributionSegments: ['id', 'label', 'value', 'color'],
  highlights: ['id', 'label', 'value', 'context', 'variant'],
  queue: ['id', 'title', 'meta', 'statusLabel', 'statusVariant'],
  alerts: ['id', 'title', 'meta', 'severityLabel', 'severityVariant'],
  activity: ['id', 'title', 'meta', 'timeLabel']
});

const pickFields = (value, allowedFields = []) => {
  const source = value && typeof value === 'object' ? value : {};
  return allowedFields.reduce((acc, field) => {
    if (source[field] !== undefined) acc[field] = source[field];
    return acc;
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
    )
  },
  distribution: {
    title: value?.distribution?.title || '',
    subtitle: value?.distribution?.subtitle || '',
    total: Number(value?.distribution?.total || 0),
    segments: (Array.isArray(value?.distribution?.segments) ? value.distribution.segments : []).map((item) =>
      pickFields(item, DASHBOARD_ALLOWLIST.distributionSegments)
    )
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
  )
});

const WIDGET_SORT_FIELDS = ['created_at', 'updated_at', 'name', 'sort_order', 'placement', 'widget_type'];

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

const resolveScope = async (query = {}, user = {}, effectiveRole = null) => {
  const userScope = {
    tenant_id: user.tenant_id || user.tenantId || null,
    facility_id: user.facility_id || user.facilityId || null,
    branch_id: user.branch_id || user.branchId || null
  };

  if (effectiveRole === ROLES.SUPER_ADMIN) {
    const tenantId = query.tenant_id || userScope.tenant_id || null;
    const facilityId = query.facility_id || userScope.facility_id || null;
    const branchId = query.branch_id || userScope.branch_id || null;

    if (!tenantId) {
      throw new HttpError('errors.validation.field.required', 422, [{ field: 'tenant_id' }]);
    }

    let resolvedFacilityId = facilityId;
    if (branchId) {
      const branchFacilityId = await dashboardWidgetRepository.resolveBranchFacilityScope(tenantId, branchId);
      if (resolvedFacilityId && branchFacilityId && resolvedFacilityId !== branchFacilityId) {
        throw new HttpError('errors.validation.invalid', 422, [{ field: 'branch_id' }]);
      }
      if (!resolvedFacilityId) resolvedFacilityId = branchFacilityId;
    }

    return {
      tenant_id: tenantId,
      facility_id: resolvedFacilityId || null,
      branch_id: branchId
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
  const index = new Map(dates.map((day) => [day.toISOString().slice(0, 10), 0]));

  for (const item of dateValues) {
    const parsed = new Date(item);
    if (Number.isNaN(parsed.getTime())) continue;
    const key = parsed.toISOString().slice(0, 10);
    if (!index.has(key)) continue;
    index.set(key, (index.get(key) || 0) + 1);
  }

  return dates.map((day) => {
    const key = day.toISOString().slice(0, 10);
    return {
      id: key,
      date: key,
      value: index.get(key) || 0
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
    color: colors[index % colors.length]
  }));
  return {
    total: segments.reduce((sum, item) => sum + Number(item.value || 0), 0),
    segments
  };
};

const avg = (values = []) => {
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
  statusVariant
});

const alertItem = (id, title, count, severityLabel, severityVariant, noun) => ({
  id,
  title,
  meta: `${Number(count || 0)} ${noun}`,
  severityLabel,
  severityVariant
});

const activityItem = (id, title, count) => ({
  id,
  title,
  meta: `${Number(count || 0)} updates`,
  timeLabel: 'last 24h'
});

const metricsToRoleSummary = (packId, metrics = {}) => {
  if (packId === ROLE_PACKS.DOCTOR) {
    return [
      { id: 'assigned', label: 'Assigned consultations', value: metrics.assigned || 0 },
      { id: 'in_progress', label: 'Consultations in progress', value: metrics.inProgress || 0 },
      { id: 'completed', label: 'Completed consultations', value: metrics.completed || 0 },
      { id: 'admissions', label: 'Active admissions', value: metrics.activeAdmissions || 0 },
      { id: 'critical_labs', label: 'Critical lab signals', value: metrics.criticalLabs || 0 }
    ];
  }

  if (packId === ROLE_PACKS.NURSE) {
    return [
      { id: 'inpatient_flow', label: 'Active inpatients', value: metrics.activeAdmissions || 0 },
      { id: 'med_admin_today', label: 'Medication administrations today', value: metrics.medAdminToday || 0 },
      { id: 'transfer_queue', label: 'Transfer queue', value: metrics.transferQueue || 0 },
      { id: 'critical_labs', label: 'Critical lab signals', value: metrics.criticalLabs || 0 },
      { id: 'discharge_pressure', label: 'Discharge pressure', value: metrics.activeAdmissions || 0 }
    ];
  }

  if (packId === ROLE_PACKS.LAB_TECH) {
    return [
      { id: 'orders_today', label: 'Lab orders today', value: metrics.ordersToday || 0 },
      { id: 'in_process', label: 'Orders in process', value: metrics.inProcess || 0 },
      { id: 'pending_results', label: 'Pending results', value: metrics.pending || 0 },
      { id: 'critical_results', label: 'Critical results', value: metrics.critical || 0 },
      { id: 'completed_orders', label: 'Completed orders', value: metrics.completed || 0 }
    ];
  }

  if (packId === ROLE_PACKS.RADIOLOGY_TECH) {
    return [
      { id: 'orders_today', label: 'Radiology orders today', value: metrics.ordersToday || 0 },
      { id: 'in_process', label: 'Studies in process', value: metrics.inProcess || 0 },
      { id: 'draft_reports', label: 'Draft reports', value: metrics.pending || 0 },
      { id: 'final_reports', label: 'Final reports', value: metrics.final || 0 },
      { id: 'completed_orders', label: 'Completed orders', value: metrics.completed || 0 }
    ];
  }

  if (packId === ROLE_PACKS.PHARMACIST) {
    return [
      { id: 'orders_today', label: 'Medication orders today', value: metrics.ordersToday || 0 },
      { id: 'pending_dispense', label: 'Pending dispense workload', value: metrics.pendingDispense || 0 },
      { id: 'dispensed_today', label: 'Dispensed today', value: metrics.dispensedToday || 0 },
      { id: 'low_stock', label: 'Low stock pressure', value: metrics.lowStock || 0 },
      { id: 'critical_stock', label: 'Critical stock pressure', value: metrics.criticalStock || 0 }
    ];
  }

  if (packId === ROLE_PACKS.RECEPTIONIST) {
    return [
      { id: 'registrations_today', label: 'Registrations today', value: metrics.registrationsToday || 0 },
      { id: 'desk_queue', label: 'Appointment desk queue', value: metrics.appointmentDeskQueue || 0 },
      { id: 'no_show_pressure', label: 'No-show pressure', value: metrics.noShowPressure || 0 },
      { id: 'front_billing_queue', label: 'Front billing queue', value: metrics.frontBillingQueue || 0 },
      { id: 'appointments_today', label: 'Appointments today', value: metrics.appointmentsToday || 0 }
    ];
  }

  if (packId === ROLE_PACKS.BILLING) {
    return [
      { id: 'invoices_today', label: 'Invoices issued today', value: metrics.invoicesToday || 0 },
      { id: 'overdue_invoices', label: 'Overdue invoices', value: metrics.overdueInvoices || 0 },
      { id: 'open_balances', label: 'Open balances', value: metrics.openBalances || 0 },
      { id: 'collections_today', label: 'Collections today', value: metrics.collectionsToday || 0, format: 'currency' },
      { id: 'refunds_today', label: 'Refunds today', value: metrics.refundsToday || 0, format: 'currency' }
    ];
  }

  if (packId === ROLE_PACKS.OPERATIONS) {
    return [
      { id: 'occupied_beds', label: 'Occupied beds', value: metrics.occupiedBeds || 0 },
      { id: 'total_beds', label: 'Total beds', value: metrics.totalBeds || 0 },
      { id: 'maintenance_open', label: 'Open maintenance requests', value: metrics.openMaintenance || 0 },
      { id: 'low_stock_pressure', label: 'Low stock pressure', value: metrics.lowStockPressure || 0 },
      { id: 'housekeeping_backlog', label: 'Housekeeping backlog', value: metrics.housekeepingBacklog || 0 }
    ];
  }

  if (packId === ROLE_PACKS.HR) {
    return [
      { id: 'active_staff', label: 'Active staff profiles', value: metrics.activeStaff || 0 },
      { id: 'shifts_today', label: 'Shifts today', value: metrics.shiftsToday || 0 },
      { id: 'pending_leaves', label: 'Pending leave approvals', value: metrics.pendingLeaves || 0 },
      { id: 'staffing_backlog', label: 'Staffing backlog', value: metrics.staffingBacklog || 0 },
      { id: 'unassigned_shifts', label: 'Unassigned shifts', value: metrics.unassignedShifts || 0 }
    ];
  }

  if (packId === ROLE_PACKS.BIOMED) {
    return [
      { id: 'open_work_orders', label: 'Open work orders', value: metrics.openWorkOrders || 0 },
      { id: 'open_incidents', label: 'Open incidents', value: metrics.openIncidents || 0 },
      { id: 'active_downtime', label: 'Active downtime events', value: metrics.activeDowntime || 0 },
      { id: 'critical_service_risk', label: 'Critical service-risk indicators', value: metrics.criticalServiceRisk || 0 },
      { id: 'high_priority', label: 'High-priority work orders', value: metrics.highPriority || 0 }
    ];
  }

  if (packId === ROLE_PACKS.HOUSE_KEEPER) {
    return [
      { id: 'pending_tasks', label: 'Pending tasks', value: metrics.pendingTasks || 0 },
      { id: 'in_progress_tasks', label: 'Tasks in progress', value: metrics.inProgressTasks || 0 },
      { id: 'overdue_tasks', label: 'Overdue tasks', value: metrics.overdueTasks || 0 },
      { id: 'completed_today', label: 'Tasks completed today', value: metrics.completedToday || 0 },
      { id: 'throughput', label: 'Completion throughput', value: metrics.throughput || 0 }
    ];
  }

  if (packId === ROLE_PACKS.AMBULANCE_OPERATOR) {
    return [
      { id: 'dispatches_today', label: 'Dispatches today', value: metrics.dispatchesToday || 0 },
      { id: 'active_trips', label: 'Active trips', value: metrics.activeTrips || 0 },
      { id: 'critical_cases', label: 'Critical emergencies', value: metrics.criticalCases || 0 },
      { id: 'fleet_available', label: 'Fleet available', value: metrics.fleetAvailable || 0 },
      { id: 'fleet_out', label: 'Fleet out of service', value: metrics.fleetOut || 0 }
    ];
  }

  return [
    { id: 'patients_today', label: 'Patients added today', value: metrics.patientsToday || 0 },
    { id: 'appointments_today', label: 'Appointments today', value: metrics.appointmentsToday || 0 },
    { id: 'active_admissions', label: 'Active admissions', value: metrics.activeAdmissions || 0 },
    { id: 'open_invoices', label: 'Open invoices', value: metrics.openInvoices || 0 },
    { id: 'payments_today', label: 'Payments received today', value: metrics.paymentsToday || 0, format: 'currency' }
  ];
};

const assertScopedWidget = async (id, user = {}) => {
  const scoped = await resolveScopedContext({}, user);
  const widget = await dashboardWidgetRepository.findById(id);
  if (!widget || widget.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.dashboard_widget.not_found', 404);
  }
  return widget;
};

const listDashboardWidgets = async (filters, page, limit, sortBy, order, user = {}) => {
  try {
    const scoped = await resolveScopeIdsForList({ filters, user });
    const skip = (page - 1) * limit;
    const whereClause = {
      tenant_id: scoped.tenant_id,
      ...buildSinceFilter(filters.since),
      ...buildSearchWhere(filters.search, ['name', 'placement']),
    };

    if (scoped.report_definition_id) whereClause.report_definition_id = scoped.report_definition_id;
    if (normalizeString(filters.report_definition_id) && !scoped.report_definition_id) {
      whereClause.report_definition_id = '__none__';
    }
    if (normalizeString(filters.name)) {
      whereClause.name = { contains: normalizeString(filters.name), mode: 'insensitive' };
    }
    if (normalizeString(filters.placement)) whereClause.placement = normalizeString(filters.placement);
    if (normalizeString(filters.widget_type)) whereClause.widget_type = safeUpper(filters.widget_type);
    if (filters.is_pinned !== undefined) whereClause.is_pinned = Boolean(filters.is_pinned);

    const orderBy = buildSort(sortBy, order, 'sort_order', WIDGET_SORT_FIELDS);
    const [dashboardWidgets, total] = await Promise.all([
      dashboardWidgetRepository.findMany(whereClause, skip, limit, orderBy, {}),
      dashboardWidgetRepository.count(whereClause)
    ]);

    return {
      dashboardWidgets: dashboardWidgets.map(serializeDashboardWidget),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getDashboardWidgetById = async (id, user = {}) => {
  try {
    return serializeDashboardWidget(await assertScopedWidget(id, user));
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createDashboardWidget = async (data, context = {}) => {
  try {
    const scoped = await resolveScopedContext(data, context.user || {});
    const payload = {
      tenant_id: scoped.tenant_id,
      report_definition_id: await resolvePayloadIdentifier({
        value: data.report_definition_id,
        model: 'report_definition',
        field: 'report_definition_id',
        tenant_id: scoped.tenant_id,
        nullable: true,
      }),
      name: normalizeString(data.name),
      widget_type: safeUpper(data.widget_type),
      role_scope_json: data.role_scope_json || null,
      placement: normalizeString(data.placement) || null,
      sort_order: Number(data.sort_order || 0),
      is_pinned: Boolean(data.is_pinned),
      config_json: data.config_json || {},
    };

    const dashboardWidget = await dashboardWidgetRepository.create(payload);

    await createAuditLog({
      tenant_id: payload.tenant_id,
      user_id: context.user_id,
      action: 'CREATE',
      entity: 'dashboard_widget',
      entity_id: dashboardWidget.id,
      diff: { after: serializeDashboardWidget(dashboardWidget) },
      ip_address: context.ip_address
    });

    return serializeDashboardWidget(dashboardWidget);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateDashboardWidget = async (id, data, context = {}) => {
  try {
    const before = await assertScopedWidget(id, context.user || {});
    ensureVersionMatch({
      current: before,
      expectedVersion: data.version,
      serializer: serializeDashboardWidget,
    });

    const updateData = {
      version: Number(before.version || 1) + 1,
    };
    if (data.report_definition_id !== undefined) {
      updateData.report_definition_id = await resolvePayloadIdentifier({
        value: data.report_definition_id,
        model: 'report_definition',
        field: 'report_definition_id',
        tenant_id: before.tenant_id,
        nullable: true,
      });
    }
    if (data.name !== undefined) updateData.name = normalizeString(data.name);
    if (data.widget_type !== undefined) updateData.widget_type = safeUpper(data.widget_type);
    if (data.role_scope_json !== undefined) updateData.role_scope_json = data.role_scope_json || null;
    if (data.placement !== undefined) updateData.placement = normalizeString(data.placement) || null;
    if (data.sort_order !== undefined) updateData.sort_order = Number(data.sort_order || 0);
    if (data.is_pinned !== undefined) updateData.is_pinned = Boolean(data.is_pinned);
    if (data.config_json !== undefined) updateData.config_json = data.config_json || {};

    const dashboardWidget = await dashboardWidgetRepository.update(id, updateData);

    await createAuditLog({
      tenant_id: before.tenant_id,
      user_id: context.user_id,
      action: 'UPDATE',
      entity: 'dashboard_widget',
      entity_id: dashboardWidget.id,
      diff: createAuditDiff(before, dashboardWidget, [
        'report_definition_id',
        'name',
        'widget_type',
        'placement',
        'sort_order',
        'is_pinned',
        'version',
      ]),
      ip_address: context.ip_address
    });

    return serializeDashboardWidget(dashboardWidget);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteDashboardWidget = async (id, context = {}) => {
  try {
    const before = await assertScopedWidget(id, context.user || {});

    await dashboardWidgetRepository.softDelete(id);

    await createAuditLog({
      tenant_id: before.tenant_id,
      user_id: context.user_id,
      action: 'DELETE',
      entity: 'dashboard_widget',
      entity_id: id,
      diff: { before: serializeDashboardWidget(before) },
      ip_address: context.ip_address
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get role-isolated dashboard summary
 *
 * @param {Object} query - Summary query params
 * @param {Object} user - Authenticated user context
 * @returns {Promise<Object>} Aggregate-only summary payload
 */
const getDashboardSummary = async (query = {}, user = {}) => {
  try {
    return await buildSharedDashboardSummary({
      query,
      user,
      repository: dashboardWidgetRepository,
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listDashboardWidgets,
  getDashboardWidgetById,
  createDashboardWidget,
  updateDashboardWidget,
  deleteDashboardWidget,
  getDashboardSummary,
  __private__: {
    resolveEffectiveRole: resolveSharedEffectiveRole,
    resolveProfileId: resolveSharedProfileId,
    resolvePackId: resolveSharedPackId,
    resolveScope: resolveSharedScope,
    sanitizeSummaryPayload: sanitizeSharedSummaryPayload,
    metricsToRoleSummary: sharedMetricsToRoleSummary
  }
};
