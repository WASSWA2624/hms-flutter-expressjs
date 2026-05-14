/**
 * NotificationDelivery repository tests
 *
 * @module tests/modules/notification-delivery/repositories
 * @description Tests for notification-delivery repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const notificationDeliveryRepository = require('@repositories/notification-delivery/notification-delivery.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  notification_delivery: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('NotificationDelivery Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find notification-delivery by id', async () => {
      const mockDelivery = { 
        id: '123', 
        notification_id: 'notif-1',
        channel: 'EMAIL',
        status: 'sent'
      };
      prisma.notification_delivery.findFirst.mockResolvedValue(mockDelivery);

      const result = await notificationDeliveryRepository.findById('123');
      expect(result).toEqual(mockDelivery);
      expect(prisma.notification_delivery.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.notification_delivery.findFirst.mockResolvedValue(null);

      const result = await notificationDeliveryRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.notification_delivery.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(notificationDeliveryRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many notification-deliveries', async () => {
      const mockDeliveries = [
        { id: '1', channel: 'EMAIL' },
        { id: '2', channel: 'SMS' }
      ];
      prisma.notification_delivery.findMany.mockResolvedValue(mockDeliveries);

      const result = await notificationDeliveryRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockDeliveries);
    });
  });

  describe('count', () => {
    it('should count notification-deliveries', async () => {
      prisma.notification_delivery.count.mockResolvedValue(15);

      const result = await notificationDeliveryRepository.count({});
      expect(result).toBe(15);
    });
  });

  describe('create', () => {
    it('should create notification-delivery', async () => {
      const mockData = { notification_id: '123', channel: 'EMAIL' };
      const mockDelivery = { id: '456', ...mockData };
      prisma.notification_delivery.create.mockResolvedValue(mockDelivery);

      const result = await notificationDeliveryRepository.create(mockData);
      expect(result).toEqual(mockDelivery);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'notification_id' };
      prisma.notification_delivery.create.mockRejectedValue(error);

      await expect(notificationDeliveryRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update notification-delivery', async () => {
      const mockDelivery = { id: '123', status: 'delivered' };
      prisma.notification_delivery.update.mockResolvedValue(mockDelivery);

      const result = await notificationDeliveryRepository.update('123', { status: 'delivered' });
      expect(result).toEqual(mockDelivery);
    });

    it('should throw HttpError if not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.notification_delivery.update.mockRejectedValue(error);

      await expect(notificationDeliveryRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete notification-delivery', async () => {
      const mockDelivery = { id: '123', deleted_at: new Date() };
      prisma.notification_delivery.update.mockResolvedValue(mockDelivery);

      const result = await notificationDeliveryRepository.softDelete('123');
      expect(result).toEqual(mockDelivery);
      expect(prisma.notification_delivery.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});
