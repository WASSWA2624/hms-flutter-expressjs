/**
 * Webhook subscription repository tests
 *
 * @module tests/modules/webhook-subscription/repositories
 * @description Tests for webhook subscription repository functions
 */

const webhookSubscriptionRepository = require('@repositories/webhook-subscription/webhook-subscription.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  webhook_subscription: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Webhook Subscription Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find webhook subscription by ID', async () => {
      const mockWebhookSubscription = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: 'tenant-123',
        event: 'user.created',
        target_url: 'https://example.com/webhook',
        is_active: true
      };

      prisma.webhook_subscription.findFirst.mockResolvedValue(mockWebhookSubscription);

      const result = await webhookSubscriptionRepository.findById(mockWebhookSubscription.id);

      expect(result).toEqual(mockWebhookSubscription);
      expect(prisma.webhook_subscription.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockWebhookSubscription.id,
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if webhook subscription not found', async () => {
      prisma.webhook_subscription.findFirst.mockResolvedValue(null);

      const result = await webhookSubscriptionRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.webhook_subscription.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(webhookSubscriptionRepository.findById('some-id'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many webhook subscriptions with filters', async () => {
      const mockWebhookSubscriptions = [
        { id: '1', event: 'user.created', is_active: true },
        { id: '2', event: 'user.updated', is_active: false }
      ];

      prisma.webhook_subscription.findMany.mockResolvedValue(mockWebhookSubscriptions);

      const filters = { tenant_id: 'tenant-123' };
      const result = await webhookSubscriptionRepository.findMany(filters, 0, 20);

      expect(result).toEqual(mockWebhookSubscriptions);
      expect(prisma.webhook_subscription.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.webhook_subscription.findMany.mockRejectedValue(new Error('Database error'));

      await expect(webhookSubscriptionRepository.findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count webhook subscriptions with filters', async () => {
      prisma.webhook_subscription.count.mockResolvedValue(10);

      const filters = { is_active: true };
      const result = await webhookSubscriptionRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.webhook_subscription.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.webhook_subscription.count.mockRejectedValue(new Error('Database error'));

      await expect(webhookSubscriptionRepository.count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new webhook subscription', async () => {
      const mockData = {
        tenant_id: 'tenant-123',
        event: 'user.created',
        target_url: 'https://example.com/webhook',
        is_active: true
      };

      const mockCreated = { id: 'new-id', ...mockData };
      prisma.webhook_subscription.create.mockResolvedValue(mockCreated);

      const result = await webhookSubscriptionRepository.create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.webhook_subscription.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['event', 'target_url'] };

      prisma.webhook_subscription.create.mockRejectedValue(error);

      await expect(webhookSubscriptionRepository.create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.webhook_subscription.create.mockRejectedValue(error);

      await expect(webhookSubscriptionRepository.create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update webhook subscription', async () => {
      const mockData = { is_active: false };
      const mockUpdated = { id: 'webhook-id', ...mockData };

      prisma.webhook_subscription.update.mockResolvedValue(mockUpdated);

      const result = await webhookSubscriptionRepository.update('webhook-id', mockData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.webhook_subscription.update).toHaveBeenCalledWith({
        where: { id: 'webhook-id' },
        data: mockData
      });
    });

    it('should throw HttpError when webhook subscription not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.webhook_subscription.update.mockRejectedValue(error);

      await expect(webhookSubscriptionRepository.update('non-existent-id', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['event'] };

      prisma.webhook_subscription.update.mockRejectedValue(error);

      await expect(webhookSubscriptionRepository.update('webhook-id', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete webhook subscription', async () => {
      const mockDeleted = {
        id: 'webhook-id',
        deleted_at: expect.any(Date)
      };

      prisma.webhook_subscription.update.mockResolvedValue(mockDeleted);

      const result = await webhookSubscriptionRepository.softDelete('webhook-id');

      expect(result).toEqual(mockDeleted);
      expect(prisma.webhook_subscription.update).toHaveBeenCalledWith({
        where: { id: 'webhook-id' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when webhook subscription not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.webhook_subscription.update.mockRejectedValue(error);

      await expect(webhookSubscriptionRepository.softDelete('non-existent-id'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
