/**
 * Module entitlement middleware
 *
 * Commercial module access is decided from the database (plan allowlists +
 * module_subscription). Path→slug maps are routing only. Platform
 * infrastructure path segments are loaded from module.extension_json
 * (is_platform_infrastructure), not from a hardcoded commercial free list.
 */

const { HttpError } = require('@lib/errors');
const prisma = require('@prisma/client');
const moduleRepository = require('@repositories/module/module.repository');
const moduleSubscriptionRepository = require('@repositories/module-subscription/module-subscription.repository');
const subscriptionRepository = require('@repositories/subscription/subscription.repository');
const { recordSecurityEvent } = require('@lib/telemetry/metrics');
const {
  evaluateModuleEntitlement,
} = require('@lib/subscriptions/policies');
const { PLAN_TIER_RANK } = require('@lib/subscriptions/plan-module-matrix');
const { canManageSubscriptionBilling } = require('@lib/subscriptions/access');
const { ROLES, normalizeRoleName } = require('@config/roles');

const CACHE_TTL_MS = 60 * 1000;
const CACHE_MAX_ENTRIES = 5000;

const entitlementCache = new Map();
const fallbackEntitlementCache = new Map();
const moduleExistenceCache = new Map();
const subscriptionStateCache = new Map();
const platformInfrastructureCache = new Map();

// Legacy fallbacks when a commercial module row is missing from older DBs.
const CORE_MODULE_METADATA_FALLBACKS = Object.freeze({
  mortuary: Object.freeze({ minimumPlanTierCode: 'PRO' }),
  physiotherapy: Object.freeze({ minimumPlanTierCode: 'ADVANCED' }),
});

const IRREGULAR_PATH_SEGMENTS = {
  diagnoses: 'diagnosis',
};

/**
 * Routing dictionary: API path segment → commercial module slug.
 * This does NOT grant access; entitlement is evaluated from the DB.
 */
