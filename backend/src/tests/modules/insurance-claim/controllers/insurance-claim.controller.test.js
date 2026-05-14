/**
 * Insurance claim controller tests
 *
 * @module tests/modules/insurance-claim/controllers
 * @description Tests for insurance claim controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const insuranceClaimController = require('@controllers/insurance-claim/insurance-claim.controller');
const insuranceClaimService = require('@services/insurance-claim/insurance-claim.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/insurance-claim/insurance-claim.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Insurance Claim Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listInsuranceClaims', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        insurance_claims: [{ id: '1', status: 'SUBMITTED' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      insuranceClaimService.listInsuranceClaims.mockResolvedValue(mockResult);

      await insuranceClaimController.listInsuranceClaims(mockReq, mockRes);

      expect(insuranceClaimService.listInsuranceClaims).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.insurance_claim.list.success',
        mockResult.insurance_claims,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'submitted_at',
        order: 'asc',
        coverage_plan_id: '123',
        status: 'APPROVED'
      };
      insuranceClaimService.listInsuranceClaims.mockResolvedValue({
        insurance_claims: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await insuranceClaimController.listInsuranceClaims(mockReq, mockRes);

      expect(insuranceClaimService.listInsuranceClaims).toHaveBeenCalledWith(
        expect.objectContaining({
          coverage_plan_id: '123',
          status: 'APPROVED'
        }),
        2,
        50,
        'submitted_at',
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getInsuranceClaimById', () => {
    it('should call service and send success response', async () => {
      const mockClaim = { id: '123', status: 'SUBMITTED' };
      mockReq.params = { id: '123' };
      insuranceClaimService.getInsuranceClaimById.mockResolvedValue(mockClaim);

      await insuranceClaimController.getInsuranceClaimById(mockReq, mockRes);

      expect(insuranceClaimService.getInsuranceClaimById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.insurance_claim.get.success', mockClaim);
    });
  });

  describe('createInsuranceClaim', () => {
    it('should call service and send success response with 201 status', async () => {
      const mockData = { coverage_plan_id: '123', invoice_id: '456' };
      const mockClaim = { id: '789', ...mockData };
      mockReq.body = mockData;
      insuranceClaimService.createInsuranceClaim.mockResolvedValue(mockClaim);

      await insuranceClaimController.createInsuranceClaim(mockReq, mockRes);

      expect(insuranceClaimService.createInsuranceClaim).toHaveBeenCalledWith(mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.insurance_claim.create.success', mockClaim);
    });
  });

  describe('updateInsuranceClaim', () => {
    it('should call service and send success response', async () => {
      const mockData = { status: 'APPROVED' };
      const mockClaim = { id: '123', status: 'APPROVED' };
      mockReq.params = { id: '123' };
      mockReq.body = mockData;
      insuranceClaimService.updateInsuranceClaim.mockResolvedValue(mockClaim);

      await insuranceClaimController.updateInsuranceClaim(mockReq, mockRes);

      expect(insuranceClaimService.updateInsuranceClaim).toHaveBeenCalledWith('123', mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.insurance_claim.update.success', mockClaim);
    });
  });

  describe('deleteInsuranceClaim', () => {
    it('should call service and send no content response', async () => {
      mockReq.params = { id: '123' };
      insuranceClaimService.deleteInsuranceClaim.mockResolvedValue();

      await insuranceClaimController.deleteInsuranceClaim(mockReq, mockRes);

      expect(insuranceClaimService.deleteInsuranceClaim).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
