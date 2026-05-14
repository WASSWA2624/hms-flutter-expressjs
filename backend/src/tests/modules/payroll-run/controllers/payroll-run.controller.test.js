/**
 * Payroll run controller tests
 *
 * @module tests/modules/payroll-run/controllers
 * @description Tests for payroll run controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const payrollRunController = require('@controllers/payroll-run/payroll-run.controller');
const payrollRunService = require('@services/payroll-run/payroll-run.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/payroll-run/payroll-run.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Payroll Run Controller', () => {
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

  describe('listPayrollRuns', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        payrollRuns: [{ id: '1', status: 'DRAFT' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      payrollRunService.listPayrollRuns.mockResolvedValue(mockResult);

      await payrollRunController.listPayrollRuns(mockReq, mockRes);

      expect(payrollRunService.listPayrollRuns).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.payroll_run.list.success',
        mockResult.payrollRuns,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'period_start',
        order: 'desc',
        tenant_id: '123',
        status: 'PROCESSED'
      };
      payrollRunService.listPayrollRuns.mockResolvedValue({
        payrollRuns: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await payrollRunController.listPayrollRuns(mockReq, mockRes);

      expect(payrollRunService.listPayrollRuns).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123',
          status: 'PROCESSED'
        }),
        2,
        50,
        'period_start',
        'desc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getPayrollRunById', () => {
    it('should call service and send success response', async () => {
      const mockPayrollRun = { id: '123', status: 'DRAFT' };
      mockReq.params = { id: '123' };
      payrollRunService.getPayrollRunById.mockResolvedValue(mockPayrollRun);

      await payrollRunController.getPayrollRunById(mockReq, mockRes);

      expect(payrollRunService.getPayrollRunById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.payroll_run.get.success', mockPayrollRun);
    });
  });

  describe('createPayrollRun', () => {
    it('should call service and send success response', async () => {
      const mockData = { tenant_id: '123', period_start: new Date(), period_end: new Date() };
      const mockPayrollRun = { id: '456', ...mockData };
      mockReq.body = mockData;
      payrollRunService.createPayrollRun.mockResolvedValue(mockPayrollRun);

      await payrollRunController.createPayrollRun(mockReq, mockRes);

      expect(payrollRunService.createPayrollRun).toHaveBeenCalledWith(mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.payroll_run.create.success', mockPayrollRun);
    });
  });

  describe('updatePayrollRun', () => {
    it('should call service and send success response', async () => {
      const mockData = { status: 'PROCESSED' };
      const mockPayrollRun = { id: '123', ...mockData };
      mockReq.params = { id: '123' };
      mockReq.body = mockData;
      payrollRunService.updatePayrollRun.mockResolvedValue(mockPayrollRun);

      await payrollRunController.updatePayrollRun(mockReq, mockRes);

      expect(payrollRunService.updatePayrollRun).toHaveBeenCalledWith('123', mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.payroll_run.update.success', mockPayrollRun);
    });
  });

  describe('deletePayrollRun', () => {
    it('should call service and send no content response', async () => {
      mockReq.params = { id: '123' };
      payrollRunService.deletePayrollRun.mockResolvedValue();

      await payrollRunController.deletePayrollRun(mockReq, mockRes);

      expect(payrollRunService.deletePayrollRun).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
