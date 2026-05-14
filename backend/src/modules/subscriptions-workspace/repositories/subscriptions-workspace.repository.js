const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const {
  SUBSCRIPTIONS_PENDING_CHANGE_STATUSES,
  SUBSCRIPTIONS_WARNING_FIT_STATUSES,
} = require('@lib/subscriptions/constants');

const tenantSelect = {
  id: true,
  human_friendly_id: true,
  name: true,
};

const subscriptionPlanSelect = {
  id: true,
  human_friendly_id: true,
  code: true,
  name: true,
  tier_code: true,
  billing_cycle: true,
  price: true,
  max_users: true,
  max_facilities: true,
  max_storage_mb: true,
  max_modules: true,
  plan_fit_warning_percent: true,
};

const moduleSelect = {
  id: true,
  human_friendly_id: true,
  name: true,
  slug: true,
  module_group: true,
  minimum_plan_tier_code: true,
  is_add_on: true,
  add_on_price: true,
  add_on_billing_cycle: true,
};

const invoiceSelect = {
  id: true,
  human_friendly_id: true,
  status: true,
  billing_status: true,
  total_amount: true,
  currency: true,
  issued_at: true,
  paid_at: true,
};

const invoiceLookupSelect = {
  id: true,
  human_friendly_id: true,
  status: true,
  billing_status: true,
  issued_at: true,
  total_amount: true,
  currency: true,
};

const mapError = (error) => {
  throw new HttpError('errors.database.unexpected', 500, [{ originalError: error?.message }]);
};

const tenantScopedWhere = (tenantId) => ({
  deleted_at: null,
  ...(tenantId ? { tenant_id: tenantId } : {}),
});

const subscriptionPlanWhere = (tenantId) => {
  if (!tenantId) return { deleted_at: null };
  return {
    deleted_at: null,
    OR: [{ tenant_id: null }, { tenant_id: tenantId }],
  };
};

const normalizeDate = (value) => {
  if (!value) return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed;
};

const mergeNestedCondition = (target, path, condition) => {
  const [head, ...tail] = path;
  if (!head) return;

  if (tail.length === 0) {
    target[head] = {
      ...(target[head] || {}),
      ...condition,
    };
    return;
  }

  const nextTarget = target[head] && typeof target[head] === 'object'
    ? target[head]
    : {};
  target[head] = nextTarget;
  mergeNestedCondition(nextTarget, tail, condition);
};

const applyDateWindow = (where, dateWindow = null) => {
  if (!dateWindow || typeof dateWindow !== 'object') return;
  const field = String(dateWindow.field || '').trim();
  if (!field) return;

  const fromDate = normalizeDate(dateWindow.from);
  const toDate = normalizeDate(dateWindow.to);
  if (!fromDate && !toDate) return;

  const condition = {
    ...(fromDate ? { gte: fromDate } : {}),
    ...(toDate ? { lte: toDate } : {}),
  };

  mergeNestedCondition(where, field.split('.'), condition);
};

const findSummary = async ({ tenant_id: tenantId } = {}) => {
  try {
    const now = new Date();
    const expiringThreshold = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    const subscriptionWhere = tenantScopedWhere(tenantId);

    const [
      activeSubscriptions,
      pendingChanges,
      pastDueInvoices,
      deniedModules,
      expiringLicenses,
      approachingLimits,
    ] = await Promise.all([
      prisma.subscription.count({
        where: { ...subscriptionWhere, status: { in: ['ACTIVE', 'TRIAL'] } },
      }),
      prisma.subscription.count({
        where: {
          ...subscriptionWhere,
          change_status: { in: SUBSCRIPTIONS_PENDING_CHANGE_STATUSES },
        },
      }),
      prisma.subscription_invoice.count({
        where: {
          deleted_at: null,
          subscription: subscriptionWhere,
          invoice: {
            deleted_at: null,
            OR: [{ status: 'OVERDUE' }, { billing_status: 'PARTIAL' }],
          },
        },
      }),
      prisma.module_subscription.count({
        where: {
          deleted_at: null,
          entitlement_denied: true,
          subscription: subscriptionWhere,
        },
      }),
      prisma.license.count({
        where: {
          ...tenantScopedWhere(tenantId),
          status: 'ACTIVE',
          expires_at: {
            not: null,
            gte: now,
            lte: expiringThreshold,
          },
        },
      }),
      prisma.subscription.count({
        where: {
          ...subscriptionWhere,
          plan_fit_status: { in: SUBSCRIPTIONS_WARNING_FIT_STATUSES },
        },
      }),
    ]);

    return {
      active_subscriptions: activeSubscriptions,
      pending_changes: pendingChanges,
      past_due_invoices: pastDueInvoices,
      denied_modules: deniedModules,
      expiring_licenses: expiringLicenses,
      approaching_limits: approachingLimits,
    };
  } catch (error) {
    mapError(error);
  }
};

