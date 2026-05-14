/**
 * Notification controller tests
 *
 * @module tests/modules/notification/controllers
 * @description Tests for notification controller operations
 * Per testing.mdc: Controller tests must mock services
 */

const notificationController = require('@controllers/notification/notification.controller');
const notificationService = require('@services/notification/notification.service');

// Mock service
jest.mock('@services/notification/notification.service');

// Mock response helpers
jest.mock('@lib/response', () => ({
  sendSuccess: jest.fn((res, status, message, data) => res.status(status).json({ message, data })),
  sendPaginated: jest.fn((res, message, data, pagination) => res.status(200).json({ message, data, pagination })),
  sendNoContent: jest.fn((res) => res.status(204).send())
}));

const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

describe('Notification Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listNotifications', () => {
    it('should list notifications with default pagination', async () => {
      const mockResult = {
        notifications: [{ id: '1' }, { id: '2' }],
        pagination: { page: 1, limit: 20, total: 2, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      notificationService.listNotifications.mockResolvedValue(mockResult);

      await notificationController.listNotifications(req, res);

      expect(notificationService.listNotifications).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'desc',
        req.user
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.notification.list.success',
        mockResult.notifications,
        mockResult.pagination
      );
    });

    it('should apply query filters', async () => {
      req.query = {
        tenant_id: 'tenant-1',
        priority: 'HIGH',
        page: '2',
        limit: '10',
        sort_by: 'created_at',
        order: 'asc'
      };
      const mockResult = {
        notifications: [],
        pagination: { page: 2, limit: 10, total: 0, totalPages: 0, hasNextPage: false, hasPreviousPage: true }
      };
      notificationService.listNotifications.mockResolvedValue(mockResult);

      await notificationController.listNotifications(req, res);

      expect(notificationService.listNotifications).toHaveBeenCalledWith(
        expect.objectContaining({ tenant_id: 'tenant-1', priority: 'HIGH' }),
        2,
        10,
        'created_at',
        'asc',
        req.user
      );
    });
  });

  describe('getNotificationHub', () => {
    it('should load notification hub payload', async () => {
      const mockHub = {
        summary: { total: 2, unread: 1 },
        timeline: [{ id: 'NTF-001' }],
        pagination: { page: 1, limit: 20, total: 2 },
      };
      notificationService.getNotificationHub.mockResolvedValue(mockHub);

      await notificationController.getNotificationHub(req, res);

      expect(notificationService.getNotificationHub).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'desc',
        req.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.notification.hub.success',
        mockHub
      );
    });
  });

  describe('getNotificationMetrics', () => {
    it('should load notification metrics', async () => {
      const metrics = { total: 10, unread: 3 };
      notificationService.getNotificationMetrics.mockResolvedValue(metrics);

      await notificationController.getNotificationMetrics(req, res);

      expect(notificationService.getNotificationMetrics).toHaveBeenCalledWith(req.query, req.user);
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.notification.metrics.success',
        metrics
      );
    });
  });

  describe('getNotificationById', () => {
    it('should get notification by id', async () => {
      const mockNotification = { id: '123', title: 'Test' };
      req.params.id = '123';
      notificationService.getNotificationById.mockResolvedValue(mockNotification);

      await notificationController.getNotificationById(req, res);

      expect(notificationService.getNotificationById).toHaveBeenCalledWith('123', req.user);
      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.notification.get.success', mockNotification);
    });
  });

  describe('createNotification', () => {
    it('should create notification', async () => {
      const mockData = { title: 'Test', message: 'Test message' };
      const mockNotification = { id: '123', ...mockData };
      req.body = mockData;
      notificationService.createNotification.mockResolvedValue(mockNotification);

      await notificationController.createNotification(req, res);

      expect(notificationService.createNotification).toHaveBeenCalledWith(mockData, req.user, '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(res, 201, 'messages.notification.create.success', mockNotification);
    });
  });

  describe('updateNotification', () => {
    it('should update notification', async () => {
      const mockData = { title: 'Updated Title' };
      const mockNotification = { id: '123', ...mockData };
      req.params.id = '123';
      req.body = mockData;
      notificationService.updateNotification.mockResolvedValue(mockNotification);

      await notificationController.updateNotification(req, res);

      expect(notificationService.updateNotification).toHaveBeenCalledWith('123', mockData, req.user, '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.notification.update.success', mockNotification);
    });
  });

  describe('deleteNotification', () => {
    it('should delete notification', async () => {
      req.params.id = '123';
      notificationService.deleteNotification.mockResolvedValue();

      await notificationController.deleteNotification(req, res);

      expect(notificationService.deleteNotification).toHaveBeenCalledWith('123', req.user, '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });

  describe('bulk notification mutations', () => {
    it('marks notifications as read in bulk', async () => {
      const result = { processed_count: 2, affected_count: 2 };
      req.body = { ids: ['NTF-001', 'NTF-002'] };
      notificationService.bulkUpdateReadState.mockResolvedValue(result);

      await notificationController.bulkMarkNotificationsRead(req, res);

      expect(notificationService.bulkUpdateReadState).toHaveBeenCalledWith(
        req.body.ids,
        true,
        req.user,
        req.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.notification.bulk_mark_read.success',
        result
      );
    });

    it('marks notifications as unread in bulk', async () => {
      const result = { processed_count: 1, affected_count: 1 };
      req.body = { ids: ['NTF-001'] };
      notificationService.bulkUpdateReadState.mockResolvedValue(result);

      await notificationController.bulkMarkNotificationsUnread(req, res);

      expect(notificationService.bulkUpdateReadState).toHaveBeenCalledWith(
        req.body.ids,
        false,
        req.user,
        req.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.notification.bulk_mark_unread.success',
        result
      );
    });
  });
});
