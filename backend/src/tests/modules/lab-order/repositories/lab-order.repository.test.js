/**
 * Lab order repository tests
 *
 * @module tests/modules/lab-order/repositories
 * @description Tests for lab order repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const labOrderRepository = require('@repositories/lab-order/lab-order.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  lab_order: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Lab Order Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find lab order by id', async () => {
      const mockLabOrder = {
        id: '123',
        patient_id: '456',
        encounter_id: '789',
        status: 'ORDERED'
      };
      prisma.lab_order.findFirst.mockResolvedValue(mockLabOrder);

      const result = await labOrderRepository.findById('123');
      expect(result).toEqual(mockLabOrder);
      expect(prisma.lab_order.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if lab order not found', async () => {
      prisma.lab_order.findFirst.mockResolvedValue(null);

      const result = await labOrderRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should pass include parameter correctly', async () => {
      const mockLabOrder = { id: '123', status: 'ORDERED' };
      const includeOptions = { items: true, patient: true };
      prisma.lab_order.findFirst.mockResolvedValue(mockLabOrder);

      await labOrderRepository.findById('123', includeOptions);
      expect(prisma.lab_order.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: includeOptions
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_order.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(labOrderRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError with correct message on database error', async () => {
      const dbError = new Error('Connection timeout');
      prisma.lab_order.findFirst.mockRejectedValue(dbError);

      try {
        await labOrderRepository.findById('123');
      } catch (error) {
        expect(error).toBeInstanceOf(HttpError);
        expect(error.message).toBe('errors.database.unexpected');
        expect(error.statusCode).toBe(500);
      }
    });
  });

  describe('findMany', () => {
    it('should find many lab orders with pagination', async () => {
      const mockLabOrders = [
        { id: '1', patient_id: '456', status: 'ORDERED' },
        { id: '2', patient_id: '457', status: 'COMPLETED' }
      ];
      prisma.lab_order.findMany.mockResolvedValue(mockLabOrders);

      const result = await labOrderRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockLabOrders);
      expect(prisma.lab_order.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters correctly', async () => {
      const filters = { patient_id: '456', status: 'ORDERED' };
      prisma.lab_order.findMany.mockResolvedValue([]);

      await labOrderRepository.findMany(filters, 0, 20);
      expect(prisma.lab_order.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom orderBy', async () => {
      const orderBy = { ordered_at: 'asc' };
      prisma.lab_order.findMany.mockResolvedValue([]);

      await labOrderRepository.findMany({}, 0, 20, orderBy);
      expect(prisma.lab_order.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy,
        include: {}
      });
    });

    it('should apply include parameter', async () => {
      const include = { items: true, patient: true };
      prisma.lab_order.findMany.mockResolvedValue([]);

      await labOrderRepository.findMany({}, 0, 20, { created_at: 'desc' }, include);
      expect(prisma.lab_order.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_order.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(labOrderRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count lab orders', async () => {
      prisma.lab_order.count.mockResolvedValue(42);

      const result = await labOrderRepository.count({});
      expect(result).toBe(42);
      expect(prisma.lab_order.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count with filters', async () => {
      const filters = { status: 'COMPLETED', patient_id: '456' };
      prisma.lab_order.count.mockResolvedValue(10);

      const result = await labOrderRepository.count(filters);
      expect(result).toBe(10);
      expect(prisma.lab_order.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should return zero when no records', async () => {
      prisma.lab_order.count.mockResolvedValue(0);

      const result = await labOrderRepository.count({});
      expect(result).toBe(0);
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_order.count.mockRejectedValue(new Error('DB Error'));

      await expect(labOrderRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create lab order', async () => {
      const mockData = {
        patient_id: '456',
        encounter_id: '789',
        status: 'ORDERED'
      };
      const mockLabOrder = { id: '123', ...mockData };
      prisma.lab_order.create.mockResolvedValue(mockLabOrder);

      const result = await labOrderRepository.create(mockData);
      expect(result).toEqual(mockLabOrder);
      expect(prisma.lab_order.create).toHaveBeenCalledWith({
        data: mockData
      });
    });

    it('should create lab order without encounter_id', async () => {
      const mockData = {
        patient_id: '456',
        status: 'ORDERED'
      };
      const mockLabOrder = { id: '123', ...mockData, encounter_id: null };
      prisma.lab_order.create.mockResolvedValue(mockLabOrder);

      const result = await labOrderRepository.create(mockData);
      expect(result).toEqual(mockLabOrder);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['id'] };
      prisma.lab_order.create.mockRejectedValue(error);

      try {
        await labOrderRepository.create({});
      } catch (e) {
        expect(e).toBeInstanceOf(HttpError);
        expect(e.message).toBe('errors.database.unique_field');
        expect(e.statusCode).toBe(409);
      }
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.lab_order.create.mockRejectedValue(error);

      try {
        await labOrderRepository.create({});
      } catch (e) {
        expect(e).toBeInstanceOf(HttpError);
        expect(e.message).toBe('errors.database.foreign_key_field');
        expect(e.statusCode).toBe(400);
      }
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.lab_order.create.mockRejectedValue(new Error('Generic DB Error'));

      await expect(labOrderRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update lab order', async () => {
      const mockLabOrder = { id: '123', status: 'COMPLETED' };
      prisma.lab_order.update.mockResolvedValue(mockLabOrder);

      const result = await labOrderRepository.update('123', { status: 'COMPLETED' });
      expect(result).toEqual(mockLabOrder);
      expect(prisma.lab_order.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { status: 'COMPLETED' }
      });
    });

    it('should update multiple fields', async () => {
      const updateData = {
        status: 'IN_PROCESS',
        encounter_id: '999'
      };
      const mockLabOrder = { id: '123', ...updateData };
      prisma.lab_order.update.mockResolvedValue(mockLabOrder);

      const result = await labOrderRepository.update('123', updateData);
      expect(result).toEqual(mockLabOrder);
    });

    it('should throw HttpError if lab order not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.lab_order.update.mockRejectedValue(error);

      try {
        await labOrderRepository.update('nonexistent', {});
      } catch (e) {
        expect(e).toBeInstanceOf(HttpError);
        expect(e.message).toBe('errors.lab_order.not_found');
        expect(e.statusCode).toBe(404);
      }
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.lab_order.update.mockRejectedValue(error);

      await expect(labOrderRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.lab_order.update.mockRejectedValue(error);

      await expect(labOrderRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete lab order', async () => {
      const mockLabOrder = { id: '123', deleted_at: new Date() };
      prisma.lab_order.update.mockResolvedValue(mockLabOrder);

      const result = await labOrderRepository.softDelete('123');
      expect(result).toEqual(mockLabOrder);
      expect(prisma.lab_order.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should set deleted_at to current date', async () => {
      const beforeDelete = new Date();
      const mockLabOrder = { id: '123', deleted_at: new Date() };
      prisma.lab_order.update.mockResolvedValue(mockLabOrder);

      await labOrderRepository.softDelete('123');
      
      const callArgs = prisma.lab_order.update.mock.calls[0][0];
      const deletedAt = callArgs.data.deleted_at;
      expect(deletedAt).toBeInstanceOf(Date);
      expect(deletedAt.getTime()).toBeGreaterThanOrEqual(beforeDelete.getTime());
    });

    it('should throw HttpError if lab order not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.lab_order.update.mockRejectedValue(error);

      try {
        await labOrderRepository.softDelete('nonexistent');
      } catch (e) {
        expect(e).toBeInstanceOf(HttpError);
        expect(e.message).toBe('errors.lab_order.not_found');
        expect(e.statusCode).toBe(404);
      }
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_order.update.mockRejectedValue(new Error('DB Error'));

      await expect(labOrderRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
