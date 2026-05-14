/**
 * Critical Alert repository tests
 *
 * @module tests/modules/critical-alert/repositories
 * @description Tests for critical alert repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const criticalAlertRepository = require('@repositories/critical-alert/critical-alert.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  critical_alert: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Critical Alert Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find critical alert by id', async () => {
      const mockAlert = { id: '123', icu_stay_id: '456', severity: 'CRITICAL', message: 'Test' };
      prisma.critical_alert.findFirst.mockResolvedValue(mockAlert);

      const result = await criticalAlertRepository.findById('123');
      expect(result).toEqual(mockAlert);
    });

    it('should return null if critical alert not found', async () => {
      prisma.critical_alert.findFirst.mockResolvedValue(null);

      const result = await criticalAlertRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.critical_alert.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(criticalAlertRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many critical alerts with pagination', async () => {
      const mockAlerts = [
        { id: '1', icu_stay_id: '100', severity: 'HIGH', message: 'Test 1' },
        { id: '2', icu_stay_id: '200', severity: 'CRITICAL', message: 'Test 2' }
      ];
      prisma.critical_alert.findMany.mockResolvedValue(mockAlerts);

      const result = await criticalAlertRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockAlerts);
    });

    it('should throw HttpError on database error', async () => {
      prisma.critical_alert.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(criticalAlertRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count critical alerts', async () => {
      prisma.critical_alert.count.mockResolvedValue(42);

      const result = await criticalAlertRepository.count({});
      expect(result).toBe(42);
    });

    it('should throw HttpError on database error', async () => {
      prisma.critical_alert.count.mockRejectedValue(new Error('DB Error'));

      await expect(criticalAlertRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create critical alert', async () => {
      const mockData = { icu_stay_id: '123', severity: 'CRITICAL', message: 'Test' };
      const mockAlert = { id: '456', ...mockData };
      prisma.critical_alert.create.mockResolvedValue(mockAlert);

      const result = await criticalAlertRepository.create(mockData);
      expect(result).toEqual(mockAlert);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'icu_stay_id' };
      prisma.critical_alert.create.mockRejectedValue(error);

      await expect(criticalAlertRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update critical alert', async () => {
      const mockAlert = { id: '123', severity: 'HIGH', message: 'Updated' };
      prisma.critical_alert.update.mockResolvedValue(mockAlert);

      const result = await criticalAlertRepository.update('123', { severity: 'HIGH' });
      expect(result).toEqual(mockAlert);
    });

    it('should throw HttpError if critical alert not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.critical_alert.update.mockRejectedValue(error);

      await expect(criticalAlertRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete critical alert', async () => {
      const mockAlert = { id: '123', deleted_at: new Date() };
      prisma.critical_alert.update.mockResolvedValue(mockAlert);

      const result = await criticalAlertRepository.softDelete('123');
      expect(result).toEqual(mockAlert);
    });

    it('should throw HttpError if critical alert not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.critical_alert.update.mockRejectedValue(error);

      await expect(criticalAlertRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });
  });
});
