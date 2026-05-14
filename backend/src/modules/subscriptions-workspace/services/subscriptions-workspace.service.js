const { HttpError } = require('@lib/errors');
const { ROLES } = require('@config/roles');
const repository = require('@repositories/subscriptions-workspace/subscriptions-workspace.repository');
const {
  SUBSCRIPTIONS_BILLING_CYCLES,
  SUBSCRIPTIONS_CHANGE_STATUS_VALUES,
  SUBSCRIPTIONS_FIT_STATUS_VALUES,
  SUBSCRIPTIONS_LICENSE_TYPES,
  SUBSCRIPTIONS_PANEL_RESOURCE_MAP,
  SUBSCRIPTIONS_PANELS,
  SUBSCRIPTIONS_PENDING_CHANGE_STATUSES,
  SUBSCRIPTIONS_PLAN_TIERS,
  SUBSCRIPTIONS_RESOURCE_PANEL_MAP,
  SUBSCRIPTIONS_RESOURCES,
  SUBSCRIPTIONS_STATUS_VALUES,
} = require('@lib/subscriptions/constants');
const {
  safePublicId,
  serializeLicense,
  serializeModule,
  serializeModuleSubscription,
  serializeSubscription,
  serializeSubscriptionInvoice,
  serializeSubscriptionPlan,
} = require('@lib/subscriptions/serializers');
const { resolveIdentifierForFilter, resolvePublicIdentifier } = require('@lib/billing/identifiers');

const text = (value) => String(value || '').trim();
const numberValue = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};
const toUpper = (value) => text(value).toUpperCase();

const DATE_PRESET_VALUES = new Set([
  'today',
  'last_30_days',
  'next_30_days',
  'next_renewal',
  'custom',
]);

const toDateOrNull = (value, fieldName) => {
  const normalized = text(value);
  if (!normalized) return null;
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: fieldName }]);
  }
  return parsed;
};

const startOfDay = (value) => {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date;
};

const endOfDay = (value) => {
  const date = new Date(value);
  date.setHours(23, 59, 59, 999);
  return date;
};

const shiftDays = (value, days) => {
  const date = new Date(value);
  date.setDate(date.getDate() + days);
  return date;
};

const resolveDateWindow = (query = {}, resource = 'subscriptions') => {
  const preset = text(query.datePreset || query.date_preset).toLowerCase();
  const explicitFrom = toDateOrNull(query.from, 'from');
  const explicitTo = toDateOrNull(query.to, 'to');
  const now = new Date();

  if (explicitFrom && explicitTo && explicitFrom.getTime() > explicitTo.getTime()) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'from' }, { field: 'to' }]);
  }

  if (!explicitFrom && !explicitTo && preset && !DATE_PRESET_VALUES.has(preset)) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'datePreset' }]);
  }

  let field = 'updated_at';
  let from = explicitFrom;
  let to = explicitTo;

  if (resource === 'subscription-invoices') {
    field = 'invoice.issued_at';
  } else if (resource === 'licenses') {
    field = 'issued_at';
  }

  if (!from && !to) {
    if (preset === 'today') {
      from = startOfDay(now);
      to = endOfDay(now);
    } else if (preset === 'last_30_days') {
      from = shiftDays(startOfDay(now), -29);
      to = endOfDay(now);
    } else if (preset === 'next_30_days') {
      from = startOfDay(now);
      to = endOfDay(shiftDays(now, 30));
    } else if (preset === 'next_renewal') {
      from = startOfDay(now);
      to = null;
    }
  }

  if ((preset === 'next_30_days' || preset === 'next_renewal') && resource === 'subscriptions') {
    field = 'end_date';
  }

  if ((preset === 'next_30_days' || preset === 'next_renewal') && resource === 'licenses') {
    field = 'expires_at';
  }

  if (!from && !to) return null;
  return { field, from, to };
};

const defaultSortField = (resource) => {
  if (resource === 'subscription-invoices') return 'issued_at';
  if (resource === 'licenses') return 'expires_at';
  if (resource === 'subscription-plans') return 'tier_code';
  return 'updated_at';
};

