/**
 * Data processing log controller tests
 *
 * @module tests/modules/data-processing-log/controllers
 * @description Tests for data processing log controller layer
 */

const dataProcessingLogController = require('@modules/data-processing-log/controllers/data-processing-log.controller');
const dataProcessingLogService = require('@modules/data-processing-log/services/data-processing-log.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@modules/data-processing-log/services/data-processing-log.service');
jest.mock('@lib/response');

describe('Data Processing Log Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = { params: {}, query: {}, body: {}, user: { id: '123e4567-e89b-12d3-a456-426614174000' }, ip: '192.168.1.1' };
    res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
  });

  describe('getDataProcessingLogById', () => {
    it('should get data processing log by ID', async () => {
      const mockId = '123e4567-e89b-12d3-a456-426614174000';
      const mockLog = { id: mockId, purpose: 'TREATMENT' };
      req.params.id = mockId;
      dataProcessingLogService.getDataProcessingLogById.mockResolvedValue(mockLog);
      await dataProcessingLogController.getDataProcessingLogById(req, res);
      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.data_processing_log.retrieved', mockLog);
    });
  });

  describe('getDataProcessingLogs', () => {
    it('should get paginated data processing logs', async () => {
      const mockResult = { data: [{ id: '1' }], total: 1, page: 1, limit: 20, totalPages: 1 };
      req.query = { page: '1', limit: '20' };
      dataProcessingLogService.getDataProcessingLogs.mockResolvedValue(mockResult);
      await dataProcessingLogController.getDataProcessingLogs(req, res);
      expect(sendPaginated).toHaveBeenCalledWith(res, 'messages.data_processing_log.list_retrieved', mockResult.data, expect.any(Object));
    });
  });

  describe('createDataProcessingLog', () => {
    it('should create data processing log', async () => {
      const mockData = { tenant_id: '123e4567-e89b-12d3-a456-426614174000', purpose: 'TREATMENT', legal_basis: 'CONSENT' };
      const mockCreated = { id: '123e4567-e89b-12d3-a456-426614174003', ...mockData };
      req.body = mockData;
      dataProcessingLogService.createDataProcessingLog.mockResolvedValue(mockCreated);
      await dataProcessingLogController.createDataProcessingLog(req, res);
      expect(sendSuccess).toHaveBeenCalledWith(res, 201, 'messages.data_processing_log.created', mockCreated);
    });
  });

  describe('updateDataProcessingLog', () => {
    it('should update data processing log', async () => {
      const mockId = '123e4567-e89b-12d3-a456-426614174000';
      const mockData = { purpose: 'OPERATIONS' };
      const mockUpdated = { id: mockId, ...mockData };
      req.params.id = mockId;
      req.body = mockData;
      dataProcessingLogService.updateDataProcessingLog.mockResolvedValue(mockUpdated);
      await dataProcessingLogController.updateDataProcessingLog(req, res);
      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.data_processing_log.updated', mockUpdated);
    });
  });

  describe('deleteDataProcessingLog', () => {
    it('should delete data processing log', async () => {
      const mockId = '123e4567-e89b-12d3-a456-426614174000';
      req.params.id = mockId;
      dataProcessingLogService.deleteDataProcessingLog.mockResolvedValue({});
      await dataProcessingLogController.deleteDataProcessingLog(req, res);
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
