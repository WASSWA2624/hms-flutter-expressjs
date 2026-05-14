/**
 * Stock adjustment schema validation tests
 */

const {
  createStockAdjustmentSchema,
  updateStockAdjustmentSchema,
  stockAdjustmentIdParamsSchema,
  listStockAdjustmentsQuerySchema
} = require('@modules/stock-adjustment/schemas/stock-adjustment.schema');

describe('Stock Adjustment Schema Validation', () => {
  describe('createStockAdjustmentSchema', () => {
    it('should validate valid stock adjustment data', () => {
      const validData = {
        inventory_item_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '660e8400-e29b-41d4-a716-446655440000',
        quantity: 10,
        reason: 'CORRECTION'
      };
      const result = createStockAdjustmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation without inventory_item_id', () => {
      const invalidData = { quantity: 10, reason: 'CORRECTION' };
      const result = createStockAdjustmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation with invalid reason', () => {
      const invalidData = {
        inventory_item_id: '550e8400-e29b-41d4-a716-446655440000',
        quantity: 10,
        reason: 'INVALID_REASON'
      };
      const result = createStockAdjustmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateStockAdjustmentSchema', () => {
    it('should validate with all fields', () => {
      const validData = { quantity: 5, reason: 'DAMAGED' };
      const result = updateStockAdjustmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const result = updateStockAdjustmentSchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });

  describe('stockAdjustmentIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validParams = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = stockAdjustmentIdParamsSchema.safeParse(validParams);
      expect(result.success).toBe(true);
    });
  });

  describe('listStockAdjustmentsQuerySchema', () => {
    it('should validate with all query parameters', () => {
      const validQuery = {
        page: '1',
        limit: '20',
        inventory_item_id: '550e8400-e29b-41d4-a716-446655440000',
        reason: 'CORRECTION'
      };
      const result = listStockAdjustmentsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });
  });
});
