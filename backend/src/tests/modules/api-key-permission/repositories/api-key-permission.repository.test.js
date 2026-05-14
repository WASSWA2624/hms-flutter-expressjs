/**
 * API Key Permission repository tests
 *
 * @module tests/modules/api-key-permission/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  api_key_permission: {
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
} = require('@repositories/api-key-permission/api-key-permission.repository');

const prisma = require('@prisma/client');

describe('API Key Permission Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find API key permission by ID', async () => {
      const mockApiKeyPermission = {
        id: 'akp-123',
        api_key_id: 'api-key-123',
        permission_id: 'perm-123',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.api_key_permission.findFirst.mockResolvedValue(mockApiKeyPermission);

      const result = await findById('akp-123');

      expect(result).toEqual(mockApiKeyPermission);
      expect(prisma.api_key_permission.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'akp-123',
          deleted_at: null
        }
      });
    });

    it('should return null if API key permission not found', async () => {
      prisma.api_key_permission.findFirst.mockResolvedValue(null);

      const result = await findById('akp-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.api_key_permission.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('akp-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many API key permissions with default pagination', async () => {
      const mockApiKeyPermissions = [
        {
          id: 'akp-1',
          api_key_id: 'api-key-123',
          permission_id: 'perm-1'
        },
        {
          id: 'akp-2',
          api_key_id: 'api-key-123',
          permission_id: 'perm-2'
        }
      ];
      prisma.api_key_permission.findMany.mockResolvedValue(mockApiKeyPermissions);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockApiKeyPermissions);
      expect(prisma.api_key_permission.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find many API key permissions with filters', async () => {
      const mockApiKeyPermissions = [
        {
          id: 'akp-1',
          api_key_id: 'api-key-123',
          permission_id: 'perm-123'
        }
      ];
      prisma.api_key_permission.findMany.mockResolvedValue(mockApiKeyPermissions);

      const filters = {
        api_key_id: 'api-key-123',
        permission_id: 'perm-123'
      };
      const result = await findMany(filters, 0, 20);

      expect(result).toEqual(mockApiKeyPermissions);
      expect(prisma.api_key_permission.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.api_key_permission.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count all API key permissions', async () => {
      prisma.api_key_permission.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
      expect(prisma.api_key_permission.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count API key permissions with filters', async () => {
      prisma.api_key_permission.count.mockResolvedValue(5);

      const filters = {
        api_key_id: 'api-key-123'
      };
      const result = await count(filters);

      expect(result).toBe(5);
      expect(prisma.api_key_permission.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.api_key_permission.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create API key permission', async () => {
      const newApiKeyPermission = {
        api_key_id: 'api-key-123',
        permission_id: 'perm-123'
      };
      const createdApiKeyPermission = {
        id: 'akp-123',
        ...newApiKeyPermission,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.api_key_permission.create.mockResolvedValue(createdApiKeyPermission);

      const result = await create(newApiKeyPermission);

      expect(result).toEqual(createdApiKeyPermission);
      expect(prisma.api_key_permission.create).toHaveBeenCalledWith({
        data: newApiKeyPermission
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['api_key_id', 'permission_id'] };
      prisma.api_key_permission.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'api_key_id' };
      prisma.api_key_permission.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.api_key_permission.create.mockRejectedValue(new Error('DB error'));

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update API key permission', async () => {
      const updateData = {
        permission_id: 'perm-456'
      };
      const updatedApiKeyPermission = {
        id: 'akp-123',
        api_key_id: 'api-key-123',
        ...updateData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };
      prisma.api_key_permission.update.mockResolvedValue(updatedApiKeyPermission);

      const result = await update('akp-123', updateData);

      expect(result).toEqual(updatedApiKeyPermission);
      expect(prisma.api_key_permission.update).toHaveBeenCalledWith({
        where: { id: 'akp-123' },
        data: updateData
      });
    });

    it('should throw HttpError when API key permission not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.api_key_permission.update.mockRejectedValue(error);

      await expect(update('akp-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.api_key_permission.update.mockRejectedValue(new Error('DB error'));

      await expect(update('akp-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete API key permission', async () => {
      const deletedApiKeyPermission = {
        id: 'akp-123',
        api_key_id: 'api-key-123',
        permission_id: 'perm-123',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: new Date('2026-01-19'),
        version: 1
      };
      prisma.api_key_permission.update.mockResolvedValue(deletedApiKeyPermission);

      const result = await softDelete('akp-123');

      expect(result).toEqual(deletedApiKeyPermission);
      expect(prisma.api_key_permission.update).toHaveBeenCalledWith({
        where: { id: 'akp-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when API key permission not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.api_key_permission.update.mockRejectedValue(error);

      await expect(softDelete('akp-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.api_key_permission.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('akp-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
