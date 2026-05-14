/**
 * Dispense Log repository tests
 *
 * @module tests/modules/dispense-log/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  dispense_log: {
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
} = require('@repositories/dispense-log/dispense-log.repository');

const prisma = require('@prisma/client');

describe('Dispense Log Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find dispense log by ID', async () => {
      const mockDispenseLog = {
        id: 'dispense-123',
        pharmacy_order_item_id: 'item-123',
        status: 'PENDING',
        dispensed_at: null,
        quantity_dispensed: 0,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.dispense_log.findFirst.mockResolvedValue(mockDispenseLog);

      const result = await findById('dispense-123');

      expect(result).toEqual(mockDispenseLog);
      expect(prisma.dispense_log.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'dispense-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if dispense log not found', async () => {
      prisma.dispense_log.findFirst.mockResolvedValue(null);

      const result = await findById('dispense-123');

      expect(result).toBeNull();
    });

    it('should find dispense log with includes', async () => {
      const mockDispenseLog = { id: 'dispense-123', status: 'DISPENSED' };
      prisma.dispense_log.findFirst.mockResolvedValue(mockDispenseLog);

      await findById('dispense-123', { pharmacy_order_item: true });

      expect(prisma.dispense_log.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'dispense-123',
          deleted_at: null
        },
        include: { pharmacy_order_item: true }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.dispense_log.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('dispense-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many dispense logs with default pagination', async () => {
      const mockDispenseLogs = [
        {
          id: 'dispense-1',
          pharmacy_order_item_id: 'item-123',
          status: 'PENDING',
          quantity_dispensed: 0
        },
        {
          id: 'dispense-2',
          pharmacy_order_item_id: 'item-124',
          status: 'DISPENSED',
          quantity_dispensed: 10
        }
      ];
      prisma.dispense_log.findMany.mockResolvedValue(mockDispenseLogs);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockDispenseLogs);
      expect(prisma.dispense_log.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters correctly', async () => {
      prisma.dispense_log.findMany.mockResolvedValue([]);

      await findMany({ status: 'DISPENSED' }, 0, 20);

      expect(prisma.dispense_log.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          status: 'DISPENSED'
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should handle pagination parameters', async () => {
      prisma.dispense_log.findMany.mockResolvedValue([]);

      await findMany({}, 20, 10, { dispensed_at: 'asc' });

      expect(prisma.dispense_log.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 10,
        orderBy: { dispensed_at: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.dispense_log.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count dispense logs', async () => {
      prisma.dispense_log.count.mockResolvedValue(42);

      const result = await count({});

      expect(result).toBe(42);
      expect(prisma.dispense_log.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count with filters', async () => {
      prisma.dispense_log.count.mockResolvedValue(10);

      const result = await count({ status: 'PENDING' });

      expect(result).toBe(10);
      expect(prisma.dispense_log.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          status: 'PENDING'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.dispense_log.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new dispense log', async () => {
      const newDispenseLog = {
        pharmacy_order_item_id: 'item-123',
        status: 'PENDING',
        quantity_dispensed: 0
      };
      const mockCreatedDispenseLog = {
        id: 'dispense-123',
        ...newDispenseLog,
        dispensed_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };

      prisma.dispense_log.create.mockResolvedValue(mockCreatedDispenseLog);

      const result = await create(newDispenseLog);

      expect(result).toEqual(mockCreatedDispenseLog);
      expect(prisma.dispense_log.create).toHaveBeenCalledWith({
        data: newDispenseLog
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = {
        code: 'P2002',
        meta: { target: ['pharmacy_order_item_id'] }
      };
      prisma.dispense_log.create.mockRejectedValue(error);

      await expect(create({ pharmacy_order_item_id: 'item-123', status: 'PENDING' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'pharmacy_order_item_id' }
      };
      prisma.dispense_log.create.mockRejectedValue(error);

      await expect(create({ pharmacy_order_item_id: 'invalid-id', status: 'PENDING' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.dispense_log.create.mockRejectedValue(new Error('Unexpected DB error'));

      await expect(create({ pharmacy_order_item_id: 'item-123', status: 'PENDING' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update dispense log', async () => {
      const updateData = { status: 'DISPENSED', quantity_dispensed: 10 };
      const mockUpdatedDispenseLog = {
        id: 'dispense-123',
        pharmacy_order_item_id: 'item-123',
        status: 'DISPENSED',
        dispensed_at: new Date('2026-01-19'),
        quantity_dispensed: 10,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };

      prisma.dispense_log.update.mockResolvedValue(mockUpdatedDispenseLog);

      const result = await update('dispense-123', updateData);

      expect(result).toEqual(mockUpdatedDispenseLog);
      expect(prisma.dispense_log.update).toHaveBeenCalledWith({
        where: { id: 'dispense-123' },
        data: updateData
      });
    });

    it('should throw HttpError if dispense log not found', async () => {
      const error = { code: 'P2025' };
      prisma.dispense_log.update.mockRejectedValue(error);

      await expect(update('dispense-123', { status: 'DISPENSED' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = {
        code: 'P2002',
        meta: { target: ['pharmacy_order_item_id'] }
      };
      prisma.dispense_log.update.mockRejectedValue(error);

      await expect(update('dispense-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected error', async () => {
      prisma.dispense_log.update.mockRejectedValue(new Error('DB error'));

      await expect(update('dispense-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete dispense log', async () => {
      const mockDeletedDispenseLog = {
        id: 'dispense-123',
        pharmacy_order_item_id: 'item-123',
        status: 'PENDING',
        dispensed_at: null,
        quantity_dispensed: 0,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: new Date('2026-01-19'),
        version: 1
      };

      prisma.dispense_log.update.mockResolvedValue(mockDeletedDispenseLog);

      const result = await softDelete('dispense-123');

      expect(result).toEqual(mockDeletedDispenseLog);
      expect(prisma.dispense_log.update).toHaveBeenCalledWith({
        where: { id: 'dispense-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError if dispense log not found', async () => {
      const error = { code: 'P2025' };
      prisma.dispense_log.update.mockRejectedValue(error);

      await expect(softDelete('dispense-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.dispense_log.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('dispense-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
