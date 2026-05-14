/**
 * Stock movement controller tests
 * @module tests/modules/stock-movement/controllers
 */

const stockMovementController = require('@controllers/stock-movement/stock-movement.controller');
const stockMovementService = require('@services/stock-movement/stock-movement.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/stock-movement/stock-movement.service');
jest.mock('@lib/response');

describe('Stock Movement Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = { query: {}, params: {}, body: {}, user: { id: 'user-123' }, ip: '127.0.0.1' };
    res = { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
  });

  const mockMovement = { id: '550e8400-e29b-41d4-a716-446655440000', quantity: 100 };

  describe('listStockMovements', () => {
    it('should list stock movements with pagination', async () => {
      stockMovementService.listStockMovements.mockResolvedValue({
        stockMovements: [mockMovement],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1 }
      });
      await stockMovementController.listStockMovements(req, res);
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getStockMovementById', () => {
    it('should get stock movement by id', async () => {
      req.params.id = mockMovement.id;
      stockMovementService.getStockMovementById.mockResolvedValue(mockMovement);
      await stockMovementController.getStockMovementById(req, res);
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createStockMovement', () => {
    it('should create stock movement', async () => {
      req.body = mockMovement;
      stockMovementService.createStockMovement.mockResolvedValue(mockMovement);
      await stockMovementController.createStockMovement(req, res);
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('updateStockMovement', () => {
    it('should update stock movement', async () => {
      req.params.id = mockMovement.id;
      req.body = { quantity: 150 };
      stockMovementService.updateStockMovement.mockResolvedValue(mockMovement);
      await stockMovementController.updateStockMovement(req, res);
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteStockMovement', () => {
    it('should delete stock movement', async () => {
      req.params.id = mockMovement.id;
      stockMovementService.deleteStockMovement.mockResolvedValue(undefined);
      await stockMovementController.deleteStockMovement(req, res);
      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
