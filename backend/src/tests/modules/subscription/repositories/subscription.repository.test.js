/**
 * Subscription repository tests
 *
 * @module tests/modules/subscription/repositories
 * @description Tests for subscription data access layer
 */

const subscriptionRepository = require('../../../../modules/subscription/repositories/subscription.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  subscription: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Subscription Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find subscription by ID', async () => {
      const mockSubscription = { id: '123', tenant_id: '456', deleted_at: null };
      prisma.subscription.findFirst.mockResolvedValue(mockSubscription);

      const result = await subscriptionRepository.findById('123');

      expect(result).toEqual(mockSubscription);
      expect(prisma.subscription.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null when not found', async () => {
      prisma.subscription.findFirst.mockResolvedValue(null);

      const result = await subscriptionRepository.findById('999');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple subscriptions', async () => {
      const mockSubscriptions = [
        { id: '1', tenant_id: '456', deleted_at: null },
        { id: '2', tenant_id: '456', deleted_at: null }
      ];
      prisma.subscription.findMany.mockResolvedValue(mockSubscriptions);

      const result = await subscriptionRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockSubscriptions);
      expect(prisma.subscription.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { status: 'ACTIVE' };
      prisma.subscription.findMany.mockResolvedValue([]);

      await subscriptionRepository.findMany(filters, 0, 20);

      expect(prisma.subscription.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription.findMany.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count subscriptions', async () => {
      prisma.subscription.count.mockResolvedValue(5);

      const result = await subscriptionRepository.count({});

      expect(result).toBe(5);
      expect(prisma.subscription.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription.count.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create subscription', async () => {
      const mockData = { tenant_id: '456', plan_id: '789', status: 'ACTIVE' };
      const mockCreated = { id: '123', ...mockData };
      prisma.subscription.create.mockResolvedValue(mockCreated);

      const result = await subscriptionRepository.create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.subscription.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['tenant_id'] } };
      prisma.subscription.create.mockRejectedValue(error);

      await expect(subscriptionRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'plan_id' } };
      prisma.subscription.create.mockRejectedValue(error);

      await expect(subscriptionRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update subscription', async () => {
      const mockUpdated = { id: '123', status: 'CANCELLED' };
      prisma.subscription.update.mockResolvedValue(mockUpdated);

      const result = await subscriptionRepository.update('123', { status: 'CANCELLED' });

      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError when not found', async () => {
      const error = { code: 'P2025' };
      prisma.subscription.update.mockRejectedValue(error);

      await expect(subscriptionRepository.update('999', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete subscription', async () => {
      const mockDeleted = { id: '123', deleted_at: expect.any(Date) };
      prisma.subscription.update.mockResolvedValue(mockDeleted);

      const result = await subscriptionRepository.softDelete('123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.subscription.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when not found', async () => {
      const error = { code: 'P2025' };
      prisma.subscription.update.mockRejectedValue(error);

      await expect(subscriptionRepository.softDelete('999')).rejects.toThrow(HttpError);
    });
  });
});
