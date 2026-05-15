/**
 * Module entitlement middleware
 *
 * Enforces free-core vs paid-module access for tenant-scoped requests.
 */

const { HttpError } = require('@lib/errors');
const moduleRepository = require('@repositories/module/module.repository');
const moduleSubscriptionRepository = require('@repositories/module-subscription/module-subscription.repository');
const subscriptionRepository = require('@repositories/subscription/subscription.repository');
const { recordSecurityEvent } = require('@lib/telemetry/metrics');

const CACHE_TTL_MS = 60 * 1000;
const CACHE_MAX_ENTRIES = 5000;

const entitlementCache = new Map();
const fallbackEntitlementCache = new Map();
const moduleExistenceCache = new Map();
const subscriptionStateCache = new Map();

const PLAN_TIER_RANK = Object.freeze({
  FREE: 0,
  BASIC: 1,
  PRO: 2,
  ADVANCED: 3,
  CUSTOM: 4,
});

// Core module definitions used when older demo databases are missing module rows.
const CORE_MODULE_METADATA_FALLBACKS = Object.freeze({
  mortuary: Object.freeze({ minimumPlanTierCode: 'BASIC' }),
});

// Free core modules available across all plans.
const FREE_CORE_MODULES = new Set([
  'tenant',
  'user-session',
  'facility',
  'branch',
  'department',
  'unit',
  'room',
  'ward',
  'bed',
  'address',
  'contact',
  'user',
  'user-profile',
  'role',
  'permission',
  'role-permission',
  'user-role',
  'user-mfa',
  'oauth-account',
  'api-key',
  'api-key-permission',
  'patient',
  'patient-identifier',
  'patient-contact',
  'patient-guardian',
  'patient-allergy',
  'patient-medical-history',
  'patient-document',
  'consent',
  'appointment',
  'appointment-participant',
  'appointment-reminder',
  'provider-schedule',
  'availability-slot',
  'doctor',
  'visit-queue',
  'opd-flow',
  'encounter',
  'clinical-note',
  'vital-sign',
  'invoice',
  'invoice-item',
  'payment',
  'billing',
  'notification',
  'notification-delivery',
  'communications-workspace',
  'template',
  'template-variable',
  'report-definition',
  'report-run',
  'dashboard-workspace',
  'dashboard-widget',
  'settings-workspace',
  'kpi-snapshot',
  'module',
  'module-subscription',
  'subscription',
  'subscription-plan',
  'subscription-invoice',
  'license',
  'maintenance-request',
  'equipment-incident-report',
  'asset',
  'asset-service-log',
  'staff-position'
]);

const IRREGULAR_PATH_SEGMENTS = {
  branches: 'branch',
  diagnoses: 'diagnosis'
};

const MODULE_SEGMENT_SLUG_OVERRIDES = Object.freeze({
  'ipd-flows': 'inpatient-bed-management',
  admissions: 'inpatient-bed-management',
  'bed-assignments': 'inpatient-bed-management',
  'ward-rounds': 'inpatient-bed-management',
  'nursing-notes': 'inpatient-bed-management',
  'medication-administrations': 'inpatient-bed-management',
  'discharge-summaries': 'inpatient-bed-management',
  'transfer-requests': 'inpatient-bed-management',
  'theatre-cases': 'theatre-anesthesia',
  'theatre-flows': 'theatre-anesthesia',
  'anesthesia-records': 'theatre-anesthesia',
  'post-op-notes': 'theatre-anesthesia',
  lab: 'lab-workflows',
  'lab-tests': 'lab-workflows',
  'lab-panels': 'lab-workflows',
  'lab-orders': 'lab-workflows',
  'lab-order-items': 'lab-workflows',
  'lab-samples': 'lab-workflows',
  'lab-results': 'lab-workflows',
  'lab-qc-logs': 'lab-workflows',
  radiology: 'radiology-workflows',
  'radiology-tests': 'radiology-workflows',
  'radiology-orders': 'radiology-workflows',
  'radiology-results': 'radiology-workflows',
  'imaging-studies': 'radiology-workflows',
  'imaging-assets': 'radiology-workflows',
  'pacs-links': 'radiology-workflows',
  pharmacy: 'pharmacy-dispensing',
  drugs: 'pharmacy-dispensing',
  'drug-batches': 'pharmacy-dispensing',
  'formulary-items': 'pharmacy-dispensing',
  'pharmacy-orders': 'pharmacy-dispensing',
  'pharmacy-order-items': 'pharmacy-dispensing',
  'dispense-logs': 'pharmacy-dispensing',
  'break-glass-access': 'break-glass-access',
});

