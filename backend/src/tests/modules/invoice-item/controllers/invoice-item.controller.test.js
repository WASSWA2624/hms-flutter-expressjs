/**
 * Invoice item controller tests
 */

const invoiceItemController = require('@controllers/invoice-item/invoice-item.controller');
const invoiceItemService = require('@services/invoice-item/invoice-item.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

jest.mock('@services/invoice-item/invoice-item.service');
jest.mock('@lib/response');

describe('Invoice Item Controller', () => {
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

  describe('listInvoiceItems', () => {
    it('should list invoice items with default pagination', async () => {
      const mockResult = {
        invoiceItems: [{ id: 'item-1' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      invoiceItemService.listInvoiceItems.mockResolvedValue(mockResult);

      await invoiceItemController.listInvoiceItems(req, res);

      expect(invoiceItemService.listInvoiceItems).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'desc'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.invoice_item.list.success',
        mockResult.invoiceItems,
        mockResult.pagination
      );
    });

    it('should apply query filters and pagination', async () => {
      req.query = {
        invoice_id: '550e8400-e29b-41d4-a716-446655440000',
        search: 'consult',
        page: '2',
        limit: '10',
        sort_by: 'created_at',
        order: 'asc'
      };
      invoiceItemService.listInvoiceItems.mockResolvedValue({
        invoiceItems: [],
        pagination: {
          page: 2,
          limit: 10,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: true
        }
      });

      await invoiceItemController.listInvoiceItems(req, res);

      expect(invoiceItemService.listInvoiceItems).toHaveBeenCalledWith(
        {
          invoice_id: '550e8400-e29b-41d4-a716-446655440000',
          search: 'consult'
        },
        2,
        10,
        'created_at',
        'asc'
      );
    });
  });

  describe('getInvoiceItemById', () => {
    it('should return invoice item by id', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const mockItem = { id: req.params.id, description: 'Consultation fee' };
      invoiceItemService.getInvoiceItemById.mockResolvedValue(mockItem);

      await invoiceItemController.getInvoiceItemById(req, res);

      expect(invoiceItemService.getInvoiceItemById).toHaveBeenCalledWith(req.params.id);
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.invoice_item.get.success',
        mockItem
      );
    });
  });

  describe('createInvoiceItem', () => {
    it('should create invoice item', async () => {
      req.body = {
        invoice_id: '550e8400-e29b-41d4-a716-446655440000',
        description: 'Lab charge',
        unit_price: '20.00',
        total_price: '20.00'
      };
      const mockCreated = { id: 'item-1', ...req.body };
      invoiceItemService.createInvoiceItem.mockResolvedValue(mockCreated);

      await invoiceItemController.createInvoiceItem(req, res);

      expect(invoiceItemService.createInvoiceItem).toHaveBeenCalledWith(
        req.body,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.invoice_item.create.success',
        mockCreated
      );
    });
  });

  describe('updateInvoiceItem', () => {
    it('should update invoice item', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      req.body = { description: 'Updated description' };
      const mockUpdated = { id: req.params.id, ...req.body };
      invoiceItemService.updateInvoiceItem.mockResolvedValue(mockUpdated);

      await invoiceItemController.updateInvoiceItem(req, res);

      expect(invoiceItemService.updateInvoiceItem).toHaveBeenCalledWith(
        req.params.id,
        req.body,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.invoice_item.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteInvoiceItem', () => {
    it('should delete invoice item', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      invoiceItemService.deleteInvoiceItem.mockResolvedValue(undefined);

      await invoiceItemController.deleteInvoiceItem(req, res);

      expect(invoiceItemService.deleteInvoiceItem).toHaveBeenCalledWith(
        req.params.id,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});

