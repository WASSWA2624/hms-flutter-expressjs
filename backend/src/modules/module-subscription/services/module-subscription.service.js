/**
 * Module subscription service
 *
 * @module modules/module-subscription/services
 * @description Business logic for module subscription operations.
 */

const moduleSubscriptionRepository = require('@repositories/module-subscription/module-subscription.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');
const {
  serializeModuleSubscription,
  serializeModuleSubscriptionEligibility,
} = require('@lib/subscriptions/serializers');
const {
  evaluateModuleEntitlement,
} = require('@lib/subscriptions/policies');
const {
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const {
  canAccessTenant,
  resolveUserTenantScope,
} = require('@lib/subscriptions/access');
const requireTenantScope = (user = {}) => {
  const scope = resolveUserTenantScope(user);
  if (!scope.is_elevated && !scope.tenant_id) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
  return scope;
};

const emptyList = (page, limit) => ({
  module_subscriptions: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const loadModuleSubscriptionRecord = async (identifier, user = {}) => {
  const scope = requireTenantScope(user);
  const resolvedId = await resolveEntityId({
    model: 'module_subscription',
    identifier,
  });
  const record = await moduleSubscriptionRepository.findById(resolvedId);

  if (
    !record
    || !canAccessTenant(scope, record.subscription?.tenant_id)
  ) {
    throw new HttpError('errors.module_subscription.not_found', 404);
  }

  return record;
};

const resolveModuleSubscriptionPayload = async (
  data = {},
  user = {},
  tenantIdContext = null
) => {
  const scope = requireTenantScope(user);
  const scopedTenantId = scope.is_elevated
    ? tenantIdContext || null
    : scope.tenant_id;

  const payload = {
    ...data,
  };

  if (data.module_id !== undefined) {
    payload.module_id = await resolveIdentifierForPayload({
      value: data.module_id,
      model: 'module',
      field: 'module_id',
    });
  }

  if (data.subscription_id !== undefined) {
    payload.subscription_id = await resolveIdentifierForPayload({
      value: data.subscription_id,
      model: 'subscription',
      field: 'subscription_id',
      where: scopedTenantId ? { tenant_id: scopedTenantId } : {},
    });
  }

  return payload;
};

const listModuleSubscriptions = async (
  filters = {},
  page = 1,
  limit = 20,
  sort_by = 'created_at',
  order = 'desc',
  user = {}
) => {
  const scope = requireTenantScope(user);
  const repoFilters = {};

  if (!scope.is_elevated) {
    repoFilters.subscription = { tenant_id: scope.tenant_id };
  }

  if (filters.module_id) {
    repoFilters.module_id = await resolveIdentifierForFilter({
      value: filters.module_id,
      model: 'module',
    });
  }

  if (filters.subscription_id) {
    const subscriptionId = await resolveIdentifierForFilter({
      value: filters.subscription_id,
      model: 'subscription',
      where: !scope.is_elevated ? { tenant_id: scope.tenant_id } : {},
    });
    if (subscriptionId === null) {
      return emptyList(page, limit);
    }
    if (subscriptionId) {
      repoFilters.subscription_id = subscriptionId;
    }
  }

  if (filters.is_active !== undefined) {
    repoFilters.is_active = filters.is_active === true || filters.is_active === 'true';
  }

  const skip = (page - 1) * limit;
  const orderBy = {
    [sort_by]: order,
  };

  const [moduleSubscriptions, total] = await Promise.all([
    moduleSubscriptionRepository.findMany(repoFilters, skip, limit, orderBy),
    moduleSubscriptionRepository.count(repoFilters),
  ]);

  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    module_subscriptions: moduleSubscriptions.map(serializeModuleSubscription),
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage,
    },
  };
};

const getModuleSubscriptionById = async (id, user = {}) => {
  const record = await loadModuleSubscriptionRecord(id, user);
  return serializeModuleSubscription(record);
};

const createModuleSubscription = async (data, context) => {
  const scope = requireTenantScope(context.user);
  const created = await moduleSubscriptionRepository.create({
    ...(await resolveModuleSubscriptionPayload(data, context.user, scope.tenant_id)),
    human_friendly_id:
      data.human_friendly_id
      || createSubscriptionPublicId(PUBLIC_ID_PREFIXES.module_subscription),
  });
  const moduleSubscription = await loadModuleSubscriptionRecord(created.id, context.user);

  createAuditLog({
    user_id: context.user?.id,
    action: 'CREATE',
    entity: 'module_subscription',
    entity_id: moduleSubscription.id,
    diff: { after: moduleSubscription },
    ip_address: context.ip,
    tenant_id: moduleSubscription.subscription?.tenant_id || context.tenant_id || null,
  }).catch(() => {});

  return serializeModuleSubscription(moduleSubscription);
};

const updateModuleSubscription = async (id, data, context) => {
  const existingModuleSubscription = await loadModuleSubscriptionRecord(
    id,
    context.user
  );
  await moduleSubscriptionRepository.update(
    existingModuleSubscription.id,
    await resolveModuleSubscriptionPayload(
      data,
      context.user,
      existingModuleSubscription.subscription?.tenant_id
    )
  );
  const updatedModuleSubscription = await loadModuleSubscriptionRecord(
    existingModuleSubscription.id,
    context.user
  );

  createAuditLog({
    user_id: context.user?.id,
    action: 'UPDATE',
    entity: 'module_subscription',
    entity_id: updatedModuleSubscription.id,
    diff: {
      before: existingModuleSubscription,
      after: updatedModuleSubscription,
    },
    ip_address: context.ip,
    tenant_id:
      existingModuleSubscription.subscription?.tenant_id
      || context.tenant_id
      || null,
  }).catch(() => {});

  return serializeModuleSubscription(updatedModuleSubscription);
};

const deleteModuleSubscription = async (id, context) => {
  const existingModuleSubscription = await loadModuleSubscriptionRecord(
    id,
    context.user
  );
  const deletedModuleSubscription = await moduleSubscriptionRepository.softDelete(
    existingModuleSubscription.id
  );

  createAuditLog({
    user_id: context.user?.id,
    action: 'DELETE',
    entity: 'module_subscription',
    entity_id: deletedModuleSubscription.id,
    diff: {
      before: existingModuleSubscription,
      after: deletedModuleSubscription,
    },
    ip_address: context.ip,
    tenant_id:
      existingModuleSubscription.subscription?.tenant_id
      || context.tenant_id
      || null,
  }).catch(() => {});

  return deletedModuleSubscription;
};

const activateModuleSubscription = async (id, data = {}, context = {}) => {
  const before = await loadModuleSubscriptionRecord(id, context.user);

  await moduleSubscriptionRepository.update(before.id, {
    is_active: true,
    entitlement_denied: false,
    entitlement_denial_reason: null,
    activation_requested_at: new Date(),
    activated_at: new Date(),
    deactivated_at: null,
  });
  const updated = await loadModuleSubscriptionRecord(before.id, context.user);

  createAuditLog({
    user_id: context.user?.id,
    action: 'UPDATE',
    entity: 'module_subscription',
    entity_id: updated.id,
    diff: {
      before,
      after: updated,
      metadata: {
        event: 'activate',
        reason: data.reason || null,
      },
    },
    ip_address: context.ip,
    tenant_id: before.subscription?.tenant_id || context.tenant_id || null,
  }).catch(() => {});

  return serializeModuleSubscription(updated);
};

const deactivateModuleSubscription = async (id, data = {}, context = {}) => {
  const before = await loadModuleSubscriptionRecord(id, context.user);

  await moduleSubscriptionRepository.update(before.id, {
    is_active: false,
    deactivated_at: new Date(),
  });
  const updated = await loadModuleSubscriptionRecord(before.id, context.user);

  createAuditLog({
    user_id: context.user?.id,
    action: 'UPDATE',
    entity: 'module_subscription',
    entity_id: updated.id,
    diff: {
      before,
      after: updated,
      metadata: {
        event: 'deactivate',
        reason: data.reason || null,
      },
    },
    ip_address: context.ip,
    tenant_id: before.subscription?.tenant_id || context.tenant_id || null,
  }).catch(() => {});

  return serializeModuleSubscription(updated);
};

const checkModuleSubscriptionEligibility = async (id, context = {}) => {
  const moduleSubscription = await loadModuleSubscriptionRecord(id, context.user);
  const eligibility = evaluateModuleEntitlement({
    subscriptionRecord: moduleSubscription.subscription || {},
    moduleRecord: moduleSubscription.module || {},
    planRecord: moduleSubscription.subscription?.plan || {},
  });
  const eligible = eligibility.eligible;
  const reason = eligibility.reason;

  await moduleSubscriptionRepository.update(moduleSubscription.id, {
    entitlement_denied: !eligible,
    entitlement_denial_reason: reason,
    eligibility_checked_at: new Date(),
    evaluated_plan_fit_status: moduleSubscription.subscription?.plan_fit_status || null,
  });
  const updated = await loadModuleSubscriptionRecord(
    moduleSubscription.id,
    context.user
  );

  createAuditLog({
    user_id: context.user?.id,
    action: 'UPDATE',
    entity: 'module_subscription',
    entity_id: updated.id,
    diff: {
      before: moduleSubscription,
      after: updated,
      metadata: {
        event: 'eligibility_check',
        module_minimum_tier:
          moduleSubscription.module?.minimum_plan_tier_code || null,
        subscription_plan_tier:
          moduleSubscription.subscription?.plan?.tier_code || null,
        eligible,
        reason,
      },
    },
    ip_address: context.ip,
    tenant_id: moduleSubscription.subscription?.tenant_id || context.tenant_id || null,
  }).catch(() => {});

  return serializeModuleSubscriptionEligibility({
    module_subscription_id: serializeModuleSubscription(updated).id,
    eligible,
    reason,
    module_minimum_tier:
      moduleSubscription.module?.minimum_plan_tier_code || null,
    subscription_plan_tier:
      moduleSubscription.subscription?.plan?.tier_code || null,
    checked_at: updated.eligibility_checked_at,
    module_subscription: serializeModuleSubscription(updated),
  });
};

module.exports = {
  listModuleSubscriptions,
  getModuleSubscriptionById,
  createModuleSubscription,
  updateModuleSubscription,
  deleteModuleSubscription,
  activateModuleSubscription,
  deactivateModuleSubscription,
  checkModuleSubscriptionEligibility,
};
