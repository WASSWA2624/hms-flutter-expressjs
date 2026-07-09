jest.mock('@prisma/client', () => ({
  permission: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  role: {
    findFirst: jest.fn(),
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
  ensureTenantAccessCatalog,
} = require('@lib/authorization/permission-catalog-sync');

describe('permission-catalog-sync', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('exposes the full canonical permission catalog from config', () => {
    expect(CANONICAL_PERMISSION_KEYS).toContain('patient:read');
    expect(CANONICAL_PERMISSION_KEYS).toContain('clinical:write');
    expect(CANONICAL_PERMISSION_KEYS.length).toBeGreaterThan(40);
    expect(SYSTEM_ROLE_CODES).toContain('DOCTOR');
    expect(SYSTEM_ROLE_CODES).toContain('NURSE');
  });

  it('syncs permissions and system roles with metadata for a tenant', async () => {
    prisma.permission.count.mockResolvedValue(CANONICAL_PERMISSION_KEYS.length);
    prisma.role.count.mockResolvedValue(SYSTEM_ROLE_CODES.length);
    prisma.permission.findFirst.mockResolvedValue(null);
    prisma.permission.create.mockImplementation(async ({ data }) => ({
      id: `perm-${data.name}`,
      ...data,
    }));
    prisma.role.findFirst.mockResolvedValue(null);
    prisma.role.create.mockImplementation(async ({ data }) => ({
      id: `role-${data.name}`,
      ...data,
    }));
    prisma.role_permission.findFirst.mockResolvedValue(null);
    prisma.role_permission.create.mockResolvedValue({});

    const result = await ensureTenantAccessCatalog('tenant-uuid');

    expect(result).toEqual({
      permissions: CANONICAL_PERMISSION_KEYS.length,
      roles: SYSTEM_ROLE_CODES.length,
    });
    expect(prisma.permission.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          name: 'patient:read',
          display_name: 'Patient — Read',
          description: expect.any(String),
        }),
      })
    );
    expect(prisma.role.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          name: 'DOCTOR',
          display_name: 'Doctor',
          description: expect.any(String),
        }),
      })
    );
  });

  it('refreshes metadata on existing permissions and roles', async () => {
    prisma.permission.count.mockResolvedValue(CANONICAL_PERMISSION_KEYS.length);
    prisma.role.count.mockResolvedValue(SYSTEM_ROLE_CODES.length);
    prisma.permission.findFirst.mockResolvedValue({
      id: 'perm-existing',
      name: 'patient:read',
    });
    prisma.permission.update.mockImplementation(async ({ data }) => ({
      id: 'perm-existing',
      name: 'patient:read',
      ...data,
    }));
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

    await ensureTenantAccessCatalog('tenant-uuid');

    expect(prisma.permission.update).toHaveBeenCalled();
    expect(prisma.role.update).toHaveBeenCalled();
    expect(prisma.permission.create).not.toHaveBeenCalled();
    expect(prisma.role.create).not.toHaveBeenCalled();
  });
});
