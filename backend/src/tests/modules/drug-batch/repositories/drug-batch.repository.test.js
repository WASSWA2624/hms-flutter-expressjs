const drugBatchRepository = require('@repositories/drug-batch/drug-batch.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  drug_batch: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Drug Batch Repository', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('findById', () => {
    it('should find drug batch by id', async () => {
      const mock = { id: '123', batch_number: 'BATCH001' };
      prisma.drug_batch.findFirst.mockResolvedValue(mock);
      expect(await drugBatchRepository.findById('123')).toEqual(mock);
    });

    it('should return null if not found', async () => {
      prisma.drug_batch.findFirst.mockResolvedValue(null);
      expect(await drugBatchRepository.findById('123')).toBeNull();
    });

    it('should throw HttpError on error', async () => {
      prisma.drug_batch.findFirst.mockRejectedValue(new Error('DB Error'));
      await expect(drugBatchRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many drug batches', async () => {
      const mocks = [{ id: '1' }, { id: '2' }];
      prisma.drug_batch.findMany.mockResolvedValue(mocks);
      expect(await drugBatchRepository.findMany({}, 0, 20)).toEqual(mocks);
    });
  });

  describe('count', () => {
    it('should count drug batches', async () => {
      prisma.drug_batch.count.mockResolvedValue(42);
      expect(await drugBatchRepository.count({})).toBe(42);
    });
  });

  describe('create', () => {
    it('should create drug batch', async () => {
      const mock = { id: '123', batch_number: 'BATCH001' };
      prisma.drug_batch.create.mockResolvedValue(mock);
      expect(await drugBatchRepository.create({ batch_number: 'BATCH001' })).toEqual(mock);
    });

    it('should handle constraint errors', async () => {
      const error = new Error('Constraint');
      error.code = 'P2002';
      error.meta = { target: ['batch_number'] };
      prisma.drug_batch.create.mockRejectedValue(error);
      await expect(drugBatchRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update drug batch', async () => {
      const mock = { id: '123', batch_number: 'BATCH002' };
      prisma.drug_batch.update.mockResolvedValue(mock);
      expect(await drugBatchRepository.update('123', { batch_number: 'BATCH002' })).toEqual(mock);
    });

    it('should throw on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.drug_batch.update.mockRejectedValue(error);
      await expect(drugBatchRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete drug batch', async () => {
      const mock = { id: '123', deleted_at: new Date() };
      prisma.drug_batch.update.mockResolvedValue(mock);
      expect(await drugBatchRepository.softDelete('123')).toEqual(mock);
    });
  });
});