const findLookups = async ({ tenant_id: tenantId } = {}) => {
  try {
    const [tenants, plans, modules, invoices] = await Promise.all([
      prisma.tenant.findMany({
        where: {
          deleted_at: null,
          ...(tenantId ? { id: tenantId } : {}),
        },
        orderBy: { name: 'asc' },
        take: 100,
        select: tenantSelect,
      }),
      prisma.subscription_plan.findMany({
        where: subscriptionPlanWhere(tenantId),
        orderBy: [{ tier_code: 'asc' }, { name: 'asc' }],
        take: 100,
        select: subscriptionPlanSelect,
      }),
      prisma.module.findMany({
        where: { deleted_at: null },
        orderBy: [{ module_group: 'asc' }, { name: 'asc' }],
        take: 100,
        select: moduleSelect,
      }),
      prisma.invoice.findMany({
        where: {
          deleted_at: null,
          ...(tenantId ? { tenant_id: tenantId } : {}),
        },
        orderBy: [{ issued_at: 'desc' }],
        take: 100,
        select: invoiceLookupSelect,
      }),
    ]);

    const module_groups = [...new Set(
      (modules || [])
        .map((entry) => entry?.module_group)
        .filter((entry) => entry !== null && entry !== undefined)
    )]
      .sort((left, right) => Number(left) - Number(right))
      .map((entry) => ({
        id: String(entry),
        label: `Group ${entry}`,
      }));

    return {
      invoices,
      module_groups,
      modules,
      plans,
      tenants,
    };
  } catch (error) {
    mapError(error);
  }
};

const findOverview = async ({ tenant_id: tenantId } = {}) => {
  try {
    if (!tenantId) {
      return {
        current_subscription: null,
        next_invoice: null,
        licenses: [],
        denied_modules_count: 0,
      };
    }

    const currentSubscription = await prisma.subscription.findFirst({
      where: {
        ...tenantScopedWhere(tenantId),
        status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
      },
      orderBy: [{ updated_at: 'desc' }],
      include: {
        tenant: { select: tenantSelect },
        plan: { select: subscriptionPlanSelect },
        pending_plan: { select: subscriptionPlanSelect },
        module_subscriptions: {
          where: { deleted_at: null },
          include: { module: { select: moduleSelect } },
        },
      },
    });

    const [nextInvoice, licenses, deniedModulesCount] = await Promise.all([
      prisma.subscription_invoice.findFirst({
        where: {
          deleted_at: null,
          subscription: tenantScopedWhere(tenantId),
          invoice: {
            deleted_at: null,
            status: { in: ['DRAFT', 'SENT', 'OVERDUE'] },
          },
        },
        orderBy: [{ created_at: 'desc' }],
        include: {
          subscription: {
            include: {
              tenant: { select: tenantSelect },
              plan: { select: subscriptionPlanSelect },
            },
          },
          invoice: { select: invoiceSelect },
        },
      }),
      prisma.license.findMany({
        where: tenantScopedWhere(tenantId),
        orderBy: [{ expires_at: 'asc' }, { updated_at: 'desc' }],
        take: 10,
        include: { tenant: { select: tenantSelect } },
      }),
      prisma.module_subscription.count({
        where: {
          deleted_at: null,
          entitlement_denied: true,
          subscription: tenantScopedWhere(tenantId),
        },
      }),
    ]);

    return {
      current_subscription: currentSubscription,
      next_invoice: nextInvoice,
      licenses,
      denied_modules_count: deniedModulesCount,
    };
  } catch (error) {
    mapError(error);
  }
};