const MODULE_SEGMENT_SLUG_OVERRIDES = Object.freeze({
  appointments: 'scheduling-queue',
  'appointment-participants': 'scheduling-queue',
  'appointment-reminders': 'scheduling-queue',
  'provider-schedules': 'scheduling-queue',
  'availability-slots': 'scheduling-queue',
  scheduling: 'scheduling-queue',
  doctors: 'scheduling-queue',
  'visit-queues': 'scheduling-queue',
  triage: 'scheduling-queue',
  'opd-flows': 'scheduling-queue',
  referrals: 'scheduling-queue',
  campaigns: 'scheduling-queue',
  feedback: 'scheduling-queue',
  'follow-ups': 'scheduling-queue',
  'emergency-cases': 'scheduling-queue',
  'triage-assessments': 'scheduling-queue',
  'emergency-responses': 'scheduling-queue',
  ambulances: 'scheduling-queue',
  'ambulance-dispatches': 'scheduling-queue',
  'ambulance-trips': 'scheduling-queue',
  'vital-signs': 'encounters-vitals',
  'care-plans': 'encounters-vitals',
  'clinical-alerts': 'encounters-vitals',
  'clinical-alert-thresholds': 'encounters-vitals',
  'clinical-terms': 'encounters-vitals',
  'clinical-catalog': 'encounters-vitals',
  'clinical-term-favorites': 'encounters-vitals',
  encounters: 'encounters-vitals',
  encounter: 'encounters-vitals',
  'clinical-notes': 'encounters-vitals',
  diagnoses: 'encounters-vitals',
  procedures: 'encounters-vitals',
  'adverse-events': 'encounters-vitals',
  patients: 'patient-registry',
  patient: 'patient-registry',
  'patient-identifiers': 'patient-registry',
  'patient-contacts': 'patient-registry',
  'patient-guardians': 'patient-registry',
  'patient-allergies': 'patient-registry',
  'patient-medical-histories': 'patient-registry',
  'patient-documents': 'patient-registry',
  'patient-reports': 'patient-registry',
  consents: 'patient-registry',
  consent: 'patient-registry',
  'ipd-flows': 'inpatient-bed-management',
  admissions: 'inpatient-bed-management',
  'bed-assignments': 'inpatient-bed-management',
  'ward-rounds': 'inpatient-bed-management',
  'nursing-notes': 'inpatient-bed-management',
  'medication-administrations': 'inpatient-bed-management',
  'discharge-summaries': 'inpatient-bed-management',
  'transfer-requests': 'inpatient-bed-management',
  'icu-stays': 'icu-critical-care',
  'icu-observations': 'icu-critical-care',
  'critical-alerts': 'icu-critical-care',
  'theatre-cases': 'theatre-anesthesia',
  'theatre-flows': 'theatre-anesthesia',
  'anesthesia-records': 'theatre-anesthesia',
  'post-op-notes': 'theatre-anesthesia',
  'therapy-flows': 'physiotherapy',
  lab: 'lab-workflows',
  'lab-tests': 'lab-workflows',
  'lab-panels': 'lab-workflows',
  'lab-orders': 'lab-workflows',
  'lab-order-items': 'lab-workflows',
  'lab-samples': 'lab-workflows',
  'lab-results': 'lab-workflows',
  'lab-qc-logs': 'lab-workflows',
  'facility-lab-catalog': 'lab-workflows',
  radiology: 'radiology-workflows',
  'facility-radiology-catalog': 'radiology-workflows',
  'radiology-tests': 'radiology-workflows',
  'radiology-procedures': 'radiology-workflows',
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
  'facility-pharmacy-catalog': 'pharmacy-dispensing',
  inventory: 'inventory-procurement-lite',
  'inventory-items': 'inventory-procurement-lite',
  'inventory-stocks': 'inventory-procurement-lite',
  'inventory-movements': 'inventory-procurement-lite',
  suppliers: 'inventory-procurement-lite',
  'purchase-requests': 'inventory-procurement-lite',
  'purchase-orders': 'inventory-procurement-lite',
  'goods-receipts': 'inventory-procurement-lite',
  invoices: 'billing-payments',
  invoice: 'billing-payments',
  'invoice-items': 'billing-payments',
  payments: 'billing-payments',
  payment: 'billing-payments',
  refunds: 'billing-payments',
  billing: 'billing-payments',
  'pricing-rules': 'billing-payments',
  'price-book-entries': 'billing-payments',
  'billing-adjustments': 'billing-payments',
  'insurance-companies': 'insurance-claims',
  'coverage-plans': 'insurance-claims',
  'scheme-offers': 'insurance-claims',
  'patient-insurance-enrollments': 'insurance-claims',
  'insurer-integrations': 'insurance-claims',
  'insurance-claims': 'insurance-claims',
  insurance: 'insurance-claims',
  'pre-authorizations': 'insurance-claims',
  'claims-workspace': 'insurance-claims',
  mortuary: 'mortuary',
  'mortuary-cases': 'mortuary',
  'mortuary-deceased-profiles': 'mortuary',
  'mortuary-storage-units': 'mortuary',
  'mortuary-storage-slots': 'mortuary',
  'mortuary-storage-assignments': 'mortuary',
  'mortuary-custody-events': 'mortuary',
  'mortuary-viewings': 'mortuary',
  'mortuary-post-mortem-requests': 'mortuary',
  'mortuary-release-authorisations': 'mortuary',
  'mortuary-billable-events': 'mortuary',
  'payroll-runs': 'hr-rosters',
  'payroll-items': 'hr-rosters',
  hr: 'hr-rosters',
  'staff-profiles': 'hr-rosters',
  'staff-assignments': 'hr-rosters',
  'staff-leaves': 'hr-rosters',
  shifts: 'hr-rosters',
  'shift-assignments': 'hr-rosters',
  'shift-swap-requests': 'hr-rosters',
  'office-contexts': 'hr-rosters',
  'shift-closes': 'hr-rosters',
  'day-closes': 'hr-rosters',
  handovers: 'hr-rosters',
  'custody-snapshots': 'hr-rosters',
  'closeout-packs': 'hr-rosters',
  'nurse-rosters': 'hr-rosters',
  'shift-templates': 'hr-rosters',
  'roster-day-offs': 'hr-rosters',
  'staff-availabilities': 'hr-rosters',
  housekeeping: 'facilities-maintenance',
  'housekeeping-tasks': 'facilities-maintenance',
  'housekeeping-schedules': 'facilities-maintenance',
  'maintenance-requests': 'facilities-maintenance',
  assets: 'facilities-maintenance',
  'asset-service-logs': 'facilities-maintenance',
  biomedical: 'biomedical-engineering-suite',
  'equipment-categories': 'biomedical-engineering-suite',
  'equipment-registries': 'biomedical-engineering-suite',
  'equipment-location-histories': 'biomedical-engineering-suite',
  'equipment-maintenance-plans': 'biomedical-engineering-suite',
  'equipment-work-orders': 'biomedical-engineering-suite',
  'equipment-calibration-logs': 'biomedical-engineering-suite',
  'equipment-safety-test-logs': 'biomedical-engineering-suite',
  'equipment-downtime-logs': 'biomedical-engineering-suite',
  'equipment-spare-parts': 'biomedical-engineering-suite',
  'equipment-warranty-contracts': 'biomedical-engineering-suite',
  'equipment-service-providers': 'biomedical-engineering-suite',
  'equipment-recall-notices': 'biomedical-engineering-suite',
  'equipment-utilization-snapshots': 'biomedical-engineering-suite',
  'equipment-disposal-transfers': 'biomedical-engineering-suite',
  'equipment-incident-reports': 'biomedical-engineering-suite',
  conversations: 'notifications-communications',
  messages: 'notifications-communications',
  notifications: 'notifications-communications',
  'notification-deliveries': 'notifications-communications',
  templates: 'notifications-communications',
  'template-variables': 'notifications-communications',
  'communications-workspace': 'notifications-communications',
  'report-definitions': 'reporting-analytics',
  'report-runs': 'reporting-analytics',
  'report-schedules': 'reporting-analytics',
  'reports-workspace': 'reporting-analytics',
  'audit-logs': 'compliance-audit-core',
  'phi-access-logs': 'compliance-audit-core',
  'data-processing-logs': 'compliance-audit-core',
  'breach-notifications': 'compliance-audit-core',
  'system-change-logs': 'compliance-audit-core',
  'subscriptions-workspace': 'subscription-controls',
  'subscription-plans': 'subscription-controls',
  subscriptions: 'subscription-controls',
  'subscription-invoices': 'subscription-controls',
  modules: 'subscription-controls',
  'module-subscriptions': 'subscription-controls',
  licenses: 'subscription-controls',
  integrations: 'integrations-core',
  'integration-logs': 'integrations-core',
  'webhook-subscriptions': 'integrations-core',
  interop: 'integrations-core',
  'api-keys': 'developer-tools',
  'api-key-permissions': 'developer-tools',
  'developer-tools': 'developer-tools',
});

