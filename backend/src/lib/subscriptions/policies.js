const { text } = require('@lib/subscriptions/access');

const PLAN_TIER_ORDER = ['FREE', 'BASIC', 'PRO', 'ADVANCED', 'CUSTOM'];

const isObject = (value) =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value);

const numberValue = (value, fallback = null) => {
  if (value === null || value === undefined || value === '') return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const normalizeTierCode = (tierCode) => {
  const normalized = text(tierCode).toUpperCase();
  return PLAN_TIER_ORDER.includes(normalized) ? normalized : null;
};

const tierMeetsMinimum = (tierCode, minimumTier) => {
  const currentIndex = PLAN_TIER_ORDER.indexOf(normalizeTierCode(tierCode));
  const minimumIndex = PLAN_TIER_ORDER.indexOf(normalizeTierCode(minimumTier));
  if (currentIndex === -1 || minimumIndex === -1) return false;
  return currentIndex >= minimumIndex;
};

const uniqueTokens = (values = []) => {
  const seen = new Set();
  return (Array.isArray(values) ? values : [])
    .map((value) => text(value))
    .filter(Boolean)
    .filter((value) => {
      const key = value.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
};

const readTokenList = (...candidates) =>
  uniqueTokens(
    candidates.flatMap((candidate) => {
      if (Array.isArray(candidate)) return candidate;
      const normalized = text(candidate);
      return normalized ? [normalized] : [];
    })
  );

const getModuleTokens = (moduleRecord = {}) =>
  readTokenList(
    moduleRecord.human_friendly_id,
    moduleRecord.slug,
    moduleRecord.name,
    moduleRecord.id
  );

const getPlanTokens = (planRecord = {}) =>
  readTokenList(
    planRecord.human_friendly_id,
    planRecord.code,
    planRecord.name,
    planRecord.id
  );

const includesAnyToken = (tokens = [], configuredValues = []) => {
  const tokenSet = new Set(
    readTokenList(configuredValues).map((value) => value.toLowerCase())
  );
  if (!tokenSet.size) return false;
  return readTokenList(tokens).some((token) => tokenSet.has(token.toLowerCase()));
};

const getPlanModuleConfiguration = (planRecord = {}) => {
  const extension = isObject(planRecord.extension_json)
    ? planRecord.extension_json
    : {};
  const allowedModules = isObject(extension.allowed_modules)
    ? extension.allowed_modules
    : {};
  const addOnEligibility = isObject(planRecord.add_on_eligibility_json)
    ? planRecord.add_on_eligibility_json
    : {};

  return {
    included_modules: readTokenList(
      allowedModules.included,
      extension.included_module_ids,
      extension.allowed_module_ids
    ),
    blocked_modules: readTokenList(
      allowedModules.blocked,
      extension.blocked_module_ids
    ),
    add_on_modules: readTokenList(
      addOnEligibility.allowed_module_ids,
      addOnEligibility.add_on_module_ids,
      addOnEligibility.modules,
      extension.add_on_module_ids
    ),
    customization_notes:
      text(allowedModules.notes || extension.customization_notes || addOnEligibility.notes) ||
      null,
  };
};

const getSubscriptionModuleConfiguration = (subscriptionRecord = {}) => {
  const extension = isObject(subscriptionRecord.extension_json)
    ? subscriptionRecord.extension_json
    : {};
  const overrides = isObject(extension.module_overrides)
    ? extension.module_overrides
    : {};

  return {
    allowed_modules: readTokenList(
      overrides.allowed,
      extension.allowed_module_ids,
      extension.custom_allowed_module_ids
    ),
    blocked_modules: readTokenList(
      overrides.blocked,
      extension.blocked_module_ids
    ),
    customization_notes:
      text(overrides.notes || extension.customization_notes) || null,
  };
};

const getModuleEntitlementConfiguration = (moduleRecord = {}) => {
  const policy = isObject(moduleRecord.entitlement_policy_json)
    ? moduleRecord.entitlement_policy_json
    : {};

  return {
    allowed_plan_ids: readTokenList(
      policy.allowed_plan_ids,
      policy.allowed_plans
    ),
    blocked_plan_ids: readTokenList(
      policy.blocked_plan_ids,
      policy.blocked_plans
    ),
    requires_customization: Boolean(policy.requires_customization),
    notes: text(policy.notes || policy.reason) || null,
  };
};

const evaluateModuleEntitlement = ({
  subscriptionRecord = {},
  moduleRecord = {},
  planRecord = {},
} = {}) => {
  const moduleTokens = getModuleTokens(moduleRecord);
  const planTokens = getPlanTokens(planRecord);
  const planConfig = getPlanModuleConfiguration(planRecord);
  const subscriptionConfig = getSubscriptionModuleConfiguration(
    subscriptionRecord
  );
  const modulePolicy = getModuleEntitlementConfiguration(moduleRecord);
  const planTier = normalizeTierCode(planRecord.tier_code);
  const moduleTier = normalizeTierCode(moduleRecord.minimum_plan_tier_code);

  if (
    modulePolicy.blocked_plan_ids.length
    && includesAnyToken(planTokens, modulePolicy.blocked_plan_ids)
  ) {
    return {
      eligible: false,
      reason: 'blocked_for_plan',
      planConfig,
      subscriptionConfig,
      modulePolicy,
    };
  }

  if (
    modulePolicy.allowed_plan_ids.length
    && !includesAnyToken(planTokens, modulePolicy.allowed_plan_ids)
  ) {
    return {
      eligible: false,
      reason: 'plan_not_allowed',
      planConfig,
      subscriptionConfig,
      modulePolicy,
    };
  }

  if (
    subscriptionConfig.blocked_modules.length
    && includesAnyToken(moduleTokens, subscriptionConfig.blocked_modules)
  ) {
    return {
      eligible: false,
      reason: 'blocked_by_subscription_customization',
      planConfig,
      subscriptionConfig,
      modulePolicy,
    };
  }

  if (
    planConfig.blocked_modules.length
    && includesAnyToken(moduleTokens, planConfig.blocked_modules)
  ) {
    return {
      eligible: false,
      reason: 'blocked_by_plan_configuration',
      planConfig,
      subscriptionConfig,
      modulePolicy,
    };
  }

  if (moduleTier && planTier && !tierMeetsMinimum(planTier, moduleTier)) {
    return {
      eligible: false,
      reason: `requires_${moduleTier}`,
      planConfig,
      subscriptionConfig,
      modulePolicy,
    };
  }

  if (
    subscriptionConfig.allowed_modules.length
    && !includesAnyToken(moduleTokens, subscriptionConfig.allowed_modules)
  ) {
    return {
      eligible: false,
      reason: 'not_in_subscription_allowlist',
      planConfig,
      subscriptionConfig,
      modulePolicy,
    };
  }

  const effectivePlanAllowlist = moduleRecord.is_add_on
    ? readTokenList(planConfig.included_modules, planConfig.add_on_modules)
    : planConfig.included_modules;

  if (
    effectivePlanAllowlist.length
    && !includesAnyToken(moduleTokens, effectivePlanAllowlist)
  ) {
    return {
      eligible: false,
      reason: moduleRecord.is_add_on
        ? 'not_in_add_on_allowlist'
        : 'not_in_plan_allowlist',
      planConfig,
      subscriptionConfig,
      modulePolicy,
    };
  }

  if (
    modulePolicy.requires_customization
    && !subscriptionConfig.allowed_modules.length
    && !planConfig.included_modules.length
    && !planConfig.add_on_modules.length
  ) {
    return {
      eligible: false,
      reason: 'customization_required',
      planConfig,
      subscriptionConfig,
      modulePolicy,
    };
  }

  return {
    eligible: true,
    reason: null,
    planConfig,
    subscriptionConfig,
    modulePolicy,
  };
};

const evaluatePlanSupport = ({
  planRecord = {},
  subscriptionRecord = {},
} = {}) => {
  const failures = [];
  const usage = {
    users_used: numberValue(subscriptionRecord.users_used, 0),
    facilities_used: numberValue(subscriptionRecord.facilities_used, 0),
    storage_used_mb: numberValue(subscriptionRecord.storage_used_mb, 0),
    modules_used: numberValue(
      subscriptionRecord.modules_used,
      Array.isArray(subscriptionRecord.module_subscriptions)
        ? subscriptionRecord.module_subscriptions.filter((entry) => entry?.is_active)
            .length
        : 0
    ),
  };

  const limits = {
    max_users: numberValue(planRecord.max_users),
    max_facilities: numberValue(planRecord.max_facilities),
    max_storage_mb: numberValue(planRecord.max_storage_mb),
    max_modules: numberValue(planRecord.max_modules),
  };

  [
    ['users', usage.users_used, limits.max_users],
    ['facilities', usage.facilities_used, limits.max_facilities],
    ['storage_mb', usage.storage_used_mb, limits.max_storage_mb],
    ['modules', usage.modules_used, limits.max_modules],
  ].forEach(([dimension, used, limit]) => {
    if (limit === null || limit === undefined || limit <= 0) return;
    if (used > limit) {
      failures.push({
        type: 'usage',
        reason: `${dimension}_limit_exceeded`,
        used,
        limit,
      });
    }
  });

  const moduleResults = (Array.isArray(subscriptionRecord.module_subscriptions)
    ? subscriptionRecord.module_subscriptions
    : []
  )
    .filter((entry) => entry?.is_active !== false)
    .map((entry) => ({
      module_subscription_id: entry.human_friendly_id || entry.id,
      module_id: entry.module?.human_friendly_id || entry.module_id || null,
      module_label: entry.module?.name || entry.module?.slug || null,
      ...evaluateModuleEntitlement({
        subscriptionRecord,
        moduleRecord: entry.module || {},
        planRecord,
      }),
    }));

  moduleResults
    .filter((entry) => !entry.eligible)
    .forEach((entry) => {
      failures.push({
        type: 'module',
        reason: entry.reason,
        module_id: entry.module_id,
        module_label: entry.module_label,
      });
    });

  return {
    eligible: failures.length === 0,
    failures,
    module_results: moduleResults,
    usage,
    limits,
  };
};

module.exports = {
  PLAN_TIER_ORDER,
  evaluateModuleEntitlement,
  evaluatePlanSupport,
  getModuleEntitlementConfiguration,
  getModuleTokens,
  getPlanModuleConfiguration,
  getPlanTokens,
  getSubscriptionModuleConfiguration,
  includesAnyToken,
  normalizeTierCode,
  tierMeetsMinimum,
  uniqueTokens,
};
