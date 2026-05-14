/**
 * Pharmacy order repository tests
 *
 * @module tests/modules/pharmacy-order/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  pharmacy_order: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/pharmacy-order/pharmacy-order.repository');

const prisma = require('@prisma/client');

describe('Pharmacy Order Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find pharmacy order by ID', async () => {
      const mockPharmacyOrder = {
        id: 'order-123',
        encounter_id: 'encounter-123',
        patient_id: 'patient-123',
        status: 'ORDERED',
        ordered_at: new Date('2026-01-19T12:00:00.000Z'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.pharmacy_order.findFirst.mockResolvedValue(mockPharmacyOrder);

      const result = await findById('order-123');

      expect(result).toEqual(mockPharmacyOrder);
      expect(prisma.pharmacy_order.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'order-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should find pharmacy order with includes', async () => {
      const mockPharmacyOrder = {
        id: 'order-123',
        patient_id: 'patient-123',
        status: 'ORDERED',
        patient: { id: 'patient-123', first_name: 'John' }
      };
      prisma.pharmacy_order.findFirst.mockResolvedValue(mockPharmacyOrder);

      const result = await findById('order-123', { patient: true });

      expect(result).toEqual(mockPharmacyOrder);
      expect(prisma.pharmacy_order.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'order-123',
          deleted_at: null
        },
        include: { patient: true }
      });
    });

    it('should return null if pharmacy order not found', async () => {
      prisma.pharmacy_order.findFirst.mockResolvedValue(null);

      const result = await findById('order-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.pharmacy_order.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('order-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many pharmacy orders with default pagination', async () => {
      const mockPharmacyOrders = [
        {
          id: 'order-1',
          patient_id: 'patient-123',
          status: 'ORDERED',
          ordered_at: new Date('2026-01-19T12:00:00.000Z')
        },
        {
          id: 'order-2',
          patient_id: 'patient-456',
          status: 'DISPENSED',
          ordered_at: new Date('2026-01-18T10:00:00.000Z')
        }
      ];
      prisma.pharmacy_order.findMany.mockResolvedValue(mockPharmacyOrders);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockPharmacyOrders);
      expect(prisma.pharmacy_order.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { ordered_at: 'desc' },
        include: {}
      });
    });

    it('should find pharmacy orders with filters', async () => {
      const mockPharmacyOrders = [
        {
          id: 'order-1',
          patient_id: 'patient-123',
          status: 'ORDERED',
          ordered_at: new Date('2026-01-19T12:00:00.000Z')
        }
      ];
      prisma.pharmacy_order.findMany.mockResolvedValue(mockPharmacyOrders);

      const result = await findMany({ 
        patient_id: 'patient-123', 
        status: 'ORDERED'
      }, 0, 10);

      expect(result).toEqual(mockPharmacyOrders);
      expect(prisma.pharmacy_order.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123',
          status: 'ORDERED'
        },
        skip: 0,
        take: 10,
        orderBy: { ordered_at: 'desc' },
        include: {}
      });
    });

    it('should find pharmacy orders with custom pagination', async () => {
      const mockPharmacyOrders = [];
      prisma.pharmacy_order.findMany.mockResolvedValue(mockPharmacyOrders);

      const result = await findMany({}, 20, 50);

      expect(result).toEqual(mockPharmacyOrders);
      expect(prisma.pharmacy_order.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 50,
        orderBy: { ordered_at: 'desc' },
        include: {}
      });
    });

    it('should find pharmacy orders with custom order', async () => {
      const mockPharmacyOrders = [];
      prisma.pharmacy_order.findMany.mockResolvedValue(mockPharmacyOrders);

      const result = await findMany({}, 0, 20, { created_at: 'asc' });

      expect(result).toEqual(mockPharmacyOrders);
      expect(prisma.pharmacy_order.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.pharmacy_order.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count all pharmacy orders', async () => {
      prisma.pharmacy_order.count.mockResolvedValue(42);

      const result = await count({});

      expect(result).toBe(42);
      expect(prisma.pharmacy_order.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count pharmacy orders with filters', async () => {
      prisma.pharmacy_order.count.mockResolvedValue(5);

      const result = await count({ patient_id: 'patient-123', status: 'ORDERED' });

      expect(result).toBe(5);
      expect(prisma.pharmacy_order.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123',
          status: 'ORDERED'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.pharmacy_order.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create pharmacy order', async () => {
      const mockData = {
        patient_id: 'patient-123',
        encounter_id: 'encounter-123',
        status: 'ORDERED',
        ordered_at: new Date('2026-01-19T12:00:00.000Z')
      };
      const mockCreated = {
        id: 'order-123',
        ...mockData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.pharmacy_order.create.mockResolvedValue(mockCreated);

      const result = await create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.pharmacy_order.create).toHaveBeenCalledWith({
        data: mockData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['patient_id'] };
      prisma.pharmacy_order.create.mockRejectedValue(error);

      await expect(create({ patient_id: 'patient-123' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.pharmacy_order.create.mockRejectedValue(error);

      await expect(create({ patient_id: 'invalid-patient' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.pharmacy_order.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ patient_id: 'patient-123' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update pharmacy order', async () => {
      const mockData = { status: 'DISPENSED' };
      const mockUpdated = {
        id: 'order-123',
        patient_id: 'patient-123',
        status: 'DISPENSED',
        updated_at: new Date()
      };
      prisma.pharmacy_order.update.mockResolvedValue(mockUpdated);

      const result = await update('order-123', mockData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.pharmacy_order.update).toHaveBeenCalledWith({
        where: { id: 'order-123' },
        data: mockData
      });
    });

    it('should throw HttpError if pharmacy order not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.pharmacy_order.update.mockRejectedValue(error);

      await expect(update('order-123', { status: 'DISPENSED' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['patient_id'] };
      prisma.pharmacy_order.update.mockRejectedValue(error);

      await expect(update('order-123', { patient_id: 'patient-123' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.pharmacy_order.update.mockRejectedValue(error);

      await expect(update('order-123', { patient_id: 'invalid-patient' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.pharmacy_order.update.mockRejectedValue(new Error('DB error'));

      await expect(update('order-123', { status: 'DISPENSED' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete pharmacy order', async () => {
      const mockDeleted = {
        id: 'order-123',
        patient_id: 'patient-123',
        deleted_at: new Date()
      };
      prisma.pharmacy_order.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('order-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.pharmacy_order.update).toHaveBeenCalledWith({
        where: { id: 'order-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError if pharmacy order not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.pharmacy_order.update.mockRejectedValue(error);

      await expect(softDelete('order-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.pharmacy_order.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('order-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
