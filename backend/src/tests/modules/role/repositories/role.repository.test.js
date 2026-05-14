/**
 * Role repository tests
 *
 * @module tests/modules/role/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  role: {
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
} = require('@repositories/role/role.repository');

const prisma = require('@prisma/client');

describe('Role Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find role by ID', async () => {
      const mockRole = {
        id: 'role-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Admin Role',
        description: 'Administrator role',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.role.findFirst.mockResolvedValue(mockRole);

      const result = await findById('role-123');

      expect(result).toEqual(mockRole);
      expect(prisma.role.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'role-123',
          deleted_at: null
        }
      });
    });

    it('should return null if role not found', async () => {
      prisma.role.findFirst.mockResolvedValue(null);
      const result = await findById('role-123');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.role.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(findById('role-123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many roles with default pagination', async () => {
      const mockRoles = [
        { id: 'role-1', tenant_id: 'tenant-123', name: 'Admin' },
        { id: 'role-2', tenant_id: 'tenant-123', name: 'User' }
      ];
      prisma.role.findMany.mockResolvedValue(mockRoles);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockRoles);
      expect(prisma.role.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find roles with filters', async () => {
      const mockRoles = [{ id: 'role-1', tenant_id: 'tenant-123', name: 'Admin' }];
      prisma.role.findMany.mockResolvedValue(mockRoles);

      const result = await findMany({ tenant_id: 'tenant-123' }, 0, 10);

      expect(result).toEqual(mockRoles);
      expect(prisma.role.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, tenant_id: 'tenant-123' },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.role.findMany.mockRejectedValue(new Error('DB error'));
      await expect(findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count roles', async () => {
      prisma.role.count.mockResolvedValue(10);
      const result = await count({});
      expect(result).toBe(10);
    });

    it('should count roles with filters', async () => {
      prisma.role.count.mockResolvedValue(5);
      const result = await count({ tenant_id: 'tenant-123' });
      expect(result).toBe(5);
      expect(prisma.role.count).toHaveBeenCalledWith({
        where: { deleted_at: null, tenant_id: 'tenant-123' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.role.count.mockRejectedValue(new Error('DB error'));
      await expect(count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create role', async () => {
      const mockRole = {
        id: 'role-123',
        tenant_id: 'tenant-123',
        name: 'New Role',
        description: 'Description'
      };
      prisma.role.create.mockResolvedValue(mockRole);

      const result = await create(mockRole);

      expect(result).toEqual(mockRole);
      expect(prisma.role.create).toHaveBeenCalledWith({ data: mockRole });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.role.create.mockRejectedValue(error);

      await expect(create({ name: 'Duplicate' })).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.role.create.mockRejectedValue(error);

      await expect(create({ tenant_id: 'invalid' })).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update role', async () => {
      const mockRole = { id: 'role-123', name: 'Updated Role' };
      prisma.role.update.mockResolvedValue(mockRole);

      const result = await update('role-123', { name: 'Updated Role' });

      expect(result).toEqual(mockRole);
      expect(prisma.role.update).toHaveBeenCalledWith({
        where: { id: 'role-123' },
        data: { name: 'Updated Role' }
      });
    });

    it('should throw HttpError when role not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.role.update.mockRejectedValue(error);

      await expect(update('role-123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete role', async () => {
      const mockRole = { id: 'role-123', deleted_at: new Date() };
      prisma.role.update.mockResolvedValue(mockRole);

      const result = await softDelete('role-123');

      expect(result).toEqual(mockRole);
      expect(prisma.role.update).toHaveBeenCalledWith({
        where: { id: 'role-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when role not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.role.update.mockRejectedValue(error);

      await expect(softDelete('role-123')).rejects.toThrow(HttpError);
    });
  });
});