const resolveOrderBy = (resource, sortBy, order = 'desc') => {
  const direction = text(order).toLowerCase() === 'asc' ? 'asc' : 'desc';
  const requestedField = text(sortBy).toLowerCase() || defaultSortField(resource);

  const scalarSortMap = {
    'subscription-plans': new Map([
      ['display_id', 'human_friendly_id'],
      ['name', 'name'],
      ['tier_code', 'tier_code'],
      ['billing_cycle', 'billing_cycle'],
      ['price', 'price'],
      ['updated_at', 'updated_at'],
      ['created_at', 'created_at'],
    ]),
    modules: new Map([
      ['display_id', 'human_friendly_id'],
      ['name', 'name'],
      ['module_group', 'module_group'],
      ['minimum_plan_tier_code', 'minimum_plan_tier_code'],
      ['is_add_on', 'is_add_on'],
      ['add_on_price', 'add_on_price'],
      ['updated_at', 'updated_at'],
      ['created_at', 'created_at'],
    ]),
    subscriptions: new Map([
      ['display_id', 'human_friendly_id'],
      ['status', 'status'],
      ['change_status', 'change_status'],
      ['plan_fit_status', 'plan_fit_status'],
      ['start_date', 'start_date'],
      ['end_date', 'end_date'],
      ['updated_at', 'updated_at'],
      ['created_at', 'created_at'],
    ]),
    'module-subscriptions': new Map([
      ['display_id', 'human_friendly_id'],
      ['is_active', 'is_active'],
      ['entitlement_denied', 'entitlement_denied'],
      ['eligibility', 'entitlement_denied'],
      ['evaluated_plan_fit_status', 'evaluated_plan_fit_status'],
      ['activated_at', 'activated_at'],
      ['updated_at', 'updated_at'],
      ['created_at', 'created_at'],
    ]),
    licenses: new Map([
      ['display_id', 'human_friendly_id'],
      ['license_type', 'license_type'],
      ['status', 'status'],
      ['plan_tier_code', 'plan_tier_code'],
      ['issued_at', 'issued_at'],
      ['expires_at', 'expires_at'],
      ['updated_at', 'updated_at'],
      ['created_at', 'created_at'],
    ]),
  };

  if (resource === 'subscription-invoices') {
    const invoiceFieldMap = new Map([
      ['invoice_display_id', 'human_friendly_id'],
      ['invoice_id', 'human_friendly_id'],
      ['invoice_status', 'status'],
      ['billing_status', 'billing_status'],
      ['total_amount', 'total_amount'],
      ['currency', 'currency'],
      ['issued_at', 'issued_at'],
      ['paid_at', 'paid_at'],
    ]);

    if (invoiceFieldMap.has(requestedField)) {
      return { invoice: { [invoiceFieldMap.get(requestedField)]: direction } };
    }

    const fallbackField = requestedField === 'display_id'
      ? 'human_friendly_id'
      : requestedField;
    if (['human_friendly_id', 'updated_at', 'created_at'].includes(fallbackField)) {
      return { [fallbackField]: direction };
    }

    return { invoice: { issued_at: direction } };
  }

  const resourceMap = scalarSortMap[resource];
  if (!resourceMap) return { updated_at: direction };

  const mappedField = resourceMap.get(requestedField) || resourceMap.get(defaultSortField(resource)) || 'updated_at';
  return { [mappedField]: direction };
};

const currentRoles = (user = {}) =>
  (Array.isArray(user.roles) ? user.roles : [user.role])
    .map((entry) => text(entry).toUpperCase())
    .filter(Boolean);

const isGlobalAdmin = (user = {}) => currentRoles(user).includes(ROLES.SUPER_ADMIN);

