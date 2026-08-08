const { ELEVATED_ROLES, ROLES, normalizeRoleName } = require('@config/roles');
const { PERMISSIONS } = require('@config/permissions');
const { getUserPermissions } = require('@middlewares/auth.middleware');

const ELEVATED_ROLE_SET = new Set(ELEVATED_ROLES);

const text = (value) => String(value || '').trim();

const getUserRoles = (user = {}) => {
  const rawRoles = Array.isArray(user.roles)
    ? user.roles
    : user.role
      ? [user.role]
      : [];

  return rawRoles
    .map((role) => normalizeRoleName(role) || text(role).toUpperCase())
    .filter(Boolean);
};

const hasElevatedRole = (user = {}) => {
  // Keep backwards compatibility for service tests/internal callers that do
  // not attach auth context.
  if (!user || typeof user !== 'object' || Object.keys(user).length === 0) {
    return true;
  }

  return getUserRoles(user).some((role) => ELEVATED_ROLE_SET.has(role));
};

const getUserTenantId = (user = {}) => text(user.tenant_id || user.tenantId) || null;

const resolveUserTenantScope = (user = {}) => ({
  is_elevated: hasElevatedRole(user),
  tenant_id: getUserTenantId(user),
});

const canAccessTenant = (scope = {}, tenantId) => {
  if (scope.is_elevated) return true;
  return Boolean(scope.tenant_id && text(tenantId) === scope.tenant_id);
};

const canAccessTenantOrGlobal = (scope = {}, tenantId) => {
  const normalizedTenantId = text(tenantId);
  if (scope.is_elevated) return true;
  if (!normalizedTenantId) return true;
  return Boolean(scope.tenant_id && normalizedTenantId === scope.tenant_id);
};

const canManageSubscriptionBilling = (user = {}) => {
  const roles = getUserRoles(user);
  if (roles.some((role) => ELEVATED_ROLE_SET.has(role))) {
    return true;
  }
  if (roles.includes(ROLES.TENANT_ADMIN) || roles.includes(ROLES.FACILITY_ADMIN)) {
    return true;
  }

  const permissions = getUserPermissions(user);
  return (
    permissions.includes(PERMISSIONS.SUBSCRIPTIONS_READ) ||
    permissions.includes(PERMISSIONS.SUBSCRIPTIONS_WRITE)
  );
};

const resolveBillingTenantScope = (user = {}, payload = {}) => {
  const actorTenantId = getUserTenantId(user);
  if (!actorTenantId) {
    const { HttpError } = require('@lib/errors');
    throw new HttpError('errors.tenant.required', 400);
  }

  const roles = getUserRoles(user);
  if (roles.includes(ROLES.PLATFORM_ADMIN)) {
    const requestedTenantId = text(payload.tenant_id || payload.tenantId);
    return requestedTenantId || actorTenantId;
  }

  const requestedTenantId = text(payload.tenant_id || payload.tenantId);
  if (requestedTenantId && requestedTenantId !== actorTenantId) {
    const { HttpError } = require('@lib/errors');
    throw new HttpError('errors.auth.scope_mismatch', 403, [
      { field: 'tenant_id', reason: 'outside_actor_tenant' },
    ]);
  }

  return actorTenantId;
};

module.exports = {
  canAccessTenant,
  canAccessTenantOrGlobal,
  canManageSubscriptionBilling,
  getUserRoles,
  getUserTenantId,
  hasElevatedRole,
  resolveBillingTenantScope,
  resolveUserTenantScope,
  text,
};
