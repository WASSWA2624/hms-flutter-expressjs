/**
 * Lab QC log repository tests
 */

const labQcLogRepository = require('@repositories/lab-qc-log/lab-qc-log.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  lab_qc_log: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Lab QC Log Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find lab QC log by id', async () => {
      const mockLabQcLog = { id: '123', lab_test_id: '456', status: 'Passed' };
      prisma.lab_qc_log.findFirst.mockResolvedValue(mockLabQcLog);

      const result = await labQcLogRepository.findById('123');
      expect(result).toEqual(mockLabQcLog);
    });

    it('should return null if not found', async () => {
      prisma.lab_qc_log.findFirst.mockResolvedValue(null);
      const result = await labQcLogRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_qc_log.findFirst.mockRejectedValue(new Error('DB Error'));
      await expect(labQcLogRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many lab QC logs', async () => {
      const mockLabQcLogs = [{ id: '1' }, { id: '2' }];
      prisma.lab_qc_log.findMany.mockResolvedValue(mockLabQcLogs);

      const result = await labQcLogRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockLabQcLogs);
    });
  });

  describe('count', () => {
    it('should count lab QC logs', async () => {
      prisma.lab_qc_log.count.mockResolvedValue(42);
      const result = await labQcLogRepository.count({});
      expect(result).toBe(42);
    });
  });

  describe('create', () => {
    it('should create lab QC log', async () => {
      const mockData = { lab_test_id: '456', status: 'Passed' };
      const mockLabQcLog = { id: '123', ...mockData };
      prisma.lab_qc_log.create.mockResolvedValue(mockLabQcLog);

      const result = await labQcLogRepository.create(mockData);
      expect(result).toEqual(mockLabQcLog);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'lab_test_id' };
      prisma.lab_qc_log.create.mockRejectedValue(error);
      await expect(labQcLogRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update lab QC log', async () => {
      const mockData = { status: 'Failed' };
      const mockLabQcLog = { id: '123', ...mockData };
      prisma.lab_qc_log.update.mockResolvedValue(mockLabQcLog);

      const result = await labQcLogRepository.update('123', mockData);
      expect(result).toEqual(mockLabQcLog);
    });

    it('should throw HttpError when not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.lab_qc_log.update.mockRejectedValue(error);
      await expect(labQcLogRepository.update('nonexistent', {})).rejects.toThrow('errors.lab_qc_log.not_found');
    });
  });

  describe('softDelete', () => {
    it('should soft delete lab QC log', async () => {
      const mockLabQcLog = { id: '123', deleted_at: new Date() };
      prisma.lab_qc_log.update.mockResolvedValue(mockLabQcLog);

      const result = await labQcLogRepository.softDelete('123');
      expect(result).toEqual(mockLabQcLog);
    });

    it('should throw HttpError when not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.lab_qc_log.update.mockRejectedValue(error);
      await expect(labQcLogRepository.softDelete('nonexistent')).rejects.toThrow('errors.lab_qc_log.not_found');
    });
  });
});
