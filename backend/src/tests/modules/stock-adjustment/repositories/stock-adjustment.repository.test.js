/**
 * Stock adjustment repository tests
 */

const stockAdjustmentRepository = require('@modules/stock-adjustment/repositories/stock-adjustment.repository');
const prisma = require('@prisma/client');

jest.mock('@prisma/client', () => ({
  stock_adjustment: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Stock Adjustment Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find stock adjustment by ID', async () => {
      const mockStockAdjustment = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        inventory_item_id: '660e8400-e29b-41d4-a716-446655440000',
        quantity: 10,
        reason: 'CORRECTION',
        deleted_at: null
      };
      prisma.stock_adjustment.findFirst.mockResolvedValue(mockStockAdjustment);

      const result = await stockAdjustmentRepository.findById('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockStockAdjustment);
    });

    it('should return null if not found', async () => {
      prisma.stock_adjustment.findFirst.mockResolvedValue(null);
      const result = await stockAdjustmentRepository.findById('non-existent-id');
      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find multiple stock adjustments', async () => {
      const mockAdjustments = [{ id: '1', quantity: 10, reason: 'CORRECTION' }];
      prisma.stock_adjustment.findMany.mockResolvedValue(mockAdjustments);

      const result = await stockAdjustmentRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockAdjustments);
    });
  });

  describe('count', () => {
    it('should count stock adjustments', async () => {
      prisma.stock_adjustment.count.mockResolvedValue(42);
      const result = await stockAdjustmentRepository.count();
      expect(result).toBe(42);
    });
  });

  describe('create', () => {
    it('should create new stock adjustment', async () => {
      const data = {
        inventory_item_id: '660e8400-e29b-41d4-a716-446655440000',
        quantity: 10,
        reason: 'CORRECTION'
      };
      const mockCreated = { id: '550e8400-e29b-41d4-a716-446655440000', ...data };
      prisma.stock_adjustment.create.mockResolvedValue(mockCreated);

      const result = await stockAdjustmentRepository.create(data);

      expect(result).toEqual(mockCreated);
    });
  });

  describe('update', () => {
    it('should update stock adjustment', async () => {
      const mockUpdated = { id: '550e8400-e29b-41d4-a716-446655440000', quantity: 5, reason: 'DAMAGED' };
      prisma.stock_adjustment.update.mockResolvedValue(mockUpdated);

      const result = await stockAdjustmentRepository.update('550e8400-e29b-41d4-a716-446655440000', { quantity: 5 });

      expect(result).toEqual(mockUpdated);
    });
  });

  describe('softDelete', () => {
    it('should soft delete stock adjustment', async () => {
      const mockDeleted = { id: '550e8400-e29b-41d4-a716-446655440000', deleted_at: new Date() };
      prisma.stock_adjustment.update.mockResolvedValue(mockDeleted);

      const result = await stockAdjustmentRepository.softDelete('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockDeleted);
    });
  });
});
