/**
 * Goods receipt schema validation tests
 */

const {
  createGoodsReceiptSchema,
  updateGoodsReceiptSchema,
  goodsReceiptIdParamsSchema,
  listGoodsReceiptsQuerySchema
} = require('@modules/goods-receipt/schemas/goods-receipt.schema');

describe('Goods Receipt Schema Validation', () => {
  describe('createGoodsReceiptSchema', () => {
    it('should validate valid goods receipt data', () => {
      const validData = {
        purchase_order_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'RECEIVED'
      };
      const result = createGoodsReceiptSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation without purchase_order_id', () => {
      const invalidData = { status: 'RECEIVED' };
      const result = createGoodsReceiptSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateGoodsReceiptSchema', () => {
    it('should validate with all fields', () => {
      const validData = { status: 'CONFIRMED' };
      const result = updateGoodsReceiptSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });

  describe('goodsReceiptIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validParams = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = goodsReceiptIdParamsSchema.safeParse(validParams);
      expect(result.success).toBe(true);
    });
  });

  describe('listGoodsReceiptsQuerySchema', () => {
    it('should validate with all query parameters', () => {
      const validQuery = {
        page: '1',
        limit: '20',
        purchase_order_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'RECEIVED'
      };
      const result = listGoodsReceiptsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });
  });
});