/** Legacy commercial slugs that still satisfy a newer product slug. */
const LEGACY_MODULE_SLUG_ALIASES = Object.freeze({
  'billing-payments': Object.freeze(['billing-insurance']),
  'insurance-claims': Object.freeze(['billing-insurance', 'insurance']),
  'inventory-procurement-lite': Object.freeze(['inventory-procurement']),
});

/**
 * Path segments that clinical workflows must reach even when the commercial
 * pharmacy module is not subscribed (doctor prescribe → pharmacy-orders).
 * Dispense / inventory paths stay pharmacy-dispensing only.
 * Suppliers stay inventory-procurement-lite primarily, but pharmacy catalog
 * tenants with pharmacy-dispensing may manage preferred product suppliers.
 */
const PATH_MODULE_ACCESS_ALTERNATES = Object.freeze({
  'pharmacy-orders': Object.freeze(['encounters-vitals']),
  'pharmacy-order-items': Object.freeze(['encounters-vitals']),
  suppliers: Object.freeze(['pharmacy-dispensing']),
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
    expiresAt: Date.now() + CACHE_TTL_MS,
  });
  enforceCacheLimit(cache);
};

const clearModuleEntitlementCaches = () => {
  entitlementCache.clear();
  fallbackEntitlementCache.clear();
  moduleExistenceCache.clear();
  subscriptionStateCache.clear();
  platformInfrastructureCache.clear();
};

const resolveEligiblePlanTiers = (minimumPlanTierCode) => {
  const minimumRank =
    PLAN_TIER_RANK[String(minimumPlanTierCode || '').toUpperCase()];
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
  if (!normalizedPath || normalizedPath === '/' || normalizedPath === '.') {
    return null;
  }

  const rawSegment = normalizedPath.replace(/^\/+/, '').split('/')[0];
  const mappedSlug =
    MODULE_SEGMENT_SLUG_OVERRIDES[
      String(rawSegment || '').trim().toLowerCase()
    ];
  if (mappedSlug) return mappedSlug;
  return normalizeSegmentToModuleSlug(rawSegment);
};

/**
 * Load platform infrastructure path segments from DB module.extension_json.
 */
