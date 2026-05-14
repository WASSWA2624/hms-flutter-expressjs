/**
 * Referral controller tests
 *
 * @module tests/modules/referral/controllers
 * Per testing.mdc: Test request handlers with mocked services
 */

// Mock dependencies
jest.mock('@services/referral/referral.service');
jest.mock('@lib/response');

const referralService = require('@services/referral/referral.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listReferrals,
  getReferralById,
  createReferral,
  updateReferral,
  deleteReferral
} = require('@controllers/referral/referral.controller');

describe('Referral Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-1' },
      ip: '127.0.0.1'
    };
    res = {};
  });

  describe('listReferrals', () => {
    it('should list referrals', async () => {
      const mockResult = {
        referrals: [{ id: 'ref-1' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      referralService.listReferrals.mockResolvedValue(mockResult);

      await listReferrals(req, res);

      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.referral.list.success',
        mockResult.referrals,
        mockResult.pagination
      );
    });
  });

  describe('getReferralById', () => {
    it('should get referral by ID', async () => {
      req.params.id = 'ref-1';
      const mockReferral = { id: 'ref-1' };
      referralService.getReferralById.mockResolvedValue(mockReferral);

      await getReferralById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.referral.get.success',
        mockReferral
      );
    });
  });

  describe('createReferral', () => {
    it('should create referral', async () => {
      req.body = { encounter_id: 'enc-1', status: 'REQUESTED' };
      const mockReferral = { id: 'ref-1', ...req.body };
      referralService.createReferral.mockResolvedValue(mockReferral);

      await createReferral(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.referral.create.success',
        mockReferral
      );
    });
  });

  describe('updateReferral', () => {
    it('should update referral', async () => {
      req.params.id = 'ref-1';
      req.body = { status: 'APPROVED' };
      const mockReferral = { id: 'ref-1', ...req.body };
      referralService.updateReferral.mockResolvedValue(mockReferral);

      await updateReferral(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.referral.update.success',
        mockReferral
      );
    });
  });

  describe('deleteReferral', () => {
    it('should delete referral', async () => {
      req.params.id = 'ref-1';
      referralService.deleteReferral.mockResolvedValue();

      await deleteReferral(req, res);

      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
