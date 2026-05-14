/**
 * Invoice controller tests
 *
 * @module tests/modules/invoice/controllers
 * @description Tests for invoice controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const invoiceController = require('@controllers/invoice/invoice.controller');
const invoiceService = require('@services/invoice/invoice.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/invoice/invoice.service');
jest.mock('@lib/response');

describe('Invoice Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listInvoices', () => {
    const mockResult = {
      invoices: [
        { id: '1', tenant_id: 'tenant-1', status: 'DRAFT', total_amount: '1000.00' },
        { id: '2', tenant_id: 'tenant-1', status: 'PAID', total_amount: '2500.50' }
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

    it('should list invoices with default pagination', async () => {
      invoiceService.listInvoices.mockResolvedValue(mockResult);

      await invoiceController.listInvoices(req, res);

      expect(invoiceService.listInvoices).toHaveBeenCalledWith(
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
        'messages.invoice.list.success',
        mockResult.invoices,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440002',
        status: 'PAID',
        billing_status: 'PAID',
        search: 'invoice-123',
        page: '2',
        limit: '10',
        sort_by: 'issued_at',
        order: 'desc'
      };
      invoiceService.listInvoices.mockResolvedValue(mockResult);

      await invoiceController.listInvoices(req, res);

      expect(invoiceService.listInvoices).toHaveBeenCalledWith(
        {
          tenant_id: '550e8400-e29b-41d4-a716-446655440000',
          facility_id: '550e8400-e29b-41d4-a716-446655440001',
          patient_id: '550e8400-e29b-41d4-a716-446655440002',
          status: 'PAID',
          billing_status: 'PAID',
          search: 'invoice-123'
        },
        2,
        10,
        'issued_at',
        'desc',
        'requester-id',
        '127.0.0.1'
      );
    });

    it('should handle missing user in request', async () => {
      req.user = undefined;
      invoiceService.listInvoices.mockResolvedValue(mockResult);

      await invoiceController.listInvoices(req, res);

      expect(invoiceService.listInvoices).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        undefined,
        '127.0.0.1'
      );
    });

    it('should handle service errors', async () => {
      const error = new Error('Service error');
      invoiceService.listInvoices.mockRejectedValue(error);

      await expect(invoiceController.listInvoices(req, res)).rejects.toThrow(error);
    });
  });

  describe('getInvoiceById', () => {
    const invoiceId = '550e8400-e29b-41d4-a716-446655440000';
    const mockInvoice = {
      id: invoiceId,
      tenant_id: 'tenant-1',
      status: 'DRAFT',
      total_amount: '1500.50'
    };

    it('should get invoice by ID', async () => {
      req.params = { id: invoiceId };
      invoiceService.getInvoiceById.mockResolvedValue(mockInvoice);

      await invoiceController.getInvoiceById(req, res);

      expect(invoiceService.getInvoiceById).toHaveBeenCalledWith(
        invoiceId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.invoice.get.success',
        mockInvoice
      );
    });

    it('should handle missing user in request', async () => {
      req.user = undefined;
      req.params = { id: invoiceId };
      invoiceService.getInvoiceById.mockResolvedValue(mockInvoice);

      await invoiceController.getInvoiceById(req, res);

      expect(invoiceService.getInvoiceById).toHaveBeenCalledWith(
        invoiceId,
        undefined,
        '127.0.0.1'
      );
    });

    it('should handle service errors', async () => {
      req.params = { id: invoiceId };
      const error = new Error('Service error');
      invoiceService.getInvoiceById.mockRejectedValue(error);

      await expect(invoiceController.getInvoiceById(req, res)).rejects.toThrow(error);
    });
  });

  describe('createInvoice', () => {
    const invoiceData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'DRAFT',
      total_amount: '1500.50',
      currency: 'USD'
    };

    const createdInvoice = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...invoiceData
    };

    it('should create new invoice', async () => {
      req.body = invoiceData;
      invoiceService.createInvoice.mockResolvedValue(createdInvoice);

      await invoiceController.createInvoice(req, res);

      expect(invoiceService.createInvoice).toHaveBeenCalledWith(
        invoiceData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.invoice.create.success',
        createdInvoice
      );
    });

    it('should handle missing user in request', async () => {
      req.user = undefined;
      req.body = invoiceData;
      invoiceService.createInvoice.mockResolvedValue(createdInvoice);

      await invoiceController.createInvoice(req, res);

      expect(invoiceService.createInvoice).toHaveBeenCalledWith(
        invoiceData,
        undefined,
        '127.0.0.1'
      );
    });

    it('should handle service errors', async () => {
      req.body = invoiceData;
      const error = new Error('Service error');
      invoiceService.createInvoice.mockRejectedValue(error);

      await expect(invoiceController.createInvoice(req, res)).rejects.toThrow(error);
    });
  });

  describe('updateInvoice', () => {
    const invoiceId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'PAID',
      billing_status: 'PAID'
    };

    const updatedInvoice = {
      id: invoiceId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'PAID',
      billing_status: 'PAID',
      total_amount: '1500.50'
    };

    it('should update invoice', async () => {
      req.params = { id: invoiceId };
      req.body = updateData;
      invoiceService.updateInvoice.mockResolvedValue(updatedInvoice);

      await invoiceController.updateInvoice(req, res);

      expect(invoiceService.updateInvoice).toHaveBeenCalledWith(
        invoiceId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.invoice.update.success',
        updatedInvoice
      );
    });

    it('should handle missing user in request', async () => {
      req.user = undefined;
      req.params = { id: invoiceId };
      req.body = updateData;
      invoiceService.updateInvoice.mockResolvedValue(updatedInvoice);

      await invoiceController.updateInvoice(req, res);

      expect(invoiceService.updateInvoice).toHaveBeenCalledWith(
        invoiceId,
        updateData,
        undefined,
        '127.0.0.1'
      );
    });

    it('should handle service errors', async () => {
      req.params = { id: invoiceId };
      req.body = updateData;
      const error = new Error('Service error');
      invoiceService.updateInvoice.mockRejectedValue(error);

      await expect(invoiceController.updateInvoice(req, res)).rejects.toThrow(error);
    });
  });

  describe('deleteInvoice', () => {
    const invoiceId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete invoice', async () => {
      req.params = { id: invoiceId };
      invoiceService.deleteInvoice.mockResolvedValue(null);

      await invoiceController.deleteInvoice(req, res);

      expect(invoiceService.deleteInvoice).toHaveBeenCalledWith(
        invoiceId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res, 'messages.invoice.delete.success');
    });

    it('should handle missing user in request', async () => {
      req.user = undefined;
      req.params = { id: invoiceId };
      invoiceService.deleteInvoice.mockResolvedValue(null);

      await invoiceController.deleteInvoice(req, res);

      expect(invoiceService.deleteInvoice).toHaveBeenCalledWith(
        invoiceId,
        undefined,
        '127.0.0.1'
      );
    });

    it('should handle service errors', async () => {
      req.params = { id: invoiceId };
      const error = new Error('Service error');
      invoiceService.deleteInvoice.mockRejectedValue(error);

      await expect(invoiceController.deleteInvoice(req, res)).rejects.toThrow(error);
    });
  });
});
