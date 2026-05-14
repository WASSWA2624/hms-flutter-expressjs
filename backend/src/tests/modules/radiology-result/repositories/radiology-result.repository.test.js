/**
 * Radiology Result repository tests
 *
 * @module tests/modules/radiology-result/repositories
 * @description Tests for radiology result repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const radiologyResultRepository = require('@repositories/radiology-result/radiology-result.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  radiology_result: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Radiology Result Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const radiologyResultId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyResult = {
      id: radiologyResultId,
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'DRAFT',
      report_text: 'Preliminary findings.',
      reported_at: new Date('2026-01-19T14:30:00.000Z'),
      created_at: new Date('2026-01-19T14:30:00.000Z'),
      updated_at: new Date('2026-01-19T14:30:00.000Z'),
      deleted_at: null,
      version: 1
    };

    it('should find radiology result by ID', async () => {
      prisma.radiology_result.findFirst.mockResolvedValue(mockRadiologyResult);

      const result = await radiologyResultRepository.findById(radiologyResultId);

      expect(result).toEqual(mockRadiologyResult);
      expect(prisma.radiology_result.findFirst).toHaveBeenCalledWith({
        where: { id: radiologyResultId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if radiology result not found', async () => {
      prisma.radiology_result.findFirst.mockResolvedValue(null);

      const result = await radiologyResultRepository.findById(radiologyResultId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted radiology results', async () => {
      prisma.radiology_result.findFirst.mockResolvedValue(null);

      await radiologyResultRepository.findById(radiologyResultId);

      expect(prisma.radiology_result.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { radiology_order: true };
      prisma.radiology_result.findFirst.mockResolvedValue(mockRadiologyResult);

      await radiologyResultRepository.findById(radiologyResultId, include);

      expect(prisma.radiology_result.findFirst).toHaveBeenCalledWith({
        where: { id: radiologyResultId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_result.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyResultRepository.findById(radiologyResultId)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.findById(radiologyResultId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockRadiologyResults = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'DRAFT',
        report_text: 'Preliminary findings.',
        reported_at: new Date('2026-01-19T14:30:00.000Z')
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        radiology_order_id: '550e8400-e29b-41d4-a716-446655440003',
        status: 'FINAL',
        report_text: 'Final report.',
        reported_at: new Date('2026-01-19T16:00:00.000Z')
      }
    ];

    it('should find many radiology results with default params', async () => {
      prisma.radiology_result.findMany.mockResolvedValue(mockRadiologyResults);

      const result = await radiologyResultRepository.findMany();

      expect(result).toEqual(mockRadiologyResults);
      expect(prisma.radiology_result.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { radiology_order_id: '550e8400-e29b-41d4-a716-446655440001', status: 'DRAFT' };
      prisma.radiology_result.findMany.mockResolvedValue(mockRadiologyResults);

      await radiologyResultRepository.findMany(filters);

      expect(prisma.radiology_result.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.radiology_result.findMany.mockResolvedValue(mockRadiologyResults);

      await radiologyResultRepository.findMany({}, 20, 10);

      expect(prisma.radiology_result.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { reported_at: 'asc' };
      prisma.radiology_result.findMany.mockResolvedValue(mockRadiologyResults);

      await radiologyResultRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.radiology_result.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { radiology_order: true };
      prisma.radiology_result.findMany.mockResolvedValue(mockRadiologyResults);

      await radiologyResultRepository.findMany({}, 0, 20, { created_at: 'desc' }, include);

      expect(prisma.radiology_result.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          include
        })
      );
    });

    it('should filter out soft-deleted radiology results', async () => {
      prisma.radiology_result.findMany.mockResolvedValue(mockRadiologyResults);

      await radiologyResultRepository.findMany();

      expect(prisma.radiology_result.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_result.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyResultRepository.findMany()).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.findMany()).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('count', () => {
    it('should count radiology results with default filters', async () => {
      prisma.radiology_result.count.mockResolvedValue(42);

      const result = await radiologyResultRepository.count();

      expect(result).toBe(42);
      expect(prisma.radiology_result.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count radiology results with filters', async () => {
      const filters = { radiology_order_id: '550e8400-e29b-41d4-a716-446655440001', status: 'FINAL' };
      prisma.radiology_result.count.mockResolvedValue(10);

      const result = await radiologyResultRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.radiology_result.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should filter out soft-deleted radiology results', async () => {
      prisma.radiology_result.count.mockResolvedValue(5);

      await radiologyResultRepository.count();

      expect(prisma.radiology_result.count).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_result.count.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyResultRepository.count()).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.count()).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('create', () => {
    const createData = {
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'DRAFT',
      report_text: 'Preliminary findings.',
      reported_at: new Date('2026-01-19T14:30:00.000Z')
    };

    const mockCreatedRadiologyResult = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData,
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should create radiology result', async () => {
      prisma.radiology_result.create.mockResolvedValue(mockCreatedRadiologyResult);

      const result = await radiologyResultRepository.create(createData);

      expect(result).toEqual(mockCreatedRadiologyResult);
      expect(prisma.radiology_result.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const uniqueError = {
        code: 'P2002',
        meta: { target: ['radiology_order_id'] }
      };
      prisma.radiology_result.create.mockRejectedValue(uniqueError);

      await expect(radiologyResultRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const fkError = {
        code: 'P2003',
        meta: { field_name: 'radiology_order_id' }
      };
      prisma.radiology_result.create.mockRejectedValue(fkError);

      await expect(radiologyResultRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on general database error', async () => {
      prisma.radiology_result.create.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyResultRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    const radiologyResultId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'FINAL'
    };

    const mockUpdatedRadiologyResult = {
      id: radiologyResultId,
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'FINAL',
      report_text: 'Final report.',
      reported_at: new Date('2026-01-19T16:00:00.000Z'),
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 2
    };

    it('should update radiology result', async () => {
      prisma.radiology_result.update.mockResolvedValue(mockUpdatedRadiologyResult);

      const result = await radiologyResultRepository.update(radiologyResultId, updateData);

      expect(result).toEqual(mockUpdatedRadiologyResult);
      expect(prisma.radiology_result.update).toHaveBeenCalledWith({
        where: { id: radiologyResultId },
        data: updateData
      });
    });

    it('should throw HttpError if radiology result not found', async () => {
      const notFoundError = { code: 'P2025' };
      prisma.radiology_result.update.mockRejectedValue(notFoundError);

      await expect(radiologyResultRepository.update(radiologyResultId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.update(radiologyResultId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.radiology_result.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const uniqueError = {
        code: 'P2002',
        meta: { target: ['radiology_order_id'] }
      };
      prisma.radiology_result.update.mockRejectedValue(uniqueError);

      await expect(radiologyResultRepository.update(radiologyResultId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.update(radiologyResultId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const fkError = {
        code: 'P2003',
        meta: { field_name: 'radiology_order_id' }
      };
      prisma.radiology_result.update.mockRejectedValue(fkError);

      await expect(radiologyResultRepository.update(radiologyResultId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.update(radiologyResultId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on general database error', async () => {
      prisma.radiology_result.update.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyResultRepository.update(radiologyResultId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.update(radiologyResultId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('softDelete', () => {
    const radiologyResultId = '550e8400-e29b-41d4-a716-446655440000';
    const mockDeletedRadiologyResult = {
      id: radiologyResultId,
      radiology_order_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'DRAFT',
      report_text: 'Preliminary findings.',
      reported_at: new Date('2026-01-19T14:30:00.000Z'),
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: new Date(),
      version: 1
    };

    it('should soft delete radiology result', async () => {
      prisma.radiology_result.update.mockResolvedValue(mockDeletedRadiologyResult);

      const result = await radiologyResultRepository.softDelete(radiologyResultId);

      expect(result).toEqual(mockDeletedRadiologyResult);
      expect(prisma.radiology_result.update).toHaveBeenCalledWith({
        where: { id: radiologyResultId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if radiology result not found', async () => {
      const notFoundError = { code: 'P2025' };
      prisma.radiology_result.update.mockRejectedValue(notFoundError);

      await expect(radiologyResultRepository.softDelete(radiologyResultId)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.softDelete(radiologyResultId)).rejects.toMatchObject({
        messageKey: 'errors.radiology_result.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on general database error', async () => {
      prisma.radiology_result.update.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyResultRepository.softDelete(radiologyResultId)).rejects.toThrow(HttpError);
      await expect(radiologyResultRepository.softDelete(radiologyResultId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });
});
