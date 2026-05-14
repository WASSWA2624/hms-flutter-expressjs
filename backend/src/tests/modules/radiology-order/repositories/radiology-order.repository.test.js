/**
 * Radiology Order repository tests
 *
 * @module tests/modules/radiology-order/repositories
 * @description Tests for radiology order repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const radiologyOrderRepository = require('@repositories/radiology-order/radiology-order.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  radiology_order: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Radiology Order Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyOrder = {
      id: radiologyOrderId,
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'ORDERED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z'),
      created_at: new Date('2026-01-19T09:00:00.000Z'),
      updated_at: new Date('2026-01-19T09:00:00.000Z'),
      deleted_at: null,
      version: 1
    };

    it('should find radiology order by ID', async () => {
      prisma.radiology_order.findFirst.mockResolvedValue(mockRadiologyOrder);

      const result = await radiologyOrderRepository.findById(radiologyOrderId);

      expect(result).toEqual(mockRadiologyOrder);
      expect(prisma.radiology_order.findFirst).toHaveBeenCalledWith({
        where: { id: radiologyOrderId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if radiology order not found', async () => {
      prisma.radiology_order.findFirst.mockResolvedValue(null);

      const result = await radiologyOrderRepository.findById(radiologyOrderId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted radiology orders', async () => {
      prisma.radiology_order.findFirst.mockResolvedValue(null);

      await radiologyOrderRepository.findById(radiologyOrderId);

      expect(prisma.radiology_order.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { patient: true, radiology_test: true };
      prisma.radiology_order.findFirst.mockResolvedValue(mockRadiologyOrder);

      await radiologyOrderRepository.findById(radiologyOrderId, include);

      expect(prisma.radiology_order.findFirst).toHaveBeenCalledWith({
        where: { id: radiologyOrderId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_order.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyOrderRepository.findById(radiologyOrderId)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.findById(radiologyOrderId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockRadiologyOrders = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440002',
        radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
        status: 'ORDERED',
        ordered_at: new Date('2026-01-19T09:00:00.000Z')
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440004',
        encounter_id: '550e8400-e29b-41d4-a716-446655440005',
        patient_id: '550e8400-e29b-41d4-a716-446655440006',
        radiology_test_id: '550e8400-e29b-41d4-a716-446655440007',
        status: 'IN_PROCESS',
        ordered_at: new Date('2026-01-19T10:00:00.000Z')
      }
    ];

    it('should find many radiology orders with default params', async () => {
      prisma.radiology_order.findMany.mockResolvedValue(mockRadiologyOrders);

      const result = await radiologyOrderRepository.findMany();

      expect(result).toEqual(mockRadiologyOrders);
      expect(prisma.radiology_order.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { patient_id: '550e8400-e29b-41d4-a716-446655440002', status: 'ORDERED' };
      prisma.radiology_order.findMany.mockResolvedValue(mockRadiologyOrders);

      await radiologyOrderRepository.findMany(filters);

      expect(prisma.radiology_order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.radiology_order.findMany.mockResolvedValue(mockRadiologyOrders);

      await radiologyOrderRepository.findMany({}, 20, 10);

      expect(prisma.radiology_order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { ordered_at: 'asc' };
      prisma.radiology_order.findMany.mockResolvedValue(mockRadiologyOrders);

      await radiologyOrderRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.radiology_order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { patient: true, encounter: true };
      prisma.radiology_order.findMany.mockResolvedValue(mockRadiologyOrders);

      await radiologyOrderRepository.findMany({}, 0, 20, { created_at: 'desc' }, include);

      expect(prisma.radiology_order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          include
        })
      );
    });

    it('should filter out soft-deleted radiology orders', async () => {
      prisma.radiology_order.findMany.mockResolvedValue(mockRadiologyOrders);

      await radiologyOrderRepository.findMany();

      expect(prisma.radiology_order.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_order.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyOrderRepository.findMany()).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.findMany()).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('count', () => {
    it('should count radiology orders with default filters', async () => {
      prisma.radiology_order.count.mockResolvedValue(42);

      const result = await radiologyOrderRepository.count();

      expect(result).toBe(42);
      expect(prisma.radiology_order.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count radiology orders with filters', async () => {
      const filters = { patient_id: '550e8400-e29b-41d4-a716-446655440002', status: 'COMPLETED' };
      prisma.radiology_order.count.mockResolvedValue(10);

      const result = await radiologyOrderRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.radiology_order.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should filter out soft-deleted radiology orders', async () => {
      prisma.radiology_order.count.mockResolvedValue(5);

      await radiologyOrderRepository.count();

      expect(prisma.radiology_order.count).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.radiology_order.count.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyOrderRepository.count()).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.count()).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('create', () => {
    const createData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'ORDERED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z')
    };

    const mockCreatedRadiologyOrder = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData,
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should create radiology order', async () => {
      prisma.radiology_order.create.mockResolvedValue(mockCreatedRadiologyOrder);

      const result = await radiologyOrderRepository.create(createData);

      expect(result).toEqual(mockCreatedRadiologyOrder);
      expect(prisma.radiology_order.create).toHaveBeenCalledWith({
        data: createData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const uniqueError = {
        code: 'P2002',
        meta: { target: ['patient_id', 'ordered_at'] }
      };
      prisma.radiology_order.create.mockRejectedValue(uniqueError);

      await expect(radiologyOrderRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const fkError = {
        code: 'P2003',
        meta: { field_name: 'patient_id' }
      };
      prisma.radiology_order.create.mockRejectedValue(fkError);

      await expect(radiologyOrderRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on general database error', async () => {
      prisma.radiology_order.create.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyOrderRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'COMPLETED'
    };

    const mockUpdatedRadiologyOrder = {
      id: radiologyOrderId,
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'COMPLETED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z'),
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 2
    };

    it('should update radiology order', async () => {
      prisma.radiology_order.update.mockResolvedValue(mockUpdatedRadiologyOrder);

      const result = await radiologyOrderRepository.update(radiologyOrderId, updateData);

      expect(result).toEqual(mockUpdatedRadiologyOrder);
      expect(prisma.radiology_order.update).toHaveBeenCalledWith({
        where: { id: radiologyOrderId },
        data: updateData
      });
    });

    it('should throw HttpError if radiology order not found', async () => {
      const notFoundError = { code: 'P2025' };
      prisma.radiology_order.update.mockRejectedValue(notFoundError);

      await expect(radiologyOrderRepository.update(radiologyOrderId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.update(radiologyOrderId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.radiology_order.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const uniqueError = {
        code: 'P2002',
        meta: { target: ['patient_id'] }
      };
      prisma.radiology_order.update.mockRejectedValue(uniqueError);

      await expect(radiologyOrderRepository.update(radiologyOrderId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.update(radiologyOrderId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const fkError = {
        code: 'P2003',
        meta: { field_name: 'encounter_id' }
      };
      prisma.radiology_order.update.mockRejectedValue(fkError);

      await expect(radiologyOrderRepository.update(radiologyOrderId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.update(radiologyOrderId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on general database error', async () => {
      prisma.radiology_order.update.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyOrderRepository.update(radiologyOrderId, updateData)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.update(radiologyOrderId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('softDelete', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const mockDeletedRadiologyOrder = {
      id: radiologyOrderId,
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'ORDERED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z'),
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: new Date(),
      version: 1
    };

    it('should soft delete radiology order', async () => {
      prisma.radiology_order.update.mockResolvedValue(mockDeletedRadiologyOrder);

      const result = await radiologyOrderRepository.softDelete(radiologyOrderId);

      expect(result).toEqual(mockDeletedRadiologyOrder);
      expect(prisma.radiology_order.update).toHaveBeenCalledWith({
        where: { id: radiologyOrderId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if radiology order not found', async () => {
      const notFoundError = { code: 'P2025' };
      prisma.radiology_order.update.mockRejectedValue(notFoundError);

      await expect(radiologyOrderRepository.softDelete(radiologyOrderId)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.softDelete(radiologyOrderId)).rejects.toMatchObject({
        messageKey: 'errors.radiology_order.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on general database error', async () => {
      prisma.radiology_order.update.mockRejectedValue(new Error('DB Error'));

      await expect(radiologyOrderRepository.softDelete(radiologyOrderId)).rejects.toThrow(HttpError);
      await expect(radiologyOrderRepository.softDelete(radiologyOrderId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });
});
