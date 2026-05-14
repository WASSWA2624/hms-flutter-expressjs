/**
 * Subscription service
 *
 * @module modules/subscription/services
 * @description Business logic layer for subscription operations.
 */

const subscriptionRepository = require('@repositories/subscription/subscription.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');
const {
  serializeSubscription,
  serializeSubscriptionFitCheck,
  serializeSubscriptionProrationPreview,
  serializeSubscriptionUpgradeRecommendation,
  serializeSubscriptionUsageSummary,
} = require('@lib/subscriptions/serializers');
const subscriptionPlanRepository = require('@repositories/subscription-plan/subscription-plan.repository');
const {
  PLAN_TIER_ORDER,
  evaluatePlanSupport,
  normalizeTierCode,
} = require('@lib/subscriptions/policies');
const {
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const {
  canAccessTenant,
  resolveUserTenantScope,
  text,
} = require('@lib/subscriptions/access');
const SUBSCRIPTION_INCLUDE = Object.freeze({
  plan: true,
  pending_plan: true,
  module_subscriptions: {
    where: {
      deleted_at: null,
    },
  },
  tenant: true,
});

const requireTenantScope = (user = {}) => {
  const scope = resolveUserTenantScope(user);
  if (!scope.is_elevated && !scope.tenant_id) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
  return scope;
};

const emptyList = (page, limit) => ({
  subscriptions: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const toNumber = (value) => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') return value;
  const numeric = Number(value);
  return Number.isNaN(numeric) ? null : numeric;
};

const getCycleDays = (billingCycle) => {
  if (billingCycle === 'YEARLY') return 365;
  if (billingCycle === 'QUARTERLY') return 90;
  return 30;
};

const addBillingCycle = (baseDate, billingCycle) => {
  const date = new Date(baseDate);
  if (billingCycle === 'YEARLY') {
    date.setFullYear(date.getFullYear() + 1);
    return date;
  }
  if (billingCycle === 'QUARTERLY') {
    date.setMonth(date.getMonth() + 3);
    return date;
  }
  date.setMonth(date.getMonth() + 1);
  return date;
};

const computePercent = (used, limit) => {
  if (!Number.isFinite(limit) || limit <= 0) return null;
  return Math.round((used / limit) * 10000) / 100;
};

const getAccessiblePlanWhere = (tenantId = '', scope = {}) =>
  scope.is_elevated
    ? tenantId
      ? { OR: [{ tenant_id: null }, { tenant_id: tenantId }] }
      : {}
    : { OR: [{ tenant_id: null }, { tenant_id: scope.tenant_id }] };

const resolveSubscriptionId = async (identifier, scope = {}) =>
  resolveEntityId({
    model: 'subscription',
    identifier,
    where: scope.is_elevated
      ? {}
      : {
          tenant_id: scope.tenant_id,
        },
  });

const resolveSubscriptionPlanId = async (
  identifier,
  tenantId = '',
  scope = {}
) =>
  resolveIdentifierForPayload({
    value: identifier,
    model: 'subscription_plan',
    field: 'plan_id',
    where: scope.is_elevated
      ? tenantId
        ? { OR: [{ tenant_id: null }, { tenant_id: tenantId }] }
        : {}
      : {
          OR: [{ tenant_id: null }, { tenant_id: scope.tenant_id }],
        },
  });

const loadSubscriptionRecord = async (identifier, user = {}) => {
  const scope = requireTenantScope(user);
  const resolvedId = await resolveSubscriptionId(identifier, scope);
  const subscription = await subscriptionRepository.findById(resolvedId, SUBSCRIPTION_INCLUDE);

  if (!subscription || !canAccessTenant(scope, subscription.tenant_id)) {
    throw new HttpError('errors.subscription.not_found', 404);
  }

  return subscription;
};

const getSubscriptionById = async (id, user = {}) => {
  const subscription = await loadSubscriptionRecord(id, user);
  return serializeSubscription(subscription);
};

const listSubscriptions = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'created_at',
  order = 'desc',
  user = {}
) => {
  const scope = requireTenantScope(user);
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };
  const where = {};

  if (!scope.is_elevated) {
    where.tenant_id = scope.tenant_id;
  }

  if (filters.tenant_id) {
    const requestedTenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
    });

    if (requestedTenantId === null) {
      return emptyList(page, limit);
    }

    if (
      !scope.is_elevated
      && requestedTenantId
      && requestedTenantId !== scope.tenant_id
    ) {
      return emptyList(page, limit);
    }

    if (requestedTenantId) {
      where.tenant_id = requestedTenantId;
    }
  }

  if (filters.plan_id) {
    const planId = await resolveIdentifierForFilter({
      value: filters.plan_id,
      model: 'subscription_plan',
      where: scope.is_elevated
        ? {}
        : { OR: [{ tenant_id: null }, { tenant_id: scope.tenant_id }] },
    });

    if (planId === null) {
      return emptyList(page, limit);
    }

    if (planId) {
      where.plan_id = planId;
    }
  }

  if (filters.status) {
    where.status = filters.status;
  }

  if (filters.search) {
    where.OR = [
      { human_friendly_id: { contains: filters.search, mode: 'insensitive' } },
      { tenant: { name: { contains: filters.search, mode: 'insensitive' } } },
      { tenant: { code: { contains: filters.search, mode: 'insensitive' } } },
      { plan: { name: { contains: filters.search, mode: 'insensitive' } } },
      { plan: { code: { contains: filters.search, mode: 'insensitive' } } },
    ];
  }

  const [subscriptions, total] = await Promise.all([
    subscriptionRepository.findMany(where, skip, limit, orderBy, SUBSCRIPTION_INCLUDE),
    subscriptionRepository.count(where),
  ]);

  const totalPages = Math.ceil(total / limit);

  return {
    subscriptions: subscriptions.map(serializeSubscription),
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1,
    },
  };
};

