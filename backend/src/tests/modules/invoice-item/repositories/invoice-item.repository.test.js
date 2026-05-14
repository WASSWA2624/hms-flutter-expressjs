/**
 * Invoice item repository tests
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  invoice_item: {
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
} = require('@repositories/invoice-item/invoice-item.repository');

describe('Invoice Item Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should return invoice item by id', async () => {
      const mockItem = { id: 'item-1', description: 'Consultation', deleted_at: null };
      prisma.invoice_item.findFirst.mockResolvedValue(mockItem);

      const result = await findById('item-1');

      expect(result).toEqual(mockItem);
      expect(prisma.invoice_item.findFirst).toHaveBeenCalledWith({
        where: { id: 'item-1', deleted_at: null },
        include: {}
      });
    });

    it('should throw HttpError on db error', async () => {
      prisma.invoice_item.findFirst.mockRejectedValue(new Error('DB Error'));
      await expect(findById('item-1')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should return paginated invoice items', async () => {
      prisma.invoice_item.findMany.mockResolvedValue([{ id: 'item-1' }]);

      const result = await findMany({ invoice_id: 'invoice-1' }, 0, 10, { created_at: 'desc' });

      expect(result).toEqual([{ id: 'item-1' }]);
      expect(prisma.invoice_item.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, invoice_id: 'invoice-1' },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count invoice items', async () => {
      prisma.invoice_item.count.mockResolvedValue(5);
      const result = await count({ invoice_id: 'invoice-1' });
      expect(result).toBe(5);
      expect(prisma.invoice_item.count).toHaveBeenCalledWith({
        where: { deleted_at: null, invoice_id: 'invoice-1' }
      });
    });
  });

  describe('create', () => {
    it('should create invoice item', async () => {
      const payload = {
        invoice_id: 'invoice-1',
        description: 'Consultation',
        quantity: 1,
        unit_price: '100.00',
        total_price: '100.00'
      };
      prisma.invoice_item.create.mockResolvedValue({ id: 'item-1', ...payload });

      const result = await create(payload);

      expect(result).toMatchObject({ id: 'item-1' });
      expect(prisma.invoice_item.create).toHaveBeenCalledWith({ data: payload });
    });

    it('should map unique constraint error', async () => {
      const error = new Error('Unique violation');
      error.code = 'P2002';
      error.meta = { target: ['field_name'] };
      prisma.invoice_item.create.mockRejectedValue(error);
      await expect(create({})).rejects.toThrow(HttpError);
    });

    it('should map foreign key error', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'invoice_id' };
      prisma.invoice_item.create.mockRejectedValue(error);
      await expect(create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update invoice item', async () => {
      prisma.invoice_item.update.mockResolvedValue({ id: 'item-1', description: 'Updated' });
      const result = await update('item-1', { description: 'Updated' });
      expect(result).toEqual({ id: 'item-1', description: 'Updated' });
      expect(prisma.invoice_item.update).toHaveBeenCalledWith({
        where: { id: 'item-1' },
        data: { description: 'Updated' }
      });
    });

    it('should map not found error', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.invoice_item.update.mockRejectedValue(error);
      await expect(update('missing', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete invoice item', async () => {
      prisma.invoice_item.update.mockResolvedValue({ id: 'item-1', deleted_at: new Date() });
      const result = await softDelete('item-1');
      expect(result).toHaveProperty('id', 'item-1');
      expect(prisma.invoice_item.update).toHaveBeenCalledWith({
        where: { id: 'item-1' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});

