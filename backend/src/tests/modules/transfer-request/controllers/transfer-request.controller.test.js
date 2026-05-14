/**
 * Transfer request controller tests
 *
 * @module tests/modules/transfer-request/controllers
 * @description Tests for transfer request controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const transferRequestController = require('@controllers/transfer-request/transfer-request.controller');
const transferRequestService = require('@services/transfer-request/transfer-request.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/transfer-request/transfer-request.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Transfer Request Controller', () => {
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

  describe('listTransferRequests', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        transferRequests: [
          {
            id: '1',
            admission_id: 'adm-1',
            from_ward_id: 'ward-1',
            to_ward_id: 'ward-2',
            status: 'REQUESTED'
          }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      transferRequestService.listTransferRequests.mockResolvedValue(mockResult);

      await transferRequestController.listTransferRequests(mockReq, mockRes);

      expect(transferRequestService.listTransferRequests).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.transfer_request.list.success',
        mockResult.transferRequests,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'requested_at',
        order: 'asc',
        admission_id: 'adm-123',
        from_ward_id: 'ward-1',
        to_ward_id: 'ward-2',
        status: 'APPROVED',
        search: 'test'
      };
      transferRequestService.listTransferRequests.mockResolvedValue({
        transferRequests: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await transferRequestController.listTransferRequests(mockReq, mockRes);

      expect(transferRequestService.listTransferRequests).toHaveBeenCalledWith(
        expect.objectContaining({
          admission_id: 'adm-123',
          from_ward_id: 'ward-1',
          to_ward_id: 'ward-2',
          status: 'APPROVED',
          search: 'test'
        }),
        2,
        50,
        'requested_at',
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });

    it('should use default page and limit when not provided', async () => {
      transferRequestService.listTransferRequests.mockResolvedValue({
        transferRequests: [],
        pagination: {}
      });

      await transferRequestController.listTransferRequests(mockReq, mockRes);

      expect(transferRequestService.listTransferRequests).toHaveBeenCalledWith(
        expect.anything(),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });

    it('should handle empty filters', async () => {
      transferRequestService.listTransferRequests.mockResolvedValue({
        transferRequests: [],
        pagination: { page: 1, limit: 20, total: 0 }
      });

      await transferRequestController.listTransferRequests(mockReq, mockRes);

      expect(transferRequestService.listTransferRequests).toHaveBeenCalledWith(
        expect.objectContaining({
          admission_id: undefined,
          from_ward_id: undefined,
          to_ward_id: undefined,
          status: undefined,
          search: undefined
        }),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getTransferRequestById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockTransferRequest = {
        id: '123',
        admission_id: 'adm-123',
        from_ward_id: 'ward-1',
        to_ward_id: 'ward-2',
        status: 'REQUESTED'
      };
      transferRequestService.getTransferRequestById.mockResolvedValue(mockTransferRequest);

      await transferRequestController.getTransferRequestById(mockReq, mockRes);

      expect(transferRequestService.getTransferRequestById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.transfer_request.get.success',
        mockTransferRequest
      );
    });
  });

  describe('createTransferRequest', () => {
    it('should call service and send success response with 201 status', async () => {
      mockReq.body = {
        admission_id: 'adm-123',
        from_ward_id: 'ward-1',
        to_ward_id: 'ward-2',
        status: 'REQUESTED'
      };
      const mockTransferRequest = { id: '456', ...mockReq.body };
      transferRequestService.createTransferRequest.mockResolvedValue(mockTransferRequest);

      await transferRequestController.createTransferRequest(mockReq, mockRes);

      expect(transferRequestService.createTransferRequest).toHaveBeenCalledWith(
        mockReq.body,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.transfer_request.create.success',
        mockTransferRequest
      );
    });

    it('should handle minimal body data', async () => {
      mockReq.body = {
        admission_id: 'adm-123'
      };
      const mockTransferRequest = { id: '456', ...mockReq.body, status: 'REQUESTED' };
      transferRequestService.createTransferRequest.mockResolvedValue(mockTransferRequest);

      await transferRequestController.createTransferRequest(mockReq, mockRes);

      expect(transferRequestService.createTransferRequest).toHaveBeenCalledWith(
        mockReq.body,
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('updateTransferRequest', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      mockReq.body = { status: 'APPROVED' };
      const mockTransferRequest = {
        id: '123',
        admission_id: 'adm-123',
        status: 'APPROVED'
      };
      transferRequestService.updateTransferRequest.mockResolvedValue(mockTransferRequest);

      await transferRequestController.updateTransferRequest(mockReq, mockRes);

      expect(transferRequestService.updateTransferRequest).toHaveBeenCalledWith(
        '123',
        mockReq.body,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.transfer_request.update.success',
        mockTransferRequest
      );
    });

    it('should handle multiple fields update', async () => {
      mockReq.params.id = '123';
      mockReq.body = {
        from_ward_id: 'ward-3',
        to_ward_id: 'ward-4',
        status: 'IN_PROGRESS'
      };
      const mockTransferRequest = { id: '123', ...mockReq.body };
      transferRequestService.updateTransferRequest.mockResolvedValue(mockTransferRequest);

      await transferRequestController.updateTransferRequest(mockReq, mockRes);

      expect(transferRequestService.updateTransferRequest).toHaveBeenCalledWith(
        '123',
        mockReq.body,
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('deleteTransferRequest', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      transferRequestService.deleteTransferRequest.mockResolvedValue();

      await transferRequestController.deleteTransferRequest(mockReq, mockRes);

      expect(transferRequestService.deleteTransferRequest).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