const resolveSubscriptionPayload = async (
  data = {},
  user = {},
  existingTenantId = null
) => {
  const scope = requireTenantScope(user);
  const scopedTenantId = scope.is_elevated ? null : scope.tenant_id;

  const tenantId =
    data.tenant_id === undefined
      ? scopedTenantId || existingTenantId || undefined
      : await resolveIdentifierForPayload({
          value: data.tenant_id,
          model: 'tenant',
          field: 'tenant_id',
        });

  if (!scope.is_elevated && tenantId && tenantId !== scope.tenant_id) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  const payload = {
    ...data,
  };

  if (tenantId !== undefined) {
    payload.tenant_id = tenantId;
  }

  if (data.plan_id !== undefined) {
    payload.plan_id = await resolveSubscriptionPlanId(
      data.plan_id,
      tenantId || existingTenantId || '',
      scope
    );
  }

  if (data.pending_plan_id !== undefined) {
    payload.pending_plan_id = await resolveIdentifierForPayload({
      value: data.pending_plan_id,
      model: 'subscription_plan',
      field: 'pending_plan_id',
      where: scope.is_elevated
        ? tenantId
          ? { OR: [{ tenant_id: null }, { tenant_id: tenantId }] }
          : {}
        : { OR: [{ tenant_id: null }, { tenant_id: scope.tenant_id }] },
      nullable: true,
    });
  }

  return payload;
};