const loadPlatformInfrastructureSegments = async () => {
  const cacheKey = 'platform-infrastructure-segments';
  const cached = getCached(platformInfrastructureCache, cacheKey);
  if (cached !== null) return cached;

  const modules = await prisma.module.findMany({
    where: { deleted_at: null },
    select: { slug: true, extension_json: true },
    take: 500,
  });

  const segments = new Set();
  for (const entry of modules) {
    const extension =
      entry.extension_json && typeof entry.extension_json === 'object'
        ? entry.extension_json
        : {};
    if (!extension.is_platform_infrastructure) {
      continue;
    }
    if (entry.slug) {
      segments.add(String(entry.slug).toLowerCase());
    }
    const paths = Array.isArray(extension.api_path_segments)
      ? extension.api_path_segments
      : [];
    for (const pathSegment of paths) {
      const normalized = String(pathSegment || '')
        .trim()
        .toLowerCase();
      if (normalized) {
        segments.add(normalized);
      }
    }
  }

  setCached(platformInfrastructureCache, cacheKey, segments);
  return segments;
};

const isPlatformInfrastructureSlug = async (moduleSlug, rawPathSegment) => {
  const segments = await loadPlatformInfrastructureSegments();
  const slug = String(moduleSlug || '').toLowerCase();
  const raw = String(rawPathSegment || '')
    .trim()
    .toLowerCase();
  return segments.has(slug) || (raw && segments.has(raw));
};

const moduleExists = async (moduleSlug) => {
  const cacheKey = `module:${moduleSlug}`;
  const cached = getCached(moduleExistenceCache, cacheKey);
  if (cached !== null) return cached;

  const exists = (await moduleRepository.count({ slug: moduleSlug })) > 0;
  setCached(moduleExistenceCache, cacheKey, exists);
  return exists;
};

const loadActiveSubscriptionWithPlan = async (tenantId) => {
  const cacheKey = `tenant-subscription-plan:${tenantId}`;
  const cached = getCached(subscriptionStateCache, cacheKey);
  if (cached !== null) return cached;

  const subscription = await prisma.subscription.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL'] },
      OR: [{ end_date: null }, { end_date: { gte: new Date() } }],
    },
    include: { plan: true },
    orderBy: { updated_at: 'desc' },
  });

  setCached(subscriptionStateCache, cacheKey, subscription || false);
  return subscription || null;
};

const tenantHasModuleAccess = async (tenantId, moduleSlug) => {
  const cacheKey = `${tenantId}:${moduleSlug}`;
  const cached = getCached(entitlementCache, cacheKey);
  if (cached !== null) return cached;

  const candidateSlugs = [
    moduleSlug,
    ...(LEGACY_MODULE_SLUG_ALIASES[moduleSlug] || []),
  ];

  const activeSubscriptionCount = await moduleSubscriptionRepository.count({
    is_active: true,
    entitlement_denied: false,
    module: {
      slug: { in: candidateSlugs },
      deleted_at: null,
    },
    subscription: {
      tenant_id: tenantId,
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL'] },
      OR: [{ end_date: null }, { end_date: { gte: new Date() } }],
    },
  });

  if (activeSubscriptionCount > 0) {
    setCached(entitlementCache, cacheKey, true);
    return true;
  }

  const [subscription, moduleRecord] = await Promise.all([
    loadActiveSubscriptionWithPlan(tenantId),
    prisma.module.findFirst({
      where: { slug: moduleSlug, deleted_at: null },
    }),
  ]);

  if (!subscription || !moduleRecord) {
    setCached(entitlementCache, cacheKey, false);
    return false;
  }

  const evaluation = evaluateModuleEntitlement({
    subscriptionRecord: subscription,
    moduleRecord,
    planRecord: subscription.plan || {},
  });

  const allowed = Boolean(evaluation.eligible);
  setCached(entitlementCache, cacheKey, allowed);
  return allowed;
};

const tenantHasActiveSubscription = async (tenantId) => {
  const subscription = await loadActiveSubscriptionWithPlan(tenantId);
  return Boolean(subscription);
};

