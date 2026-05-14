/**
 * Insurance claim service tests
 *
 * @module tests/modules/insurance-claim/services
 * @description Tests for insurance claim service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const insuranceClaimService = require('@services/insurance-claim/insurance-claim.service');
const insuranceClaimRepository = require('@repositories/insurance-claim/insurance-claim.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/insurance-claim/insurance-claim.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
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

describe('Insurance Claim Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listInsuranceClaims', () => {
    it('should list insurance claims with pagination', async () => {
      const mockClaims = [{ id: '1', status: 'SUBMITTED' }];
      insuranceClaimRepository.findMany.mockResolvedValue(mockClaims);
      insuranceClaimRepository.count.mockResolvedValue(1);

      const result = await insuranceClaimService.listInsuranceClaims({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.insurance_claims).toEqual(
        expect.arrayContaining(mockClaims.map((entry) => expect.objectContaining(entry)))
      );
      expect(result.pagination.total).toBe(1);
      expect(insuranceClaimRepository.findMany).toHaveBeenCalled();
      expect(insuranceClaimRepository.count).toHaveBeenCalled();
    });

    it('should handle date range filters', async () => {
      insuranceClaimRepository.findMany.mockResolvedValue([]);
      insuranceClaimRepository.count.mockResolvedValue(0);

      await insuranceClaimService.listInsuranceClaims({ 
        submitted_at_from: '2024-01-01T00:00:00.000Z',
        submitted_at_to: '2024-12-31T23:59:59.999Z'
      }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(insuranceClaimRepository.findMany).toHaveBeenCalled();
    });

    it('should throw HttpError on repository error', async () => {
      insuranceClaimRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        insuranceClaimService.listInsuranceClaims({}, 1, 20, null, 'asc', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getInsuranceClaimById', () => {
    it('should get insurance claim by id', async () => {
      const mockClaim = { id: '123', status: 'SUBMITTED' };
      insuranceClaimRepository.findById.mockResolvedValue(mockClaim);

      const result = await insuranceClaimService.getInsuranceClaimById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockClaim));
      expect(insuranceClaimRepository.findById).toHaveBeenCalledWith('123', expect.any(Object));
    });

    it('should throw HttpError if insurance claim not found', async () => {
      insuranceClaimRepository.findById.mockResolvedValue(null);

      await expect(
        insuranceClaimService.getInsuranceClaimById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
      await expect(
        insuranceClaimService.getInsuranceClaimById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(/not_found/);
    });
  });

  describe('createInsuranceClaim', () => {
    it('should create insurance claim and log audit', async () => {
      const mockData = { coverage_plan_id: '123', invoice_id: '456', status: 'SUBMITTED' };
      const mockClaim = { id: '789', ...mockData };
      insuranceClaimRepository.create.mockResolvedValue(mockClaim);
      insuranceClaimRepository.findById.mockResolvedValue(mockClaim);

      const result = await insuranceClaimService.createInsuranceClaim(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockClaim));
      expect(insuranceClaimRepository.create).toHaveBeenCalledWith(mockData);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'insurance_claim',
        entity_id: '789'
      }));
    });

    it('should handle repository errors', async () => {
      insuranceClaimRepository.create.mockRejectedValue(new HttpError('errors.database.unique_field', 409));

      await expect(
        insuranceClaimService.createInsuranceClaim({}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('updateInsuranceClaim', () => {
    it('should update insurance claim and log audit', async () => {
      const mockBefore = { id: '123', status: 'SUBMITTED' };
      const mockAfter = { id: '123', status: 'APPROVED' };
      insuranceClaimRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      insuranceClaimRepository.update.mockResolvedValue(mockAfter);

      const result = await insuranceClaimService.updateInsuranceClaim('123', { status: 'APPROVED' }, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockAfter));
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'UPDATE',
        entity: 'insurance_claim',
        diff: { before: mockBefore, after: mockAfter }
      }));
    });

    it('should throw HttpError if insurance claim not found', async () => {
      insuranceClaimRepository.findById.mockResolvedValue(null);

      await expect(
        insuranceClaimService.updateInsuranceClaim('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteInsuranceClaim', () => {
    it('should soft delete insurance claim and log audit', async () => {
      const mockClaim = { id: '123', status: 'SUBMITTED' };
      insuranceClaimRepository.findById.mockResolvedValue(mockClaim);
      insuranceClaimRepository.softDelete.mockResolvedValue(mockClaim);

      await insuranceClaimService.deleteInsuranceClaim('123', mockUserId, mockIpAddress);

      expect(insuranceClaimRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'DELETE',
        entity: 'insurance_claim',
        entity_id: '123'
      }));
    });

    it('should throw HttpError if insurance claim not found', async () => {
      insuranceClaimRepository.findById.mockResolvedValue(null);

      await expect(
        insuranceClaimService.deleteInsuranceClaim('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
