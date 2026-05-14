/**
 * Inventory stock repository tests
 * @module tests/modules/inventory-stock/repositories
 */

const inventoryStockRepository = require('@repositories/inventory-stock/inventory-stock.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  inventory_stock: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Inventory Stock Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const mockStock = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    inventory_item_id: '550e8400-e29b-41d4-a716-446655440001',
    facility_id: '550e8400-e29b-41d4-a716-446655440002',
    quantity: 100,
    reorder_level: 10,
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  describe('findById', () => {
    it('should find inventory stock by id', async () => {
      prisma.inventory_stock.findFirst.mockResolvedValue(mockStock);
      const result = await inventoryStockRepository.findById(mockStock.id);
      expect(result).toEqual(mockStock);
    });

    it('should return null if not found', async () => {
      prisma.inventory_stock.findFirst.mockResolvedValue(null);
      const result = await inventoryStockRepository.findById('non-existent');
      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find many inventory stocks', async () => {
      prisma.inventory_stock.findMany.mockResolvedValue([mockStock]);
      const result = await inventoryStockRepository.findMany();
      expect(result).toEqual([mockStock]);
    });
  });

  describe('count', () => {
    it('should count inventory stocks', async () => {
      prisma.inventory_stock.count.mockResolvedValue(10);
      const result = await inventoryStockRepository.count();
      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create inventory stock', async () => {
      prisma.inventory_stock.create.mockResolvedValue(mockStock);
      const result = await inventoryStockRepository.create(mockStock);
      expect(result).toEqual(mockStock);
    });
  });

  describe('update', () => {
    it('should update inventory stock', async () => {
      prisma.inventory_stock.update.mockResolvedValue(mockStock);
      const result = await inventoryStockRepository.update(mockStock.id, { quantity: 150 });
      expect(result).toEqual(mockStock);
    });
  });

  describe('softDelete', () => {
    it('should soft delete inventory stock', async () => {
      prisma.inventory_stock.update.mockResolvedValue({ ...mockStock, deleted_at: new Date() });
      const result = await inventoryStockRepository.softDelete(mockStock.id);
      expect(result.deleted_at).not.toBeNull();
    });
  });
});