const buildPagination = (page, limit, total) => {
  const totalPages = total > 0 ? Math.ceil(total / limit) : 0;
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const mapSummary = (summary = {}) => [
  { id: 'active_subscriptions', label: 'Active subscriptions', value: numberValue(summary.active_subscriptions) },
  { id: 'pending_changes', label: 'Pending changes', value: numberValue(summary.pending_changes) },
  { id: 'past_due_invoices', label: 'Past due invoices', value: numberValue(summary.past_due_invoices) },
  { id: 'denied_modules', label: 'Denied modules', value: numberValue(summary.denied_modules) },
  { id: 'expiring_licenses', label: 'Expiring licenses', value: numberValue(summary.expiring_licenses) },
  { id: 'approaching_limits', label: 'Approaching limits', value: numberValue(summary.approaching_limits) },
];

const mapQueueSummaries = (summary = {}) => [
  { id: 'renewals_due', label: 'Renewals due', count: numberValue(summary.expiring_licenses), panel: 'governance', resource: 'licenses', queue: 'EXPIRING_LICENSES' },
  { id: 'past_due_billing', label: 'Past due billing', count: numberValue(summary.past_due_invoices), panel: 'billing', resource: 'subscription-invoices', queue: 'PAST_DUE' },
  { id: 'upgrade_recommended', label: 'Upgrade recommended', count: numberValue(summary.approaching_limits), panel: 'operations', resource: 'subscriptions', queue: 'UPGRADE_RECOMMENDED' },
  { id: 'module_blocked', label: 'Module blocked', count: numberValue(summary.denied_modules), panel: 'operations', resource: 'module-subscriptions', queue: 'MODULE_BLOCKED' },
  { id: 'pending_changes', label: 'Pending changes', count: numberValue(summary.pending_changes), panel: 'operations', resource: 'subscriptions', queue: 'PENDING_CHANGES' },
];

const mapPanelSummaries = (summary = {}) => [
  { id: 'overview', count: numberValue(summary.pending_changes) + numberValue(summary.past_due_invoices), default_resource: 'subscriptions' },
  { id: 'catalog', count: numberValue(summary.active_subscriptions), default_resource: 'subscription-plans' },
  { id: 'operations', count: numberValue(summary.pending_changes) + numberValue(summary.denied_modules), default_resource: 'subscriptions' },
  { id: 'billing', count: numberValue(summary.past_due_invoices), default_resource: 'subscription-invoices' },
  { id: 'governance', count: numberValue(summary.expiring_licenses), default_resource: 'licenses' },
];

const serializeItems = (resource, items = []) => {
  if (resource === 'subscription-plans') return items.map(serializeSubscriptionPlan);
  if (resource === 'modules') return items.map(serializeModule);
  if (resource === 'subscriptions') return items.map(serializeSubscription);
  if (resource === 'module-subscriptions') return items.map(serializeModuleSubscription);
  if (resource === 'subscription-invoices') return items.map(serializeSubscriptionInvoice);
  return items.map(serializeLicense);
};

const mapTimeline = (timeline = {}) => {
  const entries = [];

  (timeline.subscriptions || []).forEach((record) => {
    const item = serializeSubscription(record);
    entries.push({
      id: `subscription:${item.id}`,
      type: 'subscription',
      title: item.display_id,
      subtitle: item.status,
      occurred_at: item.updated_at || item.created_at,
      status: item.status,
      resource: 'subscriptions',
      target_id: item.id,
    });
  });

  (timeline.moduleSubscriptions || []).forEach((record) => {
    const item = serializeModuleSubscription(record);
    entries.push({
      id: `module-subscription:${item.id}`,
      type: 'module_subscription',
      title: item.module_label || item.display_id,
      subtitle: item.entitlement_denied ? 'DENIED' : (item.is_active ? 'ACTIVE' : 'INACTIVE'),
      occurred_at: item.updated_at || item.created_at,
      status: item.entitlement_denied ? 'DENIED' : (item.is_active ? 'ACTIVE' : 'INACTIVE'),
      resource: 'module-subscriptions',
      target_id: item.id,
    });
  });

  (timeline.invoices || []).forEach((record) => {
    const item = serializeSubscriptionInvoice(record);
    entries.push({
      id: `subscription-invoice:${item.id}`,
      type: 'subscription_invoice',
      title: item.invoice_display_id || item.display_id,
      subtitle: item.invoice_status || item.billing_status,
      occurred_at: item.updated_at || item.issued_at || item.created_at,
      status: item.invoice_status || item.billing_status,
      resource: 'subscription-invoices',
      target_id: item.id,
    });
  });

  (timeline.licenses || []).forEach((record) => {
    const item = serializeLicense(record);
    entries.push({
      id: `license:${item.id}`,
      type: 'license',
      title: item.display_id,
      subtitle: item.status,
      occurred_at: item.updated_at || item.issued_at || item.created_at,
      status: item.status,
      resource: 'licenses',
      target_id: item.id,
    });
  });

  return entries
    .sort((left, right) => new Date(right.occurred_at || 0).getTime() - new Date(left.occurred_at || 0).getTime())
    .slice(0, 20);
};

const buildLookups = (lookups = {}) => ({
  tenants: (lookups.tenants || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
  })),
  plans: (lookups.plans || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
    subtitle: entry.code || entry.tier_code || null,
    meta: {
      tier_code: entry.tier_code || null,
      billing_cycle: entry.billing_cycle || null,
    },
  })),
  modules: (lookups.modules || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: entry.name,
    subtitle: entry.slug || null,
    meta: {
      minimum_plan_tier_code: entry.minimum_plan_tier_code || null,
      is_add_on: Boolean(entry.is_add_on),
    },
  })),
  module_groups: (lookups.module_groups || []).map((entry) => ({
    id: text(entry.id),
    label: text(entry.label) || `Group ${text(entry.id)}`,
  })),
  invoices: (lookups.invoices || []).map((entry) => ({
    id: safePublicId(entry.human_friendly_id, entry.id),
    label: safePublicId(entry.human_friendly_id, entry.id),
    subtitle: [entry.status, entry.billing_status].filter(Boolean).join(' / ') || null,
    meta: {
      status: entry.status || null,
      billing_status: entry.billing_status || null,
      issued_at: entry.issued_at || null,
      total_amount: entry.total_amount != null ? Number(entry.total_amount) : null,
      currency: entry.currency || null,
    },
  })),
  statuses: SUBSCRIPTIONS_STATUS_VALUES.map((value) => ({ id: value, label: value })),
  change_statuses: SUBSCRIPTIONS_CHANGE_STATUS_VALUES.map((value) => ({ id: value, label: value })),
  fit_statuses: SUBSCRIPTIONS_FIT_STATUS_VALUES.map((value) => ({ id: value, label: value })),
  billing_cycles: SUBSCRIPTIONS_BILLING_CYCLES.map((value) => ({ id: value, label: value })),
  tiers: SUBSCRIPTIONS_PLAN_TIERS.map((value) => ({ id: value, label: value })),
  license_types: SUBSCRIPTIONS_LICENSE_TYPES.map((value) => ({ id: value, label: value })),
  invoice_statuses: ['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED'].map((value) => ({ id: value, label: value })),
  eligibility_states: [
    { id: 'ELIGIBLE', label: 'Eligible' },
    { id: 'DENIED', label: 'Denied' },
  ],
  panels: SUBSCRIPTIONS_PANELS.map((entry) => ({ id: entry.id, label_key: entry.label_key })),
  resources: SUBSCRIPTIONS_RESOURCES.map((entry) => ({ id: entry, label: entry })),
});