const createSubscription = async (data, user, ip) => {
  const scope = requireTenantScope(user);
  const subscriptionData = await resolveSubscriptionPayload({
    ...data,
    tenant_id: scope.is_elevated ? data.tenant_id : scope.tenant_id,
    human_friendly_id:
      data.human_friendly_id
      || createSubscriptionPublicId(PUBLIC_ID_PREFIXES.subscription),
    status: data.status || 'ACTIVE',
    start_date: data.start_date || new Date().toISOString(),
  }, user);

  const created = await subscriptionRepository.create(subscriptionData);
  const subscription = await loadSubscriptionRecord(created.id, user);

  await createAuditLog({
    tenant_id: subscription.tenant_id,
    user_id: user?.id || null,
    action: 'CREATE',
    entity: 'subscription',
    entity_id: subscription.id,
    diff: { after: subscription },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscription(subscription);
};

const updateSubscription = async (id, data, user, ip) => {
  const before = await loadSubscriptionRecord(id, user);
  const payload = await resolveSubscriptionPayload(data, user, before.tenant_id);
  await subscriptionRepository.update(before.id, payload);
  const subscription = await loadSubscriptionRecord(before.id, user);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription',
    entity_id: subscription.id,
    diff: { before, after: subscription },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscription(subscription);
};

const cancelSubscription = async (id, user, ip) => {
  const before = await loadSubscriptionRecord(id, user);

  if (before.status === 'CANCELLED') {
    throw new HttpError('errors.subscription.already_cancelled', 400);
  }

  await subscriptionRepository.update(before.id, {
    status: 'CANCELLED',
    end_date: new Date().toISOString(),
  });
  const subscription = await loadSubscriptionRecord(before.id, user);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription',
    entity_id: subscription.id,
    diff: {
      before,
      after: subscription,
      metadata: {
        event: 'cancel',
      },
    },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscription(subscription);
};

const reactivateSubscription = async (id, user, ip) => {
  const before = await loadSubscriptionRecord(id, user);

  if (before.status !== 'CANCELLED') {
    throw new HttpError('errors.subscription.not_cancelled', 400);
  }

  await subscriptionRepository.update(before.id, {
    status: 'ACTIVE',
    end_date: null,
  });
  const subscription = await loadSubscriptionRecord(before.id, user);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription',
    entity_id: subscription.id,
    diff: {
      before,
      after: subscription,
      metadata: {
        event: 'reactivate',
      },
    },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscription(subscription);
};

const deleteSubscription = async (id, user, ip) => {
  const before = await loadSubscriptionRecord(id, user);
  const subscription = await subscriptionRepository.softDelete(before.id);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'DELETE',
    entity: 'subscription',
    entity_id: subscription.id,
    diff: { before, after: subscription },
    ip_address: ip,
  }).catch(() => {});

  return subscription;
};

const upgradeSubscription = async (id, data, user, ip) => {
  const before = await loadSubscriptionRecord(id, user);
  const scope = requireTenantScope(user);
  const targetPlanId = await resolveIdentifierForPayload({
    value: data.target_plan_id,
    model: 'subscription_plan',
    field: 'target_plan_id',
    where: getAccessiblePlanWhere(before.tenant_id, scope),
  });
  const targetPlanRecord = await resolveEntityId({
    model: 'subscription_plan',
    identifier: targetPlanId,
  });
  const targetPlan = targetPlanRecord
    ? await subscriptionPlanRepository.findById(targetPlanRecord)
    : null;

  if (!targetPlan) {
    throw new HttpError('errors.subscription_plan.not_found', 404);
  }

  if (before.plan_id === targetPlan.id) {
    throw new HttpError('errors.subscription.already_on_target_plan', 400);
  }

  const currentPrice = toNumber(before.plan?.price) || 0;
  const targetPrice = toNumber(targetPlan.price) || 0;

  if (targetPrice <= currentPrice) {
    throw new HttpError('errors.subscription.invalid_upgrade_path', 400);
  }

  await subscriptionRepository.update(before.id, {
    pending_plan_id: targetPlan.id,
    change_status: 'PENDING_UPGRADE',
    change_requested_at: new Date(),
    change_effective_at: data.effective_at ? new Date(data.effective_at) : null,
    proration_amount: targetPrice - currentPrice,
    proration_currency_code: 'USD',
  });
  const subscription = await loadSubscriptionRecord(before.id, user);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription',
    entity_id: subscription.id,
    diff: {
      before,
      after: subscription,
      metadata: {
        event: 'upgrade_request',
        target_plan_id: targetPlan.id,
        target_plan_human_friendly_id: targetPlan.human_friendly_id || null,
        reason: data.reason || null,
      },
    },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscription(subscription);
};

