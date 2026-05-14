/**
 * Inventory stock controller tests
 * @module tests/modules/inventory-stock/controllers
 */

const inventoryStockController = require('@controllers/inventory-stock/inventory-stock.controller');
const inventoryStockService = require('@services/inventory-stock/inventory-stock.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/inventory-stock/inventory-stock.service');
jest.mock('@lib/response');

describe('Inventory Stock Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = { query: {}, params: {}, body: {}, user: { id: 'user-123' }, ip: '127.0.0.1' };
    res = { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
  });

  const mockStock = { id: '550e8400-e29b-41d4-a716-446655440000', quantity: 100 };

  describe('listInventoryStocks', () => {
    it('should list inventory stocks with pagination', async () => {
      inventoryStockService.listInventoryStocks.mockResolvedValue({
        inventoryStocks: [mockStock],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1 }
      });
      await inventoryStockController.listInventoryStocks(req, res);
      expect(inventoryStockService.listInventoryStocks).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        'user-123',
        '127.0.0.1',
        req.user
      );
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getInventoryStockById', () => {
    it('should get inventory stock by id', async () => {
      req.params.id = mockStock.id;
      inventoryStockService.getInventoryStockById.mockResolvedValue(mockStock);
      await inventoryStockController.getInventoryStockById(req, res);
      expect(inventoryStockService.getInventoryStockById).toHaveBeenCalledWith(
        mockStock.id,
        'user-123',
        '127.0.0.1',
        req.user
      );
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createInventoryStock', () => {
    it('should create inventory stock', async () => {
      req.body = mockStock;
      inventoryStockService.createInventoryStock.mockResolvedValue(mockStock);
      await inventoryStockController.createInventoryStock(req, res);
      expect(inventoryStockService.createInventoryStock).toHaveBeenCalledWith(
        mockStock,
        'user-123',
        '127.0.0.1',
        req.user
      );
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('updateInventoryStock', () => {
    it('should update inventory stock', async () => {
      req.params.id = mockStock.id;
      req.body = { quantity: 150 };
      inventoryStockService.updateInventoryStock.mockResolvedValue(mockStock);
      await inventoryStockController.updateInventoryStock(req, res);
      expect(inventoryStockService.updateInventoryStock).toHaveBeenCalledWith(
        mockStock.id,
        { quantity: 150 },
        'user-123',
        '127.0.0.1',
        req.user
      );
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteInventoryStock', () => {
    it('should delete inventory stock', async () => {
      req.params.id = mockStock.id;
      inventoryStockService.deleteInventoryStock.mockResolvedValue(undefined);
      await inventoryStockController.deleteInventoryStock(req, res);
      expect(inventoryStockService.deleteInventoryStock).toHaveBeenCalledWith(
        mockStock.id,
        'user-123',
        '127.0.0.1',
        req.user
      );
      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