const resolveTenantScope = async (filters = {}, user = {}) => {
  const globalAdmin = isGlobalAdmin(user);
  const userTenantId = text(user.tenant_id || user.tenantId);
  const requestedTenant = filters.tenant_id || filters.tenantId;

  if (globalAdmin) {
    if (!requestedTenant) {
      return { tenant_id: '', global_admin: true };
    }

    const resolvedTenantId = await resolveIdentifierForFilter({
      value: requestedTenant,
      model: 'tenant',
    });

    if (resolvedTenantId === null) {
      return { tenant_id: null, global_admin: true };
    }

    return { tenant_id: resolvedTenantId || '', global_admin: true };
  }

  if (!userTenantId) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  return { tenant_id: userTenantId, global_admin: false };
};

const resolveResourceFilters = async (
  filters = {},
  scope = {},
  resource = 'subscriptions'
) => {
  const queue = toUpper(filters.queue);
  const resolved = {
    search: text(filters.search),
    status: toUpper(filters.status),
    change_status: toUpper(filters.changeStatus || filters.change_status),
    fit_status: toUpper(filters.fitStatus || filters.fit_status),
    tier_code: toUpper(filters.tierCode || filters.tier_code),
    billing_cycle: toUpper(filters.billingCycle || filters.billing_cycle),
    invoice_status: toUpper(filters.invoiceStatus || filters.invoice_status),
    license_type: toUpper(filters.licenseType || filters.license_type),
    eligibility_state: toUpper(
      filters.eligibilityState || filters.eligibility_state
    ),
    is_add_on: filters.isAddOn ?? filters.is_add_on,
    queue,
    date_window: resolveDateWindow(filters, resource),
  };

  if (filters.planId || filters.plan_id) {
    const planId = await resolveIdentifierForFilter({
      value: filters.planId || filters.plan_id,
      model: 'subscription_plan',
      where: scope.tenant_id ? { OR: [{ tenant_id: null }, { tenant_id: scope.tenant_id }] } : {},
    });
    if (planId === null) return null;
    resolved.plan_id = planId;
  }

  if (filters.moduleId || filters.module_id) {
    const moduleId = await resolveIdentifierForFilter({
      value: filters.moduleId || filters.module_id,
      model: 'module',
    });
    if (moduleId === null) return null;
    resolved.module_id = moduleId;
  }

  if (
    resource === 'subscriptions' &&
    resolved.fit_status &&
    ['WARNING', 'CRITICAL'].includes(resolved.fit_status)
  ) {
    resolved.fit_status = 'WARNING';
  }

  return resolved;
};

