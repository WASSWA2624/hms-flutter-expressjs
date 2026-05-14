/**
 * Coverage Plan repository tests
 *
 * @module tests/modules/coverage-plan/repositories
 * @description Tests for coverage plan repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const coveragePlanRepository = require('@repositories/coverage-plan/coverage-plan.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  coverage_plan: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Coverage Plan Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const coveragePlanId = '550e8400-e29b-41d4-a716-446655440000';
    const mockCoveragePlan = {
      id: coveragePlanId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Basic Plan',
      coverage_percentage: 80
    };

    it('should find coverage plan by ID', async () => {
      prisma.coverage_plan.findFirst.mockResolvedValue(mockCoveragePlan);

      const result = await coveragePlanRepository.findById(coveragePlanId);

      expect(result).toEqual(mockCoveragePlan);
      expect(prisma.coverage_plan.findFirst).toHaveBeenCalledWith({
        where: { id: coveragePlanId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if coverage plan not found', async () => {
      prisma.coverage_plan.findFirst.mockResolvedValue(null);

      const result = await coveragePlanRepository.findById(coveragePlanId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted coverage plans', async () => {
      prisma.coverage_plan.findFirst.mockResolvedValue(null);

      await coveragePlanRepository.findById(coveragePlanId);

      expect(prisma.coverage_plan.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.coverage_plan.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(coveragePlanRepository.findById(coveragePlanId)).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    const mockCoveragePlans = [
      { id: '1', name: 'Plan 1' },
      { id: '2', name: 'Plan 2' }
    ];

    it('should find many coverage plans', async () => {
      prisma.coverage_plan.findMany.mockResolvedValue(mockCoveragePlans);

      const result = await coveragePlanRepository.findMany();

      expect(result).toEqual(mockCoveragePlans);
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '550e8400-e29b-41d4-a716-446655440000' };
      prisma.coverage_plan.findMany.mockResolvedValue(mockCoveragePlans);

      await coveragePlanRepository.findMany(filters);

      expect(prisma.coverage_plan.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            deleted_at: null,
            tenant_id: filters.tenant_id
          })
        })
      );
    });
  });

  describe('count', () => {
    it('should count coverage plans', async () => {
      prisma.coverage_plan.count.mockResolvedValue(10);

      const result = await coveragePlanRepository.count();

      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    const createData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      name: 'New Plan',
      coverage_percentage: 80
    };

    it('should create coverage plan', async () => {
      const mockCreated = { id: '1', ...createData };
      prisma.coverage_plan.create.mockResolvedValue(mockCreated);

      const result = await coveragePlanRepository.create(createData);

      expect(result).toEqual(mockCreated);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['name'] } };
      prisma.coverage_plan.create.mockRejectedValue(error);

      await expect(coveragePlanRepository.create(createData)).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    const coveragePlanId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { name: 'Updated Plan' };

    it('should update coverage plan', async () => {
      const mockUpdated = { id: coveragePlanId, ...updateData };
      prisma.coverage_plan.update.mockResolvedValue(mockUpdated);

      const result = await coveragePlanRepository.update(coveragePlanId, updateData);

      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError when coverage plan not found', async () => {
      const error = { code: 'P2025' };
      prisma.coverage_plan.update.mockRejectedValue(error);

      await expect(coveragePlanRepository.update(coveragePlanId, updateData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const coveragePlanId = '550e8400-e29b-41d4-a716-446655440000';

    it('should soft delete coverage plan', async () => {
      const mockDeleted = { id: coveragePlanId, deleted_at: new Date() };
      prisma.coverage_plan.update.mockResolvedValue(mockDeleted);

      const result = await coveragePlanRepository.softDelete(coveragePlanId);

      expect(result).toEqual(mockDeleted);
    });

    it('should throw HttpError when coverage plan not found', async () => {
      const error = { code: 'P2025' };
      prisma.coverage_plan.update.mockRejectedValue(error);

      await expect(coveragePlanRepository.softDelete(coveragePlanId)).rejects.toThrow(HttpError);
    });
  });
});
