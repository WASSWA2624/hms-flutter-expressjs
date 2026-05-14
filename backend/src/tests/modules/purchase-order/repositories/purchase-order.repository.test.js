/**
 * Purchase order repository tests
 */

const purchaseOrderRepository = require('@modules/purchase-order/repositories/purchase-order.repository');
const prisma = require('@prisma/client');

jest.mock('@prisma/client', () => ({
  purchase_order: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Purchase Order Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find purchase order by ID', async () => {
      const mockPurchaseOrder = { id: '550e8400-e29b-41d4-a716-446655440000', status: 'PENDING', deleted_at: null };
      prisma.purchase_order.findFirst.mockResolvedValue(mockPurchaseOrder);

      const result = await purchaseOrderRepository.findById('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockPurchaseOrder);
    });

    it('should return null if not found', async () => {
      prisma.purchase_order.findFirst.mockResolvedValue(null);
      const result = await purchaseOrderRepository.findById('non-existent-id');
      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find multiple purchase orders', async () => {
      const mockOrders = [{ id: '1', status: 'PENDING' }];
      prisma.purchase_order.findMany.mockResolvedValue(mockOrders);

      const result = await purchaseOrderRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockOrders);
    });
  });

  describe('count', () => {
    it('should count purchase orders', async () => {
      prisma.purchase_order.count.mockResolvedValue(42);
      const result = await purchaseOrderRepository.count();
      expect(result).toBe(42);
    });
  });

  describe('create', () => {
    it('should create new purchase order', async () => {
      const data = { status: 'PENDING' };
      const mockCreated = { id: '550e8400-e29b-41d4-a716-446655440000', ...data };
      prisma.purchase_order.create.mockResolvedValue(mockCreated);

      const result = await purchaseOrderRepository.create(data);

      expect(result).toEqual(mockCreated);
    });
  });

  describe('update', () => {
    it('should update purchase order', async () => {
      const mockUpdated = { id: '550e8400-e29b-41d4-a716-446655440000', status: 'APPROVED' };
      prisma.purchase_order.update.mockResolvedValue(mockUpdated);

      const result = await purchaseOrderRepository.update('550e8400-e29b-41d4-a716-446655440000', { status: 'APPROVED' });

      expect(result).toEqual(mockUpdated);
    });
  });

  describe('softDelete', () => {
    it('should soft delete purchase order', async () => {
      const mockDeleted = { id: '550e8400-e29b-41d4-a716-446655440000', deleted_at: new Date() };
      prisma.purchase_order.update.mockResolvedValue(mockDeleted);

      const result = await purchaseOrderRepository.softDelete('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockDeleted);
    });
  });
});
