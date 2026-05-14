/**
 * Payment controller tests
 */

const paymentController = require('@controllers/payment/payment.controller');
const paymentService = require('@services/payment/payment.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

jest.mock('@services/payment/payment.service');
jest.mock('@lib/response');

describe('Payment Controller', () => {
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

  describe('listPayments', () => {
    it('should list payments with default pagination', async () => {
      const mockResult = {
        payments: [{ id: 'payment-1' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      paymentService.listPayments.mockResolvedValue(mockResult);

      await paymentController.listPayments(req, res);

      expect(paymentService.listPayments).toHaveBeenCalledWith(
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
        'messages.payment.list.success',
        mockResult.payments,
        mockResult.pagination
      );
    });
  });

  describe('getPaymentById', () => {
    it('should get payment by id', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const mockPayment = { id: req.params.id };
      paymentService.getPaymentById.mockResolvedValue(mockPayment);

      await paymentController.getPaymentById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.payment.get.success',
        mockPayment
      );
    });
  });

  describe('createPayment', () => {
    it('should create payment', async () => {
      req.body = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        invoice_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'PENDING',
        method: 'CASH',
        amount: '50.00'
      };
      const mockCreated = { id: 'payment-1', ...req.body };
      paymentService.createPayment.mockResolvedValue(mockCreated);

      await paymentController.createPayment(req, res);

      expect(paymentService.createPayment).toHaveBeenCalledWith(
        req.body,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.payment.create.success',
        mockCreated
      );
    });
  });

  describe('updatePayment', () => {
    it('should update payment', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      req.body = { status: 'COMPLETED' };
      const mockUpdated = { id: req.params.id, ...req.body };
      paymentService.updatePayment.mockResolvedValue(mockUpdated);

      await paymentController.updatePayment(req, res);

      expect(paymentService.updatePayment).toHaveBeenCalledWith(
        req.params.id,
        req.body,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.payment.update.success',
        mockUpdated
      );
    });
  });

  describe('deletePayment', () => {
    it('should delete payment', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      paymentService.deletePayment.mockResolvedValue(undefined);

      await paymentController.deletePayment(req, res);

      expect(paymentService.deletePayment).toHaveBeenCalledWith(
        req.params.id,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});

