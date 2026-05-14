/**
 * Module subscription controller tests
 *
 * @module tests/modules/module-subscription/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/module-subscription/module-subscription.service');
jest.mock('@lib/response');
jest.mock('@lib/i18n');

const moduleSubscriptionService = require('@services/module-subscription/module-subscription.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { getLocale } = require('@lib/i18n');
const {
  listModuleSubscriptions,
  getModuleSubscriptionById,
  createModuleSubscription,
  updateModuleSubscription,
  deleteModuleSubscription
} = require('@controllers/module-subscription/module-subscription.controller');

describe('Module Subscription Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    getLocale.mockReturnValue('en');
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '192.168.1.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listModuleSubscriptions', () => {
    it('should list module subscriptions with pagination', async () => {
      const mockResult = {
        module_subscriptions: [
          { id: 'sub-1', module_id: 'module-1' },
          { id: 'sub-2', module_id: 'module-2' }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      moduleSubscriptionService.listModuleSubscriptions.mockResolvedValue(mockResult);

      req.query = { page: 1, limit: 20 };

      await listModuleSubscriptions(req, res);

      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.module_subscription.list.success',
        mockResult.module_subscriptions,
        mockResult.pagination,
        'en'
      );
    });
  });

  describe('getModuleSubscriptionById', () => {
    it('should get module subscription by ID', async () => {
      const mockSubscription = {
        id: 'sub-123',
        module_id: 'module-123'
      };
      moduleSubscriptionService.getModuleSubscriptionById.mockResolvedValue(mockSubscription);

      req.params = { id: 'sub-123' };

      await getModuleSubscriptionById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.module_subscription.get.success',
        mockSubscription,
        'en'
      );
    });
  });

  describe('createModuleSubscription', () => {
    it('should create module subscription', async () => {
      const data = {
        module_id: 'module-123',
        subscription_id: 'subscription-123'
      };
      const mockCreated = { id: 'sub-new', ...data };
      moduleSubscriptionService.createModuleSubscription.mockResolvedValue(mockCreated);

      req.body = data;

      await createModuleSubscription(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.module_subscription.create.success',
        mockCreated,
        'en'
      );
    });
  });

  describe('updateModuleSubscription', () => {
    it('should update module subscription', async () => {
      const updateData = { is_active: false };
      const mockUpdated = { id: 'sub-123', is_active: false };
      moduleSubscriptionService.updateModuleSubscription.mockResolvedValue(mockUpdated);

      req.params = { id: 'sub-123' };
      req.body = updateData;

      await updateModuleSubscription(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.module_subscription.update.success',
        mockUpdated,
        'en'
      );
    });
  });

  describe('deleteModuleSubscription', () => {
    it('should delete module subscription', async () => {
      moduleSubscriptionService.deleteModuleSubscription.mockResolvedValue({});

      req.params = { id: 'sub-123' };

      await deleteModuleSubscription(req, res);

      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
