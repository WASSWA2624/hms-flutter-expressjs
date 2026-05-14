/**
 * Stock movement repository tests
 * @module tests/modules/stock-movement/repositories
 */

const stockMovementRepository = require('@repositories/stock-movement/stock-movement.repository');
const prisma = require('@prisma/client');

jest.mock('@prisma/client', () => ({
  stock_movement: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Stock Movement Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const mockMovement = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    inventory_item_id: '550e8400-e29b-41d4-a716-446655440001',
    movement_type: 'INBOUND',
    reason: 'PURCHASE',
    quantity: 100,
    occurred_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  describe('findById', () => {
    it('should find stock movement by id', async () => {
      prisma.stock_movement.findFirst.mockResolvedValue(mockMovement);
      const result = await stockMovementRepository.findById(mockMovement.id);
      expect(result).toEqual(mockMovement);
    });
  });

  describe('findMany', () => {
    it('should find many stock movements', async () => {
      prisma.stock_movement.findMany.mockResolvedValue([mockMovement]);
      const result = await stockMovementRepository.findMany();
      expect(result).toEqual([mockMovement]);
    });
  });

  describe('count', () => {
    it('should count stock movements', async () => {
      prisma.stock_movement.count.mockResolvedValue(10);
      const result = await stockMovementRepository.count();
      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create stock movement', async () => {
      prisma.stock_movement.create.mockResolvedValue(mockMovement);
      const result = await stockMovementRepository.create(mockMovement);
      expect(result).toEqual(mockMovement);
    });
  });

  describe('update', () => {
    it('should update stock movement', async () => {
      prisma.stock_movement.update.mockResolvedValue(mockMovement);
      const result = await stockMovementRepository.update(mockMovement.id, { quantity: 150 });
      expect(result).toEqual(mockMovement);
    });
  });

  describe('softDelete', () => {
    it('should soft delete stock movement', async () => {
      prisma.stock_movement.update.mockResolvedValue({ ...mockMovement, deleted_at: new Date() });
      const result = await stockMovementRepository.softDelete(mockMovement.id);
      expect(result.deleted_at).not.toBeNull();
    });
  });
});
