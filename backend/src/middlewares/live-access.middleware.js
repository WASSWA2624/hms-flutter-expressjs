/**
 * Live access hydration
 *
 * Re-applies the subscription plan gate to JWT permission grants on every
 * authenticated request so downgrades take effect before token refresh.
 */

const {
  resolveTenantModuleEntitlements,
} = require('@lib/subscriptions/tenant-entitlements');
const {
  filterPermissionNamesByPlanModules,
  normalizeEnabledModuleSet,
} = require('@lib/authorization/permission-module-map');
const {
  userHasSuperAdminRole,
} = require('@lib/authorization/effective-access');

const CACHE_TTL_MS = Number(process.env.LIVE_ACCESS_ENTITLEMENT_TTL_MS || 60 * 1000);
const CACHE_MAX_ENTRIES = 5000;

/** @type {Map<string, { at: number, entitlements: Object[] }>} */
const entitlementCache = new Map();

const getCachedEntitlements = (tenantId) => {
  const cached = entitlementCache.get(tenantId);
  if (!cached) {
    return null;
  }
  if (Date.now() - cached.at > CACHE_TTL_MS) {
    entitlementCache.delete(tenantId);
    return null;
  }
  return cached.entitlements;
};

const setCachedEntitlements = (tenantId, entitlements) => {
  if (entitlementCache.size >= CACHE_MAX_ENTRIES) {
    const oldestKey = entitlementCache.keys().next().value;
    if (oldestKey) {
      entitlementCache.delete(oldestKey);
    }
  }
  entitlementCache.set(tenantId, { at: Date.now(), entitlements });
};

const clearLiveAccessCaches = (tenantId = null) => {
  if (tenantId) {
    entitlementCache.delete(tenantId);
    return;
  }
  entitlementCache.clear();
};

const isApiKeyContext = (user = {}) =>
  String(user.auth_type || user.authType || '').toLowerCase() === 'api_key';

/**
 * Attach live module entitlements and re-gate token permissions by plan.
 *
 * @returns {Function} Express middleware
 */
const hydrateLiveAccess = () => async (req, res, next) => {
  try {
    const user = req.user;
    if (!user || typeof user !== 'object' || isApiKeyContext(user)) {
      return next();
    }

    if (userHasSuperAdminRole(user)) {
      return next();
    }

    const tenantId = user.tenant_id || user.tenantId || null;
    if (!tenantId) {
      return next();
    }

    let entitlements = getCachedEntitlements(tenantId);
    if (!entitlements) {
      entitlements = await resolveTenantModuleEntitlements(tenantId);
      setCachedEntitlements(tenantId, entitlements);
    }

    user.module_entitlements = entitlements;
    user.moduleEntitlements = entitlements;

    const tokenPermissions = Array.isArray(user.permissions)
      ? user.permissions
          .map((entry) =>
            typeof entry === 'string'
              ? String(entry || '').trim()
              : String(
                  entry?.name ||
                    entry?.code ||
                    entry?.permission_name ||
                    entry?.permission?.name ||
                    ''
                ).trim()
          )
          .filter(Boolean)
      : [];

    if (tokenPermissions.length > 0) {
      const enabledModules = normalizeEnabledModuleSet(entitlements);
      const gated = filterPermissionNamesByPlanModules(
        tokenPermissions,
        enabledModules
      );
      user.permissions = gated;
      user.permission_names = gated;
    }

    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  clearLiveAccessCaches,
  hydrateLiveAccess,
};
