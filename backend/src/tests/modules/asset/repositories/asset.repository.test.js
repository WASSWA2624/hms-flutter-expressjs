/**
 * Asset repository tests
 *
 * @module tests/modules/asset/repositories
 * @description Tests for asset repository data access layer
 */

const assetRepository = require('../../../../modules/asset/repositories/asset.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  asset: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Asset Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find asset by ID', async () => {
      const mockAsset = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Medical Equipment',
        status: 'OPEN'
      };

      prisma.asset.findFirst.mockResolvedValue(mockAsset);

      const result = await assetRepository.findById(mockAsset.id);

      expect(result).toEqual(mockAsset);
      expect(prisma.asset.findFirst).toHaveBeenCalledWith({
        where: { id: mockAsset.id, deleted_at: null },
        include: {}
      });
    });

    it('should return null when asset not found', async () => {
      prisma.asset.findFirst.mockResolvedValue(null);

      const result = await assetRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.asset.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(assetRepository.findById('some-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple assets with filters', async () => {
      const mockAssets = [
        { id: '1', name: 'Asset 1', status: 'OPEN' },
        { id: '2', name: 'Asset 2', status: 'IN_PROGRESS' }
      ];

      prisma.asset.findMany.mockResolvedValue(mockAssets);

      const filters = { status: 'OPEN' };
      const result = await assetRepository.findMany(filters, 0, 20);

      expect(result).toEqual(mockAssets);
      expect(prisma.asset.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.asset.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(assetRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count assets with filters', async () => {
      prisma.asset.count.mockResolvedValue(15);

      const filters = { status: 'OPEN' };
      const result = await assetRepository.count(filters);

      expect(result).toBe(15);
      expect(prisma.asset.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.asset.count.mockRejectedValue(new Error('DB Error'));

      await expect(assetRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new asset', async () => {
      const mockData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'New Asset',
        status: 'OPEN'
      };

      const mockCreated = { id: '1', ...mockData };
      prisma.asset.create.mockResolvedValue(mockCreated);

      const result = await assetRepository.create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.asset.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['asset_tag'] };

      prisma.asset.create.mockRejectedValue(error);

      await expect(assetRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.asset.create.mockRejectedValue(error);

      await expect(assetRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update asset', async () => {
      const mockUpdated = {
        id: '1',
        name: 'Updated Asset',
        status: 'COMPLETED'
      };

      prisma.asset.update.mockResolvedValue(mockUpdated);

      const result = await assetRepository.update('1', { name: 'Updated Asset' });

      expect(result).toEqual(mockUpdated);
      expect(prisma.asset.update).toHaveBeenCalledWith({
        where: { id: '1' },
        data: { name: 'Updated Asset' }
      });
    });

    it('should throw HttpError when asset not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';

      prisma.asset.update.mockRejectedValue(error);

      await expect(assetRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete asset', async () => {
      const mockDeleted = { id: '1', deleted_at: new Date() };
      prisma.asset.update.mockResolvedValue(mockDeleted);

      const result = await assetRepository.softDelete('1');

      expect(result).toEqual(mockDeleted);
      expect(prisma.asset.update).toHaveBeenCalledWith({
        where: { id: '1' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when asset not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';

      prisma.asset.update.mockRejectedValue(error);

      await expect(assetRepository.softDelete('non-existent')).rejects.toThrow(HttpError);
    });
  });
});
