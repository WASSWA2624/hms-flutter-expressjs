const drugBatchService = require('@services/drug-batch/drug-batch.service');
const drugBatchRepository = require('@repositories/drug-batch/drug-batch.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/drug-batch/drug-batch.repository');
jest.mock('@lib/audit');

describe('Drug Batch Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listDrugBatches', () => {
    it('should list drug batches with pagination', async () => {
      drugBatchRepository.findMany.mockResolvedValue([{ id: '1' }]);
      drugBatchRepository.count.mockResolvedValue(1);

      const result = await drugBatchService.listDrugBatches({}, 1, 20, null, 'asc', mockUserId, mockIpAddress);
      expect(result.drugBatches).toHaveLength(1);
      expect(result.pagination.total).toBe(1);
    });

    it('should handle expiry filter', async () => {
      drugBatchRepository.findMany.mockResolvedValue([]);
      drugBatchRepository.count.mockResolvedValue(0);

      await drugBatchService.listDrugBatches({ expired: true }, 1, 20, null, 'asc', mockUserId, mockIpAddress);
      expect(drugBatchRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ expiry_date: { lt: expect.any(Date) } }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });
  });

  describe('getDrugBatchById', () => {
    it('should get drug batch by id', async () => {
      const mock = { id: '123' };
      drugBatchRepository.findById.mockResolvedValue(mock);
      expect(await drugBatchService.getDrugBatchById('123', mockUserId, mockIpAddress)).toEqual(mock);
    });

    it('should throw if not found', async () => {
      drugBatchRepository.findById.mockResolvedValue(null);
      await expect(drugBatchService.getDrugBatchById('123', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('createDrugBatch', () => {
    it('should create drug batch and log audit', async () => {
      const mock = { id: '123', batch_number: 'BATCH001' };
      drugBatchRepository.create.mockResolvedValue(mock);

      const result = await drugBatchService.createDrugBatch({ batch_number: 'BATCH001' }, mockUserId, mockIpAddress);
      expect(result).toEqual(mock);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ action: 'CREATE', entity: 'drug_batch' }));
    });
  });

  describe('updateDrugBatch', () => {
    it('should update drug batch and log audit', async () => {
      const mockBefore = { id: '123', batch_number: 'BATCH001' };
      const mockAfter = { id: '123', batch_number: 'BATCH002' };
      drugBatchRepository.findById.mockResolvedValue(mockBefore);
      drugBatchRepository.update.mockResolvedValue(mockAfter);

      const result = await drugBatchService.updateDrugBatch('123', { batch_number: 'BATCH002' }, mockUserId, mockIpAddress);
      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ action: 'UPDATE' }));
    });
  });

  describe('deleteDrugBatch', () => {
    it('should soft delete drug batch and log audit', async () => {
      const mock = { id: '123' };
      drugBatchRepository.findById.mockResolvedValue(mock);
      drugBatchRepository.softDelete.mockResolvedValue({ id: '123', deleted_at: new Date() });

      await drugBatchService.deleteDrugBatch('123', mockUserId, mockIpAddress);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ action: 'DELETE' }));
    });
  });
});
