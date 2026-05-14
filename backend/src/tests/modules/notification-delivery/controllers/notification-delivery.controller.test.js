/**
 * NotificationDelivery controller tests
 *
 * @module tests/modules/notification-delivery/controllers
 * @description Tests for notification-delivery controller operations
 * Per testing.mdc: Controller tests must mock services
 */

const notificationDeliveryController = require('@controllers/notification-delivery/notification-delivery.controller');
const notificationDeliveryService = require('@services/notification-delivery/notification-delivery.service');

// Mock service
jest.mock('@services/notification-delivery/notification-delivery.service');

// Mock response helpers
jest.mock('@lib/response', () => ({
  sendSuccess: jest.fn((res, status, message, data) => res.status(status).json({ message, data })),
  sendPaginated: jest.fn((res, message, data, pagination) => res.status(200).json({ message, data, pagination })),
  sendNoContent: jest.fn((res) => res.status(204).send())
}));

const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

describe('NotificationDelivery Controller', () => {
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

  describe('listNotificationDeliveries', () => {
    it('should list deliveries with default pagination', async () => {
      const mockResult = {
        notificationDeliveries: [{ id: '1' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      notificationDeliveryService.listNotificationDeliveries.mockResolvedValue(mockResult);

      await notificationDeliveryController.listNotificationDeliveries(req, res);

      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.notification_delivery.list.success',
        mockResult.notificationDeliveries,
        mockResult.pagination
      );
    });
  });

  describe('getNotificationDeliveryById', () => {
    it('should get delivery by id', async () => {
      const mockDelivery = { id: '123', channel: 'EMAIL' };
      req.params.id = '123';
      notificationDeliveryService.getNotificationDeliveryById.mockResolvedValue(mockDelivery);

      await notificationDeliveryController.getNotificationDeliveryById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.notification_delivery.get.success', mockDelivery);
    });
  });

  describe('createNotificationDelivery', () => {
    it('should create delivery', async () => {
      const mockData = { notification_id: '123', channel: 'EMAIL' };
      const mockDelivery = { id: '456', ...mockData };
      req.body = mockData;
      notificationDeliveryService.createNotificationDelivery.mockResolvedValue(mockDelivery);

      await notificationDeliveryController.createNotificationDelivery(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(res, 201, 'messages.notification_delivery.create.success', mockDelivery);
    });
  });

  describe('updateNotificationDelivery', () => {
    it('should update delivery', async () => {
      const mockDelivery = { id: '123', status: 'sent' };
      req.params.id = '123';
      req.body = { status: 'sent' };
      notificationDeliveryService.updateNotificationDelivery.mockResolvedValue(mockDelivery);

      await notificationDeliveryController.updateNotificationDelivery(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.notification_delivery.update.success', mockDelivery);
    });
  });

  describe('deleteNotificationDelivery', () => {
    it('should delete delivery', async () => {
      req.params.id = '123';
      notificationDeliveryService.deleteNotificationDelivery.mockResolvedValue();

      await notificationDeliveryController.deleteNotificationDelivery(req, res);

      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
