/**
 * Default included modules for subscription plans by tier.
 *
 * Core modules whose minimum_plan_tier_code is at or below the plan tier are
 * included by default. Add-ons are never auto-included.
 */

const PLAN_TIER_RANK = Object.freeze({
  FREE: 0,
  BASIC: 1,
  PRO: 2,
  ADVANCED: 3,
  CUSTOM: 4,
});

const text = (value) => String(value || '').trim();

const normalizeTierCode = (value) => text(value).toUpperCase();

const planTierRank = (tierCode) => {
  const rank = PLAN_TIER_RANK[normalizeTierCode(tierCode)];
  return Number.isFinite(rank) ? rank : -1;
};

const isModuleEligibleForTier = (tierCode, minimumPlanTierCode) =>
  planTierRank(tierCode) >= planTierRank(minimumPlanTierCode);

const modulePublicId = (moduleRecord = {}) =>
  text(moduleRecord.human_friendly_id) || text(moduleRecord.id) || null;

/**
 * @param {string|null|undefined} tierCode
 * @param {Array<Object>} modules
 * @param {{ includeAddOns?: boolean }} [options]
 * @returns {string[]} Public module IDs eligible for the plan tier
 */
const resolveDefaultIncludedModuleIds = (
  tierCode,
  modules = [],
  { includeAddOns = false } = {}
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
    if (
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
