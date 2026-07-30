/**
 * Lab result repository tests
 */

const labResultRepository = require('@repositories/lab-result/lab-result.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  lab_result: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Lab Result Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find lab result by id', async () => {
      const mockLabResult = { id: '123', lab_order_item_id: '456', status: 'PENDING' };
      prisma.lab_result.findFirst.mockResolvedValue(mockLabResult);

      const result = await labResultRepository.findById('123');
      expect(result).toEqual(mockLabResult);
      expect(prisma.lab_result.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.lab_result.findFirst.mockResolvedValue(null);
      const result = await labResultRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_result.findFirst.mockRejectedValue(new Error('DB Error'));
      await expect(labResultRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many lab results', async () => {
      const mockLabResults = [{ id: '1' }, { id: '2' }];
      prisma.lab_result.findMany.mockResolvedValue(mockLabResults);

      const result = await labResultRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockLabResults);
    });
  });

  describe('count', () => {
    it('should count lab results', async () => {
      prisma.lab_result.count.mockResolvedValue(42);
      const result = await labResultRepository.count({});
      expect(result).toBe(42);
    });
  });

  describe('create', () => {
    it('should create lab result', async () => {
      const mockData = { lab_order_item_id: '456', status: 'PENDING' };
      const mockLabResult = { id: '123', ...mockData };
      prisma.lab_result.create.mockResolvedValue(mockLabResult);

      const result = await labResultRepository.create(mockData);
      expect(result).toEqual(mockLabResult);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.lab_result.create.mockRejectedValue(error);
      await expect(labResultRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'lab_order_item_id' };
      prisma.lab_result.create.mockRejectedValue(error);
      await expect(labResultRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update lab result', async () => {
      const mockData = { status: 'NORMAL' };
      const mockLabResult = { id: '123', ...mockData };
      prisma.lab_result.update.mockResolvedValue(mockLabResult);

      const result = await labResultRepository.update('123', mockData);
      expect(result).toEqual(mockLabResult);
    });

    it('should throw HttpError when not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.lab_result.update.mockRejectedValue(error);
      await expect(labResultRepository.update('nonexistent', {})).rejects.toThrow('errors.lab_result.not_found');
    });
  });

  describe('softDelete', () => {
    it('should soft delete lab result', async () => {
      const mockLabResult = { id: '123', deleted_at: new Date() };
      prisma.lab_result.update.mockResolvedValue(mockLabResult);

      const result = await labResultRepository.softDelete('123');
      expect(result).toEqual(mockLabResult);
    });

    it('should throw HttpError when not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.lab_result.update.mockRejectedValue(error);
      await expect(labResultRepository.softDelete('nonexistent')).rejects.toThrow('errors.lab_result.not_found');
    });
  });
});