const downgradeSubscription = async (id, data, user, ip) => {
  const before = await loadSubscriptionRecord(id, user);
  const scope = requireTenantScope(user);
  const targetPlanId = await resolveIdentifierForPayload({
    value: data.target_plan_id,
    model: 'subscription_plan',
    field: 'target_plan_id',
    where: getAccessiblePlanWhere(before.tenant_id, scope),
  });
  const targetPlanRecord = await resolveEntityId({
    model: 'subscription_plan',
    identifier: targetPlanId,
  });
  const targetPlan = targetPlanRecord
    ? await subscriptionPlanRepository.findById(targetPlanRecord)
    : null;

  if (!targetPlan) {
    throw new HttpError('errors.subscription_plan.not_found', 404);
  }

  if (before.plan_id === targetPlan.id) {
    throw new HttpError('errors.subscription.already_on_target_plan', 400);
  }

  const currentPrice = toNumber(before.plan?.price) || 0;
  const targetPrice = toNumber(targetPlan.price) || 0;

  if (targetPrice > currentPrice) {
    throw new HttpError('errors.subscription.invalid_downgrade_path', 400);
  }

  await subscriptionRepository.update(before.id, {
    pending_plan_id: targetPlan.id,
    change_status: 'PENDING_DOWNGRADE',
    change_requested_at: new Date(),
    change_effective_at: data.effective_at ? new Date(data.effective_at) : null,
    proration_amount: targetPrice - currentPrice,
    proration_currency_code: 'USD',
  });
  const subscription = await loadSubscriptionRecord(before.id, user);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription',
    entity_id: subscription.id,
    diff: {
      before,
      after: subscription,
      metadata: {
        event: 'downgrade_request',
        target_plan_id: targetPlan.id,
        target_plan_human_friendly_id: targetPlan.human_friendly_id || null,
        reason: data.reason || null,
      },
    },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscription(subscription);
};

const renewSubscription = async (id, data = {}, user, ip) => {
  const before = await loadSubscriptionRecord(id, user);
  const baseDate = before.end_date ? new Date(before.end_date) : new Date();
  const renewedEndDate = data.end_date
    ? new Date(data.end_date)
    : addBillingCycle(baseDate, before.plan?.billing_cycle || 'MONTHLY');

  await subscriptionRepository.update(before.id, {
    status: 'ACTIVE',
    end_date: renewedEndDate,
    change_status: 'NONE',
    change_requested_at: null,
    change_effective_at: null,
  });
  const subscription = await loadSubscriptionRecord(before.id, user);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription',
    entity_id: subscription.id,
    diff: {
      before,
      after: subscription,
      metadata: {
        event: 'renew',
        reason: data.reason || null,
      },
    },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscription(subscription);
};

const getSubscriptionProrationPreview = async (id, targetPlanId, user = {}) => {
  const subscription = await loadSubscriptionRecord(id, user);
  const scope = requireTenantScope(user);
  const targetPlanIdentifier = text(targetPlanId);
  let targetPlan = subscription.pending_plan || subscription.plan;

  if (targetPlanIdentifier) {
    const resolvedTargetPlanId = await resolveIdentifierForPayload({
      value: targetPlanIdentifier,
      model: 'subscription_plan',
      field: 'target_plan_id',
      where: getAccessiblePlanWhere(subscription.tenant_id, scope),
    });
    targetPlan = await subscriptionPlanRepository.findById(resolvedTargetPlanId);
  }

  if (!targetPlan) {
    return serializeSubscriptionProrationPreview({
      subscription_id: serializeSubscription(subscription).id,
      current_plan_id: serializeSubscription(subscription).plan_id,
      target_plan_id: null,
      proration_amount: null,
      currency_code: subscription.proration_currency_code || 'USD',
      cycle_days: getCycleDays(subscription.plan?.billing_cycle || 'MONTHLY'),
      remaining_days: null,
    });
  }

  const cycleDays = getCycleDays(subscription.plan?.billing_cycle || 'MONTHLY');
  const now = new Date();
  const endDate = subscription.end_date
    ? new Date(subscription.end_date)
    : addBillingCycle(
        subscription.start_date || now,
        subscription.plan?.billing_cycle || 'MONTHLY'
      );

  const remainingMs = Math.max(0, endDate.getTime() - now.getTime());
  const remainingDays = Math.ceil(remainingMs / (24 * 60 * 60 * 1000));

  const currentPrice = toNumber(subscription.plan?.price) || 0;
  const targetPrice = toNumber(targetPlan.price) || 0;
  const prorationAmount = ((targetPrice - currentPrice) / cycleDays) * remainingDays;
  const serializedSubscription = serializeSubscription(subscription);

  return serializeSubscriptionProrationPreview({
    subscription_id: serializedSubscription.id,
    current_plan_id: serializedSubscription.plan_id,
    target_plan_id: targetPlan.human_friendly_id || targetPlan.id,
    cycle_days: cycleDays,
    remaining_days: remainingDays,
    proration_amount: Math.round(prorationAmount * 100) / 100,
    currency_code: subscription.proration_currency_code || 'USD',
  });
};

