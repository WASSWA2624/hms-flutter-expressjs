/**
 * System change log repository tests
 *
 * @module tests/modules/system-change-log/repositories
 * @description Tests for system change log repository operations
 * Per testing.mdc: Comprehensive repository tests with mocked Prisma client
 */

const systemChangeLogRepository = require('@repositories/system-change-log/system-change-log.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  system_change_log: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('System Change Log Repository', () => {
  const mockSystemChangeLog = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '550e8400-e29b-41d4-a716-446655440001',
    user_id: '550e8400-e29b-41d4-a716-446655440002',
    change_type: 'DATABASE_MIGRATION',
    details: 'Added new column to users table',
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find system change log by ID', async () => {
      prisma.system_change_log.findFirst.mockResolvedValue(mockSystemChangeLog);

      const result = await systemChangeLogRepository.findById(mockSystemChangeLog.id);

      expect(result).toEqual(mockSystemChangeLog);
      expect(prisma.system_change_log.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockSystemChangeLog.id,
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null when system change log not found', async () => {
      prisma.system_change_log.findFirst.mockResolvedValue(null);

      const result = await systemChangeLogRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.system_change_log.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(systemChangeLogRepository.findById(mockSystemChangeLog.id))
        .rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many system change logs with filters', async () => {
      const mockSystemChangeLogs = [mockSystemChangeLog];
      prisma.system_change_log.findMany.mockResolvedValue(mockSystemChangeLogs);

      const filters = { change_type: 'DATABASE_MIGRATION' };
      const result = await systemChangeLogRepository.findMany(filters, 0, 20);

      expect(result).toEqual(mockSystemChangeLogs);
      expect(prisma.system_change_log.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.system_change_log.findMany.mockRejectedValue(new Error('Database error'));

      await expect(systemChangeLogRepository.findMany())
        .rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count system change logs with filters', async () => {
      prisma.system_change_log.count.mockResolvedValue(5);

      const filters = { change_type: 'DATABASE_MIGRATION' };
      const result = await systemChangeLogRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.system_change_log.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.system_change_log.count.mockRejectedValue(new Error('Database error'));

      await expect(systemChangeLogRepository.count())
        .rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new system change log', async () => {
      const createData = {
        tenant_id: mockSystemChangeLog.tenant_id,
        user_id: mockSystemChangeLog.user_id,
        change_type: 'DATABASE_MIGRATION',
        details: 'Added new column to users table'
      };

      prisma.system_change_log.create.mockResolvedValue(mockSystemChangeLog);

      const result = await systemChangeLogRepository.create(createData);

      expect(result).toEqual(mockSystemChangeLog);
      expect(prisma.system_change_log.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['email'] };

      prisma.system_change_log.create.mockRejectedValue(error);

      await expect(systemChangeLogRepository.create({}))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.system_change_log.create.mockRejectedValue(error);

      await expect(systemChangeLogRepository.create({}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a system change log', async () => {
      const updateData = { change_type: 'CONFIG_UPDATE' };
      const updatedSystemChangeLog = { ...mockSystemChangeLog, ...updateData };

      prisma.system_change_log.update.mockResolvedValue(updatedSystemChangeLog);

      const result = await systemChangeLogRepository.update(mockSystemChangeLog.id, updateData);

      expect(result).toEqual(updatedSystemChangeLog);
      expect(prisma.system_change_log.update).toHaveBeenCalledWith({
        where: { id: mockSystemChangeLog.id },
        data: updateData
      });
    });

    it('should throw HttpError when system change log not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.system_change_log.update.mockRejectedValue(error);

      await expect(systemChangeLogRepository.update('non-existent-id', {}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a system change log', async () => {
      const deletedSystemChangeLog = { ...mockSystemChangeLog, deleted_at: new Date() };

      prisma.system_change_log.update.mockResolvedValue(deletedSystemChangeLog);

      const result = await systemChangeLogRepository.softDelete(mockSystemChangeLog.id);

      expect(result).toEqual(deletedSystemChangeLog);
      expect(prisma.system_change_log.update).toHaveBeenCalledWith({
        where: { id: mockSystemChangeLog.id },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when system change log not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.system_change_log.update.mockRejectedValue(error);

      await expect(systemChangeLogRepository.softDelete('non-existent-id'))
        .rejects.toThrow(HttpError);
    });
  });
});
