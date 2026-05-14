/**
 * Subscription Invoice controller tests
 *
 * @module tests/modules/subscription-invoice/controllers
 * @description Tests for subscription invoice controller layer
 */

const subscriptionInvoiceController = require('../../../../modules/subscription-invoice/controllers/subscription-invoice.controller');
const subscriptionInvoiceService = require('../../../../modules/subscription-invoice/services/subscription-invoice.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

jest.mock('../../../../modules/subscription-invoice/services/subscription-invoice.service');
jest.mock('@lib/response');

describe('Subscription Invoice Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    mockReq = {
      params: {},
      query: {},
      body: {},
      user: { id: 'user123' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn()
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getSubscriptionInvoice', () => {
    it('should get subscription invoice by ID', async () => {
      const mockInvoice = { id: '123', subscription_id: '456' };
      mockReq.params.id = '123';
      subscriptionInvoiceService.getSubscriptionInvoiceById.mockResolvedValue(mockInvoice);

      await subscriptionInvoiceController.getSubscriptionInvoice(mockReq, mockRes);

      expect(subscriptionInvoiceService.getSubscriptionInvoiceById).toHaveBeenCalledWith(
        '123',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.subscription_invoice.retrieved',
        mockInvoice
      );
    });
  });

  describe('listSubscriptionInvoices', () => {
    it('should list subscription invoices', async () => {
      const mockResult = {
        subscriptionInvoices: [{ id: '1' }, { id: '2' }],
        pagination: { page: 1, limit: 20, total: 2, totalPages: 1 }
      };
      mockReq.query = { page: '1', limit: '20' };
      subscriptionInvoiceService.listSubscriptionInvoices.mockResolvedValue(mockResult);

      await subscriptionInvoiceController.listSubscriptionInvoices(mockReq, mockRes);

      expect(subscriptionInvoiceService.listSubscriptionInvoices).toHaveBeenCalledWith(
        {},
        1,
        20,
        'created_at',
        'desc',
        mockReq.user
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.subscription_invoice.list_retrieved',
        mockResult.subscriptionInvoices,
        mockResult.pagination
      );
    });

    it('should apply filters', async () => {
      const mockResult = {
        subscriptionInvoices: [],
        pagination: { page: 1, limit: 20, total: 0, totalPages: 0 }
      };
      mockReq.query = { subscription_id: '456', invoice_id: '789' };
      subscriptionInvoiceService.listSubscriptionInvoices.mockResolvedValue(mockResult);

      await subscriptionInvoiceController.listSubscriptionInvoices(mockReq, mockRes);

      expect(subscriptionInvoiceService.listSubscriptionInvoices).toHaveBeenCalledWith(
        { subscription_id: '456', invoice_id: '789' },
        1,
        20,
        'created_at',
        'desc',
        mockReq.user
      );
    });
  });

  describe('createSubscriptionInvoice', () => {
    it('should create subscription invoice', async () => {
      const mockData = { subscription_id: '456', invoice_id: '789' };
      const mockCreated = { id: '123', ...mockData };
      mockReq.body = mockData;
      subscriptionInvoiceService.createSubscriptionInvoice.mockResolvedValue(mockCreated);

      await subscriptionInvoiceController.createSubscriptionInvoice(mockReq, mockRes);

      expect(subscriptionInvoiceService.createSubscriptionInvoice).toHaveBeenCalledWith(
        mockData,
        mockReq.user,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.subscription_invoice.created',
        mockCreated
      );
    });
  });

  describe('updateSubscriptionInvoice', () => {
    it('should update subscription invoice', async () => {
      const mockUpdated = { id: '123', invoice_id: '999' };
      mockReq.params.id = '123';
      mockReq.body = { invoice_id: '999' };
      subscriptionInvoiceService.updateSubscriptionInvoice.mockResolvedValue(mockUpdated);

      await subscriptionInvoiceController.updateSubscriptionInvoice(mockReq, mockRes);

      expect(subscriptionInvoiceService.updateSubscriptionInvoice).toHaveBeenCalledWith(
        '123',
        mockReq.body,
        mockReq.user,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.subscription_invoice.updated',
        mockUpdated
      );
    });
  });

  describe('deleteSubscriptionInvoice', () => {
    it('should delete subscription invoice', async () => {
      mockReq.params.id = '123';
      subscriptionInvoiceService.deleteSubscriptionInvoice.mockResolvedValue({});

      await subscriptionInvoiceController.deleteSubscriptionInvoice(mockReq, mockRes);

      expect(subscriptionInvoiceService.deleteSubscriptionInvoice).toHaveBeenCalledWith(
        '123',
        mockReq.user,
        mockReq.ip
      );
      expect(mockRes.status).toHaveBeenCalledWith(204);
      expect(mockRes.send).toHaveBeenCalled();
    });
  });
});
