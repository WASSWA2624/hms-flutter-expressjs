/**
 * Purchase order schema validation tests
 */

const {
  createPurchaseOrderSchema,
  updatePurchaseOrderSchema,
  purchaseOrderIdParamsSchema,
  listPurchaseOrdersQuerySchema
} = require('@modules/purchase-order/schemas/purchase-order.schema');

describe('Purchase Order Schema Validation', () => {
  describe('createPurchaseOrderSchema', () => {
    it('should validate valid purchase order data', () => {
      const validData = {
        purchase_request_id: '550e8400-e29b-41d4-a716-446655440000',
        supplier_id: '660e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING'
      };
      const result = createPurchaseOrderSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation without status', () => {
      const invalidData = { supplier_id: '660e8400-e29b-41d4-a716-446655440000' };
      const result = createPurchaseOrderSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updatePurchaseOrderSchema', () => {
    it('should validate with all fields', () => {
      const validData = { status: 'APPROVED' };
      const result = updatePurchaseOrderSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const result = updatePurchaseOrderSchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });

  describe('purchaseOrderIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validParams = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = purchaseOrderIdParamsSchema.safeParse(validParams);
      expect(result.success).toBe(true);
    });
  });

  describe('listPurchaseOrdersQuerySchema', () => {
    it('should validate with all query parameters', () => {
      const validQuery = {
        page: '1',
        limit: '20',
        supplier_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING'
      };
      const result = listPurchaseOrdersQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });
  });
});
