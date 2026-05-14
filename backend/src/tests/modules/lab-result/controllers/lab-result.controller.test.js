/**
 * Lab result controller tests
 */

const labResultController = require('@controllers/lab-result/lab-result.controller');
const labResultService = require('@services/lab-result/lab-result.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/lab-result/lab-result.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Lab Result Controller', () => {
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

  describe('listLabResults', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        labResults: [{ id: '1', lab_order_item_id: '456', status: 'PENDING' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      labResultService.listLabResults.mockResolvedValue(mockResult);

      await labResultController.listLabResults(mockReq, mockRes);

      expect(labResultService.listLabResults).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.lab_result.list.success',
        mockResult.labResults,
        mockResult.pagination
      );
    });
  });

  describe('getLabResultById', () => {
    it('should call service and send success response', async () => {
      const mockLabResult = { id: '123', lab_order_item_id: '456', status: 'PENDING' };
      mockReq.params.id = '123';
      labResultService.getLabResultById.mockResolvedValue(mockLabResult);

      await labResultController.getLabResultById(mockReq, mockRes);

      expect(labResultService.getLabResultById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.lab_result.get.success', mockLabResult);
    });
  });

  describe('createLabResult', () => {
    it('should call service and send created response', async () => {
      const mockData = { lab_order_item_id: '456', status: 'PENDING' };
      const mockLabResult = { id: '123', ...mockData };
      mockReq.body = mockData;
      labResultService.createLabResult.mockResolvedValue(mockLabResult);

      await labResultController.createLabResult(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.lab_result.create.success', mockLabResult);
    });
  });

  describe('updateLabResult', () => {
    it('should call service and send success response', async () => {
      const mockData = { status: 'NORMAL' };
      const mockLabResult = { id: '123', ...mockData };
      mockReq.params.id = '123';
      mockReq.body = mockData;
      labResultService.updateLabResult.mockResolvedValue(mockLabResult);

      await labResultController.updateLabResult(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.lab_result.update.success', mockLabResult);
    });
  });

  describe('deleteLabResult', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      labResultService.deleteLabResult.mockResolvedValue();

      await labResultController.deleteLabResult(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
