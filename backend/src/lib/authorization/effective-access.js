/**
 * Effective access calculation
 *
 * A user may hold one or more roles (`user_role`). Net rights are the
 * permission union of all assigned roles (plus module/direct grants), then
 * intersected with subscription and assigned-module ceilings:
 *
 *   union(role ∪ module ∪ direct-user grants)
 *   ∩ active subscription permissions
 *   ∩ assigned modules
 *   ∩ ABAC scope (evaluated separately in middleware/services)
 *
 * This module owns the grant ∪ subscription ∩ assigned-modules portion.
 * ABAC remains in abac.middleware / policy-evaluator.
 */

const { ROLES } = require('@config/roles');
const {
  PERMISSIONS,
  ROLE_PERMISSIONS,
  normalizePermissionName,
} = require('@config/permissions');
const { normalizeRoleName } = require('@config/roles');
const {
  filterVersionDisabledPermissionNames,
} = require('@config/version-disabled-permissions');
const {
  filterPermissionNamesByPlanModules,
  filterPermissionNamesBySubscriptionPermissions,
  moduleForPermissionName,
  normalizeEnabledModuleSet,
  normalizeModuleCode,
} = require('@lib/authorization/permission-module-map');

const uniqueValues = (values = []) =>
  Array.from(
    new Set(
      (Array.isArray(values) ? values : [])
        .map((value) => String(value || '').trim())
        .filter(Boolean)
    )
  );

const text = (value) => String(value || '').trim();

const extractPermissionName = (entry) => {
  if (entry == null) return '';
  const raw =
    typeof entry === 'string'
      ? text(entry)
      : text(
          entry.name ||
            entry.code ||
            entry.permission_name ||
            entry.permissionName ||
            entry.permission?.name ||
            entry.permission?.code
        );
  return normalizePermissionName(raw) || raw;
};

const extractModuleCode = (entry) => {
  if (entry == null) return '';
  if (typeof entry === 'string') return normalizeModuleCode(entry);
  return normalizeModuleCode(
    entry.module_slug ||
      entry.moduleSlug ||
      entry.code ||
      entry.module_code ||
      entry.moduleCode ||
      entry.slug ||
      entry.id ||
      entry.module?.slug ||
      entry.module?.code
  );
};

const getRoleNames = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [];
  const names = roles
    .flatMap((role) => {
      if (typeof role === 'string') {
        const normalized = normalizeRoleName(role) || text(role).toUpperCase();
        return normalized ? [normalized] : [];
      }
      // ORM shape: user_role { role: { name } } or flat { name }
      const candidates = [
        role?.role?.name,
        role?.role?.code,
        role?.name,
        role?.role_name,
        role?.code,
      ];
      return candidates
        .map((candidate) => normalizeRoleName(candidate) || text(candidate).toUpperCase())
        .filter(Boolean);
    })
    .filter(Boolean);

  const direct =
    normalizeRoleName(user.role) ||
    normalizeRoleName(user.role?.name) ||
    text(typeof user.role === 'string' ? user.role : user.role?.name).toUpperCase();
  if (direct) names.push(direct);
  return uniqueValues(names);
};

const userHasPlatformOwnerRole = (user = {}) =>
  getRoleNames(user).includes(ROLES.PLATFORM_OWNER);

const userHasSuperAdminRole = (user = {}) => {
  const roles = getRoleNames(user);
  return (
    roles.includes(ROLES.PLATFORM_OWNER) || roles.includes(ROLES.PLATFORM_ADMIN)
  );
};

/**
 * Direct user permission grants (user_permission).
 */
const resolveDirectPermissionNames = (user = {}) => {
  if (
    Array.isArray(user.direct_permissions) ||
    Array.isArray(user.directPermissions) ||
    Array.isArray(user.user_permissions) ||
    Array.isArray(user.userPermissions)
  ) {
    return uniqueValues(
      [
        ...(user.direct_permissions || []),
        ...(user.directPermissions || []),
        ...(user.user_permissions || []),
        ...(user.userPermissions || []),
      ].map(extractPermissionName)
    );
  }

  // Loaded ORM shape: permissions: [{ permission: { name } }]
  if (
    Array.isArray(user.permissions) &&
    user.permissions.some((entry) => entry && typeof entry === 'object' && entry.permission)
  ) {
    return uniqueValues(user.permissions.map(extractPermissionName));
  }

  return [];
};

/**
 * Role-attached permission grants (role_permission + catalog fallback).
 */
