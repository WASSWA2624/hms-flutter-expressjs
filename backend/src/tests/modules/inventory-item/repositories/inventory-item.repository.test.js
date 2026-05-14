/**
 * Inventory item repository tests
 *
 * @module tests/modules/inventory-item/repositories
 * @description Tests for inventory item repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const inventoryItemRepository = require('@repositories/inventory-item/inventory-item.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  inventory_item: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Inventory Item Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find inventory item by id', async () => {
      const mockItem = { id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      prisma.inventory_item.findFirst.mockResolvedValue(mockItem);

      const result = await inventoryItemRepository.findById('123');
      expect(result).toEqual(mockItem);
      expect(prisma.inventory_item.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if inventory item not found', async () => {
      prisma.inventory_item.findFirst.mockResolvedValue(null);

      const result = await inventoryItemRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.inventory_item.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(inventoryItemRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockItem = { id: '123', name: 'Surgical Gloves', stocks: [] };
      prisma.inventory_item.findFirst.mockResolvedValue(mockItem);

      const include = { stocks: true };
      const result = await inventoryItemRepository.findById('123', include);
      expect(result).toEqual(mockItem);
      expect(prisma.inventory_item.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many inventory items with pagination', async () => {
      const mockItems = [
        { id: '1', name: 'Surgical Gloves', category: 'SUPPLY' },
        { id: '2', name: 'Paracetamol', category: 'MEDICATION' }
      ];
      prisma.inventory_item.findMany.mockResolvedValue(mockItems);

      const result = await inventoryItemRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockItems);
      expect(prisma.inventory_item.findMany).toHaveBeenCalled();
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '123', category: 'SUPPLY' };
      prisma.inventory_item.findMany.mockResolvedValue([]);

      await inventoryItemRepository.findMany(filters, 0, 20);
      expect(prisma.inventory_item.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom ordering', async () => {
      prisma.inventory_item.findMany.mockResolvedValue([]);

      await inventoryItemRepository.findMany({}, 0, 20, { name: 'asc' });
      expect(prisma.inventory_item.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.inventory_item.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(inventoryItemRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count inventory items', async () => {
      prisma.inventory_item.count.mockResolvedValue(42);

      const result = await inventoryItemRepository.count({});
      expect(result).toBe(42);
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '123', category: 'MEDICATION' };
      prisma.inventory_item.count.mockResolvedValue(10);

      await inventoryItemRepository.count(filters);
      expect(prisma.inventory_item.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.inventory_item.count.mockRejectedValue(new Error('DB Error'));

      await expect(inventoryItemRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create inventory item', async () => {
      const mockData = { tenant_id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      const mockItem = { id: '456', ...mockData };
      prisma.inventory_item.create.mockResolvedValue(mockItem);

      const result = await inventoryItemRepository.create(mockData);
      expect(result).toEqual(mockItem);
      expect(prisma.inventory_item.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const mockData = { tenant_id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['sku'] };
      prisma.inventory_item.create.mockRejectedValue(error);

      await expect(inventoryItemRepository.create(mockData)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const mockData = { tenant_id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.inventory_item.create.mockRejectedValue(error);

      await expect(inventoryItemRepository.create(mockData)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      const mockData = { tenant_id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      prisma.inventory_item.create.mockRejectedValue(new Error('DB Error'));

      await expect(inventoryItemRepository.create(mockData)).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update inventory item', async () => {
      const mockData = { name: 'Updated Gloves' };
      const mockItem = { id: '123', ...mockData };
      prisma.inventory_item.update.mockResolvedValue(mockItem);

      const result = await inventoryItemRepository.update('123', mockData);
      expect(result).toEqual(mockItem);
      expect(prisma.inventory_item.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: mockData
      });
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.inventory_item.update.mockRejectedValue(error);

      await expect(inventoryItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['sku'] };
      prisma.inventory_item.update.mockRejectedValue(error);

      await expect(inventoryItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.inventory_item.update.mockRejectedValue(error);

      await expect(inventoryItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.inventory_item.update.mockRejectedValue(new Error('DB Error'));

      await expect(inventoryItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete inventory item', async () => {
      const mockItem = { id: '123', deleted_at: new Date() };
      prisma.inventory_item.update.mockResolvedValue(mockItem);

      const result = await inventoryItemRepository.softDelete('123');
      expect(result).toEqual(mockItem);
      expect(prisma.inventory_item.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.inventory_item.update.mockRejectedValue(error);

      await expect(inventoryItemRepository.softDelete('123')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.inventory_item.update.mockRejectedValue(new Error('DB Error'));

      await expect(inventoryItemRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