const buildResourceWhere = (resource, filters = {}, tenantId) => {
  const search = String(filters.search || '').trim();
  const queue = String(filters.queue || '').trim().toUpperCase();
  const dateWindow = filters.date_window || null;

  if (resource === 'subscription-plans') {
    const where = subscriptionPlanWhere(tenantId);
    if (filters.tier_code) where.tier_code = String(filters.tier_code).trim().toUpperCase();
    if (filters.billing_cycle) where.billing_cycle = String(filters.billing_cycle).trim().toUpperCase();
    if (search) {
      where.AND = [{
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { code: { contains: search, mode: 'insensitive' } },
          { human_friendly_id: { contains: search.toUpperCase() } },
        ],
      }];
    }
    applyDateWindow(where, dateWindow);
    return where;
  }

  if (resource === 'modules') {
    const where = { deleted_at: null };
    if (filters.tier_code) where.minimum_plan_tier_code = String(filters.tier_code).trim().toUpperCase();
    if (filters.is_add_on === 'true') where.is_add_on = true;
    if (filters.is_add_on === 'false') where.is_add_on = false;
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { slug: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { human_friendly_id: { contains: search.toUpperCase() } },
      ];
    }
    applyDateWindow(where, dateWindow);
    return where;
  }

  if (resource === 'subscriptions') {
    const where = tenantScopedWhere(tenantId);
    if (filters.status) where.status = String(filters.status).trim().toUpperCase();
    if (filters.change_status === 'PENDING' || queue === 'PENDING_CHANGES') {
      where.change_status = { in: SUBSCRIPTIONS_PENDING_CHANGE_STATUSES };
    } else if (filters.change_status) {
      where.change_status = String(filters.change_status).trim().toUpperCase();
    }

    if (filters.fit_status === 'WARNING' || queue === 'UPGRADE_RECOMMENDED') {
      where.plan_fit_status = { in: SUBSCRIPTIONS_WARNING_FIT_STATUSES };
    } else if (filters.fit_status) {
      where.plan_fit_status = String(filters.fit_status).trim().toUpperCase();
    }

    if (filters.plan_id) where.plan_id = filters.plan_id;
    if (search) {
      where.OR = [
        { human_friendly_id: { contains: search.toUpperCase() } },
        { tenant: { name: { contains: search, mode: 'insensitive' } } },
        { plan: { name: { contains: search, mode: 'insensitive' } } },
        { plan: { code: { contains: search, mode: 'insensitive' } } },
      ];
    }
    applyDateWindow(where, dateWindow);
    return where;
  }

  if (resource === 'module-subscriptions') {
    const where = {
      deleted_at: null,
      subscription: tenantScopedWhere(tenantId),
    };
    if (filters.module_id) where.module_id = filters.module_id;
    if (filters.fit_status) where.evaluated_plan_fit_status = String(filters.fit_status).trim().toUpperCase();
    if (filters.eligibility_state === 'DENIED' || queue === 'MODULE_BLOCKED') where.entitlement_denied = true;
    if (filters.eligibility_state === 'ELIGIBLE') where.entitlement_denied = false;
    if (filters.status === 'ACTIVE') where.is_active = true;
    if (filters.status === 'INACTIVE') where.is_active = false;
    if (search) {
      where.OR = [
        { human_friendly_id: { contains: search.toUpperCase() } },
        { module: { name: { contains: search, mode: 'insensitive' } } },
        { module: { slug: { contains: search, mode: 'insensitive' } } },
        { subscription: { human_friendly_id: { contains: search.toUpperCase() } } },
      ];
    }
    applyDateWindow(where, dateWindow);
    return where;
  }

  if (resource === 'subscription-invoices') {
    const where = {
      deleted_at: null,
      subscription: tenantScopedWhere(tenantId),
    };
    if (filters.invoice_status) {
      where.invoice = {
        ...(where.invoice || {}),
        status: String(filters.invoice_status).trim().toUpperCase(),
      };
    }
    if (filters.status) {
      where.invoice = {
        ...(where.invoice || {}),
        billing_status: String(filters.status).trim().toUpperCase(),
      };
    }
    if (
      queue === 'PAST_DUE' ||
      queue === 'PAST_DUE_BILLING'
    ) {
      where.invoice = {
        ...(where.invoice || {}),
        OR: [{ status: 'OVERDUE' }, { billing_status: 'PARTIAL' }],
      };
    }
    if (filters.plan_id) where.subscription = { ...where.subscription, plan_id: filters.plan_id };
    if (search) {
      where.OR = [
        { human_friendly_id: { contains: search.toUpperCase() } },
        { subscription: { human_friendly_id: { contains: search.toUpperCase() } } },
        { invoice: { human_friendly_id: { contains: search.toUpperCase() } } },
      ];
    }
    applyDateWindow(where, dateWindow);
    return where;
  }

  const where = tenantScopedWhere(tenantId);
  if (filters.status || queue === 'EXPIRING_LICENSES' || queue === 'RENEWALS_DUE') {
    where.status = String(filters.status || 'ACTIVE').trim().toUpperCase();
  }
  if (filters.license_type) where.license_type = String(filters.license_type).trim().toUpperCase();
  if (filters.tier_code) where.plan_tier_code = String(filters.tier_code).trim().toUpperCase();
  if (search) {
    where.OR = [
      { human_friendly_id: { contains: search.toUpperCase() } },
      { tenant: { name: { contains: search, mode: 'insensitive' } } },
    ];
  }
  if ((queue === 'EXPIRING_LICENSES' || queue === 'RENEWALS_DUE') && !dateWindow) {
    const now = new Date();
    const nextThirtyDays = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    where.expires_at = {
      gte: now,
      lte: nextThirtyDays,
    };
  }
  applyDateWindow(where, dateWindow);
  return where;
};

