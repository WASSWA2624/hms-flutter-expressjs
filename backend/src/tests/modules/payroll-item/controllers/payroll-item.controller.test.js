/**
 * Payroll item controller tests
 *
 * @module tests/modules/payroll-item/controllers
 * @description Tests for payroll item controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const payrollItemController = require('@controllers/payroll-item/payroll-item.controller');
const payrollItemService = require('@services/payroll-item/payroll-item.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/payroll-item/payroll-item.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Payroll Item Controller', () => {
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

  describe('listPayrollItems', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        payrollItems: [{ id: '1', amount: 5000 }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      payrollItemService.listPayrollItems.mockResolvedValue(mockResult);

      await payrollItemController.listPayrollItems(mockReq, mockRes);

      expect(payrollItemService.listPayrollItems).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.payroll_item.list.success',
        mockResult.payrollItems,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'amount',
        order: 'desc',
        payroll_run_id: '123',
        staff_profile_id: 'staff-123',
        currency: 'USD',
        amount_min: '1000',
        amount_max: '5000'
      };
      payrollItemService.listPayrollItems.mockResolvedValue({
        payrollItems: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await payrollItemController.listPayrollItems(mockReq, mockRes);

      expect(payrollItemService.listPayrollItems).toHaveBeenCalledWith(
        expect.objectContaining({
          payroll_run_id: '123',
          staff_profile_id: 'staff-123',
          currency: 'USD',
          amount_min: '1000',
          amount_max: '5000'
        }),
        2,
        50,
        'amount',
        'desc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getPayrollItemById', () => {
    it('should call service and send success response', async () => {
      const mockPayrollItem = { id: '123', amount: 5000 };
      mockReq.params = { id: '123' };
      payrollItemService.getPayrollItemById.mockResolvedValue(mockPayrollItem);

      await payrollItemController.getPayrollItemById(mockReq, mockRes);

      expect(payrollItemService.getPayrollItemById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.payroll_item.get.success', mockPayrollItem);
    });
  });

  describe('createPayrollItem', () => {
    it('should call service and send success response', async () => {
      const mockData = { payroll_run_id: '123', staff_profile_id: 'staff-123', amount: 5000, currency: 'USD' };
      const mockPayrollItem = { id: '456', ...mockData };
      mockReq.body = mockData;
      payrollItemService.createPayrollItem.mockResolvedValue(mockPayrollItem);

      await payrollItemController.createPayrollItem(mockReq, mockRes);

      expect(payrollItemService.createPayrollItem).toHaveBeenCalledWith(mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.payroll_item.create.success', mockPayrollItem);
    });
  });

  describe('updatePayrollItem', () => {
    it('should call service and send success response', async () => {
      const mockData = { amount: 5500 };
      const mockPayrollItem = { id: '123', ...mockData };
      mockReq.params = { id: '123' };
      mockReq.body = mockData;
      payrollItemService.updatePayrollItem.mockResolvedValue(mockPayrollItem);

      await payrollItemController.updatePayrollItem(mockReq, mockRes);

      expect(payrollItemService.updatePayrollItem).toHaveBeenCalledWith('123', mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.payroll_item.update.success', mockPayrollItem);
    });
  });

  describe('deletePayrollItem', () => {
    it('should call service and send no content response', async () => {
      mockReq.params = { id: '123' };
      payrollItemService.deletePayrollItem.mockResolvedValue();

      await payrollItemController.deletePayrollItem(mockReq, mockRes);

      expect(payrollItemService.deletePayrollItem).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
