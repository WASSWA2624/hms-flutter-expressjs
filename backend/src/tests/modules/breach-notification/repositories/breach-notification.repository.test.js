/**
 * Breach notification repository tests
 *
 * @module tests/modules/breach-notification/repositories
 * @description Tests for breach notification repository operations
 * Per testing.mdc: Comprehensive repository tests with mocked Prisma client
 */

const breachNotificationRepository = require('@repositories/breach-notification/breach-notification.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  breach_notification: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Breach Notification Repository', () => {
  const mockBreachNotification = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '550e8400-e29b-41d4-a716-446655440001',
    severity: 'HIGH',
    status: 'OPEN',
    description: 'Security breach detected',
    reported_at: new Date('2024-01-01T10:00:00Z'),
    resolved_at: null,
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find breach notification by ID', async () => {
      prisma.breach_notification.findFirst.mockResolvedValue(mockBreachNotification);

      const result = await breachNotificationRepository.findById(mockBreachNotification.id);

      expect(result).toEqual(mockBreachNotification);
      expect(prisma.breach_notification.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockBreachNotification.id,
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null when breach notification not found', async () => {
      prisma.breach_notification.findFirst.mockResolvedValue(null);

      const result = await breachNotificationRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.breach_notification.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(breachNotificationRepository.findById(mockBreachNotification.id))
        .rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many breach notifications with filters', async () => {
      const mockBreachNotifications = [mockBreachNotification];
      prisma.breach_notification.findMany.mockResolvedValue(mockBreachNotifications);

      const filters = { severity: 'HIGH' };
      const result = await breachNotificationRepository.findMany(filters, 0, 20);

      expect(result).toEqual(mockBreachNotifications);
      expect(prisma.breach_notification.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        },
        skip: 0,
        take: 20,
        orderBy: { reported_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.breach_notification.findMany.mockRejectedValue(new Error('Database error'));

      await expect(breachNotificationRepository.findMany())
        .rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count breach notifications with filters', async () => {
      prisma.breach_notification.count.mockResolvedValue(5);

      const filters = { severity: 'HIGH' };
      const result = await breachNotificationRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.breach_notification.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.breach_notification.count.mockRejectedValue(new Error('Database error'));

      await expect(breachNotificationRepository.count())
        .rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new breach notification', async () => {
      const createData = {
        tenant_id: mockBreachNotification.tenant_id,
        severity: 'HIGH',
        status: 'OPEN',
        description: 'Security breach detected'
      };

      prisma.breach_notification.create.mockResolvedValue(mockBreachNotification);

      const result = await breachNotificationRepository.create(createData);

      expect(result).toEqual(mockBreachNotification);
      expect(prisma.breach_notification.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['email'] };

      prisma.breach_notification.create.mockRejectedValue(error);

      await expect(breachNotificationRepository.create({}))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.breach_notification.create.mockRejectedValue(error);

      await expect(breachNotificationRepository.create({}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a breach notification', async () => {
      const updateData = { status: 'INVESTIGATING' };
      const updatedBreachNotification = { ...mockBreachNotification, ...updateData };

      prisma.breach_notification.update.mockResolvedValue(updatedBreachNotification);

      const result = await breachNotificationRepository.update(mockBreachNotification.id, updateData);

      expect(result).toEqual(updatedBreachNotification);
      expect(prisma.breach_notification.update).toHaveBeenCalledWith({
        where: { id: mockBreachNotification.id },
        data: updateData
      });
    });

    it('should throw HttpError when breach notification not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.breach_notification.update.mockRejectedValue(error);

      await expect(breachNotificationRepository.update('non-existent-id', {}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a breach notification', async () => {
      const deletedBreachNotification = { ...mockBreachNotification, deleted_at: new Date() };

      prisma.breach_notification.update.mockResolvedValue(deletedBreachNotification);

      const result = await breachNotificationRepository.softDelete(mockBreachNotification.id);

      expect(result).toEqual(deletedBreachNotification);
      expect(prisma.breach_notification.update).toHaveBeenCalledWith({
        where: { id: mockBreachNotification.id },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when breach notification not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.breach_notification.update.mockRejectedValue(error);

      await expect(breachNotificationRepository.softDelete('non-existent-id'))
        .rejects.toThrow(HttpError);
    });
  });
});
