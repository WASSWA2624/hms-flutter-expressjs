/**
 * Actor permission ceiling helpers for role create / assign flows.
 *
 * Admins may only grant permissions (and assign roles) within the union of
 * permissions implied by their own roles — never above their level.
 */

const prisma = require('@prisma/client');
const { ROLES } = require('@config/roles');
const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');
const { HttpError } = require('@lib/errors');
const { getUserPermissions } = require('@middlewares/auth.middleware');
const {
  getRoleNames,
  userHasSuperAdminRole,
} = require('@lib/authorization/effective-access');
const { resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  filterPermissionRecordsByPlanModules,
  isPermissionAllowedByPlan,
  normalizeEnabledModuleSet,
} = require('@lib/authorization/permission-module-map');
const {
  resolveTenantModuleEntitlements,
} = require('@lib/subscriptions/tenant-entitlements');

const ACCESS_ADMIN_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.OPERATIONS,
  ROLES.HR,
]);

const ROLE_RANK = Object.freeze({
  [ROLES.SUPER_ADMIN]: 100,
  [ROLES.TENANT_ADMIN]: 80,
  [ROLES.FACILITY_ADMIN]: 60,
  [ROLES.OPERATIONS]: 40,
  [ROLES.HR]: 40,
});

const text = (value) => String(value || '').trim();

const normalizeRoleName = (entry) => {
  if (typeof entry === 'string') {
    return entry.trim().toUpperCase();
  }
  if (entry && typeof entry === 'object') {
    return text(entry.name || entry.role_name || entry.role?.name).toUpperCase();
  }
  return text(entry).toUpperCase();
};

const resolveActorRoleNames = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [user.role];
  return [...new Set(roles.map(normalizeRoleName).filter(Boolean))];
};

const resolveActorMaxRank = (user = {}) => {
  const ranks = resolveActorRoleNames(user).map((role) => ROLE_RANK[role] || 0);
  return ranks.length > 0 ? Math.max(...ranks) : 0;
};

const resolveActorAssignablePermissionNames = (user = {}) => {
  const roleNames = resolveActorRoleNames(user);
  // Super admins keep a full assignment ceiling. Plan entitlements still gate
  // which module-scoped rights can be granted to a specific tenant.
  if (roleNames.includes(ROLES.SUPER_ADMIN)) {
    return new Set(ROLE_PERMISSIONS[ROLES.SUPER_ADMIN] || []);
  }

  const fromContext = getUserPermissions(user);
  if (fromContext.length > 0) {
    return new Set(fromContext);
  }

  return new Set(
    roleNames.flatMap((role) => ROLE_PERMISSIONS[role] || [])
  );
};

const canActorCreateTenantWideRole = (user = {}) => {
  const roles = new Set(resolveActorRoleNames(user));
  if (roles.has(ROLES.SUPER_ADMIN) || roles.has(ROLES.TENANT_ADMIN)) {
    return true;
  }
  // Facility admins (and below) may only create facility-scoped roles.
  return false;
};

const canActorCreatePlatformRole = (user = {}) => {
  // Match FE canCreateTenant / Platform radio: elevated role or system:admin.
  if (userHasSuperAdminRole(user)) {
    return true;
  }
  if (getRoleNames(user).includes(ROLES.SUPER_ADMIN)) {
    return true;
  }

  const tokenPermissions = new Set(
    (Array.isArray(user.permissions) ? user.permissions : [])
      .map((entry) =>
        typeof entry === 'string'
          ? text(entry)
          : text(entry?.name || entry?.permission?.name || entry?.code)
      )
      .filter(Boolean)
  );
  if (tokenPermissions.has(PERMISSIONS.SYSTEM_ADMIN)) {
    return true;
  }

  const permissions = new Set(getUserPermissions(user));
  return permissions.has(PERMISSIONS.SYSTEM_ADMIN);
};

const isPermissionNameAssignable = (permissionName, assignableSet) => {
  const name = text(permissionName);
  if (!name) {
    return false;
  }
  return assignableSet.has(name);
};

const filterPermissionRecordsByCeiling = (
  permissions = [],
  user = {},
  enabledModules = null
) => {
  const assignable = resolveActorAssignablePermissionNames(user);
  if (assignable.size === 0) {
    return [];
  }
  const withinCeiling = permissions.filter((entry) =>
    isPermissionNameAssignable(entry?.name || entry?.label, assignable)
  );
  return filterPermissionRecordsByPlanModules(withinCeiling, enabledModules);
};

/**
 * Resolve enabled module slugs for a tenant (Plan gate for assignable rights).
 * @param {string|null|undefined} tenantId
 * @returns {Promise<Set<string>|null>} null when tenant is unknown (skip plan filter)
 */
