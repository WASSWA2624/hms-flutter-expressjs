const drugBatchController = require('@controllers/drug-batch/drug-batch.controller');
const drugBatchService = require('@services/drug-batch/drug-batch.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/drug-batch/drug-batch.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({ DEFAULT_PAGE: 1, DEFAULT_PAGE_LIMIT: 20 }));

describe('Drug Batch Controller', () => {
  let mockReq, mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = { query: {}, params: {}, body: {}, user: { id: 'user-123' }, ip: '127.0.0.1' };
    mockRes = { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
  });

  describe('listDrugBatches', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = { drugBatches: [{ id: '1' }], pagination: { page: 1, limit: 20, total: 1 } };
      drugBatchService.listDrugBatches.mockResolvedValue(mockResult);

      await drugBatchController.listDrugBatches(mockReq, mockRes);
      expect(sendPaginated).toHaveBeenCalledWith(mockRes, 'messages.drug_batch.list.success', mockResult.drugBatches, mockResult.pagination);
    });
  });

  describe('getDrugBatchById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mock = { id: '123' };
      drugBatchService.getDrugBatchById.mockResolvedValue(mock);

      await drugBatchController.getDrugBatchById(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.drug_batch.get.success', mock);
    });
  });

  describe('createDrugBatch', () => {
    it('should call service and send success response', async () => {
      const mockData = { batch_number: 'BATCH001' };
      const mock = { id: '123', ...mockData };
      mockReq.body = mockData;
      drugBatchService.createDrugBatch.mockResolvedValue(mock);

      await drugBatchController.createDrugBatch(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.drug_batch.create.success', mock);
    });
  });

  describe('updateDrugBatch', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const updateData = { batch_number: 'BATCH002' };
      const mock = { id: '123', ...updateData };
      mockReq.body = updateData;
      drugBatchService.updateDrugBatch.mockResolvedValue(mock);

      await drugBatchController.updateDrugBatch(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.drug_batch.update.success', mock);
    });
  });

  describe('deleteDrugBatch', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      drugBatchService.deleteDrugBatch.mockResolvedValue();

      await drugBatchController.deleteDrugBatch(mockReq, mockRes);
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
