/**
 * Pricing Rule repository tests
 *
 * @module tests/modules/pricing-rule/repositories
 * @description Tests for pricing rule repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const pricingRuleRepository = require('@repositories/pricing-rule/pricing-rule.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  pricing_rule: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Pricing Rule Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const pricingRuleId = '550e8400-e29b-41d4-a716-446655440000';
    const mockPricingRule = {
      id: pricingRuleId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Standard Consultation',
      amount: 50.00,
      currency: 'USD'
    };

    it('should find pricing rule by ID', async () => {
      prisma.pricing_rule.findFirst.mockResolvedValue(mockPricingRule);

      const result = await pricingRuleRepository.findById(pricingRuleId);

      expect(result).toEqual(mockPricingRule);
      expect(prisma.pricing_rule.findFirst).toHaveBeenCalledWith({
        where: { id: pricingRuleId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if pricing rule not found', async () => {
      prisma.pricing_rule.findFirst.mockResolvedValue(null);

      const result = await pricingRuleRepository.findById(pricingRuleId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted pricing rules', async () => {
      prisma.pricing_rule.findFirst.mockResolvedValue(null);

      await pricingRuleRepository.findById(pricingRuleId);

      expect(prisma.pricing_rule.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { tenant: true };
      prisma.pricing_rule.findFirst.mockResolvedValue(mockPricingRule);

      await pricingRuleRepository.findById(pricingRuleId, include);

      expect(prisma.pricing_rule.findFirst).toHaveBeenCalledWith({
        where: { id: pricingRuleId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.pricing_rule.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(pricingRuleRepository.findById(pricingRuleId)).rejects.toThrow(HttpError);
      await expect(pricingRuleRepository.findById(pricingRuleId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockPricingRules = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Rule 1',
        amount: 50.00
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440001',
        name: 'Rule 2',
        amount: 75.00
      }
    ];

    it('should find many pricing rules', async () => {
      prisma.pricing_rule.findMany.mockResolvedValue(mockPricingRules);

      const result = await pricingRuleRepository.findMany();

      expect(result).toEqual(mockPricingRules);
      expect(prisma.pricing_rule.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '550e8400-e29b-41d4-a716-446655440002' };
      prisma.pricing_rule.findMany.mockResolvedValue(mockPricingRules);

      await pricingRuleRepository.findMany(filters);

      expect(prisma.pricing_rule.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            deleted_at: null,
            tenant_id: filters.tenant_id
          })
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.pricing_rule.findMany.mockResolvedValue(mockPricingRules);

      await pricingRuleRepository.findMany({}, 10, 5);

      expect(prisma.pricing_rule.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 10,
          take: 5
        })
      );
    });

    it('should apply custom orderBy', async () => {
      const orderBy = { name: 'asc' };
      prisma.pricing_rule.findMany.mockResolvedValue(mockPricingRules);

      await pricingRuleRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.pricing_rule.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.pricing_rule.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(pricingRuleRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count pricing rules', async () => {
      prisma.pricing_rule.count.mockResolvedValue(10);

      const result = await pricingRuleRepository.count();

      expect(result).toBe(10);
      expect(prisma.pricing_rule.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters to count', async () => {
      const filters = { tenant_id: '550e8400-e29b-41d4-a716-446655440000' };
      prisma.pricing_rule.count.mockResolvedValue(5);

      await pricingRuleRepository.count(filters);

      expect(prisma.pricing_rule.count).toHaveBeenCalledWith({
        where: expect.objectContaining({
          deleted_at: null,
          tenant_id: filters.tenant_id
        })
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.pricing_rule.count.mockRejectedValue(new Error('DB Error'));

      await expect(pricingRuleRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const createData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'New Rule',
      amount: 50.00,
      currency: 'USD'
    };

    it('should create pricing rule', async () => {
      const mockCreated = { id: '550e8400-e29b-41d4-a716-446655440001', ...createData };
      prisma.pricing_rule.create.mockResolvedValue(mockCreated);

      const result = await pricingRuleRepository.create(createData);

      expect(result).toEqual(mockCreated);
      expect(prisma.pricing_rule.create).toHaveBeenCalledWith({ data: createData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['name'] } };
      prisma.pricing_rule.create.mockRejectedValue(error);

      await expect(pricingRuleRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(pricingRuleRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'tenant_id' } };
      prisma.pricing_rule.create.mockRejectedValue(error);

      await expect(pricingRuleRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(pricingRuleRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.pricing_rule.create.mockRejectedValue(new Error('DB Error'));

      await expect(pricingRuleRepository.create(createData)).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    const pricingRuleId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { name: 'Updated Rule', amount: 75.00 };

    it('should update pricing rule', async () => {
      const mockUpdated = { id: pricingRuleId, ...updateData };
      prisma.pricing_rule.update.mockResolvedValue(mockUpdated);

      const result = await pricingRuleRepository.update(pricingRuleId, updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.pricing_rule.update).toHaveBeenCalledWith({
        where: { id: pricingRuleId },
        data: updateData
      });
    });

    it('should throw HttpError when pricing rule not found', async () => {
      const error = { code: 'P2025' };
      prisma.pricing_rule.update.mockRejectedValue(error);

      await expect(pricingRuleRepository.update(pricingRuleId, updateData)).rejects.toThrow(HttpError);
      await expect(pricingRuleRepository.update(pricingRuleId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.pricing_rule.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['name'] } };
      prisma.pricing_rule.update.mockRejectedValue(error);

      await expect(pricingRuleRepository.update(pricingRuleId, updateData)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.pricing_rule.update.mockRejectedValue(new Error('DB Error'));

      await expect(pricingRuleRepository.update(pricingRuleId, updateData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const pricingRuleId = '550e8400-e29b-41d4-a716-446655440000';

    it('should soft delete pricing rule', async () => {
      const mockDeleted = { id: pricingRuleId, deleted_at: new Date() };
      prisma.pricing_rule.update.mockResolvedValue(mockDeleted);

      const result = await pricingRuleRepository.softDelete(pricingRuleId);

      expect(result).toEqual(mockDeleted);
      expect(prisma.pricing_rule.update).toHaveBeenCalledWith({
        where: { id: pricingRuleId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when pricing rule not found', async () => {
      const error = { code: 'P2025' };
      prisma.pricing_rule.update.mockRejectedValue(error);

      await expect(pricingRuleRepository.softDelete(pricingRuleId)).rejects.toThrow(HttpError);
      await expect(pricingRuleRepository.softDelete(pricingRuleId)).rejects.toMatchObject({
        messageKey: 'errors.pricing_rule.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.pricing_rule.update.mockRejectedValue(new Error('DB Error'));

      await expect(pricingRuleRepository.softDelete(pricingRuleId)).rejects.toThrow(HttpError);
    });
  });
});