const resolveAssignablePlanModules = async (tenantId) => {
  if (!tenantId) {
    return null;
  }
  const entitlements = await resolveTenantModuleEntitlements(tenantId);
  return normalizeEnabledModuleSet(entitlements);
};

const collectRolePermissionNames = (role = {}) => {
  // When permission joins were loaded (even if empty), trust the DB — do not
  // invent built-in packs for custom roles that happen to share a name.
  if (Array.isArray(role.permissions)) {
    return role.permissions
      .map((entry) => entry?.permission?.name || entry?.name || entry?.permission_name)
      .map(text)
      .filter(Boolean);
  }

  const roleName = normalizeRoleName(role.name);
  return ROLE_PERMISSIONS[roleName] || [];
};

const isRoleWithinActorCeiling = (role = {}, user = {}) => {
  const assignable = resolveActorAssignablePermissionNames(user);
  if (assignable.size === 0) {
    return false;
  }

  const roleName = normalizeRoleName(role.name);
  const roleRank = ROLE_RANK[roleName];
  if (roleRank != null && roleRank > resolveActorMaxRank(user)) {
    return false;
  }

  const permissionNames = collectRolePermissionNames(role);
  if (permissionNames.length === 0) {
    return true;
  }

  return permissionNames.every((name) => assignable.has(name));
};

const filterRoleRecordsByCeiling = (roles = [], user = {}) =>
  roles.filter((role) => isRoleWithinActorCeiling(role, user));

const assertPermissionNamesAssignable = (
  permissionNames = [],
  user = {},
  enabledModules = null
) => {
  const assignable = resolveActorAssignablePermissionNames(user);
  const uniqueNames = [
    ...new Set(permissionNames.map(text).filter(Boolean)),
  ];
  const aboveCeiling = uniqueNames.filter((name) => !assignable.has(name));
  if (aboveCeiling.length > 0) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      {
        field: 'permission_id',
        reason: 'above_actor_ceiling',
        denied: aboveCeiling,
      },
    ]);
  }

  const outsidePlan = uniqueNames.filter(
    (name) => !isPermissionAllowedByPlan(name, enabledModules)
  );
  if (outsidePlan.length > 0) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      {
        field: 'permission_id',
        reason: 'module_not_entitled',
        denied: outsidePlan,
      },
    ]);
  }
};

const assertPermissionIdAssignable = async (
  permissionId,
  user = {},
  { tenantId = null, enabledModules = null } = {}
) => {
  const resolvedId = await resolveIdentifierForPayload({
    value: permissionId,
    model: 'permission',
    field: 'permission_id',
  });
  const permission = await prisma.permission.findFirst({
    where: { id: resolvedId, deleted_at: null },
    select: { id: true, name: true, tenant_id: true },
  });
  if (!permission) {
    throw new HttpError('errors.permission.not_found', 404);
  }
  const planModules =
    enabledModules ??
    (await resolveAssignablePlanModules(
      tenantId || permission.tenant_id || user.tenant_id || user.tenantId || null
    ));
  assertPermissionNamesAssignable([permission.name], user, planModules);
  return permission;
};

/**
 * Resolve and ceiling-check many permission identifiers in one query.
 * @returns {Promise<string[]>} Deduped permission UUIDs
 */
const assertPermissionIdsAssignable = async (
  permissionIds = [],
  user = {},
  { tenantId = null, enabledModules = null } = {}
) => {
  const unique = [
    ...new Set(
      (Array.isArray(permissionIds) ? permissionIds : [])
        .map(text)
        .filter(Boolean)
    ),
  ];
  if (unique.length === 0) {
    return [];
  }

  const uuidIds = unique.filter((id) => isUuidLike(id));
  const friendlyIds = unique.filter((id) => !isUuidLike(id));
  const orFilters = [];
  if (uuidIds.length > 0) {
    orFilters.push({ id: { in: uuidIds } });
  }
  if (friendlyIds.length > 0) {
    orFilters.push({ human_friendly_id: { in: friendlyIds } });
  }

  const permissions = await prisma.permission.findMany({
    where: {
      deleted_at: null,
      OR: orFilters,
    },
    select: { id: true, name: true, human_friendly_id: true, tenant_id: true },
  });

  const byId = new Map(permissions.map((entry) => [entry.id, entry]));
  const byFriendly = new Map(
    permissions
      .filter((entry) => entry.human_friendly_id)
      .map((entry) => [entry.human_friendly_id, entry])
  );

  const resolved = [];
  const missing = [];
  for (const identifier of unique) {
    const match = byId.get(identifier) || byFriendly.get(identifier);
    if (!match) {
      missing.push(identifier);
      continue;
    }
    resolved.push(match);
  }

  if (missing.length > 0) {
    throw new HttpError('errors.permission.not_found', 404, [
      { field: 'permission_ids', missing },
    ]);
  }

  const inferredTenantId =
    tenantId ||
    user.tenant_id ||
    user.tenantId ||
    resolved.find((entry) => entry.tenant_id)?.tenant_id ||
    null;
  const planModules =
    enabledModules ?? (await resolveAssignablePlanModules(inferredTenantId));
  assertPermissionNamesAssignable(
    resolved.map((entry) => entry.name),
    user,
    planModules
  );

  return [...new Set(resolved.map((entry) => entry.id))];
};

