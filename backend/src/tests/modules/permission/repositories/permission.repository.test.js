/**
 * Permission repository tests
 *
 * @module tests/modules/permission/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  permission: {
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
} = require('@repositories/permission/permission.repository');

const prisma = require('@prisma/client');

describe('Permission Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find permission by ID', async () => {
      const mockPermission = {
        id: 'permission-123',
        tenant_id: 'tenant-123',
        name: 'view_users',
        description: 'View users permission'
      };
      prisma.permission.findFirst.mockResolvedValue(mockPermission);

      const result = await findById('permission-123');

      expect(result).toEqual(mockPermission);
    });

    it('should return null if not found', async () => {
      prisma.permission.findFirst.mockResolvedValue(null);
      const result = await findById('permission-123');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.permission.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(findById('permission-123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many permissions', async () => {
      const mockPermissions = [
        { id: 'permission-1', name: 'view_users' },
        { id: 'permission-2', name: 'edit_users' }
      ];
      prisma.permission.findMany.mockResolvedValue(mockPermissions);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockPermissions);
    });
  });

  describe('count', () => {
    it('should count permissions', async () => {
      prisma.permission.count.mockResolvedValue(10);
      const result = await count({});
      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create permission', async () => {
      const mockPermission = { id: 'permission-123', name: 'view_users' };
      prisma.permission.create.mockResolvedValue(mockPermission);

      const result = await create(mockPermission);

      expect(result).toEqual(mockPermission);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.permission.create.mockRejectedValue(error);

      await expect(create({ name: 'duplicate' })).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update permission', async () => {
      const mockPermission = { id: 'permission-123', name: 'updated' };
      prisma.permission.update.mockResolvedValue(mockPermission);

      const result = await update('permission-123', { name: 'updated' });

      expect(result).toEqual(mockPermission);
    });

    it('should throw HttpError when not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.permission.update.mockRejectedValue(error);

      await expect(update('permission-123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete permission', async () => {
      const mockPermission = { id: 'permission-123', deleted_at: new Date() };
      prisma.permission.update.mockResolvedValue(mockPermission);

      const result = await softDelete('permission-123');

      expect(result).toEqual(mockPermission);
    });
  });
});
