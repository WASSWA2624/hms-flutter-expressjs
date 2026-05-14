/**
 * Lab test repository tests
 *
 * @module tests/modules/lab-test/repositories
 * @description Tests for lab test repository operations
 * Per testing.mdc: All repositories must be tested with mocked Prisma
 */

const labTestRepository = require('@repositories/lab-test/lab-test.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  lab_test: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Lab Test Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find lab test by ID successfully', async () => {
      const mockLabTest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Complete Blood Count',
        code: 'CBC',
        unit: 'cells/mcL',
        reference_range: '4,500-11,000',
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      prisma.lab_test.findFirst.mockResolvedValue(mockLabTest);

      const result = await labTestRepository.findById('123e4567-e89b-12d3-a456-426614174000');

      expect(result).toEqual(mockLabTest);
      expect(prisma.lab_test.findFirst).toHaveBeenCalledWith({
        where: {
          id: '123e4567-e89b-12d3-a456-426614174000',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null when lab test not found', async () => {
      prisma.lab_test.findFirst.mockResolvedValue(null);

      const result = await labTestRepository.findById('123e4567-e89b-12d3-a456-426614174000');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_test.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(labTestRepository.findById('123e4567-e89b-12d3-a456-426614174000'))
        .rejects.toThrow(HttpError);
    });

    it('should include relations when specified', async () => {
      const mockLabTest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count'
      };

      prisma.lab_test.findFirst.mockResolvedValue(mockLabTest);

      await labTestRepository.findById('123e4567-e89b-12d3-a456-426614174000', { tenant: true });

      expect(prisma.lab_test.findFirst).toHaveBeenCalledWith({
        where: {
          id: '123e4567-e89b-12d3-a456-426614174000',
          deleted_at: null
        },
        include: { tenant: true }
      });
    });
  });

  describe('findMany', () => {
    it('should find many lab tests successfully', async () => {
      const mockLabTests = [
        {
          id: '123e4567-e89b-12d3-a456-426614174000',
          name: 'Complete Blood Count',
          deleted_at: null
        },
        {
          id: '123e4567-e89b-12d3-a456-426614174001',
          name: 'Hemoglobin',
          deleted_at: null
        }
      ];

      prisma.lab_test.findMany.mockResolvedValue(mockLabTests);

      const result = await labTestRepository.findMany();

      expect(result).toEqual(mockLabTests);
      expect(prisma.lab_test.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters correctly', async () => {
      prisma.lab_test.findMany.mockResolvedValue([]);

      await labTestRepository.findMany({ tenant_id: '123e4567-e89b-12d3-a456-426614174000' });

      expect(prisma.lab_test.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: '123e4567-e89b-12d3-a456-426614174000'
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply pagination correctly', async () => {
      prisma.lab_test.findMany.mockResolvedValue([]);

      await labTestRepository.findMany({}, 10, 5);

      expect(prisma.lab_test.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 10,
        take: 5,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom order by', async () => {
      prisma.lab_test.findMany.mockResolvedValue([]);

      await labTestRepository.findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.lab_test.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_test.findMany.mockRejectedValue(new Error('Database error'));

      await expect(labTestRepository.findMany())
        .rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count lab tests successfully', async () => {
      prisma.lab_test.count.mockResolvedValue(10);

      const result = await labTestRepository.count();

      expect(result).toBe(10);
      expect(prisma.lab_test.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters when counting', async () => {
      prisma.lab_test.count.mockResolvedValue(5);

      await labTestRepository.count({ tenant_id: '123e4567-e89b-12d3-a456-426614174000' });

      expect(prisma.lab_test.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: '123e4567-e89b-12d3-a456-426614174000'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_test.count.mockRejectedValue(new Error('Database error'));

      await expect(labTestRepository.count())
        .rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create lab test successfully', async () => {
      const newLabTest = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Complete Blood Count',
        code: 'CBC',
        unit: 'cells/mcL',
        reference_range: '4,500-11,000'
      };

      const createdLabTest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        ...newLabTest,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      prisma.lab_test.create.mockResolvedValue(createdLabTest);

      const result = await labTestRepository.create(newLabTest);

      expect(result).toEqual(createdLabTest);
      expect(prisma.lab_test.create).toHaveBeenCalledWith({
        data: newLabTest
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['code'] };

      prisma.lab_test.create.mockRejectedValue(error);

      await expect(labTestRepository.create({ name: 'Test' }))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.lab_test.create.mockRejectedValue(error);

      await expect(labTestRepository.create({ name: 'Test' }))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.lab_test.create.mockRejectedValue(new Error('Database error'));

      await expect(labTestRepository.create({ name: 'Test' }))
        .rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update lab test successfully', async () => {
      const updateData = {
        name: 'Updated Lab Test'
      };

      const updatedLabTest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Updated Lab Test',
        code: 'CBC',
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };

      prisma.lab_test.update.mockResolvedValue(updatedLabTest);

      const result = await labTestRepository.update('123e4567-e89b-12d3-a456-426614174000', updateData);

      expect(result).toEqual(updatedLabTest);
      expect(prisma.lab_test.update).toHaveBeenCalledWith({
        where: { id: '123e4567-e89b-12d3-a456-426614174000' },
        data: updateData
      });
    });

    it('should throw HttpError when lab test not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.lab_test.update.mockRejectedValue(error);

      await expect(labTestRepository.update('123e4567-e89b-12d3-a456-426614174000', { name: 'Test' }))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['code'] };

      prisma.lab_test.update.mockRejectedValue(error);

      await expect(labTestRepository.update('123e4567-e89b-12d3-a456-426614174000', { name: 'Test' }))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.lab_test.update.mockRejectedValue(error);

      await expect(labTestRepository.update('123e4567-e89b-12d3-a456-426614174000', { name: 'Test' }))
        .rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete lab test successfully', async () => {
      const deletedLabTest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        deleted_at: new Date()
      };

      prisma.lab_test.update.mockResolvedValue(deletedLabTest);

      const result = await labTestRepository.softDelete('123e4567-e89b-12d3-a456-426614174000');

      expect(result).toEqual(deletedLabTest);
      expect(prisma.lab_test.update).toHaveBeenCalledWith({
        where: { id: '123e4567-e89b-12d3-a456-426614174000' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when lab test not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.lab_test.update.mockRejectedValue(error);

      await expect(labTestRepository.softDelete('123e4567-e89b-12d3-a456-426614174000'))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_test.update.mockRejectedValue(new Error('Database error'));

      await expect(labTestRepository.softDelete('123e4567-e89b-12d3-a456-426614174000'))
        .rejects.toThrow(HttpError);
    });
  });
});
