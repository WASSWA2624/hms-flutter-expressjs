/**
 * Stock movement service tests
 * @module tests/modules/stock-movement/services
 */

const stockMovementService = require('@services/stock-movement/stock-movement.service');
const stockMovementRepository = require('@repositories/stock-movement/stock-movement.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/stock-movement/stock-movement.repository');
jest.mock('@lib/audit');

describe('Stock Movement Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  const mockMovement = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    inventory_item_id: '550e8400-e29b-41d4-a716-446655440001',
    movement_type: 'INBOUND',
    reason: 'PURCHASE',
    quantity: 100
  };

  describe('listStockMovements', () => {
    it('should list stock movements with pagination', async () => {
      stockMovementRepository.findMany.mockResolvedValue([mockMovement]);
      stockMovementRepository.count.mockResolvedValue(1);

      const result = await stockMovementService.listStockMovements({}, 1, 20, 'created_at', 'desc', userId, ipAddress);

      expect(result.stockMovements).toEqual([mockMovement]);
      expect(result.pagination.total).toBe(1);
    });
  });

  describe('getStockMovementById', () => {
    it('should get stock movement by id', async () => {
      stockMovementRepository.findById.mockResolvedValue(mockMovement);
      const result = await stockMovementService.getStockMovementById(mockMovement.id, userId, ipAddress);
      expect(result).toEqual(mockMovement);
    });
  });

  describe('createStockMovement', () => {
    it('should create stock movement and log audit', async () => {
      stockMovementRepository.create.mockResolvedValue(mockMovement);
      const result = await stockMovementService.createStockMovement(mockMovement, userId, ipAddress);
      expect(result).toEqual(mockMovement);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateStockMovement', () => {
    it('should update stock movement and log audit', async () => {
      stockMovementRepository.findById.mockResolvedValue(mockMovement);
      stockMovementRepository.update.mockResolvedValue(mockMovement);
      const result = await stockMovementService.updateStockMovement(mockMovement.id, { quantity: 150 }, userId, ipAddress);
      expect(result).toEqual(mockMovement);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteStockMovement', () => {
    it('should delete stock movement and log audit', async () => {
      stockMovementRepository.findById.mockResolvedValue(mockMovement);
      stockMovementRepository.softDelete.mockResolvedValue(undefined);
      await stockMovementService.deleteStockMovement(mockMovement.id, userId, ipAddress);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
