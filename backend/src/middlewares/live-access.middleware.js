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
  getRoleNames,
  resolveEffectiveAccess,
} = require('@lib/authorization/effective-access');
const {
  filterPermissionNamesByPlanModules,
  filterPermissionNamesBySubscriptionPermissions,
  normalizeEnabledModuleSet,
} = require('@lib/authorization/permission-module-map');
const authRepository = require('@repositories/auth/auth.repository');
const { HttpError } = require('@lib/errors');

// Authorization changes must take effect immediately by default. A deployment
// may opt into a short cache only when every access mutation invalidates it.
const CACHE_TTL_MS = Number(process.env.LIVE_ACCESS_ENTITLEMENT_TTL_MS || 0);
const CACHE_MAX_ENTRIES = 5000;

/** @type {Map<string, { at: number, entitlements: Object[] }>} */
const entitlementCache = new Map();

const getCachedEntitlements = (tenantId) => {
  if (CACHE_TTL_MS <= 0) {
    return null;
  }
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
  if (CACHE_TTL_MS <= 0) {
    return;
  }
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
    if (!user || typeof user !== 'object') {
      return next();
    }

    const tenantId = user.tenant_id || user.tenantId || null;
    if (!tenantId) {
      return next();
    }

    const userId = user.id || user.user_id || user.userId || null;
    if (!userId) {
      throw new HttpError('errors.auth.unauthorized', 401);
    }

    const liveUser = await authRepository.findUserById(userId);
    if (
      !liveUser ||
      liveUser.status !== 'ACTIVE' ||
      String(liveUser.tenant_id || '') !== String(tenantId)
    ) {
      throw new HttpError('errors.auth.unauthorized', 401);
    }

    let entitlements = getCachedEntitlements(tenantId);
    if (!entitlements) {
      entitlements = await resolveTenantModuleEntitlements(tenantId);
      setCachedEntitlements(tenantId, entitlements);
    }

    if (isApiKeyContext(user)) {
      const tokenPermissions = Array.isArray(user.permissions)
        ? user.permissions
            .map((permission) => String(permission || '').trim())
            .filter(Boolean)
        : [];
      user.permissions = filterPermissionNamesBySubscriptionPermissions(
        filterPermissionNamesByPlanModules(
          tokenPermissions,
          normalizeEnabledModuleSet(entitlements)
        ),
        entitlements
      );
      user.permission_names = user.permissions;
      user.module_entitlements = entitlements;
      user.moduleEntitlements = entitlements;
      return next();
    }

    const liveAccess = resolveEffectiveAccess(
      {
        ...liveUser,
        tenant_id: tenantId,
        facility_id: user.facility_id || user.facilityId || liveUser.facility_id,
      },
      {
        moduleEntitlements: entitlements,
        applyPlanGate: true,
        applyAssignedModuleGate: true,
      }
    );

    // Keep request roles as canonical name strings. Prisma returns user_role
    // rows; authorize()/RBAC compare against PLATFORM_ADMIN etc. and must not see
    // nested ORM objects (which stringify to "[OBJECT OBJECT]").
    const liveRoleNames = getRoleNames(liveUser);
    user.roles = liveRoleNames.length
      ? liveRoleNames
      : getRoleNames(user);
    user.role = user.roles[0] || user.role || null;
    user.permissions = liveAccess.permissions;
    user.permission_names = liveAccess.permissions;
    user.direct_permissions = liveAccess.direct_permissions;
    user.role_permissions = liveAccess.role_permissions;
    user.module_permissions = liveAccess.module_permissions;
    user.assigned_modules = liveAccess.assigned_modules;
    user.module_entitlements = entitlements;
    user.moduleEntitlements = entitlements;

    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  clearLiveAccessCaches,
  hydrateLiveAccess,
};
