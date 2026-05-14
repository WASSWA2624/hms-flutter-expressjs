/**
 * Asset service log repository tests
 *
 * @module tests/modules/asset-service-log/repositories
 * @description Tests for asset service log repository data access layer
 */

const assetServiceLogRepository = require('../../../../modules/asset-service-log/repositories/asset-service-log.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  asset_service_log: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Asset Service Log Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find asset service log by ID', async () => {
      const mockLog = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        asset_id: '123e4567-e89b-12d3-a456-426614174001',
        notes: 'Service completed'
      };

      prisma.asset_service_log.findFirst.mockResolvedValue(mockLog);

      const result = await assetServiceLogRepository.findById(mockLog.id);

      expect(result).toEqual(mockLog);
      expect(prisma.asset_service_log.findFirst).toHaveBeenCalledWith({
        where: { id: mockLog.id, deleted_at: null },
        include: {}
      });
    });

    it('should return null when asset service log not found', async () => {
      prisma.asset_service_log.findFirst.mockResolvedValue(null);

      const result = await assetServiceLogRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.asset_service_log.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(assetServiceLogRepository.findById('some-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple asset service logs with filters', async () => {
      const mockLogs = [
        { id: '1', asset_id: 'asset-1', notes: 'Log 1' },
        { id: '2', asset_id: 'asset-1', notes: 'Log 2' }
      ];

      prisma.asset_service_log.findMany.mockResolvedValue(mockLogs);

      const filters = { asset_id: 'asset-1' };
      const result = await assetServiceLogRepository.findMany(filters, 0, 20);

      expect(result).toEqual(mockLogs);
      expect(prisma.asset_service_log.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.asset_service_log.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(assetServiceLogRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count asset service logs with filters', async () => {
      prisma.asset_service_log.count.mockResolvedValue(5);

      const filters = { asset_id: 'asset-1' };
      const result = await assetServiceLogRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.asset_service_log.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.asset_service_log.count.mockRejectedValue(new Error('DB Error'));

      await expect(assetServiceLogRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new asset service log', async () => {
      const mockData = {
        asset_id: '123e4567-e89b-12d3-a456-426614174000',
        notes: 'New service log'
      };

      const mockCreated = { id: '1', ...mockData };
      prisma.asset_service_log.create.mockResolvedValue(mockCreated);

      const result = await assetServiceLogRepository.create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.asset_service_log.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field_name'] };

      prisma.asset_service_log.create.mockRejectedValue(error);

      await expect(assetServiceLogRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'asset_id' };

      prisma.asset_service_log.create.mockRejectedValue(error);

      await expect(assetServiceLogRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update asset service log', async () => {
      const mockUpdated = {
        id: '1',
        notes: 'Updated notes'
      };

      prisma.asset_service_log.update.mockResolvedValue(mockUpdated);

      const result = await assetServiceLogRepository.update('1', { notes: 'Updated notes' });

      expect(result).toEqual(mockUpdated);
      expect(prisma.asset_service_log.update).toHaveBeenCalledWith({
        where: { id: '1' },
        data: { notes: 'Updated notes' }
      });
    });

    it('should throw HttpError when asset service log not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';

      prisma.asset_service_log.update.mockRejectedValue(error);

      await expect(assetServiceLogRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete asset service log', async () => {
      const mockDeleted = { id: '1', deleted_at: new Date() };
      prisma.asset_service_log.update.mockResolvedValue(mockDeleted);

      const result = await assetServiceLogRepository.softDelete('1');

      expect(result).toEqual(mockDeleted);
      expect(prisma.asset_service_log.update).toHaveBeenCalledWith({
        where: { id: '1' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when asset service log not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';

      prisma.asset_service_log.update.mockRejectedValue(error);

      await expect(assetServiceLogRepository.softDelete('non-existent')).rejects.toThrow(HttpError);
    });
  });
});
