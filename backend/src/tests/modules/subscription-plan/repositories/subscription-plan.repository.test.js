/**
 * Subscription Plan repository tests
 *
 * @module tests/modules/subscription-plan/repositories
 * @description Tests for subscription plan data access layer
 */

const subscriptionPlanRepository = require('../../../../modules/subscription-plan/repositories/subscription-plan.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  subscription_plan: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Subscription Plan Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find subscription plan by ID', async () => {
      const mockPlan = { id: '123', name: 'Basic Plan', deleted_at: null };
      prisma.subscription_plan.findFirst.mockResolvedValue(mockPlan);

      const result = await subscriptionPlanRepository.findById('123');

      expect(result).toEqual(mockPlan);
      expect(prisma.subscription_plan.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null when not found', async () => {
      prisma.subscription_plan.findFirst.mockResolvedValue(null);

      const result = await subscriptionPlanRepository.findById('999');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription_plan.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionPlanRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple subscription plans', async () => {
      const mockPlans = [
        { id: '1', name: 'Basic Plan', deleted_at: null },
        { id: '2', name: 'Pro Plan', deleted_at: null }
      ];
      prisma.subscription_plan.findMany.mockResolvedValue(mockPlans);

      const result = await subscriptionPlanRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockPlans);
      expect(prisma.subscription_plan.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { billing_cycle: 'MONTHLY' };
      prisma.subscription_plan.findMany.mockResolvedValue([]);

      await subscriptionPlanRepository.findMany(filters, 0, 20);

      expect(prisma.subscription_plan.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription_plan.findMany.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionPlanRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count subscription plans', async () => {
      prisma.subscription_plan.count.mockResolvedValue(5);

      const result = await subscriptionPlanRepository.count({});

      expect(result).toBe(5);
      expect(prisma.subscription_plan.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.subscription_plan.count.mockRejectedValue(new Error('DB error'));

      await expect(subscriptionPlanRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create subscription plan', async () => {
      const mockData = { name: 'Basic Plan', price: 99.99, billing_cycle: 'MONTHLY' };
      const mockCreated = { id: '123', ...mockData };
      prisma.subscription_plan.create.mockResolvedValue(mockCreated);

      const result = await subscriptionPlanRepository.create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.subscription_plan.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['name'] } };
      prisma.subscription_plan.create.mockRejectedValue(error);

      await expect(subscriptionPlanRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'tenant_id' } };
      prisma.subscription_plan.create.mockRejectedValue(error);

      await expect(subscriptionPlanRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update subscription plan', async () => {
      const mockUpdated = { id: '123', name: 'Updated Plan' };
      prisma.subscription_plan.update.mockResolvedValue(mockUpdated);

      const result = await subscriptionPlanRepository.update('123', { name: 'Updated Plan' });

      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError when not found', async () => {
      const error = { code: 'P2025' };
      prisma.subscription_plan.update.mockRejectedValue(error);

      await expect(subscriptionPlanRepository.update('999', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete subscription plan', async () => {
      const mockDeleted = { id: '123', deleted_at: expect.any(Date) };
      prisma.subscription_plan.update.mockResolvedValue(mockDeleted);

      const result = await subscriptionPlanRepository.softDelete('123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.subscription_plan.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when not found', async () => {
      const error = { code: 'P2025' };
      prisma.subscription_plan.update.mockRejectedValue(error);

      await expect(subscriptionPlanRepository.softDelete('999')).rejects.toThrow(HttpError);
    });
  });
});
