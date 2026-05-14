/**
 * Data processing log repository tests
 *
 * @module tests/modules/data-processing-log/repositories
 * @description Tests for data processing log repository layer
 */

const dataProcessingLogRepository = require('@modules/data-processing-log/repositories/data-processing-log.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  data_processing_log: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Data Processing Log Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const mockId = '123e4567-e89b-12d3-a456-426614174000';
    const mockLog = {
      id: mockId,
      tenant_id: '123e4567-e89b-12d3-a456-426614174001',
      purpose: 'TREATMENT',
      legal_basis: 'CONSENT',
      processed_at: new Date(),
      deleted_at: null
    };

    it('should find data processing log by ID', async () => {
      prisma.data_processing_log.findFirst.mockResolvedValue(mockLog);
      const result = await dataProcessingLogRepository.findById(mockId);
      expect(result).toEqual(mockLog);
    });

    it('should return null if not found', async () => {
      prisma.data_processing_log.findFirst.mockResolvedValue(null);
      const result = await dataProcessingLogRepository.findById(mockId);
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.data_processing_log.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(dataProcessingLogRepository.findById(mockId)).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    const mockLogs = [{ id: '1', purpose: 'TREATMENT' }, { id: '2', purpose: 'BILLING' }];

    it('should find many data processing logs', async () => {
      prisma.data_processing_log.findMany.mockResolvedValue(mockLogs);
      const result = await dataProcessingLogRepository.findMany();
      expect(result).toEqual(mockLogs);
    });

    it('should apply filters', async () => {
      const filters = { purpose: 'TREATMENT' };
      prisma.data_processing_log.findMany.mockResolvedValue(mockLogs);
      await dataProcessingLogRepository.findMany(filters, 0, 10);
      expect(prisma.data_processing_log.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: expect.objectContaining(filters) })
      );
    });
  });

  describe('count', () => {
    it('should count data processing logs', async () => {
      prisma.data_processing_log.count.mockResolvedValue(50);
      const result = await dataProcessingLogRepository.count();
      expect(result).toBe(50);
    });
  });

  describe('create', () => {
    const mockData = { tenant_id: '123e4567-e89b-12d3-a456-426614174000', purpose: 'TREATMENT', legal_basis: 'CONSENT' };
    const mockCreated = { id: '123e4567-e89b-12d3-a456-426614174003', ...mockData };

    it('should create data processing log', async () => {
      prisma.data_processing_log.create.mockResolvedValue(mockCreated);
      const result = await dataProcessingLogRepository.create(mockData);
      expect(result).toEqual(mockCreated);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const dbError = new Error('Unique constraint');
      dbError.code = 'P2002';
      prisma.data_processing_log.create.mockRejectedValue(dbError);
      await expect(dataProcessingLogRepository.create(mockData)).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    const mockId = '123e4567-e89b-12d3-a456-426614174000';
    const mockData = { purpose: 'OPERATIONS' };
    const mockUpdated = { id: mockId, ...mockData };

    it('should update data processing log', async () => {
      prisma.data_processing_log.update.mockResolvedValue(mockUpdated);
      const result = await dataProcessingLogRepository.update(mockId, mockData);
      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError if not found', async () => {
      const dbError = new Error('Not found');
      dbError.code = 'P2025';
      prisma.data_processing_log.update.mockRejectedValue(dbError);
      await expect(dataProcessingLogRepository.update(mockId, mockData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const mockId = '123e4567-e89b-12d3-a456-426614174000';
    const mockDeleted = { id: mockId, deleted_at: new Date() };

    it('should soft delete data processing log', async () => {
      prisma.data_processing_log.update.mockResolvedValue(mockDeleted);
      const result = await dataProcessingLogRepository.softDelete(mockId);
      expect(result).toEqual(mockDeleted);
    });

    it('should throw HttpError if not found', async () => {
      const dbError = new Error('Not found');
      dbError.code = 'P2025';
      prisma.data_processing_log.update.mockRejectedValue(dbError);
      await expect(dataProcessingLogRepository.softDelete(mockId)).rejects.toThrow(HttpError);
    });
  });
});