const resolveRolePermissionNames = (user = {}) => {
  const fromEmbeddedRoles = [];
  const roles = Array.isArray(user.roles) ? user.roles : [];

  for (const roleEntry of roles) {
    if (roleEntry && typeof roleEntry === 'object') {
      const role = roleEntry.role || roleEntry;
      if (Array.isArray(role.permissions)) {
        for (const permissionEntry of role.permissions) {
          fromEmbeddedRoles.push(extractPermissionName(permissionEntry));
        }
      }
      if (Array.isArray(roleEntry.permissions) && roleEntry.permissions !== role.permissions) {
        for (const permissionEntry of roleEntry.permissions) {
          fromEmbeddedRoles.push(extractPermissionName(permissionEntry));
        }
      }
    }
  }

  if (fromEmbeddedRoles.length > 0) {
    // Union shipped ROLE_PERMISSIONS so pack additions (e.g. reports:read) apply
    // immediately even when tenant role_permission rows are stale.
    const roleNames = getRoleNames(user);
    const fromPack = roleNames.flatMap(
      (roleName) => ROLE_PERMISSIONS[roleName] || []
    );
    // Pure system-role users: pack is the source of truth so stale DB extras
    // (e.g. lab:read left on DOCTOR) cannot over-grant shell destinations.
    const onlySystemRoles =
      roleNames.length > 0 &&
      roleNames.every((roleName) => Boolean(ROLE_PERMISSIONS[roleName]));
    if (onlySystemRoles) {
      return uniqueValues(fromPack);
    }
    return uniqueValues([...fromEmbeddedRoles, ...fromPack]);
  }

  if (Array.isArray(user.role_permissions) || Array.isArray(user.rolePermissions)) {
    const fromDb = uniqueValues(
      [...(user.role_permissions || []), ...(user.rolePermissions || [])].map(
        extractPermissionName
      )
    );
    const roleNames = getRoleNames(user);
    const fromPack = roleNames.flatMap(
      (roleName) => ROLE_PERMISSIONS[roleName] || []
    );
    const onlySystemRoles =
      roleNames.length > 0 &&
      roleNames.every((roleName) => Boolean(ROLE_PERMISSIONS[roleName]));
    if (onlySystemRoles) {
      return uniqueValues(fromPack);
    }
    return uniqueValues([...fromDb, ...fromPack]);
  }

  return uniqueValues(
    getRoleNames(user).flatMap((roleName) => ROLE_PERMISSIONS[roleName] || [])
  );
};

/**
 * Module-level grants (permissions attached via module assignment packs).
 */
const resolveModulePermissionNames = (user = {}) => {
  const sources = [
    user.module_permissions,
    user.modulePermissions,
    user.module_grants,
    user.moduleGrants,
  ];

  return uniqueValues(
    sources.flatMap((source) => (Array.isArray(source) ? source : [])).map(extractPermissionName)
  );
};

/**
 * Explicit per-user assigned modules. Empty means "no extra restriction beyond
 * grants ∩ subscription" (assigned modules derived from grant domains).
 */
const resolveAssignedModuleCodes = (user = {}) => {
  const sources = [
    user.module_assignments,
    user.moduleAssignments,
    user.assigned_modules,
    user.assignedModules,
    user.explicit_modules,
    user.explicitModules,
  ];

  return uniqueValues(
    sources.flatMap((source) => (Array.isArray(source) ? source : [])).map(extractModuleCode)
  );
};

const modulesImpliedByPermissions = (permissionNames = []) =>
  uniqueValues(
    permissionNames
      .map((name) => moduleForPermissionName(name))
      .filter(Boolean)
      .map(normalizeModuleCode)
  );

const filterPermissionNamesByAssignedModules = (
  permissionNames = [],
  assignedModules = null
) => {
  if (assignedModules == null) {
    return permissionNames;
  }

  const assigned = assignedModules instanceof Set
    ? assignedModules
    : new Set(
        (Array.isArray(assignedModules) ? assignedModules : [])
          .map(normalizeModuleCode)
          .filter(Boolean)
      );

  if (assigned.size === 0) {
    return permissionNames;
  }

  return permissionNames.filter((name) => {
    const moduleSlug = moduleForPermissionName(name);
    if (!moduleSlug) {
      return true;
    }
    return (
      assigned.has(moduleSlug) || assigned.has(normalizeModuleCode(moduleSlug))
    );
  });
};

/**
 * Compute effective permission names for a user.
 *
 * @param {Object} user
 * @param {Object} [options]
 * @param {Iterable|null} [options.moduleEntitlements] - Tenant subscription modules
 * @param {boolean} [options.applyPlanGate=true]
 * @param {boolean} [options.applyAssignedModuleGate=true]
 * @returns {{
 *   direct_permissions: string[],
 *   role_permissions: string[],
 *   module_permissions: string[],
 *   grant_union: string[],
 *   assigned_modules: string[],
 *   subscription_modules: string[]|null,
 *   permissions: string[],
 * }}
 */
