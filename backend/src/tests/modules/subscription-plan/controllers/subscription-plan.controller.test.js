/**
 * Subscription Plan controller tests
 *
 * @module tests/modules/subscription-plan/controllers
 * @description Tests for subscription plan controller layer
 */

const subscriptionPlanController = require('../../../../modules/subscription-plan/controllers/subscription-plan.controller');
const subscriptionPlanService = require('../../../../modules/subscription-plan/services/subscription-plan.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

jest.mock('../../../../modules/subscription-plan/services/subscription-plan.service');
jest.mock('@lib/response');

describe('Subscription Plan Controller', () => {
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

  describe('getSubscriptionPlan', () => {
    it('should get subscription plan by ID', async () => {
      const mockPlan = { id: '123', name: 'Basic Plan' };
      mockReq.params.id = '123';
      subscriptionPlanService.getSubscriptionPlanById.mockResolvedValue(mockPlan);

      await subscriptionPlanController.getSubscriptionPlan(mockReq, mockRes);

      expect(subscriptionPlanService.getSubscriptionPlanById).toHaveBeenCalledWith(
        '123',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.subscription_plan.retrieved',
        mockPlan
      );
    });
  });

  describe('listSubscriptionPlans', () => {
    it('should list subscription plans', async () => {
      const mockResult = {
        subscriptionPlans: [{ id: '1' }, { id: '2' }],
        pagination: { page: 1, limit: 20, total: 2, totalPages: 1 }
      };
      mockReq.query = { page: '1', limit: '20' };
      subscriptionPlanService.listSubscriptionPlans.mockResolvedValue(mockResult);

      await subscriptionPlanController.listSubscriptionPlans(mockReq, mockRes);

      expect(subscriptionPlanService.listSubscriptionPlans).toHaveBeenCalledWith(
        {},
        1,
        20,
        'created_at',
        'desc',
        mockReq.user
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.subscription_plan.list_retrieved',
        mockResult.subscriptionPlans,
        mockResult.pagination
      );
    });

    it('should apply filters', async () => {
      const mockResult = {
        subscriptionPlans: [],
        pagination: { page: 1, limit: 20, total: 0, totalPages: 0 }
      };
      mockReq.query = { billing_cycle: 'MONTHLY', search: 'basic' };
      subscriptionPlanService.listSubscriptionPlans.mockResolvedValue(mockResult);

      await subscriptionPlanController.listSubscriptionPlans(mockReq, mockRes);

      expect(subscriptionPlanService.listSubscriptionPlans).toHaveBeenCalledWith(
        { billing_cycle: 'MONTHLY', search: 'basic' },
        1,
        20,
        'created_at',
        'desc',
        mockReq.user
      );
    });
  });

  describe('createSubscriptionPlan', () => {
    it('should create subscription plan', async () => {
      const mockData = { name: 'Basic Plan', price: 99.99, billing_cycle: 'MONTHLY' };
      const mockCreated = { id: '123', ...mockData };
      mockReq.body = mockData;
      subscriptionPlanService.createSubscriptionPlan.mockResolvedValue(mockCreated);

      await subscriptionPlanController.createSubscriptionPlan(mockReq, mockRes);

      expect(subscriptionPlanService.createSubscriptionPlan).toHaveBeenCalledWith(
        mockData,
        mockReq.user,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.subscription_plan.created',
        mockCreated
      );
    });
  });

  describe('updateSubscriptionPlan', () => {
    it('should update subscription plan', async () => {
      const mockUpdated = { id: '123', name: 'Updated Plan' };
      mockReq.params.id = '123';
      mockReq.body = { name: 'Updated Plan' };
      subscriptionPlanService.updateSubscriptionPlan.mockResolvedValue(mockUpdated);

      await subscriptionPlanController.updateSubscriptionPlan(mockReq, mockRes);

      expect(subscriptionPlanService.updateSubscriptionPlan).toHaveBeenCalledWith(
        '123',
        mockReq.body,
        mockReq.user,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.subscription_plan.updated',
        mockUpdated
      );
    });
  });

  describe('deleteSubscriptionPlan', () => {
    it('should delete subscription plan', async () => {
      mockReq.params.id = '123';
      subscriptionPlanService.deleteSubscriptionPlan.mockResolvedValue({});

      await subscriptionPlanController.deleteSubscriptionPlan(mockReq, mockRes);

      expect(subscriptionPlanService.deleteSubscriptionPlan).toHaveBeenCalledWith(
        '123',
        mockReq.user,
        mockReq.ip
      );
      expect(mockRes.status).toHaveBeenCalledWith(204);
      expect(mockRes.send).toHaveBeenCalled();
    });
  });
});
