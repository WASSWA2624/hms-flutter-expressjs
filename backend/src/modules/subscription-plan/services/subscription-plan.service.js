/**
 * Subscription Plan service
 *
 * @module modules/subscription-plan/services
 * @description Business logic layer for subscription plan operations.
 */

const subscriptionPlanRepository = require('@repositories/subscription-plan/subscription-plan.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');
const {
  serializePlanAddOnEligibility,
  serializePlanEntitlements,
  serializeSubscriptionPlan,
} = require('@lib/subscriptions/serializers');
const {
  getPlanModuleConfiguration,
  includesAnyToken,
  normalizeTierCode,
  tierMeetsMinimum,
} = require('@lib/subscriptions/policies');
const {
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const {
  canAccessTenant,
  canAccessTenantOrGlobal,
  resolveUserTenantScope,
} = require('@lib/subscriptions/access');
const PLAN_INCLUDE = Object.freeze({
  tenant: true,
  _count: {
    select: {
      subscriptions: true,
    },
  },
});

const TIER_BASE_ENTITLEMENTS = {
  FREE: ['group_1', 'group_2_basic', 'group_3_basic', 'group_4_basic', 'group_13_basic', 'group_17_view_only', 'group_15_fault_reporting'],
  BASIC: ['group_1', 'group_2', 'group_3', 'group_4', 'group_13_core', 'group_16', 'group_17_basic', 'group_15_foundation'],
  PRO: ['group_1_to_20_core', 'group_15A_add_on_eligible'],
  ADVANCED: ['group_1_to_20_core', 'on_prem_standard_package', 'all_standard_add_ons'],
  CUSTOM: ['group_1_to_20_core', 'all_standard_add_ons', 'bespoke_contract_scope'],
};

const ADD_ONS = [
  { code: 'inventory_procurement_lite', name: 'Inventory and Procurement Lite', minimum_tier: 'BASIC', price_range: '$19-$59/mo' },
  { code: 'biomedical_engineering_suite', name: 'Biomedical Engineering Suite', minimum_tier: 'PRO', price_range: '$49-$199/mo' },
  { code: 'compliance_audit_suite', name: 'Compliance and Audit Suite', minimum_tier: 'PRO', price_range: '$39-$149/mo' },
  { code: 'advanced_analytics', name: 'Advanced Analytics', minimum_tier: 'PRO', price_range: '$29-$99/mo' },
  { code: 'integrations_webhooks_pack', name: 'Integrations/Webhooks Pack', minimum_tier: 'PRO', price_range: '$49-$149/mo' },
  { code: 'extra_storage', name: 'Extra Storage', minimum_tier: 'BASIC', price_range: '$5 / 10GB' },
  { code: 'sms_credits', name: 'SMS Credits', minimum_tier: 'BASIC', price_range: 'usage-based' },
];

const requireTenantScope = (user = {}) => {
  const scope = resolveUserTenantScope(user);
  if (!scope.is_elevated && !scope.tenant_id) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
  return scope;
};

const emptyList = (page, limit) => ({
  subscriptionPlans: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const loadSubscriptionPlanRecord = async (
  identifier,
  user = {},
  requireOwnedTenant = false
) => {
  const scope = requireTenantScope(user);
  const resolvedId = await resolveEntityId({
    model: 'subscription_plan',
    identifier,
  });
  const subscriptionPlan = await subscriptionPlanRepository.findById(resolvedId, PLAN_INCLUDE);

  if (!subscriptionPlan) {
    throw new HttpError('errors.subscription_plan.not_found', 404);
  }

  const accessible = requireOwnedTenant
    ? canAccessTenant(scope, subscriptionPlan.tenant_id)
    : canAccessTenantOrGlobal(scope, subscriptionPlan.tenant_id);

  if (!accessible) {
    throw new HttpError('errors.subscription_plan.not_found', 404);
  }

  return subscriptionPlan;
};

const resolveSubscriptionPlanPayload = async (data = {}, user = {}) => {
  const scope = requireTenantScope(user);
  const payload = {
    ...data,
  };

  if (!scope.is_elevated) {
    payload.tenant_id = scope.tenant_id;
    return payload;
  }

  if (data.tenant_id !== undefined) {
    payload.tenant_id = await resolveIdentifierForPayload({
      value: data.tenant_id,
      model: 'tenant',
      field: 'tenant_id',
      nullable: true,
    });
  }

  return payload;
};

const getSubscriptionPlanById = async (id, user = {}) => {
  const subscriptionPlan = await loadSubscriptionPlanRecord(id, user);
  return serializeSubscriptionPlan(subscriptionPlan);
};

const listSubscriptionPlans = async (
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
    where.OR = [{ tenant_id: null }, { tenant_id: scope.tenant_id }];
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
      delete where.OR;
    }
  }

  if (filters.billing_cycle) {
    where.billing_cycle = filters.billing_cycle;
  }

  if (filters.search) {
    const searchClauses = [
      { human_friendly_id: { contains: filters.search, mode: 'insensitive' } },
      { name: { contains: filters.search, mode: 'insensitive' } },
      { code: { contains: filters.search, mode: 'insensitive' } },
      { tier_code: { contains: filters.search, mode: 'insensitive' } },
    ];

    if (where.OR) {
      where.AND = [...(where.AND || []), { OR: where.OR }, { OR: searchClauses }];
      delete where.OR;
    } else {
      where.OR = searchClauses;
    }
  }

  if (filters.name) {
    where.name = { contains: filters.name, mode: 'insensitive' };
  }

  const [subscriptionPlans, total] = await Promise.all([
    subscriptionPlanRepository.findMany(where, skip, limit, orderBy, PLAN_INCLUDE),
    subscriptionPlanRepository.count(where),
  ]);

  const totalPages = Math.ceil(total / limit);

  return {
    subscriptionPlans: subscriptionPlans.map(serializeSubscriptionPlan),
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

const createSubscriptionPlan = async (data, user, ip) => {
  const scope = requireTenantScope(user);
  const payload = await resolveSubscriptionPlanPayload({
    ...data,
    tenant_id: scope.is_elevated ? data.tenant_id : scope.tenant_id,
    human_friendly_id:
      data.human_friendly_id
      || createSubscriptionPublicId(PUBLIC_ID_PREFIXES.subscription_plan),
  }, user);

  const created = await subscriptionPlanRepository.create(payload);
  const subscriptionPlan = await loadSubscriptionPlanRecord(
    created.id,
    user,
    true
  );

  await createAuditLog({
    tenant_id: subscriptionPlan.tenant_id,
    user_id: user?.id || null,
    action: 'CREATE',
    entity: 'subscription_plan',
    entity_id: subscriptionPlan.id,
    diff: { after: subscriptionPlan },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscriptionPlan(subscriptionPlan);
};

const updateSubscriptionPlan = async (id, data, user, ip) => {
  const before = await loadSubscriptionPlanRecord(id, user, true);
  const payload = await resolveSubscriptionPlanPayload(data, user);
  await subscriptionPlanRepository.update(before.id, payload);
  const subscriptionPlan = await loadSubscriptionPlanRecord(before.id, user, true);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity: 'subscription_plan',
    entity_id: subscriptionPlan.id,
    diff: { before, after: subscriptionPlan },
    ip_address: ip,
  }).catch(() => {});

  return serializeSubscriptionPlan(subscriptionPlan);
};

const deleteSubscriptionPlan = async (id, user, ip) => {
  const before = await loadSubscriptionPlanRecord(id, user, true);
  const subscriptionPlan = await subscriptionPlanRepository.softDelete(before.id);

  await createAuditLog({
    tenant_id: before.tenant_id,
    user_id: user?.id || null,
    action: 'DELETE',
    entity: 'subscription_plan',
    entity_id: subscriptionPlan.id,
    diff: { before, after: subscriptionPlan },
    ip_address: ip,
  }).catch(() => {});

  return subscriptionPlan;
};

const getPlanEntitlements = async (id, user = {}) => {
  const plan = await loadSubscriptionPlanRecord(id, user);
  const serializedPlan = serializeSubscriptionPlan(plan);
  const tierCode = normalizeTierCode(plan.tier_code);
  const planModuleConfig = getPlanModuleConfiguration(plan);

  return serializePlanEntitlements({
    subscription_plan_id: serializedPlan.id,
    code: plan.code,
    name: plan.name,
    tier_code: tierCode,
    billing_cycle: plan.billing_cycle,
    limits: {
      max_users: plan.max_users,
      max_facilities: plan.max_facilities,
      max_storage_mb: plan.max_storage_mb,
      max_modules: plan.max_modules,
      warning_percent: plan.plan_fit_warning_percent,
    },
    base_entitlements: tierCode ? (TIER_BASE_ENTITLEMENTS[tierCode] || []) : [],
    add_on_eligibility: plan.add_on_eligibility_json || null,
    limit_policy: plan.limit_policy_json || null,
    allowed_modules: {
      included: planModuleConfig.included_modules,
      blocked: planModuleConfig.blocked_modules,
      add_on_eligible: planModuleConfig.add_on_modules,
      customization_notes: planModuleConfig.customization_notes,
    },
  });
};

const getPlanAddOnEligibility = async (id, user = {}) => {
  const plan = await loadSubscriptionPlanRecord(id, user);
  const serializedPlan = serializeSubscriptionPlan(plan);
  const tierCode = normalizeTierCode(plan.tier_code);
  const planModuleConfig = getPlanModuleConfiguration(plan);

  const addOns = ADD_ONS.map((addOn) => {
    const eligible = tierCode ? tierMeetsMinimum(tierCode, addOn.minimum_tier) : false;
    return {
      code: addOn.code,
      name: addOn.name,
      minimum_tier: addOn.minimum_tier,
      price_range: addOn.price_range,
      eligible,
      configured:
        planModuleConfig.add_on_modules.length === 0
          ? eligible
          : includesAnyToken([addOn.code], planModuleConfig.add_on_modules),
    };
  });

  return serializePlanAddOnEligibility({
    subscription_plan_id: serializedPlan.id,
    tier_code: tierCode,
    add_ons: addOns,
    configured_add_on_module_ids: planModuleConfig.add_on_modules,
    customization_notes: planModuleConfig.customization_notes,
  });
};

module.exports = {
  getSubscriptionPlanById,
  listSubscriptionPlans,
  createSubscriptionPlan,
  updateSubscriptionPlan,
  deleteSubscriptionPlan,
  getPlanEntitlements,
  getPlanAddOnEligibility,
};
