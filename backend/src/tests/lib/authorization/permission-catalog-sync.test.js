jest.mock('@prisma/client', () => ({
  permission: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    createMany: jest.fn(),
    update: jest.fn(),
  },
  role: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  role_permission: {
    findFirst: jest.fn(),
    create: jest.fn(),
  },
}));

const prisma = require('@prisma/client');
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
  });

  it('exposes the full canonical permission catalog from config', () => {
    expect(CANONICAL_PERMISSION_KEYS).toContain('patient:read');
    expect(CANONICAL_PERMISSION_KEYS).toContain('clinical:write');
    expect(CANONICAL_PERMISSION_KEYS.length).toBeGreaterThan(40);
    expect(SYSTEM_ROLE_CODES).toContain('DOCTOR');
    expect(SYSTEM_ROLE_CODES).toContain('NURSE');
  });

  it('ensures missing permissions and system roles without rewriting complete catalogs', async () => {
    prisma.permission.findMany.mockResolvedValue(
      CANONICAL_PERMISSION_KEYS.map((name) => ({
        id: `perm-${name}`,
        name,
      }))
    );
    prisma.role.findMany.mockResolvedValue(
      SYSTEM_ROLE_CODES.map((name) => ({
        id: `role-${name}`,
        name,
      }))
    );

    const result = await ensureTenantAccessCatalog('tenant-uuid');

    expect(result).toEqual({
      permissions: CANONICAL_PERMISSION_KEYS.length,
      roles: SYSTEM_ROLE_CODES.length,
    });
    expect(prisma.permission.createMany).not.toHaveBeenCalled();
    expect(prisma.role.create).not.toHaveBeenCalled();
  });

  it('creates only missing system roles on the fast path', async () => {
    prisma.permission.findMany.mockResolvedValue(
      CANONICAL_PERMISSION_KEYS.map((name) => ({
        id: `perm-${name}`,
        name,
      }))
    );
    prisma.role.findMany.mockResolvedValue(
      SYSTEM_ROLE_CODES.filter((name) => name !== 'DOCTOR').map((name) => ({
        id: `role-${name}`,
        name,
      }))
    );
    prisma.role.findFirst.mockResolvedValue(null);
    prisma.role.create.mockImplementation(async ({ data }) => ({
      id: `role-${data.name}`,
      ...data,
    }));
    prisma.role_permission.findFirst.mockResolvedValue(null);
    prisma.role_permission.create.mockResolvedValue({});

    const result = await ensureTenantAccessCatalog('tenant-uuid');

    expect(result.roles).toBe(SYSTEM_ROLE_CODES.length);
    expect(prisma.role.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          name: 'DOCTOR',
          display_name: 'Doctor',
        }),
      })
    );
  });

  it('caches access catalog results across calls', async () => {
    prisma.permission.findMany.mockResolvedValue(
      CANONICAL_PERMISSION_KEYS.map((name) => ({
        id: `perm-${name}`,
        name,
      }))
    );
    prisma.role.findMany.mockResolvedValue(
      SYSTEM_ROLE_CODES.map((name) => ({
        id: `role-${name}`,
        name,
      }))
    );

    await ensureTenantAccessCatalog('tenant-uuid');
    await ensureTenantAccessCatalog('tenant-uuid');

    expect(prisma.permission.findMany).toHaveBeenCalledTimes(1);
    expect(prisma.role.findMany).toHaveBeenCalledTimes(1);
  });

  it('refreshes metadata when explicitly requested', async () => {
    prisma.permission.findFirst.mockResolvedValue({
      id: 'perm-existing',
      name: 'patient:read',
    });
    prisma.permission.update.mockImplementation(async ({ data }) => ({
      id: 'perm-existing',
      name: 'patient:read',
      ...data,
    }));
    prisma.permission.findMany.mockResolvedValue(
      CANONICAL_PERMISSION_KEYS.map((name) => ({
        id: `perm-${name}`,
        name,
      }))
    );
    prisma.permission.count.mockResolvedValue(CANONICAL_PERMISSION_KEYS.length);
    prisma.role.count.mockResolvedValue(SYSTEM_ROLE_CODES.length);
    prisma.role.findFirst.mockResolvedValue({
      id: 'role-existing',
      name: 'DOCTOR',
    });
    prisma.role.update.mockImplementation(async ({ data }) => ({
      id: 'role-existing',
      name: 'DOCTOR',
      ...data,
    }));
    prisma.role_permission.findFirst.mockResolvedValue({ id: 'link-existing' });

    await refreshTenantAccessCatalog('tenant-uuid');

    expect(prisma.permission.update).toHaveBeenCalled();
    expect(prisma.role.update).toHaveBeenCalled();
    expect(prisma.permission.create).not.toHaveBeenCalled();
    expect(prisma.role.create).not.toHaveBeenCalled();
  });

  it('creates only missing permissions for a tenant', async () => {
    prisma.permission.findMany
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([
        {
          id: 'perm-new',
          name: 'patient:read',
          display_name: 'Patient — Read',
        },
      ]);
    prisma.permission.createMany.mockResolvedValue({ count: 1 });

    const result = await ensureTenantPermissionCatalog('tenant-uuid');

    expect(prisma.permission.createMany).toHaveBeenCalled();
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('patient:read');
  });
});
