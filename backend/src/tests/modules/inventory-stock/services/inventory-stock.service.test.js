/**
 * Inventory stock service tests
 * @module tests/modules/inventory-stock/services
 */

const inventoryStockService = require('@services/inventory-stock/inventory-stock.service');
const inventoryStockRepository = require('@repositories/inventory-stock/inventory-stock.repository');
const { createAuditLog } = require('@lib/audit');
const { resolveModelIdOrThrow } = require('@services/pharmacy-workspace/pharmacy.shared');

jest.mock('@repositories/inventory-stock/inventory-stock.repository');
jest.mock('@lib/audit');
jest.mock('@services/pharmacy-workspace/pharmacy.shared', () => {
  const actual = jest.requireActual('@services/pharmacy-workspace/pharmacy.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
  };
});

describe('Inventory Stock Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';
  const mockUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    roles: ['PHARMACIST'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveModelIdOrThrow.mockImplementation(async ({ identifier, allowNull = false }) => {
      if ((identifier === null || identifier === undefined || identifier === '') && allowNull) {
        return null;
      }
      return identifier;
    });
  });

  const mockStock = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    inventory_item_id: '550e8400-e29b-41d4-a716-446655440001',
    inventory_item: {
      tenant_id: 'tenant-123',
    },
    quantity: 100,
    reorder_level: 10
  };

  describe('listInventoryStocks', () => {
    it('should list inventory stocks with pagination', async () => {
      inventoryStockRepository.findMany.mockResolvedValue([mockStock]);
      inventoryStockRepository.count.mockResolvedValue(1);

      const result = await inventoryStockService.listInventoryStocks(
        {},
        1,
        20,
        'created_at',
        'desc',
        userId,
        ipAddress,
        mockUser
      );

      expect(result.inventoryStocks).toEqual([mockStock]);
      expect(result.pagination.total).toBe(1);
    });
  });

  describe('getInventoryStockById', () => {
    it('should get inventory stock by id', async () => {
      inventoryStockRepository.findById.mockResolvedValue(mockStock);
      const result = await inventoryStockService.getInventoryStockById(
        mockStock.id,
        userId,
        ipAddress,
        mockUser
      );
      expect(result).toEqual(mockStock);
    });
  });

  describe('createInventoryStock', () => {
    it('should create inventory stock and log audit', async () => {
      inventoryStockRepository.create.mockResolvedValue(mockStock);
      const result = await inventoryStockService.createInventoryStock(
        mockStock,
        userId,
        ipAddress,
        mockUser
      );
      expect(result).toEqual(mockStock);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ tenant_id: 'tenant-123' }));
    });
  });

  describe('updateInventoryStock', () => {
    it('should update inventory stock and log audit', async () => {
      inventoryStockRepository.findById.mockResolvedValue(mockStock);
      inventoryStockRepository.update.mockResolvedValue(mockStock);
      const result = await inventoryStockService.updateInventoryStock(
        mockStock.id,
        { quantity: 150 },
        userId,
        ipAddress,
        mockUser
      );
      expect(result).toEqual(mockStock);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ tenant_id: 'tenant-123' }));
    });
  });

  describe('deleteInventoryStock', () => {
    it('should delete inventory stock and log audit', async () => {
      inventoryStockRepository.findById.mockResolvedValue(mockStock);
      inventoryStockRepository.softDelete.mockResolvedValue(undefined);
      await inventoryStockService.deleteInventoryStock(mockStock.id, userId, ipAddress, mockUser);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ tenant_id: 'tenant-123' }));
    });
  });
});
