/**
 * Default included modules for subscription plans by tier.
 *
 * Core modules whose minimum_plan_tier_code is at or below the plan tier are
 * included by default. Add-ons are never auto-included.
 * Platform infrastructure modules are included so plan allowlists stay complete.
 */

const {
  PLAN_TIER_RANK,
  isEligibleForTier,
} = require('@lib/subscriptions/plan-module-matrix');

const text = (value) => String(value || '').trim();

const normalizeTierCode = (value) => text(value).toUpperCase();

const planTierRank = (tierCode) => {
  const rank = PLAN_TIER_RANK[normalizeTierCode(tierCode)];
  return Number.isFinite(rank) ? rank : -1;
};

const isModuleEligibleForTier = (tierCode, minimumPlanTierCode) =>
  isEligibleForTier(tierCode, minimumPlanTierCode);

const modulePublicId = (moduleRecord = {}) =>
  text(moduleRecord.human_friendly_id) || text(moduleRecord.id) || null;

const isPlatformInfrastructure = (moduleRecord = {}) => {
  const extension =
    moduleRecord.extension_json && typeof moduleRecord.extension_json === 'object'
      ? moduleRecord.extension_json
      : moduleRecord.extensionJson && typeof moduleRecord.extensionJson === 'object'
        ? moduleRecord.extensionJson
        : {};
  return Boolean(extension.is_platform_infrastructure);
};

const isDeprecatedLegacyAlias = (moduleRecord = {}) => {
  const extension =
    moduleRecord.extension_json && typeof moduleRecord.extension_json === 'object'
      ? moduleRecord.extension_json
      : moduleRecord.extensionJson && typeof moduleRecord.extensionJson === 'object'
        ? moduleRecord.extensionJson
        : {};
  return Boolean(extension.deprecated);
};

/**
 * @param {string|null|undefined} tierCode
 * @param {Array<Object>} modules
 * @param {{ includeAddOns?: boolean, includeLegacyAliases?: boolean }} [options]
 * @returns {string[]} Public module IDs eligible for the plan tier
 */
const resolveDefaultIncludedModuleIds = (
  tierCode,
  modules = [],
  { includeAddOns = false, includeLegacyAliases = false } = {}
) => {
  if (!tierCode || !Array.isArray(modules) || modules.length === 0) {
    return [];
  }

  const ids = [];
  const seen = new Set();
  for (const moduleRecord of modules) {
    if (!moduleRecord) {
      continue;
    }
    if (!includeAddOns && moduleRecord.is_add_on) {
      continue;
    }
    if (!includeLegacyAliases && isDeprecatedLegacyAlias(moduleRecord)) {
      continue;
    }
    if (
      !isPlatformInfrastructure(moduleRecord) &&
      !isModuleEligibleForTier(
        tierCode,
        moduleRecord.minimum_plan_tier_code ||
          moduleRecord.minimumPlanTierCode ||
          moduleRecord.meta?.minimum_plan_tier_code
      )
    ) {
      continue;
    }
    const id = modulePublicId(moduleRecord);
    if (!id || seen.has(id)) {
      continue;
    }
    seen.add(id);
    ids.push(id);
  }
  return ids;
};

/**
 * Prefer stored allowlist; otherwise derive from tier + catalog modules.
 * @param {string[]} storedIds
 * @param {string|null|undefined} tierCode
 * @param {Array<Object>} modules
 * @returns {string[]}
 */
const resolveEffectiveIncludedModuleIds = (
  storedIds = [],
  tierCode = null,
  modules = []
) => {
  const stored = Array.isArray(storedIds)
    ? storedIds.map(text).filter(Boolean)
    : [];
  if (stored.length > 0) {
    return [...new Set(stored)];
  }
  return resolveDefaultIncludedModuleIds(tierCode, modules);
};

module.exports = {
  PLAN_TIER_RANK,
  isModuleEligibleForTier,
  planTierRank,
  resolveDefaultIncludedModuleIds,
  resolveEffectiveIncludedModuleIds,
};
