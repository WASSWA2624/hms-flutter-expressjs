/**
 * Stock movement schema tests
 *
 * @module tests/modules/stock-movement/schemas
 * @description Tests for stock movement validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createStockMovementSchema,
  updateStockMovementSchema,
  stockMovementIdParamsSchema,
  listStockMovementsQuerySchema
} = require('@validations/stock-movement/stock-movement.schema');

describe('Stock Movement Schemas', () => {
  describe('createStockMovementSchema', () => {
    const validData = {
      inventory_item_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      movement_type: 'INBOUND',
      reason: 'PURCHASE',
      quantity: 100,
      occurred_at: '2024-01-01T10:00:00Z'
    };

    it('should validate correct stock movement data', () => {
      const result = createStockMovementSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require inventory_item_id', () => {
      const data = { ...validData };
      delete data.inventory_item_id;
      const result = createStockMovementSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require movement_type', () => {
      const data = { ...validData };
      delete data.movement_type;
      const result = createStockMovementSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require reason', () => {
      const data = { ...validData };
      delete data.reason;
      const result = createStockMovementSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require quantity', () => {
      const data = { ...validData };
      delete data.quantity;
      const result = createStockMovementSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate movement_type enum values', () => {
      const data = { ...validData, movement_type: 'INVALID' };
      const result = createStockMovementSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid movement_type values', () => {
      const types = ['INBOUND', 'OUTBOUND', 'ADJUSTMENT', 'TRANSFER'];
      types.forEach(movement_type => {
        const data = { ...validData, movement_type };
        const result = createStockMovementSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should validate reason enum values', () => {
      const data = { ...validData, reason: 'INVALID' };
      const result = createStockMovementSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid reason values', () => {
      const reasons = ['PURCHASE', 'DISPENSE', 'RETURN', 'DAMAGE', 'EXPIRY', 'OTHER'];
      reasons.forEach(reason => {
        const data = { ...validData, reason };
        const result = createStockMovementSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createStockMovementSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional occurred_at', () => {
      const data = { ...validData };
      delete data.occurred_at;
      const result = createStockMovementSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateStockMovementSchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        movement_type: 'OUTBOUND',
        reason: 'DISPENSE',
        quantity: 50
      };
      const result = updateStockMovementSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { quantity: 150 };
      const result = updateStockMovementSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty update object', () => {
      const data = {};
      const result = updateStockMovementSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('stockMovementIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = stockMovementIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = stockMovementIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });
  });

  describe('listStockMovementsQuerySchema', () => {
    it('should validate query with all optional filters', () => {
      const query = {
        inventory_item_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        movement_type: 'INBOUND',
        reason: 'PURCHASE',
        page: 1,
        limit: 20
      };
      const result = listStockMovementsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate query with no filters', () => {
      const query = {};
      const result = listStockMovementsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });
  });
});