const assertRoleIdAssignable = async (roleId, user = {}) => {
  const resolvedId = await resolveIdentifierForPayload({
    value: roleId,
    model: 'role',
    field: 'role_id',
  });
  const role = await prisma.role.findFirst({
    where: { id: resolvedId, deleted_at: null },
    include: {
      permissions: {
        where: { deleted_at: null },
        include: {
          permission: {
            select: { name: true },
          },
        },
      },
    },
  });
  if (!role) {
    throw new HttpError('errors.role.not_found', 404);
  }
  if (!isRoleWithinActorCeiling(role, user)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      { field: 'role_id', reason: 'above_actor_ceiling' },
    ]);
  }
  return role;
};

const assertRoleScopeAllowed = async (payload = {}, user = {}) => {
  const facilityId = payload.facility_id;
  const hasFacility =
    facilityId != null && String(facilityId).trim() !== '';
  const hasTenant =
    payload.tenant_id != null && String(payload.tenant_id).trim() !== '';

  // Platform-scoped role: no tenant, no facility.
  if (!hasFacility && !hasTenant) {
    if (!canActorCreatePlatformRole(user)) {
      throw new HttpError('errors.auth.insufficient_permissions', 403, [
        { field: 'tenant_id', reason: 'platform_scope_forbidden' },
      ]);
    }
    return {
      ...payload,
      tenant_id: null,
      facility_id: null,
    };
  }

  if (!hasFacility && !canActorCreateTenantWideRole(user)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      { field: 'facility_id', reason: 'facility_scope_required' },
    ]);
  }

  if (!hasFacility) {
    assertActorTenantMatches(payload.tenant_id, user);
    return payload;
  }

  const resolvedFacilityId = await resolveIdentifierForPayload({
    value: facilityId,
    model: 'facility',
    field: 'facility_id',
    nullable: true,
  });

  const facility = await prisma.facility.findFirst({
    where: { id: resolvedFacilityId, deleted_at: null },
    select: { id: true, tenant_id: true },
  });
  if (!facility) {
    throw new HttpError('errors.facility.not_found', 404);
  }

  const tenantId = payload.tenant_id;
  if (tenantId && facility.tenant_id !== tenantId) {
    throw new HttpError('errors.auth.scope_mismatch', 403, [
      { field: 'facility_id', reason: 'facility_tenant_mismatch' },
    ]);
  }

  const actorRoles = new Set(resolveActorRoleNames(user));
  if (
    actorRoles.has(ROLES.FACILITY_ADMIN) &&
    !actorRoles.has(ROLES.TENANT_ADMIN) &&
    !actorRoles.has(ROLES.SUPER_ADMIN)
  ) {
    const actorFacilityId = user.facility_id || user.facilityId || null;
    if (!actorFacilityId) {
      throw new HttpError('errors.auth.scope_mismatch', 403, [
        { field: 'facility_id', reason: 'actor_facility_required' },
      ]);
    }
    if (actorFacilityId !== facility.id) {
      throw new HttpError('errors.auth.scope_mismatch', 403, [
        { field: 'facility_id', reason: 'outside_actor_facility' },
      ]);
    }
  }

  const nextPayload = {
    ...payload,
    facility_id: facility.id,
    tenant_id: payload.tenant_id || facility.tenant_id,
  };
  assertActorTenantMatches(nextPayload.tenant_id, user);
  return nextPayload;
};

const assertActorTenantMatches = (tenantId, user = {}) => {
  const actorRoles = new Set(resolveActorRoleNames(user));
  if (actorRoles.has(ROLES.SUPER_ADMIN)) {
    return;
  }
  const actorTenantId = user.tenant_id || user.tenantId || null;
  if (!tenantId || !actorTenantId || tenantId !== actorTenantId) {
    throw new HttpError('errors.auth.scope_mismatch', 403, [
      { field: 'tenant_id', reason: 'outside_actor_tenant' },
    ]);
  }
};

/**
 * Ensure the actor may mutate an existing role record (ceiling + tenant/facility).
 * @param {Object} role
 * @param {Object} user
 */