const findItems = async ({ resource, filters = {}, tenant_id: tenantId, skip = 0, take = 20, orderBy = { updated_at: 'desc' } } = {}) => {
  try {
    const where = buildResourceWhere(resource, filters, tenantId);

    if (resource === 'subscription-plans') {
      const [items, total] = await Promise.all([
        prisma.subscription_plan.findMany({
          where,
          skip,
          take,
          orderBy,
          include: {
            tenant: { select: tenantSelect },
            _count: { select: { subscriptions: true } },
          },
        }),
        prisma.subscription_plan.count({ where }),
      ]);
      return { items, total };
    }

    if (resource === 'modules') {
      const [items, total] = await Promise.all([
        prisma.module.findMany({
          where,
          skip,
          take,
          orderBy,
          include: { _count: { select: { subscriptions: true } } },
        }),
        prisma.module.count({ where }),
      ]);
      return { items, total };
    }

    if (resource === 'subscriptions') {
      const [items, total] = await Promise.all([
        prisma.subscription.findMany({
          where,
          skip,
          take,
          orderBy,
          include: {
            tenant: { select: tenantSelect },
            plan: { select: subscriptionPlanSelect },
            pending_plan: { select: subscriptionPlanSelect },
            module_subscriptions: {
              where: { deleted_at: null },
              select: { id: true, is_active: true, deleted_at: true },
            },
          },
        }),
        prisma.subscription.count({ where }),
      ]);
      return { items, total };
    }

    if (resource === 'module-subscriptions') {
      const [items, total] = await Promise.all([
        prisma.module_subscription.findMany({
          where,
          skip,
          take,
          orderBy,
          include: {
            module: { select: moduleSelect },
            subscription: {
              include: {
                tenant: { select: tenantSelect },
                plan: { select: subscriptionPlanSelect },
              },
            },
          },
        }),
        prisma.module_subscription.count({ where }),
      ]);
      return { items, total };
    }

    if (resource === 'subscription-invoices') {
      const [items, total] = await Promise.all([
        prisma.subscription_invoice.findMany({
          where,
          skip,
          take,
          orderBy,
          include: {
            subscription: {
              include: {
                tenant: { select: tenantSelect },
                plan: { select: subscriptionPlanSelect },
              },
            },
            invoice: { select: invoiceSelect },
          },
        }),
        prisma.subscription_invoice.count({ where }),
      ]);
      return { items, total };
    }

    const [items, total] = await Promise.all([
      prisma.license.findMany({
        where,
        skip,
        take,
        orderBy,
        include: { tenant: { select: tenantSelect } },
      }),
      prisma.license.count({ where }),
    ]);
    return { items, total };
  } catch (error) {
    mapError(error);
  }
};