const trimExpiredEntries = (cache) => {
  const now = Date.now();
  for (const [key, entry] of cache.entries()) {
    if (!entry || entry.expiresAt <= now) {
      cache.delete(key);
    }
  }
};

const enforceCacheLimit = (cache) => {
  if (cache.size <= CACHE_MAX_ENTRIES) return;

  trimExpiredEntries(cache);
  if (cache.size <= CACHE_MAX_ENTRIES) return;

  // Remove oldest entries first (Map iteration order is insertion order)
  while (cache.size > CACHE_MAX_ENTRIES) {
    const oldestKey = cache.keys().next().value;
    if (!oldestKey) break;
    cache.delete(oldestKey);
  }
};

const getCached = (cache, key) => {
  const cached = cache.get(key);
  if (!cached) return null;
  if (cached.expiresAt <= Date.now()) {
    cache.delete(key);
    return null;
  }
  return cached.value;
};

const setCached = (cache, key, value) => {
  cache.set(key, {
    value,
    expiresAt: Date.now() + CACHE_TTL_MS
  });
  enforceCacheLimit(cache);
};

const resolveEligiblePlanTiers = (minimumPlanTierCode) => {
  const minimumRank = PLAN_TIER_RANK[String(minimumPlanTierCode || '').toUpperCase()];
  if (minimumRank === undefined) return [];

  return Object.entries(PLAN_TIER_RANK)
    .filter(([, rank]) => rank >= minimumRank)
    .map(([tier]) => tier);
};

const normalizeSegmentToModuleSlug = (segment) => {
  const normalized = String(segment || '').trim().toLowerCase();
  if (!normalized) return null;

  if (IRREGULAR_PATH_SEGMENTS[normalized]) {
    return IRREGULAR_PATH_SEGMENTS[normalized];
  }

  if (normalized.endsWith('ies')) {
    return `${normalized.slice(0, -3)}y`;
  }

  if (normalized.endsWith('sses')) {
    return normalized.slice(0, -2);
  }

  if (normalized.endsWith('s')) {
    return normalized.slice(0, -1);
  }

  return normalized;
};

const resolveModuleSlugFromPath = (reqPath) => {
  const normalizedPath = String(reqPath || '').trim();
  if (!normalizedPath || normalizedPath === '/' || normalizedPath === '.') return null;

  const rawSegment = normalizedPath.replace(/^\/+/, '').split('/')[0];
  const mappedSlug =
    MODULE_SEGMENT_SLUG_OVERRIDES[String(rawSegment || '').trim().toLowerCase()];
  if (mappedSlug) return mappedSlug;
  return normalizeSegmentToModuleSlug(rawSegment);
};

const moduleExists = async (moduleSlug) => {
  const cacheKey = `module:${moduleSlug}`;
  const cached = getCached(moduleExistenceCache, cacheKey);
  if (cached !== null) return cached;

  const exists = (await moduleRepository.count({ slug: moduleSlug })) > 0;
  setCached(moduleExistenceCache, cacheKey, exists);
  return exists;
};

const tenantHasModuleAccess = async (tenantId, moduleSlug) => {
  const cacheKey = `${tenantId}:${moduleSlug}`;
  const cached = getCached(entitlementCache, cacheKey);
  if (cached !== null) return cached;

  const allowed = (await moduleSubscriptionRepository.count({
    is_active: true,
    module: {
      slug: moduleSlug,
      deleted_at: null
    },
    subscription: {
      tenant_id: tenantId,
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL'] },
      OR: [
        { end_date: null },
        { end_date: { gte: new Date() } }
      ]
    }
  })) > 0;

  setCached(entitlementCache, cacheKey, allowed);
  return allowed;
};

