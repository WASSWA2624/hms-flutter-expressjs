jest.mock('@lib/authorization/platform-access-catalog', () => {
  const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');
  const CANONICAL_PERMISSION_KEYS = Object.freeze(
    Array.from(new Set(Object.values(PERMISSIONS))).sort()
  );
  const SYSTEM_ROLE_CODES = Object.freeze(Object.keys(ROLE_PERMISSIONS).sort());

  return {
    CANONICAL_PERMISSION_KEYS,
    SYSTEM_ROLE_CODES,
    ensurePlatformAccessCatalog: jest.fn(),
    listPlatformPermissions: jest.fn(),
    consolidateTenantCatalogDuplicates: jest.fn(),
    loadPlatformPermissionMap: jest.fn(),
    loadPlatformRoleMap: jest.fn(),
  };
});

const platformCatalog = require('@lib/authorization/platform-access-catalog');
const {
  CANONICAL_PERMISSION_KEYS,
  SYSTEM_ROLE_CODES,
  clearAccessCatalogCache,
  ensureTenantAccessCatalog,
  ensureTenantPermissionCatalog,
  refreshTenantAccessCatalog,
} = require('@lib/authorization/permission-catalog-sync');

describe('permission-catalog-sync', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    clearAccessCatalogCache();
    platformCatalog.ensurePlatformAccessCatalog.mockResolvedValue({
      permissions: CANONICAL_PERMISSION_KEYS.length,
      roles: SYSTEM_ROLE_CODES.length,
      force: false,
    });
    platformCatalog.listPlatformPermissions.mockResolvedValue(
      CANONICAL_PERMISSION_KEYS.map((name) => ({
        id: `perm-${name}`,
        name,
        tenant_id: null,
      }))
    );
  });

  it('exposes the full canonical permission catalog from config', () => {
    expect(CANONICAL_PERMISSION_KEYS).toContain('patient:read');
    expect(CANONICAL_PERMISSION_KEYS).toContain('clinical:write');
    expect(CANONICAL_PERMISSION_KEYS.length).toBeGreaterThan(40);
    expect(SYSTEM_ROLE_CODES).toContain('DOCTOR');
    expect(SYSTEM_ROLE_CODES).toContain('NURSE');
  });

  it('ensures the platform catalog on the access-catalog fast path', async () => {
    const result = await ensureTenantAccessCatalog('tenant-uuid');

    expect(result).toEqual({
      permissions: CANONICAL_PERMISSION_KEYS.length,
      roles: SYSTEM_ROLE_CODES.length,
    });
    expect(platformCatalog.ensurePlatformAccessCatalog).toHaveBeenCalledWith({
      force: false,
    });
  });

  it('caches access catalog results across calls', async () => {
    await ensureTenantAccessCatalog('tenant-uuid');
    await ensureTenantAccessCatalog('tenant-uuid');

    expect(platformCatalog.ensurePlatformAccessCatalog).toHaveBeenCalledTimes(1);
  });

  it('refreshes the platform catalog when explicitly requested', async () => {
    platformCatalog.ensurePlatformAccessCatalog.mockResolvedValue({
      permissions: CANONICAL_PERMISSION_KEYS.length,
      roles: SYSTEM_ROLE_CODES.length,
      force: true,
    });

    await refreshTenantAccessCatalog('tenant-uuid');

    expect(platformCatalog.ensurePlatformAccessCatalog).toHaveBeenCalledWith({
      force: true,
    });
    expect(platformCatalog.listPlatformPermissions).toHaveBeenCalled();
  });

  it('lists platform permissions for the permission-catalog path', async () => {
    const result = await ensureTenantPermissionCatalog('tenant-uuid');

    expect(platformCatalog.ensurePlatformAccessCatalog).toHaveBeenCalled();
    expect(platformCatalog.listPlatformPermissions).toHaveBeenCalled();
    expect(result).toHaveLength(CANONICAL_PERMISSION_KEYS.length);
    expect(result[0].tenant_id).toBeNull();
  });
});
