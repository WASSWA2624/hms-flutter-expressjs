/**
 * Webhook subscription controller tests
 *
 * @module tests/modules/webhook-subscription/controllers
 * @description Tests for webhook subscription controller functions
 */

const webhookSubscriptionController = require('@controllers/webhook-subscription/webhook-subscription.controller');
const webhookSubscriptionService = require('@services/webhook-subscription/webhook-subscription.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

// Mock dependencies
jest.mock('@services/webhook-subscription/webhook-subscription.service');
jest.mock('@lib/response');

describe('Webhook Subscription Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      params: {},
      query: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn(),
      json: jest.fn()
    };

    sendSuccess.mockImplementation((res, status, message, data) => {
      return res;
    });

    sendPaginated.mockImplementation((res, message, data, pagination) => {
      return res;
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getWebhookSubscription', () => {
    it('should return webhook subscription by ID', async () => {
      const mockWebhookSubscription = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        event: 'user.created',
        target_url: 'https://example.com/webhook'
      };

      req.params.id = mockWebhookSubscription.id;
      webhookSubscriptionService.getWebhookSubscriptionById.mockResolvedValue(mockWebhookSubscription);

      await webhookSubscriptionController.getWebhookSubscription(req, res);

      expect(webhookSubscriptionService.getWebhookSubscriptionById).toHaveBeenCalledWith(mockWebhookSubscription.id);
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.webhook_subscription.retrieved',
        mockWebhookSubscription
      );
    });
  });

  describe('listWebhookSubscriptions', () => {
    it('should return paginated webhook subscriptions', async () => {
      const mockResult = {
        data: [
          { id: '1', event: 'user.created' },
          { id: '2', event: 'user.updated' }
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

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: 'tenant-123'
      };

      webhookSubscriptionService.listWebhookSubscriptions.mockResolvedValue(mockResult);

      await webhookSubscriptionController.listWebhookSubscriptions(req, res);

      expect(webhookSubscriptionService.listWebhookSubscriptions).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        1,
        20,
        'created_at',
        'desc'
      );

      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.webhook_subscription.list_retrieved',
        mockResult.data,
        mockResult.pagination
      );
    });
  });

  describe('createWebhookSubscription', () => {
    it('should create new webhook subscription', async () => {
      const mockData = {
        tenant_id: 'tenant-123',
        event: 'user.created',
        target_url: 'https://example.com/webhook',
        is_active: true
      };

      const mockCreated = { id: 'new-id', ...mockData };
      req.body = mockData;

      webhookSubscriptionService.createWebhookSubscription.mockResolvedValue(mockCreated);

      await webhookSubscriptionController.createWebhookSubscription(req, res);

      expect(webhookSubscriptionService.createWebhookSubscription).toHaveBeenCalledWith(
        mockData,
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          ip_address: '127.0.0.1'
        }
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.webhook_subscription.created',
        mockCreated
      );
    });
  });

  describe('updateWebhookSubscription', () => {
    it('should update webhook subscription', async () => {
      const mockData = { is_active: false };
      const mockUpdated = { id: 'webhook-id', ...mockData };

      req.params.id = 'webhook-id';
      req.body = mockData;

      webhookSubscriptionService.updateWebhookSubscription.mockResolvedValue(mockUpdated);

      await webhookSubscriptionController.updateWebhookSubscription(req, res);

      expect(webhookSubscriptionService.updateWebhookSubscription).toHaveBeenCalledWith(
        'webhook-id',
        mockData,
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          ip_address: '127.0.0.1'
        }
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.webhook_subscription.updated',
        mockUpdated
      );
    });
  });

  describe('deleteWebhookSubscription', () => {
    it('should delete webhook subscription and return 204', async () => {
      req.params.id = 'webhook-id';

      webhookSubscriptionService.deleteWebhookSubscription.mockResolvedValue({});

      await webhookSubscriptionController.deleteWebhookSubscription(req, res);

      expect(webhookSubscriptionService.deleteWebhookSubscription).toHaveBeenCalledWith(
        'webhook-id',
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          ip_address: '127.0.0.1'
        }
      );

      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
