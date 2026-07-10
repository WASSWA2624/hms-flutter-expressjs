/**
 * Actor permission ceiling helpers for role create / assign flows.
 *
 * Admins may only grant permissions (and assign roles) within the union of
 * permissions implied by their own roles — never above their level.
 */

const prisma = require('@prisma/client');
const { ROLES } = require('@config/roles');
const { ROLE_PERMISSIONS } = require('@config/permissions');
const { HttpError } = require('@lib/errors');
const { getUserPermissions } = require('@middlewares/auth.middleware');
const { resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');

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
  const fromContext = getUserPermissions(user);
  if (fromContext.length > 0) {
    return new Set(fromContext);
  }

  return new Set(
    resolveActorRoleNames(user).flatMap((role) => ROLE_PERMISSIONS[role] || [])
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

const isPermissionNameAssignable = (permissionName, assignableSet) => {
  const name = text(permissionName);
  if (!name) {
    return false;
  }
  return assignableSet.has(name);
};

const filterPermissionRecordsByCeiling = (permissions = [], user = {}) => {
  const assignable = resolveActorAssignablePermissionNames(user);
  if (assignable.size === 0) {
    return [];
  }
  return permissions.filter((entry) =>
    isPermissionNameAssignable(entry?.name || entry?.label, assignable)
  );
};

const collectRolePermissionNames = (role = {}) => {
  const fromAssignments = Array.isArray(role.permissions)
    ? role.permissions
        .map((entry) => entry?.permission?.name || entry?.name || entry?.permission_name)
        .map(text)
        .filter(Boolean)
    : [];

  if (fromAssignments.length > 0) {
    return fromAssignments;
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

const assertPermissionNamesAssignable = (permissionNames = [], user = {}) => {
  const assignable = resolveActorAssignablePermissionNames(user);
  const denied = [...new Set(permissionNames.map(text).filter(Boolean))].filter(
    (name) => !assignable.has(name)
  );
  if (denied.length > 0) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      { field: 'permission_id', reason: 'above_actor_ceiling', denied },
    ]);
  }
};

const assertPermissionIdAssignable = async (permissionId, user = {}) => {
  const resolvedId = await resolveIdentifierForPayload({
    value: permissionId,
    model: 'permission',
    field: 'permission_id',
  });
  const permission = await prisma.permission.findFirst({
    where: { id: resolvedId, deleted_at: null },
    select: { id: true, name: true },
  });
  if (!permission) {
    throw new HttpError('errors.permission.not_found', 404);
  }
  assertPermissionNamesAssignable([permission.name], user);
  return permission;
};

/**
 * Resolve and ceiling-check many permission identifiers in one query.
 * @returns {Promise<string[]>} Deduped permission UUIDs
 */
const assertPermissionIdsAssignable = async (permissionIds = [], user = {}) => {
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
    select: { id: true, name: true, human_friendly_id: true },
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

  assertPermissionNamesAssignable(
    resolved.map((entry) => entry.name),
    user
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

  if (!hasFacility && !canActorCreateTenantWideRole(user)) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      { field: 'facility_id', reason: 'facility_scope_required' },
    ]);
  }

  if (!hasFacility) {
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
    if (actorFacilityId && actorFacilityId !== facility.id) {
      throw new HttpError('errors.auth.scope_mismatch', 403, [
        { field: 'facility_id', reason: 'outside_actor_facility' },
      ]);
    }
  }

  return {
    ...payload,
    facility_id: facility.id,
    tenant_id: payload.tenant_id || facility.tenant_id,
  };
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
  assertPermissionIdAssignable,
  assertPermissionIdsAssignable,
  assertPermissionNamesAssignable,
  assertRoleIdAssignable,
  assertRoleScopeAllowed,
  buildRoleScopeWhere,
  canActorCreateTenantWideRole,
  collectRolePermissionNames,
  filterPermissionRecordsByCeiling,
  filterRoleRecordsByCeiling,
  isRoleWithinActorCeiling,
  resolveActorAssignablePermissionNames,
  resolveActorMaxRank,
  resolveActorRoleNames,
};