const buildOverview = (records = {}) => {
  const currentSubscription = serializeSubscription(records.current_subscription);
  const nextInvoice = serializeSubscriptionInvoice(records.next_invoice);
  const licenses = (records.licenses || []).map(serializeLicense);
  const primaryLicense = licenses[0] || null;
  const recommendations = [];

  if (currentSubscription?.plan_fit_status && currentSubscription.plan_fit_status !== 'HEALTHY') {
    recommendations.push({
      id: 'plan-fit-warning',
      type: 'upgrade',
      title: 'Upgrade recommended',
      description: 'Current usage is approaching or exceeding plan limits.',
      subscription_id: currentSubscription.id,
      queue: 'UPGRADE_RECOMMENDED',
    });
  }

  if (numberValue(records.denied_modules_count) > 0) {
    recommendations.push({
      id: 'module-blocked',
      type: 'module',
      title: 'Modules blocked by entitlement',
      description: 'Some module subscriptions are denied by the current plan.',
      queue: 'MODULE_BLOCKED',
    });
  }

  if (nextInvoice?.invoice_status === 'OVERDUE') {
    recommendations.push({
      id: 'billing-overdue',
      type: 'billing',
      title: 'Billing follow-up needed',
      description: 'A subscription invoice is overdue.',
      queue: 'PAST_DUE',
    });
  }

  if (primaryLicense?.expires_at) {
    recommendations.push({
      id: 'license-expiring',
      type: 'license',
      title: 'License expiry approaching',
      description: 'Review upcoming license expirations.',
      queue: 'EXPIRING_LICENSES',
    });
  }

  return {
    current_subscription: currentSubscription,
    pending_change:
      currentSubscription && SUBSCRIPTIONS_PENDING_CHANGE_STATUSES.includes(currentSubscription.change_status)
        ? {
            status: currentSubscription.change_status,
            requested_at: currentSubscription.change_requested_at,
            effective_at: currentSubscription.change_effective_at,
            pending_plan_id: currentSubscription.pending_plan_id,
            pending_plan_label: currentSubscription.pending_plan_label,
          }
        : null,
    current_plan: currentSubscription
      ? {
          id: currentSubscription.plan_id,
          label: currentSubscription.plan_label,
          code: currentSubscription.plan_code,
          tier_code: currentSubscription.tier_code,
          billing_cycle: currentSubscription.billing_cycle,
        }
      : null,
    usage_summary: currentSubscription
      ? {
          subscription_id: currentSubscription.id,
          plan_id: currentSubscription.plan_id,
          users_used: currentSubscription.users_used,
          facilities_used: currentSubscription.facilities_used,
          storage_used_mb: currentSubscription.storage_used_mb,
          modules_used: currentSubscription.modules_used,
          fit_status: currentSubscription.plan_fit_status,
        }
      : null,
    next_invoice: nextInvoice,
    license_summary: {
      active_count: licenses.filter((entry) => entry.status === 'ACTIVE').length,
      expiring_count: licenses.filter((entry) => entry.expires_at).length,
      primary_license: primaryLicense,
      items: licenses,
    },
    recommendations,
  };
};