const getSubscriptionUsageSummary = async (id, user = {}) => {
  const subscription = await loadSubscriptionRecord(id, user);
  const plan = subscription.plan || {};
  const serializedSubscription = serializeSubscription(subscription);

  const usage = {
    users_used: subscription.users_used || 0,
    facilities_used: subscription.facilities_used || 0,
    storage_used_mb: subscription.storage_used_mb || 0,
    modules_used:
      subscription.modules_used
      || subscription.module_subscriptions?.length
      || 0,
  };

  const limits = {
    max_users: plan.max_users,
    max_facilities: plan.max_facilities,
    max_storage_mb: plan.max_storage_mb,
    max_modules: plan.max_modules,
  };

  return serializeSubscriptionUsageSummary({
    subscription_id: serializedSubscription.id,
    plan_id: serializedSubscription.plan_id,
    pending_plan_id: serializedSubscription.pending_plan_id,
    usage,
    limits,
    utilization_percent: {
      users: computePercent(usage.users_used, limits.max_users),
      facilities: computePercent(usage.facilities_used, limits.max_facilities),
      storage_mb: computePercent(usage.storage_used_mb, limits.max_storage_mb),
      modules: computePercent(usage.modules_used, limits.max_modules),
    },
  });
};

const getSubscriptionFitCheck = async (id, user = {}) => {
  const subscription = await loadSubscriptionRecord(id, user);
  const usageSummary = await getSubscriptionUsageSummary(id, user);
  const warningPercent = subscription.plan?.plan_fit_warning_percent || 80;
  const serializedSubscription = serializeSubscription(subscription);

  const percents = Object.values(usageSummary.utilization_percent).filter(
    (value) => value !== null
  );
  const maxPercent = percents.length ? Math.max(...percents) : 0;

  let computedStatus = 'HEALTHY';
  if (maxPercent > 100) {
    computedStatus = 'EXCEEDED';
  } else if (maxPercent >= warningPercent) {
    computedStatus = 'APPROACHING_LIMIT';
  }

  return serializeSubscriptionFitCheck({
    subscription_id: serializedSubscription.id,
    plan_id: serializedSubscription.plan_id,
    stored_status: subscription.plan_fit_status,
    computed_status: computedStatus,
    warning_percent: warningPercent,
    utilization_percent: usageSummary.utilization_percent,
    exceeded: computedStatus === 'EXCEEDED',
    approaching_limit: computedStatus === 'APPROACHING_LIMIT',
  });
};

