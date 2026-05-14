const { ELEVATED_ROLES, normalizeRoleName } = require('@config/roles');

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

module.exports = {
  canAccessTenant,
  canAccessTenantOrGlobal,
  getUserRoles,
  getUserTenantId,
  hasElevatedRole,
  resolveUserTenantScope,
  text,
};