const findTimeline = async ({ tenant_id: tenantId } = {}, take = 20) => {
  try {
    const subscriptionWhere = tenantScopedWhere(tenantId);
    const [subscriptions, moduleSubscriptions, invoices, licenses] = await Promise.all([
      prisma.subscription.findMany({
        where: subscriptionWhere,
        take,
        orderBy: [{ updated_at: 'desc' }],
        include: {
          tenant: { select: tenantSelect },
          plan: { select: subscriptionPlanSelect },
          pending_plan: { select: subscriptionPlanSelect },
        },
      }),
      prisma.module_subscription.findMany({
        where: { deleted_at: null, subscription: subscriptionWhere },
        take,
        orderBy: [{ updated_at: 'desc' }],
        include: {
          module: { select: moduleSelect },
          subscription: {
            include: {
              tenant: { select: tenantSelect },
              plan: { select: subscriptionPlanSelect },
            },
          },
        },
      }),
      prisma.subscription_invoice.findMany({
        where: { deleted_at: null, subscription: subscriptionWhere },
        take,
        orderBy: [{ updated_at: 'desc' }],
        include: {
          subscription: {
            include: {
              tenant: { select: tenantSelect },
              plan: { select: subscriptionPlanSelect },
            },
          },
          invoice: { select: invoiceSelect },
        },
      }),
      prisma.license.findMany({
        where: subscriptionWhere,
        take,
        orderBy: [{ updated_at: 'desc' }],
        include: { tenant: { select: tenantSelect } },
      }),
    ]);

    return { invoices, licenses, moduleSubscriptions, subscriptions };
  } catch (error) {
    mapError(error);
  }
};

const resolveLegacyRecord = async (resource, identifier, tenantId = '') => {
  const normalizedResource = String(resource || '').trim().toLowerCase();
  const mapping = {
    'subscription-plans': 'subscription_plan',
    modules: 'module',
    subscriptions: 'subscription',
    'module-subscriptions': 'module_subscription',
    'subscription-invoices': 'subscription_invoice',
    licenses: 'license',
  };
  const model = mapping[normalizedResource];
  if (!model) return null;

  const where = (() => {
    if (!tenantId) return {};
    if (normalizedResource === 'subscription-plans') {
      return {
        OR: [{ tenant_id: null }, { tenant_id: tenantId }],
      };
    }
    if (normalizedResource === 'subscriptions' || normalizedResource === 'licenses') {
      return { tenant_id: tenantId };
    }
    if (normalizedResource === 'module-subscriptions' || normalizedResource === 'subscription-invoices') {
      return {
        subscription: { tenant_id: tenantId },
      };
    }
    return {};
  })();

  return resolveModelRecordByIdentifier({
    model,
    identifier,
    where,
    select: { id: true, human_friendly_id: true },
  });
};

module.exports = {
  findItems,
  findLookups,
  findOverview,
  findSummary,
  findTimeline,
  resolveLegacyRecord,
};
