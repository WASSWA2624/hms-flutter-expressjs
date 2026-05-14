/**
 * Pre-authorization controller tests
 *
 * @module tests/modules/pre-authorization/controllers
 * @description Tests for pre-authorization controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const preAuthorizationController = require('@controllers/pre-authorization/pre-authorization.controller');
const preAuthorizationService = require('@services/pre-authorization/pre-authorization.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/pre-authorization/pre-authorization.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Pre-Authorization Controller', () => {
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

  describe('listPreAuthorizations', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        pre_authorizations: [{ id: '1', status: 'PENDING' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      preAuthorizationService.listPreAuthorizations.mockResolvedValue(mockResult);

      await preAuthorizationController.listPreAuthorizations(mockReq, mockRes);

      expect(preAuthorizationService.listPreAuthorizations).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.pre_authorization.list.success',
        mockResult.pre_authorizations,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'requested_at',
        order: 'asc',
        coverage_plan_id: '123',
        status: 'APPROVED'
      };
      preAuthorizationService.listPreAuthorizations.mockResolvedValue({
        pre_authorizations: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await preAuthorizationController.listPreAuthorizations(mockReq, mockRes);

      expect(preAuthorizationService.listPreAuthorizations).toHaveBeenCalledWith(
        expect.objectContaining({
          coverage_plan_id: '123',
          status: 'APPROVED'
        }),
        2,
        50,
        'requested_at',
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getPreAuthorizationById', () => {
    it('should call service and send success response', async () => {
      const mockAuth = { id: '123', status: 'PENDING' };
      mockReq.params = { id: '123' };
      preAuthorizationService.getPreAuthorizationById.mockResolvedValue(mockAuth);

      await preAuthorizationController.getPreAuthorizationById(mockReq, mockRes);

      expect(preAuthorizationService.getPreAuthorizationById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.pre_authorization.get.success', mockAuth);
    });
  });

  describe('createPreAuthorization', () => {
    it('should call service and send success response with 201 status', async () => {
      const mockData = { coverage_plan_id: '123', status: 'PENDING' };
      const mockAuth = { id: '789', ...mockData };
      mockReq.body = mockData;
      preAuthorizationService.createPreAuthorization.mockResolvedValue(mockAuth);

      await preAuthorizationController.createPreAuthorization(mockReq, mockRes);

      expect(preAuthorizationService.createPreAuthorization).toHaveBeenCalledWith(mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.pre_authorization.create.success', mockAuth);
    });
  });

  describe('updatePreAuthorization', () => {
    it('should call service and send success response', async () => {
      const mockData = { status: 'APPROVED' };
      const mockAuth = { id: '123', status: 'APPROVED' };
      mockReq.params = { id: '123' };
      mockReq.body = mockData;
      preAuthorizationService.updatePreAuthorization.mockResolvedValue(mockAuth);

      await preAuthorizationController.updatePreAuthorization(mockReq, mockRes);

      expect(preAuthorizationService.updatePreAuthorization).toHaveBeenCalledWith('123', mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.pre_authorization.update.success', mockAuth);
    });
  });

  describe('deletePreAuthorization', () => {
    it('should call service and send no content response', async () => {
      mockReq.params = { id: '123' };
      preAuthorizationService.deletePreAuthorization.mockResolvedValue();

      await preAuthorizationController.deletePreAuthorization(mockReq, mockRes);

      expect(preAuthorizationService.deletePreAuthorization).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
