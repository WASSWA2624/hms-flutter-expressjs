/**
 * Tenant repository tests
 *
 * @module tests/modules/tenant/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  tenant: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/tenant/tenant.repository');

const prisma = require('@prisma/client');

describe('Tenant Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find tenant by ID', async () => {
      const mockTenant = {
        id: 'tenant-123',
        name: 'Test Hospital',
        slug: 'test-hospital',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.tenant.findFirst.mockResolvedValue(mockTenant);

      const result = await findById('tenant-123');

      expect(result).toEqual(mockTenant);
      expect(prisma.tenant.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'tenant-123',
          deleted_at: null
        },
        include: expect.objectContaining({
          user_roles: expect.objectContaining({
            take: 1,
            where: expect.objectContaining({
              deleted_at: null,
              role: {
                deleted_at: null,
                name: 'TENANT_ADMIN',
              },
              user: {
                deleted_at: null,
              },
            }),
            include: expect.objectContaining({
              role: expect.any(Object),
              user: expect.any(Object),
            }),
          }),
        }),
      });
    });

    it('should return null if tenant not found', async () => {
      prisma.tenant.findFirst.mockResolvedValue(null);

      const result = await findById('tenant-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.tenant.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('tenant-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many tenants with default pagination', async () => {
      const mockTenants = [
        {
          id: 'tenant-1',
          name: 'Hospital A',
          slug: 'hospital-a',
          is_active: true
        },
        {
          id: 'tenant-2',
          name: 'Hospital B',
          slug: 'hospital-b',
          is_active: true
        }
      ];
      prisma.tenant.findMany.mockResolvedValue(mockTenants);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockTenants);
      expect(prisma.tenant.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: expect.objectContaining({
          user_roles: expect.objectContaining({
            take: 1,
          }),
        }),
      });
    });

    it('should find tenants with filters', async () => {
      const mockTenants = [
        {
          id: 'tenant-1',
          name: 'Hospital A',
          slug: 'hospital-a',
          is_active: true
        }
      ];
      prisma.tenant.findMany.mockResolvedValue(mockTenants);

      const result = await findMany({ is_active: true }, 0, 10);

      expect(result).toEqual(mockTenants);
      expect(prisma.tenant.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          is_active: true
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: expect.objectContaining({
          user_roles: expect.objectContaining({
            take: 1,
          }),
        }),
      });
    });

    it('should find tenants with custom sort order', async () => {
      const mockTenants = [];
      prisma.tenant.findMany.mockResolvedValue(mockTenants);

      await findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.tenant.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' },
        include: expect.objectContaining({
          user_roles: expect.objectContaining({
            take: 1,
          }),
        }),
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.tenant.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count tenants without filters', async () => {
      prisma.tenant.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.tenant.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count tenants with filters', async () => {
      prisma.tenant.count.mockResolvedValue(5);

      const result = await count({ is_active: true });

      expect(result).toBe(5);
      expect(prisma.tenant.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          is_active: true
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.tenant.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new tenant', async () => {
      const tenantData = {
        name: 'New Hospital',
        slug: 'new-hospital',
        is_active: true
      };
      const mockCreatedTenant = {
        id: 'tenant-new',
        ...tenantData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.tenant.create.mockResolvedValue(mockCreatedTenant);

      const result = await create(tenantData);

      expect(result).toEqual(mockCreatedTenant);
      expect(prisma.tenant.create).toHaveBeenCalledWith({
        data: tenantData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const tenantData = {
        name: 'Duplicate Hospital',
        slug: 'duplicate-hospital'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['slug'] };
      prisma.tenant.create.mockRejectedValue(error);

      await expect(create(tenantData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.tenant.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ name: 'Test' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a tenant', async () => {
      const updateData = {
        name: 'Updated Hospital',
        is_active: false
      };
      const mockUpdatedTenant = {
        id: 'tenant-123',
        ...updateData,
        slug: 'test-hospital',
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      prisma.tenant.update.mockResolvedValue(mockUpdatedTenant);

      const result = await update('tenant-123', updateData);

      expect(result).toEqual(mockUpdatedTenant);
      expect(prisma.tenant.update).toHaveBeenCalledWith({
        where: { id: 'tenant-123' },
        data: updateData
      });
    });

    it('should throw HttpError when tenant not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.tenant.update.mockRejectedValue(error);

      await expect(update('tenant-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['slug'] };
      prisma.tenant.update.mockRejectedValue(error);

      await expect(update('tenant-123', { slug: 'duplicate-slug' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.tenant.update.mockRejectedValue(new Error('DB error'));

      await expect(update('tenant-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a tenant', async () => {
      const mockDeletedTenant = {
        id: 'tenant-123',
        name: 'Test Hospital',
        slug: 'test-hospital',
        is_active: true,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: new Date(),
        version: 1
      };
      prisma.tenant.update.mockResolvedValue(mockDeletedTenant);

      const result = await softDelete('tenant-123');

      expect(result).toEqual(mockDeletedTenant);
      expect(prisma.tenant.update).toHaveBeenCalledWith({
        where: { id: 'tenant-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when tenant not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.tenant.update.mockRejectedValue(error);

      await expect(softDelete('tenant-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.tenant.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('tenant-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
