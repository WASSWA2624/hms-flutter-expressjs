/**
 * Pharmacy order item repository tests
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  pharmacy_order_item: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const prisma = require('@prisma/client');
const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/pharmacy-order-item/pharmacy-order-item.repository');

describe('Pharmacy Order Item Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should return pharmacy order item by id', async () => {
      prisma.pharmacy_order_item.findFirst.mockResolvedValue({ id: 'item-1' });
      const result = await findById('item-1');
      expect(result).toEqual({ id: 'item-1' });
      expect(prisma.pharmacy_order_item.findFirst).toHaveBeenCalledWith({
        where: { id: 'item-1', deleted_at: null },
        include: {}
      });
    });

    it('should throw HttpError on db error', async () => {
      prisma.pharmacy_order_item.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(findById('item-1')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should return pharmacy order items list', async () => {
      prisma.pharmacy_order_item.findMany.mockResolvedValue([{ id: 'item-1' }]);
      const result = await findMany({ pharmacy_order_id: 'order-1' }, 0, 20, { created_at: 'desc' });
      expect(result).toEqual([{ id: 'item-1' }]);
      expect(prisma.pharmacy_order_item.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, pharmacy_order_id: 'order-1' },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count pharmacy order items', async () => {
      prisma.pharmacy_order_item.count.mockResolvedValue(4);
      const result = await count({ pharmacy_order_id: 'order-1' });
      expect(result).toBe(4);
      expect(prisma.pharmacy_order_item.count).toHaveBeenCalledWith({
        where: { deleted_at: null, pharmacy_order_id: 'order-1' }
      });
    });
  });

  describe('create', () => {
    it('should create pharmacy order item', async () => {
      const payload = { pharmacy_order_id: 'order-1', drug_id: 'drug-1', quantity: 1 };
      prisma.pharmacy_order_item.create.mockResolvedValue({ id: 'item-1', ...payload });
      const result = await create(payload);
      expect(result).toHaveProperty('id', 'item-1');
      expect(prisma.pharmacy_order_item.create).toHaveBeenCalledWith({ data: payload });
    });

    it('should map foreign key error', async () => {
      const error = new Error('FK');
      error.code = 'P2003';
      error.meta = { field_name: 'drug_id' };
      prisma.pharmacy_order_item.create.mockRejectedValue(error);
      await expect(create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update pharmacy order item', async () => {
      prisma.pharmacy_order_item.update.mockResolvedValue({ id: 'item-1', quantity: 3 });
      const result = await update('item-1', { quantity: 3 });
      expect(result).toEqual({ id: 'item-1', quantity: 3 });
      expect(prisma.pharmacy_order_item.update).toHaveBeenCalledWith({
        where: { id: 'item-1' },
        data: { quantity: 3 }
      });
    });

    it('should map not found error', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.pharmacy_order_item.update.mockRejectedValue(error);
      await expect(update('missing', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete pharmacy order item', async () => {
      prisma.pharmacy_order_item.update.mockResolvedValue({ id: 'item-1', deleted_at: new Date() });
      await softDelete('item-1');
      expect(prisma.pharmacy_order_item.update).toHaveBeenCalledWith({
        where: { id: 'item-1' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});

