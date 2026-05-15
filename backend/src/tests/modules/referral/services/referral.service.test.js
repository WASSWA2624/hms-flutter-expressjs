/**
 * Referral service tests
 *
 * @module tests/modules/referral/services
 * Per testing.mdc: Test business logic with mocked repositories
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/referral/referral.repository');
jest.mock('@lib/audit');

const referralRepository = require('@repositories/referral/referral.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listReferrals,
  getReferralById,
  createReferral,
  updateReferral,
  deleteReferral
} = require('@services/referral/referral.service');

const withDisplayFields = (referral) => ({
  ...referral,
  encounter_display_id: referral.encounter?.human_friendly_id || referral.encounter_id || '',
  from_department_name:
    referral.from_department?.name || referral.from_department?.short_name || '',
  from_department_display_id:
    referral.from_department?.human_friendly_id || referral.from_department_id || '',
  to_department_name:
    referral.to_department?.name || referral.to_department?.short_name || '',
  to_department_display_id:
    referral.to_department?.human_friendly_id || referral.to_department_id || '',
});

describe('Referral Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue();
  });

  describe('listReferrals', () => {
    it('should list referrals with pagination', async () => {
      const mockReferrals = [
        { id: 'ref-1', encounter_id: 'enc-1' },
        { id: 'ref-2', encounter: { human_friendly_id: 'ENC-2' } },
      ];
      referralRepository.findMany.mockResolvedValue(mockReferrals);
      referralRepository.count.mockResolvedValue(2);

      const result = await listReferrals({}, 1, 20, 'created_at', 'desc', 'user-1', '127.0.0.1');

      expect(result.referrals).toEqual(mockReferrals.map(withDisplayFields));
      expect(result.pagination.total).toBe(2);
    });
  });

  describe('getReferralById', () => {
    it('should get referral by ID', async () => {
      const mockReferral = {
        id: 'ref-1',
        encounter: { human_friendly_id: 'ENC-1' },
        to_department: { name: 'Cardiology', human_friendly_id: 'DEP-1' },
      };
      referralRepository.findById.mockResolvedValue(mockReferral);

      const result = await getReferralById('ref-1', 'user-1', '127.0.0.1');

      expect(result).toEqual(withDisplayFields(mockReferral));
    });

    it('should throw HttpError if not found', async () => {
      referralRepository.findById.mockResolvedValue(null);

      await expect(getReferralById('ref-1', 'user-1', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createReferral', () => {
    it('should create referral and audit log', async () => {
      const mockReferral = { id: 'ref-1', encounter_id: 'enc-1' };
      referralRepository.create.mockResolvedValue(mockReferral);
      referralRepository.findById.mockResolvedValue(mockReferral);

      const result = await createReferral({ encounter_id: 'enc-1', status: 'PENDING' }, 'user-1', '127.0.0.1');

      expect(result).toEqual(withDisplayFields(mockReferral));
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateReferral', () => {
    it('should update referral and audit log', async () => {
      const mockBefore = { id: 'ref-1', status: 'REQUESTED' };
      const mockAfter = { id: 'ref-1', status: 'APPROVED' };
      referralRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      referralRepository.update.mockResolvedValue(mockAfter);

      const result = await updateReferral('ref-1', { status: 'APPROVED' }, 'user-1', '127.0.0.1');

      expect(result).toEqual(withDisplayFields(mockAfter));
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if not found', async () => {
      referralRepository.findById.mockResolvedValue(null);

      await expect(updateReferral('ref-1', {}, 'user-1', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteReferral', () => {
    it('should soft delete referral and audit log', async () => {
      const mockReferral = { id: 'ref-1' };
      referralRepository.findById.mockResolvedValue(mockReferral);
      referralRepository.softDelete.mockResolvedValue(mockReferral);

      await deleteReferral('ref-1', 'user-1', '127.0.0.1');

      expect(referralRepository.softDelete).toHaveBeenCalledWith('ref-1');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if not found', async () => {
      referralRepository.findById.mockResolvedValue(null);

      await expect(deleteReferral('ref-1', 'user-1', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
