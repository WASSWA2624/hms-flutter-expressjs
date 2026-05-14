/**
 * Lab sample repository tests
 *
 * @module tests/modules/lab-sample/repositories
 * @description Tests for lab sample repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const labSampleRepository = require('@repositories/lab-sample/lab-sample.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  lab_sample: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Lab Sample Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find lab sample by id', async () => {
      const mockLabSample = {
        id: '123',
        lab_order_id: '456',
        status: 'PENDING',
        collected_at: null,
        received_at: null
      };
      prisma.lab_sample.findFirst.mockResolvedValue(mockLabSample);

      const result = await labSampleRepository.findById('123');
      expect(result).toEqual(mockLabSample);
      expect(prisma.lab_sample.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if lab sample not found', async () => {
      prisma.lab_sample.findFirst.mockResolvedValue(null);

      const result = await labSampleRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_sample.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(labSampleRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockLabSample = { id: '123', status: 'PENDING' };
      const include = { lab_order: true };
      prisma.lab_sample.findFirst.mockResolvedValue(mockLabSample);

      await labSampleRepository.findById('123', include);
      expect(prisma.lab_sample.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many lab samples with pagination', async () => {
      const mockLabSamples = [
        { id: '1', lab_order_id: '456', status: 'PENDING' },
        { id: '2', lab_order_id: '789', status: 'COLLECTED' }
      ];
      prisma.lab_sample.findMany.mockResolvedValue(mockLabSamples);

      const result = await labSampleRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockLabSamples);
      expect(prisma.lab_sample.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { lab_order_id: '456', status: 'PENDING' };
      prisma.lab_sample.findMany.mockResolvedValue([]);

      await labSampleRepository.findMany(filters, 0, 20);
      expect(prisma.lab_sample.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom ordering', async () => {
      const orderBy = { status: 'asc' };
      prisma.lab_sample.findMany.mockResolvedValue([]);

      await labSampleRepository.findMany({}, 0, 20, orderBy);
      expect(prisma.lab_sample.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_sample.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(labSampleRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count lab samples', async () => {
      prisma.lab_sample.count.mockResolvedValue(42);

      const result = await labSampleRepository.count({});
      expect(result).toBe(42);
    });

    it('should count with filters', async () => {
      const filters = { status: 'PENDING' };
      prisma.lab_sample.count.mockResolvedValue(10);

      const result = await labSampleRepository.count(filters);
      expect(result).toBe(10);
      expect(prisma.lab_sample.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_sample.count.mockRejectedValue(new Error('DB Error'));

      await expect(labSampleRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create lab sample', async () => {
      const mockData = {
        lab_order_id: '456',
        status: 'PENDING',
        collected_at: null,
        received_at: null
      };
      const mockLabSample = { id: '123', ...mockData };
      prisma.lab_sample.create.mockResolvedValue(mockLabSample);

      const result = await labSampleRepository.create(mockData);
      expect(result).toEqual(mockLabSample);
      expect(prisma.lab_sample.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.lab_sample.create.mockRejectedValue(error);

      await expect(labSampleRepository.create({})).rejects.toThrow(HttpError);
      await expect(labSampleRepository.create({})).rejects.toThrow('errors.database.unique_field');
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'lab_order_id' };
      prisma.lab_sample.create.mockRejectedValue(error);

      await expect(labSampleRepository.create({})).rejects.toThrow(HttpError);
      await expect(labSampleRepository.create({})).rejects.toThrow('errors.database.foreign_key_field');
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.lab_sample.create.mockRejectedValue(new Error('DB Error'));

      await expect(labSampleRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update lab sample', async () => {
      const mockData = { status: 'COLLECTED' };
      const mockLabSample = { id: '123', ...mockData };
      prisma.lab_sample.update.mockResolvedValue(mockLabSample);

      const result = await labSampleRepository.update('123', mockData);
      expect(result).toEqual(mockLabSample);
      expect(prisma.lab_sample.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: mockData
      });
    });

    it('should throw HttpError when lab sample not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.lab_sample.update.mockRejectedValue(error);

      await expect(labSampleRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
      await expect(labSampleRepository.update('nonexistent', {})).rejects.toThrow('errors.lab_sample.not_found');
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.lab_sample.update.mockRejectedValue(error);

      await expect(labSampleRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'lab_order_id' };
      prisma.lab_sample.update.mockRejectedValue(error);

      await expect(labSampleRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete lab sample', async () => {
      const mockLabSample = { id: '123', deleted_at: new Date() };
      prisma.lab_sample.update.mockResolvedValue(mockLabSample);

      const result = await labSampleRepository.softDelete('123');
      expect(result).toEqual(mockLabSample);
      expect(prisma.lab_sample.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when lab sample not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.lab_sample.update.mockRejectedValue(error);

      await expect(labSampleRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
      await expect(labSampleRepository.softDelete('nonexistent')).rejects.toThrow('errors.lab_sample.not_found');
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.lab_sample.update.mockRejectedValue(new Error('DB Error'));

      await expect(labSampleRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
