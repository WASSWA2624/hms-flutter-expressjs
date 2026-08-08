/**
 * Sync canonical permission catalog and system roles into the platform catalog.
 *
 * Hot paths (reference-data / workspace) use a short in-memory TTL cache.
 * Default roles/permissions are platform-scoped (tenant_id null) — never cloned
 * per tenant.
 *
 * @module lib/authorization/permission-catalog-sync
 */

const {
  ensurePlatformAccessCatalog,
  listPlatformPermissions,
  consolidateTenantCatalogDuplicates,
  loadPlatformPermissionMap,
  loadPlatformRoleMap,
  CANONICAL_PERMISSION_KEYS: PLATFORM_PERMISSION_KEYS,
  SYSTEM_ROLE_CODES: PLATFORM_ROLE_CODES,
} = require('@lib/authorization/platform-access-catalog');

const CANONICAL_PERMISSION_KEYS = PLATFORM_PERMISSION_KEYS;
const SYSTEM_ROLE_CODES = PLATFORM_ROLE_CODES;

const CATALOG_TTL_MS = Number(process.env.ACCESS_CATALOG_CACHE_TTL_MS || 5 * 60 * 1000);

/** @type {Map<string, { at: number, records: Object[] }>} */
const permissionCatalogCache = new Map();

/** @type {Map<string, { at: number, permissions: number, roles: number }>} */
const accessCatalogCache = new Map();

/**
 * @deprecated Prefer ensurePlatformAccessCatalog. Kept for callers that still
 * request a "tenant" sync; always seeds the shared platform catalog.
 */
const syncPermissionsForTenant = async (tenantId, names = CANONICAL_PERMISSION_KEYS) => {
  void tenantId;
  void names;
  await ensurePlatformAccessCatalog();
  return loadPlatformPermissionMap();
};

/**
 * @deprecated Prefer ensurePlatformAccessCatalog. Kept for callers that still
 * request a "tenant" sync; always seeds the shared platform catalog.
 */
const syncSystemRolesForTenant = async (
  tenantId,
  permissionMap,
  roleNames = SYSTEM_ROLE_CODES,
  options = {}
) => {
  void tenantId;
  void permissionMap;
  void roleNames;
  void options;
  await ensurePlatformAccessCatalog({ force: true });
  return loadPlatformRoleMap();
};

const readCachedPermissionCatalog = (tenantId) => {
  const cached = permissionCatalogCache.get(tenantId);
  if (!cached) {
    return null;
  }
  if (Date.now() - cached.at > CATALOG_TTL_MS) {
    permissionCatalogCache.delete(tenantId);
    return null;
  }
  return cached.records;
};

const writeCachedPermissionCatalog = (tenantId, records) => {
  permissionCatalogCache.set(tenantId, { at: Date.now(), records });
};

const ensureTenantPermissionCatalog = async (tenantId, { force = false } = {}) => {
  // Catalog is platform-scoped; tenantId is retained for cache keying only.
  const cacheKey = tenantId || '__platform__';
  if (!force) {
    const cached = readCachedPermissionCatalog(cacheKey);
    if (cached) {
      return cached;
    }
  }

  await ensurePlatformAccessCatalog({ force });
  const records = await listPlatformPermissions();
  writeCachedPermissionCatalog(cacheKey, records);
  return records;
};

/**
 * Fast path for workspace/reference-data: ensure the platform catalog exists.
 * No longer clones system roles/permissions per tenant.
 */
const ensureTenantAccessCatalog = async (tenantId, { force = false } = {}) => {
  const cacheKey = tenantId || '__platform__';

  if (!force) {
    const cached = accessCatalogCache.get(cacheKey);
    if (cached && Date.now() - cached.at <= CATALOG_TTL_MS) {
      return { permissions: cached.permissions, roles: cached.roles };
    }
  }

  const result = await ensurePlatformAccessCatalog({ force });
  const summary = {
    permissions: result.permissions,
    roles: result.roles,
  };
  accessCatalogCache.set(cacheKey, {
    at: Date.now(),
    ...summary,
  });
  return summary;
};

/**
 * Full metadata refresh of the platform catalog.
 */
const refreshTenantAccessCatalog = async (tenantId) => {
  clearAccessCatalogCache(tenantId || null);
  const result = await ensurePlatformAccessCatalog({ force: true });
  const cacheKey = tenantId || '__platform__';
  accessCatalogCache.set(cacheKey, {
    at: Date.now(),
    permissions: result.permissions,
    roles: result.roles,
  });
  const permissionRecords = await listPlatformPermissions();
  writeCachedPermissionCatalog(cacheKey, permissionRecords);
  return result;
};

const clearAccessCatalogCache = (tenantId = null) => {
  if (tenantId) {
    permissionCatalogCache.delete(tenantId);
    accessCatalogCache.delete(tenantId);
    return;
  }
  permissionCatalogCache.clear();
  accessCatalogCache.clear();
};

/**
 * Restore shipped role→permission defaults (platform-scoped).
 * tenantId is accepted for API compatibility.
 *
 * @param {string} tenantId
 * @param {Object} [options]
 * @param {string[]} [options.roleNames]
 */
const restoreTenantRolePermissionDefaults = async (tenantId, options = {}) => {
  void tenantId;
  void options;
  const seeded = await ensurePlatformAccessCatalog({ force: true });
  clearAccessCatalogCache();
  return {
    permissions: seeded.permissions,
    roles: seeded.roles,
    role_permissions_added: 0,
    role_permissions_removed: 0,
    before: {},
    after: {},
    scope: 'platform',
  };
};

module.exports = {
  CANONICAL_PERMISSION_KEYS,
  SYSTEM_ROLE_CODES,
  clearAccessCatalogCache,
  consolidateTenantCatalogDuplicates,
  ensurePlatformAccessCatalog,
  ensureTenantAccessCatalog,
  ensureTenantPermissionCatalog,
  refreshTenantAccessCatalog,
  restoreTenantRolePermissionDefaults,
  syncPermissionsForTenant,
  syncSystemRolesForTenant,
};