const getSubscriptionUpgradeRecommendation = async (id, user = {}) => {
  const subscription = await loadSubscriptionRecord(id, user);
  const fitCheck = await getSubscriptionFitCheck(id, user);
  const scope = requireTenantScope(user);
  const currentTier = normalizeTierCode(subscription.plan?.tier_code);
  const serializedSubscription = serializeSubscription(subscription);
  const currentPlanSupport = evaluatePlanSupport({
    planRecord: subscription.plan || {},
    subscriptionRecord: subscription,
  });
  const hasModuleFailure = currentPlanSupport.failures.some(
    (entry) => entry.type === 'module'
  );

  if (
    fitCheck.computed_status === 'HEALTHY'
    && currentPlanSupport.eligible
  ) {
    return serializeSubscriptionUpgradeRecommendation({
      subscription_id: serializedSubscription.id,
      current_plan_id: serializedSubscription.plan_id,
      recommended_plan_id: null,
      current_tier: currentTier,
      recommended_tier: null,
      recommendation: 'keep_current_plan',
      reason: 'Current usage is within healthy thresholds.',
    });
  }

  const plans = await subscriptionPlanRepository.findMany(
    getAccessiblePlanWhere(subscription.tenant_id, scope),
    0,
    100,
    { price: 'asc' }
  );
  const currentTierIndex = PLAN_TIER_ORDER.indexOf(currentTier);
  const currentPrice = toNumber(subscription.plan?.price) || 0;

  const candidatePlans = (Array.isArray(plans) ? plans : [])
    .filter((plan) => plan?.id && plan.id !== subscription.plan_id)
    .sort((left, right) => {
      const leftTierIndex = PLAN_TIER_ORDER.indexOf(
        normalizeTierCode(left?.tier_code)
      );
      const rightTierIndex = PLAN_TIER_ORDER.indexOf(
        normalizeTierCode(right?.tier_code)
      );
      if (leftTierIndex !== rightTierIndex) {
        return leftTierIndex - rightTierIndex;
      }
      return (toNumber(left?.price) || 0) - (toNumber(right?.price) || 0);
    });

  const compatiblePlan = candidatePlans.find((plan) => {
    const targetTier = normalizeTierCode(plan?.tier_code);
    const targetTierIndex = PLAN_TIER_ORDER.indexOf(targetTier);
    const targetPrice = toNumber(plan?.price) || 0;
    const qualifiesAsUpgrade =
      hasModuleFailure
        ? true
        : targetTierIndex > currentTierIndex || targetPrice > currentPrice;
    if (!qualifiesAsUpgrade) return false;
    return evaluatePlanSupport({
      planRecord: plan,
      subscriptionRecord: subscription,
    }).eligible;
  });

  if (compatiblePlan) {
    const recommendedTier = normalizeTierCode(compatiblePlan.tier_code);
    const currentFailure = currentPlanSupport.failures[0] || null;
    const reason =
      currentFailure?.type === 'module'
        ? 'Current plan customizations do not allow all active modules.'
        : fitCheck.computed_status === 'EXCEEDED'
          ? 'Usage exceeded current plan limits.'
          : 'Usage is approaching configured warning thresholds.';

    return serializeSubscriptionUpgradeRecommendation({
      subscription_id: serializedSubscription.id,
      current_plan_id: serializedSubscription.plan_id,
      recommended_plan_id:
        compatiblePlan.human_friendly_id || compatiblePlan.id,
      current_tier: currentTier,
      recommended_tier: recommendedTier,
      recommendation:
        fitCheck.computed_status === 'EXCEEDED'
        || currentFailure?.type === 'module'
          ? 'upgrade_required'
          : 'upgrade_recommended',
      reason,
    });
  }

  const customPlan = candidatePlans.find(
    (plan) => normalizeTierCode(plan?.tier_code) === 'CUSTOM'
  );
  if (customPlan) {
    return serializeSubscriptionUpgradeRecommendation({
      subscription_id: serializedSubscription.id,
      current_plan_id: serializedSubscription.plan_id,
      recommended_plan_id: customPlan.human_friendly_id || customPlan.id,
      current_tier: currentTier,
      recommended_tier: 'CUSTOM',
      recommendation: 'upgrade_required',
      reason:
        'A custom subscription configuration is required to cover the active module set and current usage.',
    });
  }

  return serializeSubscriptionUpgradeRecommendation({
    subscription_id: serializedSubscription.id,
    current_plan_id: serializedSubscription.plan_id,
    recommended_plan_id: null,
    current_tier: currentTier,
    recommended_tier:
      PLAN_TIER_ORDER[Math.min(currentTierIndex + 1, PLAN_TIER_ORDER.length - 1)],
    recommendation:
      fitCheck.computed_status === 'EXCEEDED'
        ? 'upgrade_required'
        : 'upgrade_recommended',
    reason:
      currentPlanSupport.failures.some((entry) => entry.type === 'module')
        ? 'Active modules require a broader entitlement configuration than the current plan provides.'
        : fitCheck.computed_status === 'EXCEEDED'
          ? 'Usage exceeded current plan limits.'
          : 'Usage is approaching configured warning thresholds.',
  });
};

module.exports = {
  getSubscriptionById,
  listSubscriptions,
  createSubscription,
  updateSubscription,
  cancelSubscription,
  reactivateSubscription,
  deleteSubscription,
  upgradeSubscription,
  downgradeSubscription,
  renewSubscription,
  getSubscriptionProrationPreview,
  getSubscriptionUsageSummary,
  getSubscriptionFitCheck,
  getSubscriptionUpgradeRecommendation,
};
