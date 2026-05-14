/**
 * Goods receipt repository tests
 */

const goodsReceiptRepository = require('@modules/goods-receipt/repositories/goods-receipt.repository');
const prisma = require('@prisma/client');

jest.mock('@prisma/client', () => ({
  goods_receipt: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Goods Receipt Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find goods receipt by ID', async () => {
      const mockGoodsReceipt = { id: '550e8400-e29b-41d4-a716-446655440000', status: 'RECEIVED', deleted_at: null };
      prisma.goods_receipt.findFirst.mockResolvedValue(mockGoodsReceipt);

      const result = await goodsReceiptRepository.findById('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockGoodsReceipt);
    });

    it('should return null if not found', async () => {
      prisma.goods_receipt.findFirst.mockResolvedValue(null);
      const result = await goodsReceiptRepository.findById('non-existent-id');
      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find multiple goods receipts', async () => {
      const mockReceipts = [{ id: '1', status: 'RECEIVED' }];
      prisma.goods_receipt.findMany.mockResolvedValue(mockReceipts);

      const result = await goodsReceiptRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockReceipts);
    });
  });

  describe('count', () => {
    it('should count goods receipts', async () => {
      prisma.goods_receipt.count.mockResolvedValue(42);
      const result = await goodsReceiptRepository.count();
      expect(result).toBe(42);
    });
  });

  describe('create', () => {
    it('should create new goods receipt', async () => {
      const data = { purchase_order_id: '660e8400-e29b-41d4-a716-446655440000', status: 'RECEIVED' };
      const mockCreated = { id: '550e8400-e29b-41d4-a716-446655440000', ...data };
      prisma.goods_receipt.create.mockResolvedValue(mockCreated);

      const result = await goodsReceiptRepository.create(data);

      expect(result).toEqual(mockCreated);
    });
  });

  describe('update', () => {
    it('should update goods receipt', async () => {
      const mockUpdated = { id: '550e8400-e29b-41d4-a716-446655440000', status: 'CONFIRMED' };
      prisma.goods_receipt.update.mockResolvedValue(mockUpdated);

      const result = await goodsReceiptRepository.update('550e8400-e29b-41d4-a716-446655440000', { status: 'CONFIRMED' });

      expect(result).toEqual(mockUpdated);
    });
  });

  describe('softDelete', () => {
    it('should soft delete goods receipt', async () => {
      const mockDeleted = { id: '550e8400-e29b-41d4-a716-446655440000', deleted_at: new Date() };
      prisma.goods_receipt.update.mockResolvedValue(mockDeleted);

      const result = await goodsReceiptRepository.softDelete('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockDeleted);
    });
  });
});
