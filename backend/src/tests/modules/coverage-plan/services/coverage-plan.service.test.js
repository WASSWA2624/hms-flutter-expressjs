/**
 * Coverage Plan service tests
 *
 * @module tests/modules/coverage-plan/services
 * @description Tests for coverage plan service layer
 * Per testing.mdc: Mock repositories and external dependencies
 */

const coveragePlanService = require('@services/coverage-plan/coverage-plan.service');
const coveragePlanRepository = require('@repositories/coverage-plan/coverage-plan.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/coverage-plan/coverage-plan.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  sanitizeIdentifier: (value) => (typeof value === 'string' ? value.trim() : ''),
  resolvePublicIdentifier: (...values) => {
    for (const value of values) {
      const normalized =
        typeof value === 'string'
          ? value.trim()
          : value == null
            ? ''
            : String(value).trim();
      if (normalized) return normalized;
    }
    return null;
  },
  resolveIdentifierForFilter: async ({ value }) => value,
  resolveIdentifierForPayload: async ({ value, nullable = false }) => {
    if (value === undefined) return undefined;
    if (value === null && nullable) return null;
    return value;
  },
  resolveEntityId: async ({ identifier }) => identifier,
}));

describe('Coverage Plan Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  const mockUserId = '550e8400-e29b-41d4-a716-446655440000';
  const mockIp = '127.0.0.1';

  describe('listCoveragePlans', () => {
    it('should list coverage plans with pagination', async () => {
      const mockData = [{ id: '1', name: 'Plan 1' }];
      coveragePlanRepository.findMany.mockResolvedValue(mockData);
      coveragePlanRepository.count.mockResolvedValue(1);

      const result = await coveragePlanService.listCoveragePlans({}, 1, 20, null, 'asc', mockUserId, mockIp);

      expect(result).toHaveProperty('coveragePlans');
      expect(result).toHaveProperty('pagination');
    });
  });

  describe('getCoveragePlanById', () => {
    const mockId = '550e8400-e29b-41d4-a716-446655440001';

    it('should get coverage plan by ID', async () => {
      const mockData = { id: mockId, name: 'Test Plan' };
      coveragePlanRepository.findById.mockResolvedValue(mockData);

      const result = await coveragePlanService.getCoveragePlanById(mockId, mockUserId, mockIp);

      expect(result).toEqual(expect.objectContaining(mockData));
    });

    it('should throw error if coverage plan not found', async () => {
      coveragePlanRepository.findById.mockResolvedValue(null);

      await expect(
        coveragePlanService.getCoveragePlanById(mockId, mockUserId, mockIp)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createCoveragePlan', () => {
    const mockData = { tenant_id: mockUserId, name: 'New Plan', coverage_percentage: 80 };

    it('should create coverage plan and audit log', async () => {
      const mockCreated = { id: '1', ...mockData };
      coveragePlanRepository.create.mockResolvedValue(mockCreated);

      const result = await coveragePlanService.createCoveragePlan(mockData, mockUserId, mockIp);

      expect(result).toEqual(expect.objectContaining(mockCreated));
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateCoveragePlan', () => {
    const mockId = '550e8400-e29b-41d4-a716-446655440001';
    const mockData = { name: 'Updated Plan' };

    it('should update coverage plan and create audit log', async () => {
      const mockBefore = { id: mockId, name: 'Old Plan' };
      const mockAfter = { id: mockId, name: 'Updated Plan' };
      coveragePlanRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      coveragePlanRepository.update.mockResolvedValue(mockAfter);

      const result = await coveragePlanService.updateCoveragePlan(mockId, mockData, mockUserId, mockIp);

      expect(result).toEqual(expect.objectContaining(mockAfter));
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw error if coverage plan not found', async () => {
      coveragePlanRepository.findById.mockResolvedValue(null);

      await expect(
        coveragePlanService.updateCoveragePlan(mockId, mockData, mockUserId, mockIp)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteCoveragePlan', () => {
    const mockId = '550e8400-e29b-41d4-a716-446655440001';

    it('should soft delete coverage plan and create audit log', async () => {
      const mockBefore = { id: mockId, name: 'Test Plan' };
      coveragePlanRepository.findById.mockResolvedValue(mockBefore);
      coveragePlanRepository.softDelete.mockResolvedValue(mockBefore);

      await coveragePlanService.deleteCoveragePlan(mockId, mockUserId, mockIp);

      expect(coveragePlanRepository.softDelete).toHaveBeenCalledWith(mockId);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw error if coverage plan not found', async () => {
      coveragePlanRepository.findById.mockResolvedValue(null);

      await expect(
        coveragePlanService.deleteCoveragePlan(mockId, mockUserId, mockIp)
      ).rejects.toThrow(HttpError);
    });
  });
});
