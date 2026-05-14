/**
 * Radiology test repository tests
 *
 * @module tests/modules/radiology-test/repositories
 * @description Tests for radiology test repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const radiologyTestRepository = require('@repositories/radiology-test/radiology-test.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  radiology_test: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Radiology Test Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyTest = {
      id: radiologyTestId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    it('should find radiology test by ID', async () => {
      prisma.radiology_test.findFirst.mockResolvedValue(mockRadiologyTest);

      const result = await radiologyTestRepository.findById(radiologyTestId);

      expect(result).toEqual(mockRadiologyTest);
      expect(prisma.radiology_test.findFirst).toHaveBeenCalledWith({
        where: { id: radiologyTestId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if radiology test not found', async () => {
      prisma.radiology_test.findFirst.mockResolvedValue(null);

      const result = await radiologyTestRepository.findById(radiologyTestId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted radiology tests', async () => {
      prisma.radiology_test.findFirst.mockResolvedValue(null);

      await radiologyTestRepository.findById(radiologyTestId);

      expect(prisma.radiology_test.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { orders: true };
      prisma.radiology_test.findFirst.mockResolvedValue(mockRadiologyTest);

      await radiologyTestRepository.findById(radiologyTestId, include);

      expect(prisma.radiology_test.findFirst).toHaveBeenCalledWith({
        where: { id: radiologyTestId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_test.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyTestRepository.findById(radiologyTestId)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.findById(radiologyTestId)).rejects.toMatchObject({
        message: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockRadiologyTests = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Chest X-Ray',
        code: 'CXR-001',
        modality: 'XRAY'
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440001',
        name: 'Brain MRI',
        code: 'MRI-001',
        modality: 'MRI'
      }
    ];

    it('should find many radiology tests with default params', async () => {
      prisma.radiology_test.findMany.mockResolvedValue(mockRadiologyTests);

      const result = await radiologyTestRepository.findMany();

      expect(result).toEqual(mockRadiologyTests);
      expect(prisma.radiology_test.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '550e8400-e29b-41d4-a716-446655440002', modality: 'XRAY' };
      prisma.radiology_test.findMany.mockResolvedValue(mockRadiologyTests);

      await radiologyTestRepository.findMany(filters);

      expect(prisma.radiology_test.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.radiology_test.findMany.mockResolvedValue(mockRadiologyTests);

      await radiologyTestRepository.findMany({}, 20, 10);

      expect(prisma.radiology_test.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { name: 'asc' };
      prisma.radiology_test.findMany.mockResolvedValue(mockRadiologyTests);

      await radiologyTestRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.radiology_test.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy })
      );
    });

    it('should accept include parameter', async () => {
      const include = { orders: true };
      prisma.radiology_test.findMany.mockResolvedValue(mockRadiologyTests);

      await radiologyTestRepository.findMany({}, 0, 20, { created_at: 'desc' }, include);

      expect(prisma.radiology_test.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ include })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_test.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyTestRepository.findMany()).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.findMany()).rejects.toMatchObject({
        message: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('count', () => {
    it('should count radiology tests', async () => {
      prisma.radiology_test.count.mockResolvedValue(5);

      const result = await radiologyTestRepository.count();

      expect(result).toBe(5);
      expect(prisma.radiology_test.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters to count', async () => {
      const filters = { modality: 'XRAY' };
      prisma.radiology_test.count.mockResolvedValue(3);

      await radiologyTestRepository.count(filters);

      expect(prisma.radiology_test.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_test.count.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyTestRepository.count()).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.count()).rejects.toMatchObject({
        message: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('create', () => {
    const createData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY'
    };

    const mockCreatedRadiologyTest = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData
    };

    it('should create radiology test', async () => {
      prisma.radiology_test.create.mockResolvedValue(mockCreatedRadiologyTest);

      const result = await radiologyTestRepository.create(createData);

      expect(result).toEqual(mockCreatedRadiologyTest);
      expect(prisma.radiology_test.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['code'] };
      prisma.radiology_test.create.mockRejectedValue(error);

      await expect(radiologyTestRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.create(createData)).rejects.toMatchObject({
        message: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.radiology_test.create.mockRejectedValue(error);

      await expect(radiologyTestRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.create(createData)).rejects.toMatchObject({
        message: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.radiology_test.create.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyTestRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.create(createData)).rejects.toMatchObject({
        message: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      name: 'Updated X-Ray',
      modality: 'CT'
    };

    const mockUpdatedRadiologyTest = {
      id: radiologyTestId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      ...updateData
    };

    it('should update radiology test', async () => {
      prisma.radiology_test.update.mockResolvedValue(mockUpdatedRadiologyTest);

      const result = await radiologyTestRepository.update(radiologyTestId, updateData);

      expect(result).toEqual(mockUpdatedRadiologyTest);
      expect(prisma.radiology_test.update).toHaveBeenCalledWith({
        where: { id: radiologyTestId },
        data: updateData
      });
    });

    it('should throw HttpError if radiology test not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.radiology_test.update.mockRejectedValue(error);

      await expect(radiologyTestRepository.update(radiologyTestId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.update(radiologyTestId, updateData)).rejects.toMatchObject({
        message: 'errors.radiology_test.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['code'] };
      prisma.radiology_test.update.mockRejectedValue(error);

      await expect(radiologyTestRepository.update(radiologyTestId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.update(radiologyTestId, updateData)).rejects.toMatchObject({
        message: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.radiology_test.update.mockRejectedValue(error);

      await expect(radiologyTestRepository.update(radiologyTestId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.update(radiologyTestId, updateData)).rejects.toMatchObject({
        message: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.radiology_test.update.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyTestRepository.update(radiologyTestId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.update(radiologyTestId, updateData)).rejects.toMatchObject({
        message: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('softDelete', () => {
    const radiologyTestId = '550e8400-e29b-41d4-a716-446655440000';
    const mockDeletedRadiologyTest = {
      id: radiologyTestId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'Chest X-Ray',
      code: 'CXR-001',
      modality: 'XRAY',
      deleted_at: new Date()
    };

    it('should soft delete radiology test', async () => {
      prisma.radiology_test.update.mockResolvedValue(mockDeletedRadiologyTest);

      const result = await radiologyTestRepository.softDelete(radiologyTestId);

      expect(result).toEqual(mockDeletedRadiologyTest);
      expect(prisma.radiology_test.update).toHaveBeenCalledWith({
        where: { id: radiologyTestId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if radiology test not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.radiology_test.update.mockRejectedValue(error);

      await expect(radiologyTestRepository.softDelete(radiologyTestId)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.softDelete(radiologyTestId)).rejects.toMatchObject({
        message: 'errors.radiology_test.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.radiology_test.update.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyTestRepository.softDelete(radiologyTestId)).rejects.toThrow(HttpError);
      await expect(radiologyTestRepository.softDelete(radiologyTestId)).rejects.toMatchObject({
        message: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });
});
