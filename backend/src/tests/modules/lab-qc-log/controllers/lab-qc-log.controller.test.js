/**
 * Lab QC log controller tests
 */

const labQcLogController = require('@controllers/lab-qc-log/lab-qc-log.controller');
const labQcLogService = require('@services/lab-qc-log/lab-qc-log.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/lab-qc-log/lab-qc-log.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Lab QC Log Controller', () => {
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

  describe('listLabQcLogs', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        labQcLogs: [{ id: '1', lab_test_id: '456', status: 'Passed' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      labQcLogService.listLabQcLogs.mockResolvedValue(mockResult);

      await labQcLogController.listLabQcLogs(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.lab_qc_log.list.success',
        mockResult.labQcLogs,
        mockResult.pagination
      );
    });
  });

  describe('getLabQcLogById', () => {
    it('should call service and send success response', async () => {
      const mockLabQcLog = { id: '123', lab_test_id: '456', status: 'Passed' };
      mockReq.params.id = '123';
      labQcLogService.getLabQcLogById.mockResolvedValue(mockLabQcLog);

      await labQcLogController.getLabQcLogById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.lab_qc_log.get.success', mockLabQcLog);
    });
  });

  describe('createLabQcLog', () => {
    it('should call service and send created response', async () => {
      const mockData = { lab_test_id: '456', status: 'Passed' };
      const mockLabQcLog = { id: '123', ...mockData };
      mockReq.body = mockData;
      labQcLogService.createLabQcLog.mockResolvedValue(mockLabQcLog);

      await labQcLogController.createLabQcLog(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.lab_qc_log.create.success', mockLabQcLog);
    });
  });

  describe('updateLabQcLog', () => {
    it('should call service and send success response', async () => {
      const mockData = { status: 'Failed' };
      const mockLabQcLog = { id: '123', ...mockData };
      mockReq.params.id = '123';
      mockReq.body = mockData;
      labQcLogService.updateLabQcLog.mockResolvedValue(mockLabQcLog);

      await labQcLogController.updateLabQcLog(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.lab_qc_log.update.success', mockLabQcLog);
    });
  });

  describe('deleteLabQcLog', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      labQcLogService.deleteLabQcLog.mockResolvedValue();

      await labQcLogController.deleteLabQcLog(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