const resolveEffectiveAccess = (user = {}, options = {}) => {
  const {
    moduleEntitlements = user.module_entitlements || user.moduleEntitlements || null,
    applyPlanGate = true,
    applyAssignedModuleGate = true,
  } = options;

  const directPermissions = resolveDirectPermissionNames(user);
  const rolePermissions = resolveRolePermissionNames(user);
  const modulePermissions = resolveModulePermissionNames(user);
  const grantUnion = uniqueValues([
    ...directPermissions,
    ...rolePermissions,
    ...modulePermissions,
  ]);

  const elevated = userHasSuperAdminRole(user);
  const hasTenantContext = Boolean(user?.tenant_id || user?.tenantId);
  const explicitAssigned = resolveAssignedModuleCodes(user);
  const assignedModules =
    explicitAssigned.length > 0
      ? explicitAssigned
      : modulesImpliedByPermissions(grantUnion);

  let permissions = grantUnion;
  let subscriptionModules = null;

  if (applyPlanGate && hasTenantContext) {
    const enabledModules = normalizeEnabledModuleSet(moduleEntitlements || []);
    subscriptionModules = [...enabledModules];
    permissions = filterPermissionNamesByPlanModules(permissions, enabledModules);
  } else if (applyPlanGate && !elevated && moduleEntitlements != null) {
    const enabledModules = normalizeEnabledModuleSet(moduleEntitlements);
    subscriptionModules = [...enabledModules];
    permissions = filterPermissionNamesByPlanModules(permissions, enabledModules);
  }

  if (applyAssignedModuleGate && !elevated && explicitAssigned.length > 0) {
    permissions = filterPermissionNamesByAssignedModules(
      permissions,
      new Set(explicitAssigned)
    );
  }

  if (applyPlanGate && moduleEntitlements != null) {
    permissions = filterPermissionNamesBySubscriptionPermissions(
      permissions,
      moduleEntitlements
    );
  }

  // Reports is platform infrastructure: available to every authenticated role
  // on every subscription package (temporary baseline until plan packaging
  // differentiates reporting again).
  if (getRoleNames(user).length > 0 || grantUnion.length > 0) {
    permissions = uniqueValues([...permissions, PERMISSIONS.REPORTS_READ]);
  }

  // Version-disabled domains are withheld from every actor until re-enabled.
  permissions = filterVersionDisabledPermissionNames(permissions);

  return {
    direct_permissions: directPermissions,
    role_permissions: rolePermissions,
    module_permissions: modulePermissions,
    grant_union: grantUnion,
    assigned_modules: assignedModules,
    subscription_modules: subscriptionModules,
    permissions: uniqueValues(permissions),
  };
};

/**
 * Resolve effective permission name list only.
 */
const resolveEffectivePermissionNames = (user = {}, options = {}) =>
  resolveEffectiveAccess(user, options).permissions;

/**
 * Request-time permission resolution for middleware.
 *
 * Prefer JWT/hydrated permission grants, then always re-apply the live
 * subscription plan gate when entitlements are present so downgrades cannot
 * outlive the token. Fall back to role-catalog resolution when the token has
 * no permission array.
 */
const resolveRequestPermissionNames = (user = {}) => {
  if (!user || typeof user !== 'object') {
    return [];
  }

  if (user.auth_type === 'api_key' || user.api_key_id) {
    return filterVersionDisabledPermissionNames(
      uniqueValues(
        (Array.isArray(user.permissions) ? user.permissions : []).map(
          extractPermissionName
        )
      )
    );
  }

  const moduleEntitlements =
    user.module_entitlements || user.moduleEntitlements || null;
  const tokenPermissions = Array.isArray(user.permissions)
    ? uniqueValues(user.permissions.map(extractPermissionName))
    : [];
  const tokenLooksLikeOrmJoin = Boolean(
    user.permissions?.some?.((entry) => entry && typeof entry === 'object' && entry.permission)
  );

  if (tokenPermissions.length > 0 && !tokenLooksLikeOrmJoin) {
    const hasTenantContext = Boolean(user.tenant_id || user.tenantId);
    if (userHasSuperAdminRole(user) && !hasTenantContext) {
      return filterVersionDisabledPermissionNames(
        uniqueValues([...tokenPermissions, PERMISSIONS.REPORTS_READ])
      );
    }

    let permissions = tokenPermissions;
    if (moduleEntitlements != null) {
      permissions = filterPermissionNamesBySubscriptionPermissions(
        filterPermissionNamesByPlanModules(
          tokenPermissions,
          normalizeEnabledModuleSet(moduleEntitlements)
        ),
        moduleEntitlements
      );
    }

    // Reports remains available on every plan for every authenticated role.
    if (getRoleNames(user).length > 0 || permissions.length > 0) {
      permissions = uniqueValues([...permissions, PERMISSIONS.REPORTS_READ]);
    }
    return filterVersionDisabledPermissionNames(permissions);
  }

  return resolveEffectivePermissionNames(user, {
    moduleEntitlements,
    applyPlanGate: Boolean(
      user.tenant_id || moduleEntitlements != null
    ),
  });
};

module.exports = {
  filterPermissionNamesByAssignedModules,
  getRoleNames,
  modulesImpliedByPermissions,
  resolveAssignedModuleCodes,
  resolveDirectPermissionNames,
  resolveEffectiveAccess,
  resolveEffectivePermissionNames,
  resolveModulePermissionNames,
  resolveRequestPermissionNames,
  resolveRolePermissionNames,
  userHasPlatformOwnerRole,
  userHasSuperAdminRole,
};
