/**
 * Billing Adjustment controller tests
 *
 * @module tests/modules/billing-adjustment/controllers
 * @description Tests for billing adjustment controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const billingAdjustmentController = require('@controllers/billing-adjustment/billing-adjustment.controller');
const billingAdjustmentService = require('@services/billing-adjustment/billing-adjustment.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/billing-adjustment/billing-adjustment.service');
jest.mock('@lib/response');

describe('Billing Adjustment Controller', () => {
  let req, res;

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

  describe('listBillingAdjustments', () => {
    const mockResult = {
      billingAdjustments: [
        { id: '1', invoice_id: 'invoice-1', amount: 100.50, status: 'DRAFT', reason: 'Discount' },
        { id: '2', invoice_id: 'invoice-2', amount: 50.25, status: 'PAID', reason: 'Tax adjustment' }
      ],
      pagination: {
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      }
    };

    it('should list billing adjustments with default pagination', async () => {
      billingAdjustmentService.listBillingAdjustments.mockResolvedValue(mockResult);

      await billingAdjustmentController.listBillingAdjustments(req, res);

      expect(billingAdjustmentService.listBillingAdjustments).toHaveBeenCalledWith(
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
        'messages.billing_adjustment.list.success',
        mockResult.billingAdjustments,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        invoice_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'PAID'
      };
      billingAdjustmentService.listBillingAdjustments.mockResolvedValue(mockResult);

      await billingAdjustmentController.listBillingAdjustments(req, res);

      expect(billingAdjustmentService.listBillingAdjustments).toHaveBeenCalledWith(
        expect.objectContaining({
          invoice_id: '550e8400-e29b-41d4-a716-446655440000',
          status: 'PAID'
        }),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });

    it('should apply pagination from query params', async () => {
      req.query = { page: '2', limit: '50' };
      billingAdjustmentService.listBillingAdjustments.mockResolvedValue(mockResult);

      await billingAdjustmentController.listBillingAdjustments(req, res);

      expect(billingAdjustmentService.listBillingAdjustments).toHaveBeenCalledWith(
        expect.any(Object),
        2,
        50,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });

    it('should apply search filter', async () => {
      req.query = { search: 'discount' };
      billingAdjustmentService.listBillingAdjustments.mockResolvedValue(mockResult);

      await billingAdjustmentController.listBillingAdjustments(req, res);

      expect(billingAdjustmentService.listBillingAdjustments).toHaveBeenCalledWith(
        expect.objectContaining({
          search: 'discount'
        }),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });
  });

  describe('getBillingAdjustmentById', () => {
    const billingAdjustmentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockBillingAdjustment = { id: billingAdjustmentId, invoice_id: 'invoice-1', amount: 100.50, status: 'DRAFT' };

    it('should get billing adjustment by ID', async () => {
      req.params = { id: billingAdjustmentId };
      billingAdjustmentService.getBillingAdjustmentById.mockResolvedValue(mockBillingAdjustment);

      await billingAdjustmentController.getBillingAdjustmentById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.billing_adjustment.get.success',
        mockBillingAdjustment
      );
    });
  });

  describe('createBillingAdjustment', () => {
    const billingAdjustmentData = {
      invoice_id: '550e8400-e29b-41d4-a716-446655440000',
      amount: 100.50,
      status: 'DRAFT',
      reason: 'Discount applied'
    };

    const createdBillingAdjustment = { id: '550e8400-e29b-41d4-a716-446655440001', ...billingAdjustmentData };

    it('should create new billing adjustment', async () => {
      req.body = billingAdjustmentData;
      billingAdjustmentService.createBillingAdjustment.mockResolvedValue(createdBillingAdjustment);

      await billingAdjustmentController.createBillingAdjustment(req, res);

      expect(billingAdjustmentService.createBillingAdjustment).toHaveBeenCalledWith(
        billingAdjustmentData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.billing_adjustment.create.success',
        createdBillingAdjustment
      );
    });
  });

  describe('updateBillingAdjustment', () => {
    const billingAdjustmentId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      amount: 200.75,
      status: 'PAID'
    };

    const updatedBillingAdjustment = { id: billingAdjustmentId, ...updateData };

    it('should update billing adjustment', async () => {
      req.params = { id: billingAdjustmentId };
      req.body = updateData;
      billingAdjustmentService.updateBillingAdjustment.mockResolvedValue(updatedBillingAdjustment);

      await billingAdjustmentController.updateBillingAdjustment(req, res);

      expect(billingAdjustmentService.updateBillingAdjustment).toHaveBeenCalledWith(
        billingAdjustmentId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.billing_adjustment.update.success',
        updatedBillingAdjustment
      );
    });
  });

  describe('deleteBillingAdjustment', () => {
    const billingAdjustmentId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete billing adjustment', async () => {
      req.params = { id: billingAdjustmentId };
      billingAdjustmentService.deleteBillingAdjustment.mockResolvedValue(undefined);

      await billingAdjustmentController.deleteBillingAdjustment(req, res);

      expect(billingAdjustmentService.deleteBillingAdjustment).toHaveBeenCalledWith(
        billingAdjustmentId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