const tenantHasFallbackModuleAccess = async (tenantId, moduleSlug) => {
  const fallback = CORE_MODULE_METADATA_FALLBACKS[moduleSlug];
  if (!fallback) return false;

  const cacheKey = `${tenantId}:${moduleSlug}`;
  const cached = getCached(fallbackEntitlementCache, cacheKey);
  if (cached !== null) return cached;

  const eligiblePlanTiers = resolveEligiblePlanTiers(
    fallback.minimumPlanTierCode
  );
  if (eligiblePlanTiers.length === 0) {
    setCached(fallbackEntitlementCache, cacheKey, false);
    return false;
  }

  const allowed =
    (await subscriptionRepository.count({
      tenant_id: tenantId,
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL'] },
      OR: [{ end_date: null }, { end_date: { gte: new Date() } }],
      plan: {
        tier_code: { in: eligiblePlanTiers },
      },
    })) > 0;

  setCached(fallbackEntitlementCache, cacheKey, allowed);
  return allowed;
};

const isSuperAdminUser = (user = {}) => {
  const rawRoles = Array.isArray(user.roles)
    ? user.roles
    : user.role
      ? [user.role]
      : [];
  return rawRoles.some((entry) => {
    const normalized =
      normalizeRoleName(entry) || String(entry || '').trim().toUpperCase();
    return normalized === ROLES.PLATFORM_ADMIN;
  });
};

const isTenantSubscriptionBillingFlowPath = (reqPath = '') => {
  const segments = String(reqPath || '')
    .replace(/^\/+/, '')
    .split('/')
    .filter(Boolean)
    .map((segment) => segment.toLowerCase());

  if (segments.length < 2 || segments[0] !== 'subscriptions-workspace') {
    return false;
  }

  return segments[1] === 'upgrade-context' || segments[1] === 'payment-requests';
};

const enforceModuleEntitlement = () => async (req, res, next) => {
  try {
    const moduleSlug = resolveModuleSlugFromPath(req.path);
    if (!moduleSlug) return next();

    const rawSegment = String(req.path || '')
      .replace(/^\/+/, '')
      .split('/')[0]
      .toLowerCase();

    if (await isPlatformInfrastructureSlug(moduleSlug, rawSegment)) {
      return next();
    }

    const user = req.user || {};
    // Platform operators manage catalog/subscriptions across tenants; commercial
    // plan packaging must not block PLATFORM_ADMIN ops tooling.
    if (isSuperAdminUser(user)) {
      return next();
    }

    if (
      isTenantSubscriptionBillingFlowPath(req.path) &&
      canManageSubscriptionBilling(user)
    ) {
      return next();
    }

    const tenantId = user.tenant_id || user.tenantId || null;
    if (!tenantId) {
      recordSecurityEvent('module.entitlement_denied', {
        'hms.module.slug': moduleSlug,
      });
      return next(
        new HttpError('errors.auth.module_not_entitled', 403, [
          {
            tenant_id: null,
            module: moduleSlug,
            reason: 'missing_tenant_scope',
          },
        ])
      );
    }

    const hasSubscription = await tenantHasActiveSubscription(tenantId);
    if (!hasSubscription) {
      recordSecurityEvent('module.entitlement_denied', {
        'hms.module.slug': moduleSlug,
      });
      return next(
        new HttpError('errors.auth.module_not_entitled', 403, [
          {
            tenant_id: tenantId,
            module: moduleSlug,
            reason: 'subscription_required',
          },
        ])
      );
    }

    const knownModule = await moduleExists(moduleSlug);
    if (!knownModule) {
      const fallbackAllowed = await tenantHasFallbackModuleAccess(
        tenantId,
        moduleSlug
      );
      if (fallbackAllowed) return next();

      recordSecurityEvent('module.entitlement_denied', {
        'hms.module.slug': moduleSlug,
      });
      return next(
        new HttpError('errors.auth.module_not_entitled', 403, [
          {
            tenant_id: tenantId,
            module: moduleSlug,
            reason: 'module_metadata_missing',
          },
        ])
      );
    }

    const allowed = await tenantHasModuleAccess(tenantId, moduleSlug);
    if (!allowed) {
      const alternateSlugs = PATH_MODULE_ACCESS_ALTERNATES[rawSegment] || [];
      for (const alternateSlug of alternateSlugs) {
        if (await tenantHasModuleAccess(tenantId, alternateSlug)) {
          return next();
        }
      }

      recordSecurityEvent('module.entitlement_denied', {
        'hms.module.slug': moduleSlug,
      });
      return next(
        new HttpError('errors.auth.module_not_entitled', 403, [
          { tenant_id: tenantId, module: moduleSlug },
        ])
      );
    }

    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  enforceModuleEntitlement,
  resolveModuleSlugFromPath,
  loadPlatformInfrastructureSegments,
  clearModuleEntitlementCaches,
  isTenantSubscriptionBillingFlowPath,
};
