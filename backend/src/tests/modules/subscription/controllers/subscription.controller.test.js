/**
 * Subscription controller tests
 *
 * @module tests/modules/subscription/controllers
 * @description Tests for subscription controller layer
 */

const subscriptionController = require('../../../../modules/subscription/controllers/subscription.controller');
const subscriptionService = require('../../../../modules/subscription/services/subscription.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

jest.mock('../../../../modules/subscription/services/subscription.service');
jest.mock('@lib/response');

describe('Subscription Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    mockReq = {
      params: {},
      query: {},
      body: {},
      user: { id: 'user123' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn()
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getSubscription', () => {
    it('should get subscription by ID', async () => {
      const mockSubscription = { id: '123', tenant_id: '456' };
      mockReq.params.id = '123';
      subscriptionService.getSubscriptionById.mockResolvedValue(mockSubscription);

      await subscriptionController.getSubscription(mockReq, mockRes);

      expect(subscriptionService.getSubscriptionById).toHaveBeenCalledWith(
        '123',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.subscription.retrieved',
        mockSubscription
      );
    });
  });

  describe('listSubscriptions', () => {
    it('should list subscriptions', async () => {
      const mockResult = {
        subscriptions: [{ id: '1' }, { id: '2' }],
        pagination: { page: 1, limit: 20, total: 2, totalPages: 1 }
      };
      mockReq.query = { page: '1', limit: '20' };
      subscriptionService.listSubscriptions.mockResolvedValue(mockResult);

      await subscriptionController.listSubscriptions(mockReq, mockRes);

      expect(subscriptionService.listSubscriptions).toHaveBeenCalledWith(
        {},
        1,
        20,
        'created_at',
        'desc',
        mockReq.user
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.subscription.list_retrieved',
        mockResult.subscriptions,
        mockResult.pagination
      );
    });

    it('should apply filters', async () => {
      const mockResult = {
        subscriptions: [],
        pagination: { page: 1, limit: 20, total: 0, totalPages: 0 }
      };
      mockReq.query = { status: 'ACTIVE', plan_id: '789' };
      subscriptionService.listSubscriptions.mockResolvedValue(mockResult);

      await subscriptionController.listSubscriptions(mockReq, mockRes);

      expect(subscriptionService.listSubscriptions).toHaveBeenCalledWith(
        { status: 'ACTIVE', plan_id: '789' },
        1,
        20,
        'created_at',
        'desc',
        mockReq.user
      );
    });
  });

  describe('createSubscription', () => {
    it('should create subscription', async () => {
      const mockData = { tenant_id: '456', plan_id: '789' };
      const mockCreated = { id: '123', ...mockData };
      mockReq.body = mockData;
      subscriptionService.createSubscription.mockResolvedValue(mockCreated);

      await subscriptionController.createSubscription(mockReq, mockRes);

      expect(subscriptionService.createSubscription).toHaveBeenCalledWith(
        mockData,
        mockReq.user,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.subscription.created',
        mockCreated
      );
    });
  });

  describe('cancelSubscription', () => {
    it('should cancel subscription', async () => {
      const mockCancelled = { id: '123', status: 'CANCELLED' };
      mockReq.params.id = '123';
      subscriptionService.cancelSubscription.mockResolvedValue(mockCancelled);

      await subscriptionController.cancelSubscription(mockReq, mockRes);

      expect(subscriptionService.cancelSubscription).toHaveBeenCalledWith(
        '123',
        mockReq.user,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.subscription.cancelled',
        mockCancelled
      );
    });
  });

  describe('reactivateSubscription', () => {
    it('should reactivate subscription', async () => {
      const mockReactivated = { id: '123', status: 'ACTIVE' };
      mockReq.params.id = '123';
      subscriptionService.reactivateSubscription.mockResolvedValue(mockReactivated);

      await subscriptionController.reactivateSubscription(mockReq, mockRes);

      expect(subscriptionService.reactivateSubscription).toHaveBeenCalledWith(
        '123',
        mockReq.user,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.subscription.reactivated',
        mockReactivated
      );
    });
  });

  describe('updateSubscription', () => {
    it('should update subscription', async () => {
      const mockUpdated = { id: '123', status: 'PAST_DUE' };
      mockReq.params.id = '123';
      mockReq.body = { status: 'PAST_DUE' };
      subscriptionService.updateSubscription.mockResolvedValue(mockUpdated);

      await subscriptionController.updateSubscription(mockReq, mockRes);

      expect(subscriptionService.updateSubscription).toHaveBeenCalledWith(
        '123',
        mockReq.body,
        mockReq.user,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.subscription.updated',
        mockUpdated
      );
    });
  });

  describe('deleteSubscription', () => {
    it('should delete subscription', async () => {
      mockReq.params.id = '123';
      subscriptionService.deleteSubscription.mockResolvedValue({});

      await subscriptionController.deleteSubscription(mockReq, mockRes);

      expect(subscriptionService.deleteSubscription).toHaveBeenCalledWith(
        '123',
        mockReq.user,
        mockReq.ip
      );
      expect(mockRes.status).toHaveBeenCalledWith(204);
      expect(mockRes.send).toHaveBeenCalled();
    });
  });
});
