/**
 * Integration log repository tests
 *
 * @module tests/modules/integration-log/repositories
 * @description Tests for integration log repository functions
 */

const integrationLogRepository = require('@repositories/integration-log/integration-log.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  integration_log: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn()
  }
}));

describe('Integration Log Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find integration log by ID', async () => {
      const mockIntegrationLog = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        integration_id: 'integration-123',
        status: 'ACTIVE',
        message: 'Test log message'
      };

      prisma.integration_log.findFirst.mockResolvedValue(mockIntegrationLog);

      const result = await integrationLogRepository.findById(mockIntegrationLog.id);

      expect(result).toEqual(mockIntegrationLog);
      expect(prisma.integration_log.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockIntegrationLog.id,
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if integration log not found', async () => {
      prisma.integration_log.findFirst.mockResolvedValue(null);

      const result = await integrationLogRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.integration_log.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(integrationLogRepository.findById('some-id'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many integration logs with filters', async () => {
      const mockIntegrationLogs = [
        { id: '1', integration_id: 'int-1', status: 'ACTIVE', message: 'Log 1' },
        { id: '2', integration_id: 'int-2', status: 'ERROR', message: 'Log 2' }
      ];

      prisma.integration_log.findMany.mockResolvedValue(mockIntegrationLogs);

      const filters = { integration_id: 'int-1' };
      const result = await integrationLogRepository.findMany(filters, 0, 20);

      expect(result).toEqual(mockIntegrationLogs);
      expect(prisma.integration_log.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        },
        skip: 0,
        take: 20,
        orderBy: { logged_at: 'desc' },
        include: {}
      });
    });

    it('should use custom orderBy', async () => {
      prisma.integration_log.findMany.mockResolvedValue([]);

      const orderBy = { created_at: 'asc' };
      await integrationLogRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.integration_log.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.integration_log.findMany.mockRejectedValue(new Error('Database error'));

      await expect(integrationLogRepository.findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count integration logs with filters', async () => {
      prisma.integration_log.count.mockResolvedValue(15);

      const filters = { status: 'ACTIVE' };
      const result = await integrationLogRepository.count(filters);

      expect(result).toBe(15);
      expect(prisma.integration_log.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        }
      });
    });

    it('should count all logs when no filters provided', async () => {
      prisma.integration_log.count.mockResolvedValue(100);

      const result = await integrationLogRepository.count();

      expect(result).toBe(100);
      expect(prisma.integration_log.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.integration_log.count.mockRejectedValue(new Error('Database error'));

      await expect(integrationLogRepository.count())
        .rejects
        .toThrow(HttpError);
    });
  });
});
