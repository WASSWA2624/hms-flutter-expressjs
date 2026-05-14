/**
 * Purchase request schema validation tests
 */

const {
  createPurchaseRequestSchema,
  updatePurchaseRequestSchema,
  purchaseRequestIdParamsSchema,
  listPurchaseRequestsQuerySchema
} = require('@modules/purchase-request/schemas/purchase-request.schema');

describe('Purchase Request Schema Validation', () => {
  describe('createPurchaseRequestSchema', () => {
    it('should validate valid purchase request data', () => {
      const validData = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '660e8400-e29b-41d4-a716-446655440000',
        requested_by_user_id: '770e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING'
      };

      const result = createPurchaseRequestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should fail validation without tenant_id', () => {
      const invalidData = { status: 'PENDING' };
      const result = createPurchaseRequestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should fail validation without status', () => {
      const invalidData = { tenant_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = createPurchaseRequestSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updatePurchaseRequestSchema', () => {
    it('should validate with all fields', () => {
      const validData = { status: 'APPROVED' };
      const result = updatePurchaseRequestSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const result = updatePurchaseRequestSchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });

  describe('purchaseRequestIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validParams = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = purchaseRequestIdParamsSchema.safeParse(validParams);
      expect(result.success).toBe(true);
    });

    it('should fail validation with invalid UUID', () => {
      const invalidParams = { id: 'invalid-uuid' };
      const result = purchaseRequestIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });
  });

  describe('listPurchaseRequestsQuerySchema', () => {
    it('should validate with all query parameters', () => {
      const validQuery = {
        page: '1',
        limit: '20',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING'
      };
      const result = listPurchaseRequestsQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });
  });
});
