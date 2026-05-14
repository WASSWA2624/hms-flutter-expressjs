/**
 * Inventory stock schema tests
 *
 * @module tests/modules/inventory-stock/schemas
 * @description Tests for inventory stock validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createInventoryStockSchema,
  updateInventoryStockSchema,
  inventoryStockIdParamsSchema,
  listInventoryStocksQuerySchema
} = require('@validations/inventory-stock/inventory-stock.schema');

describe('Inventory Stock Schemas', () => {
  describe('createInventoryStockSchema', () => {
    const validData = {
      inventory_item_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      quantity: 100,
      reorder_level: 10
    };

    it('should validate correct inventory stock data', () => {
      const result = createInventoryStockSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require inventory_item_id', () => {
      const data = { ...validData };
      delete data.inventory_item_id;
      const result = createInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require quantity', () => {
      const data = { ...validData };
      delete data.quantity;
      const result = createInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject negative quantity', () => {
      const data = { ...validData, quantity: -1 };
      const result = createInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject non-integer quantity', () => {
      const data = { ...validData, quantity: 10.5 };
      const result = createInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should default reorder_level to 0', () => {
      const data = { ...validData };
      delete data.reorder_level;
      const result = createInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.reorder_level).toBe(0);
      }
    });

    it('should reject negative reorder_level', () => {
      const data = { ...validData, reorder_level: -1 };
      const result = createInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateInventoryStockSchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        quantity: 150,
        reorder_level: 20
      };
      const result = updateInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { quantity: 150 };
      const result = updateInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty update object', () => {
      const data = {};
      const result = updateInventoryStockSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('inventoryStockIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = inventoryStockIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = inventoryStockIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });
  });

  describe('listInventoryStocksQuerySchema', () => {
    it('should validate query with all optional filters', () => {
      const query = {
        inventory_item_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        page: 1,
        limit: 20
      };
      const result = listInventoryStocksQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate query with no filters', () => {
      const query = {};
      const result = listInventoryStocksQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });
  });
});
