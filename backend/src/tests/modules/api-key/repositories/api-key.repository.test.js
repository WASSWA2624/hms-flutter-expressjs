/**
 * API Key repository tests
 *
 * @module tests/modules/api-key/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  api_key: {
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
} = require('@repositories/api-key/api-key.repository');

const prisma = require('@prisma/client');

describe('API Key Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find API key by ID', async () => {
      const mockApiKey = {
        id: 'api-key-123',
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        name: 'Production API Key',
        key_hash: 'hashed-key',
        is_active: true,
        last_used_at: null,
        expires_at: new Date('2027-12-31'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.api_key.findFirst.mockResolvedValue(mockApiKey);

      const result = await findById('api-key-123');

      expect(result).toEqual(mockApiKey);
      expect(prisma.api_key.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'api-key-123',
          deleted_at: null
        }
      });
    });

    it('should return null if API key not found', async () => {
      prisma.api_key.findFirst.mockResolvedValue(null);

      const result = await findById('api-key-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.api_key.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('api-key-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many API keys with default pagination', async () => {
      const mockApiKeys = [
        {
          id: 'api-key-1',
          tenant_id: 'tenant-123',
          user_id: 'user-123',
          name: 'Production API Key',
          key_hash: 'hashed-key-1',
          is_active: true,
          last_used_at: null,
          expires_at: new Date('2027-12-31')
        },
        {
          id: 'api-key-2',
          tenant_id: 'tenant-123',
          user_id: 'user-456',
          name: 'Development API Key',
          key_hash: 'hashed-key-2',
          is_active: true,
          last_used_at: null,
          expires_at: new Date('2027-06-30')
        }
      ];
      prisma.api_key.findMany.mockResolvedValue(mockApiKeys);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockApiKeys);
      expect(prisma.api_key.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find many API keys with filters', async () => {
      const mockApiKeys = [
        {
          id: 'api-key-1',
          tenant_id: 'tenant-123',
          user_id: 'user-123',
          name: 'Production API Key',
          key_hash: 'hashed-key-1',
          is_active: true
        }
      ];
      prisma.api_key.findMany.mockResolvedValue(mockApiKeys);

      const filters = {
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        is_active: true
      };
      const result = await findMany(filters, 0, 20);

      expect(result).toEqual(mockApiKeys);
      expect(prisma.api_key.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find many API keys with custom pagination', async () => {
      const mockApiKeys = [];
      prisma.api_key.findMany.mockResolvedValue(mockApiKeys);

      await findMany({}, 20, 10);

      expect(prisma.api_key.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find many API keys with custom ordering', async () => {
      const mockApiKeys = [];
      prisma.api_key.findMany.mockResolvedValue(mockApiKeys);

      await findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.api_key.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.api_key.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count all API keys', async () => {
      prisma.api_key.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
      expect(prisma.api_key.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count API keys with filters', async () => {
      prisma.api_key.count.mockResolvedValue(5);

      const filters = {
        tenant_id: 'tenant-123',
        is_active: true
      };
      const result = await count(filters);

      expect(result).toBe(5);
      expect(prisma.api_key.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.api_key.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create API key', async () => {
      const newApiKey = {
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        name: 'New API Key',
        key_hash: 'hashed-key',
        is_active: true,
        expires_at: new Date('2027-12-31')
      };
      const createdApiKey = {
        id: 'api-key-123',
        ...newApiKey,
        last_used_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.api_key.create.mockResolvedValue(createdApiKey);

      const result = await create(newApiKey);

      expect(result).toEqual(createdApiKey);
      expect(prisma.api_key.create).toHaveBeenCalledWith({
        data: newApiKey
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.api_key.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.api_key.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.api_key.create.mockRejectedValue(new Error('DB error'));

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update API key', async () => {
      const updateData = {
        name: 'Updated API Key',
        is_active: false
      };
      const updatedApiKey = {
        id: 'api-key-123',
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        ...updateData,
        key_hash: 'hashed-key',
        last_used_at: null,
        expires_at: new Date('2027-12-31'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };
      prisma.api_key.update.mockResolvedValue(updatedApiKey);

      const result = await update('api-key-123', updateData);

      expect(result).toEqual(updatedApiKey);
      expect(prisma.api_key.update).toHaveBeenCalledWith({
        where: { id: 'api-key-123' },
        data: updateData
      });
    });

    it('should throw HttpError when API key not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.api_key.update.mockRejectedValue(error);

      await expect(update('api-key-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.api_key.update.mockRejectedValue(error);

      await expect(update('api-key-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'user_id' };
      prisma.api_key.update.mockRejectedValue(error);

      await expect(update('api-key-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.api_key.update.mockRejectedValue(new Error('DB error'));

      await expect(update('api-key-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete API key', async () => {
      const deletedApiKey = {
        id: 'api-key-123',
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        name: 'Deleted API Key',
        key_hash: 'hashed-key',
        is_active: true,
        last_used_at: null,
        expires_at: new Date('2027-12-31'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: new Date('2026-01-19'),
        version: 1
      };
      prisma.api_key.update.mockResolvedValue(deletedApiKey);

      const result = await softDelete('api-key-123');

      expect(result).toEqual(deletedApiKey);
      expect(prisma.api_key.update).toHaveBeenCalledWith({
        where: { id: 'api-key-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when API key not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.api_key.update.mockRejectedValue(error);

      await expect(softDelete('api-key-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.api_key.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('api-key-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