const assertActorCanManageRoleRecord = (role = {}, user = {}) => {
  if (!role || !role.id) {
    throw new HttpError('errors.role.not_found', 404);
  }

  const actorRoles = new Set(resolveActorRoleNames(user));
  if (actorRoles.has(ROLES.SUPER_ADMIN)) {
    if (!isRoleWithinActorCeiling(role, user)) {
      throw new HttpError('errors.auth.insufficient_permissions', 403, [
        { field: 'role_id', reason: 'above_actor_ceiling' },
      ]);
    }
    return role;
  }

  const isPlatformRole =
    (role.tenant_id == null || String(role.tenant_id).trim() === '') &&
    (role.facility_id == null || String(role.facility_id).trim() === '');
  if (isPlatformRole) {
    if (!canActorCreatePlatformRole(user)) {
      throw new HttpError('errors.auth.insufficient_permissions', 403, [
        { field: 'tenant_id', reason: 'platform_scope_forbidden' },
      ]);
    }
    if (!isRoleWithinActorCeiling(role, user)) {
      throw new HttpError('errors.auth.insufficient_permissions', 403, [
        { field: 'role_id', reason: 'above_actor_ceiling' },
      ]);
    }
    return role;
  }

  const actorTenantId = user.tenant_id || user.tenantId || null;
  if (!actorTenantId || role.tenant_id !== actorTenantId) {
    throw new HttpError('errors.auth.scope_mismatch', 403, [
      { field: 'tenant_id', reason: 'outside_actor_tenant' },
    ]);
  }

  if (
    actorRoles.has(ROLES.FACILITY_ADMIN) &&
    !actorRoles.has(ROLES.TENANT_ADMIN)
  ) {
    const actorFacilityId = user.facility_id || user.facilityId || null;
    if (!actorFacilityId) {
      throw new HttpError('errors.auth.scope_mismatch', 403, [
        { field: 'facility_id', reason: 'actor_facility_required' },
      ]);
    }
    if (role.facility_id !== actorFacilityId) {
      throw new HttpError('errors.auth.scope_mismatch', 403, [
        { field: 'role_id', reason: 'outside_actor_facility' },
      ]);
    }
  }

  if (!isRoleWithinActorCeiling(role, user)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      { field: 'role_id', reason: 'above_actor_ceiling' },
    ]);
  }

  return role;
};

/**
 * Block mutation of seeded/system roles that catalog sync owns.
 * @param {Object} role
 * @param {'update'|'delete'} [operation='delete']
 */
const assertRoleNotSystemProtected = (role = {}, operation = 'delete') => {
  const roleName = normalizeRoleName(role.name);
  if (!roleName || !ROLE_PERMISSIONS[roleName]) {
    return;
  }
  if (operation === 'delete' || roleName === ROLES.SUPER_ADMIN) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      {
        field: 'role_id',
        reason: 'system_role_protected',
        role: roleName,
        operation,
      },
    ]);
  }
};

/**
 * Role list/lookup where.
 *
 * - Facility-only actors: exact facility_id match (no tenant-wide roles).
 * - Tenant/super admins: facility roles for the scope plus tenant-wide (null),
 *   unless roleScope filter narrows to tenant or facility only.
 *
 * @param {Object} scope
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted=false]
 * @param {boolean} [options.includeTenantWide=true]
 * @param {'tenant'|'facility'|null} [options.roleScope]
 */
const buildRoleScopeWhere = (
  scope = {},
  {
    includeDeleted = false,
    includeTenantWide = true,
    roleScope = null,
  } = {}
) => {
  const where = {};
  if (!includeDeleted) {
    where.deleted_at = null;
  }
  if (scope.tenant_id) {
    where.tenant_id = scope.tenant_id;
  }

  const normalizedScope = String(roleScope || '')
    .trim()
    .toLowerCase();

  if (normalizedScope === 'tenant') {
    where.facility_id = null;
    return where;
  }

  if (normalizedScope === 'facility') {
    if (scope.facility_id) {
      where.facility_id = scope.facility_id;
    } else {
      where.NOT = { facility_id: null };
    }
    return where;
  }

  if (scope.facility_id) {
    if (includeTenantWide) {
      where.OR = [
        { facility_id: scope.facility_id },
        { facility_id: null },
      ];
    } else {
      where.facility_id = scope.facility_id;
    }
  }

  return where;
};

module.exports = {
  ACCESS_ADMIN_ROLES,
  ROLE_RANK,
  assertActorCanManageRoleRecord,
  assertPermissionIdAssignable,
  assertPermissionIdsAssignable,
  assertPermissionNamesAssignable,
  assertRoleIdAssignable,
  assertRoleNotSystemProtected,
  assertRoleScopeAllowed,
  assertActorTenantMatches,
  buildRoleScopeWhere,
  canActorCreatePlatformRole,
  canActorCreateTenantWideRole,
  collectRolePermissionNames,
  filterPermissionRecordsByCeiling,
  filterRoleRecordsByCeiling,
  isRoleWithinActorCeiling,
  resolveActorAssignablePermissionNames,
  resolveActorMaxRank,
  resolveActorRoleNames,
  resolveAssignablePlanModules,
};