const tenantHasActiveSubscription = async (tenantId) => {
  const cacheKey = `tenant-subscription:${tenantId}`;
  const cached = getCached(subscriptionStateCache, cacheKey);
  if (cached !== null) return cached;

  const hasActiveSubscription = (await subscriptionRepository.count({
    tenant_id: tenantId,
    deleted_at: null,
    status: { in: ['ACTIVE', 'TRIAL'] },
    OR: [
      { end_date: null },
      { end_date: { gte: new Date() } }
    ]
  })) > 0;

  setCached(subscriptionStateCache, cacheKey, hasActiveSubscription);
  return hasActiveSubscription;
};

const tenantHasFallbackModuleAccess = async (tenantId, moduleSlug) => {
  const fallback = CORE_MODULE_METADATA_FALLBACKS[moduleSlug];
  if (!fallback) return false;

  const cacheKey = `${tenantId}:${moduleSlug}`;
  const cached = getCached(fallbackEntitlementCache, cacheKey);
  if (cached !== null) return cached;

  const eligiblePlanTiers = resolveEligiblePlanTiers(fallback.minimumPlanTierCode);
  if (eligiblePlanTiers.length === 0) {
    setCached(fallbackEntitlementCache, cacheKey, false);
    return false;
  }

  const allowed = (await subscriptionRepository.count({
    tenant_id: tenantId,
    deleted_at: null,
    status: { in: ['ACTIVE', 'TRIAL'] },
    OR: [
      { end_date: null },
      { end_date: { gte: new Date() } }
    ],
    plan: {
      tier_code: { in: eligiblePlanTiers }
    }
  })) > 0;

  setCached(fallbackEntitlementCache, cacheKey, allowed);
  return allowed;
};

const enforceModuleEntitlement = () => async (req, res, next) => {
  try {
    const moduleSlug = resolveModuleSlugFromPath(req.path);
    if (!moduleSlug) return next();

    if (FREE_CORE_MODULES.has(moduleSlug)) return next();

    const user = req.user || {};
    const tenantId = user.tenant_id || user.tenantId || null;
    if (!tenantId) {
      recordSecurityEvent('module.entitlement_denied', {
        'hms.module.slug': moduleSlug,
      });
      return next(new HttpError('errors.auth.module_not_entitled', 403, [
        { tenant_id: null, module: moduleSlug, reason: 'missing_tenant_scope' }
      ]));
    }

    const hasSubscription = await tenantHasActiveSubscription(tenantId);
    if (!hasSubscription) {
      recordSecurityEvent('module.entitlement_denied', {
        'hms.module.slug': moduleSlug,
      });
      return next(new HttpError('errors.auth.module_not_entitled', 403, [
        { tenant_id: tenantId, module: moduleSlug, reason: 'subscription_required' }
      ]));
    }

    const knownModule = await moduleExists(moduleSlug);
    if (!knownModule) {
      const fallbackAllowed = await tenantHasFallbackModuleAccess(tenantId, moduleSlug);
      if (fallbackAllowed) return next();

      recordSecurityEvent('module.entitlement_denied', {
        'hms.module.slug': moduleSlug,
      });
      return next(new HttpError('errors.auth.module_not_entitled', 403, [
        { tenant_id: tenantId, module: moduleSlug, reason: 'module_metadata_missing' }
      ]));
    }

    const allowed = await tenantHasModuleAccess(tenantId, moduleSlug);
    if (!allowed) {
      recordSecurityEvent('module.entitlement_denied', {
        'hms.module.slug': moduleSlug,
      });
      return next(new HttpError('errors.auth.module_not_entitled', 403, [
        { tenant_id: tenantId, module: moduleSlug }
      ]));
    }

    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  enforceModuleEntitlement
};
