/**
 * Notification repository tests
 *
 * @module tests/modules/notification/repositories
 * @description Tests for notification repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const notificationRepository = require('@repositories/notification/notification.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  notification: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Notification Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find notification by id', async () => {
      const mockNotification = { 
        id: '123', 
        tenant_id: 'tenant-1',
        notification_type: 'SYSTEM',
        priority: 'MEDIUM',
        title: 'Test',
        message: 'Test message'
      };
      prisma.notification.findFirst.mockResolvedValue(mockNotification);

      const result = await notificationRepository.findById('123');
      expect(result).toEqual(mockNotification);
      expect(prisma.notification.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if notification not found', async () => {
      prisma.notification.findFirst.mockResolvedValue(null);

      const result = await notificationRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.notification.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(notificationRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many notifications with pagination', async () => {
      const mockNotifications = [
        { id: '1', title: 'Test 1', message: 'Message 1' },
        { id: '2', title: 'Test 2', message: 'Message 2' }
      ];
      prisma.notification.findMany.mockResolvedValue(mockNotifications);

      const result = await notificationRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockNotifications);
      expect(prisma.notification.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { tenant_id: 'tenant-1', priority: 'HIGH' };
      prisma.notification.findMany.mockResolvedValue([]);

      await notificationRepository.findMany(filters, 0, 20);
      expect(prisma.notification.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.notification.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(notificationRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count notifications', async () => {
      prisma.notification.count.mockResolvedValue(42);

      const result = await notificationRepository.count({});
      expect(result).toBe(42);
    });

    it('should count with filters', async () => {
      const filters = { priority: 'URGENT' };
      prisma.notification.count.mockResolvedValue(5);

      const result = await notificationRepository.count(filters);
      expect(result).toBe(5);
      expect(prisma.notification.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.notification.count.mockRejectedValue(new Error('DB Error'));

      await expect(notificationRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create notification', async () => {
      const mockData = { 
        tenant_id: '123', 
        notification_type: 'APPOINTMENT',
        priority: 'HIGH',
        title: 'Test',
        message: 'Test message'
      };
      const mockNotification = { id: '456', ...mockData };
      prisma.notification.create.mockResolvedValue(mockNotification);

      const result = await notificationRepository.create(mockData);
      expect(result).toEqual(mockNotification);
      expect(prisma.notification.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.notification.create.mockRejectedValue(error);

      await expect(notificationRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.notification.create.mockRejectedValue(error);

      await expect(notificationRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.notification.create.mockRejectedValue(new Error('Unexpected error'));

      await expect(notificationRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update notification', async () => {
      const mockNotification = { id: '123', title: 'Updated Title' };
      prisma.notification.update.mockResolvedValue(mockNotification);

      const result = await notificationRepository.update('123', { title: 'Updated Title' });
      expect(result).toEqual(mockNotification);
      expect(prisma.notification.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { title: 'Updated Title' }
      });
    });

    it('should throw HttpError if notification not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.notification.update.mockRejectedValue(error);

      await expect(notificationRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
      await expect(notificationRepository.update('nonexistent', {})).rejects.toThrow('errors.notification.not_found');
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.notification.update.mockRejectedValue(error);

      await expect(notificationRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'user_id' };
      prisma.notification.update.mockRejectedValue(error);

      await expect(notificationRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete notification', async () => {
      const mockNotification = { id: '123', deleted_at: new Date() };
      prisma.notification.update.mockResolvedValue(mockNotification);

      const result = await notificationRepository.softDelete('123');
      expect(result).toEqual(mockNotification);
      expect(prisma.notification.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if notification not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.notification.update.mockRejectedValue(error);

      await expect(notificationRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
      await expect(notificationRepository.softDelete('nonexistent')).rejects.toThrow('errors.notification.not_found');
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.notification.update.mockRejectedValue(new Error('Unexpected error'));

      await expect(notificationRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
