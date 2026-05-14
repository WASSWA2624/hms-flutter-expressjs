/**
 * Refund controller tests
 */

const refundController = require('@controllers/refund/refund.controller');
const refundService = require('@services/refund/refund.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

jest.mock('@services/refund/refund.service');
jest.mock('@lib/response');

describe('Refund Controller', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id', tenant_id: 'tenant-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listRefunds', () => {
    it('should list refunds with default pagination', async () => {
      const mockResult = {
        refunds: [{ id: 'refund-1' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      refundService.listRefunds.mockResolvedValue(mockResult);

      await refundController.listRefunds(req, res);

      expect(refundService.listRefunds).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.refund.list.success',
        mockResult.refunds,
        mockResult.pagination
      );
    });
  });

  describe('getRefundById', () => {
    it('should get refund by id', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const mockRefund = { id: req.params.id };
      refundService.getRefundById.mockResolvedValue(mockRefund);

      await refundController.getRefundById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.refund.get.success',
        mockRefund
      );
    });
  });

  describe('createRefund', () => {
    it('should create refund', async () => {
      req.body = {
        payment_id: '550e8400-e29b-41d4-a716-446655440000',
        amount: '10.00',
        reason: 'Duplicate'
      };
      const mockCreated = { id: 'refund-1', ...req.body };
      refundService.createRefund.mockResolvedValue(mockCreated);

      await refundController.createRefund(req, res);

      expect(refundService.createRefund).toHaveBeenCalledWith(
        req.body,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.refund.create.success',
        mockCreated
      );
    });
  });

  describe('updateRefund', () => {
    it('should update refund', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      req.body = { reason: 'Updated reason' };
      const mockUpdated = { id: req.params.id, ...req.body };
      refundService.updateRefund.mockResolvedValue(mockUpdated);

      await refundController.updateRefund(req, res);

      expect(refundService.updateRefund).toHaveBeenCalledWith(
        req.params.id,
        req.body,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.refund.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteRefund', () => {
    it('should delete refund', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      refundService.deleteRefund.mockResolvedValue(undefined);

      await refundController.deleteRefund(req, res);

      expect(refundService.deleteRefund).toHaveBeenCalledWith(
        req.params.id,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});