const getWorkspace = async (query = {}, page = 1, limit = 20, sortBy, order = 'desc', user = {}) => {
  const panel = text(query.panel).toLowerCase() || 'overview';
  const resource = text(query.resource).toLowerCase()
    || SUBSCRIPTIONS_PANEL_RESOURCE_MAP[panel]
    || 'subscriptions';
  const scope = await resolveTenantScope(query, user);

  if (scope.tenant_id === null) {
    return {
      summary: mapSummary(),
      queue_summaries: [],
      panel_summaries: mapPanelSummaries(),
      filters: { panel, resource, tenantId: null },
      lookups: buildLookups(),
      items: [],
      pagination: buildPagination(page, limit, 0),
      spotlight: [],
      timeline: [],
      overview: buildOverview(),
    };
  }

  const resolvedFilters = await resolveResourceFilters(query, scope, resource);
  if (resolvedFilters === null) {
    const lookups = await repository.findLookups(scope);
    const overviewRecords = await repository.findOverview(scope);
    return {
      summary: mapSummary(),
      queue_summaries: [],
      panel_summaries: mapPanelSummaries(),
      filters: { panel, resource, tenantId: safePublicId(undefined, scope.tenant_id) },
      lookups: buildLookups(lookups),
      items: [],
      pagination: buildPagination(page, limit, 0),
      spotlight: [],
      timeline: [],
      overview: buildOverview(overviewRecords),
    };
  }

  const orderBy = resolveOrderBy(resource, sortBy, order);

  const [summary, lookups, overviewRecords, itemsResult, timeline] = await Promise.all([
    repository.findSummary(scope),
    repository.findLookups(scope),
    repository.findOverview(scope),
    repository.findItems({
      resource,
      filters: resolvedFilters,
      tenant_id: scope.tenant_id,
      skip: (page - 1) * limit,
      take: limit,
      orderBy,
    }),
    repository.findTimeline(scope),
  ]);

  const queueSummaries = mapQueueSummaries(summary);

  return {
    summary: mapSummary(summary),
    queue_summaries: queueSummaries,
    panel_summaries: mapPanelSummaries(summary),
    filters: {
      panel,
      resource,
      id: text(query.id) || null,
      action: text(query.action) || null,
      queue: text(query.queue) || null,
      search: text(query.search) || '',
      tenantId: safePublicId(undefined, scope.tenant_id),
      status: resolvedFilters.status || null,
      tierCode: resolvedFilters.tier_code || null,
      billingCycle: resolvedFilters.billing_cycle || null,
      planId: safePublicId(undefined, resolvedFilters.plan_id),
      moduleId: safePublicId(undefined, resolvedFilters.module_id),
      fitStatus: resolvedFilters.fit_status || null,
      changeStatus: resolvedFilters.change_status || null,
      invoiceStatus: resolvedFilters.invoice_status || null,
      licenseType: resolvedFilters.license_type || null,
      isAddOn: resolvedFilters.is_add_on === undefined ? null : String(resolvedFilters.is_add_on),
      eligibilityState: resolvedFilters.eligibility_state || null,
      datePreset: text(query.datePreset || query.date_preset) || null,
      from: text(query.from) || null,
      to: text(query.to) || null,
    },
    lookups: buildLookups(lookups),
    items: serializeItems(resource, itemsResult.items),
    pagination: buildPagination(page, limit, numberValue(itemsResult.total)),
    spotlight: queueSummaries.filter((entry) => entry.count > 0).sort((left, right) => right.count - left.count).slice(0, 5),
    timeline: mapTimeline(timeline),
    overview: buildOverview(overviewRecords),
  };
};

const getReferenceData = async (query = {}, user = {}) => {
  const scope = await resolveTenantScope(query, user);
  if (scope.tenant_id === null) {
    return buildLookups();
  }
  const lookups = await repository.findLookups(scope);
  return buildLookups(lookups);
};

const resolveLegacyRoute = async (resource, identifier, user = {}) => {
  const normalizedResource = text(resource).toLowerCase();
  if (!SUBSCRIPTIONS_RESOURCES.includes(normalizedResource)) {
    throw new HttpError('errors.not_found', 404);
  }

  const scope = await resolveTenantScope({}, user);
  const record = await repository.resolveLegacyRecord(
    normalizedResource,
    identifier,
    scope.tenant_id || ''
  );
  if (!record) {
    throw new HttpError('errors.not_found', 404);
  }

  return {
    panel: SUBSCRIPTIONS_RESOURCE_PANEL_MAP[normalizedResource] || 'overview',
    resource: normalizedResource,
    id: resolvePublicIdentifier(record.human_friendly_id, record.id) || null,
    action: 'view',
    tenantId: safePublicId(undefined, scope.tenant_id),
  };
};

module.exports = {
  getReferenceData,
  getWorkspace,
  resolveLegacyRoute,
};
