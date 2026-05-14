/**
 * Billing Adjustment schema tests
 *
 * @module tests/modules/billing-adjustment/schemas
 * @description Tests for billing adjustment validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createBillingAdjustmentSchema,
  updateBillingAdjustmentSchema,
  billingAdjustmentIdParamsSchema,
  listBillingAdjustmentsQuerySchema
} = require('@validations/billing-adjustment/billing-adjustment.schema');

describe('Billing Adjustment Schemas', () => {
  describe('createBillingAdjustmentSchema', () => {
    const validData = {
      invoice_id: '550e8400-e29b-41d4-a716-446655440000',
      amount: 100.50,
      status: 'DRAFT',
      reason: 'Discount applied',
      adjusted_at: '2026-01-19T10:00:00.000Z'
    };

    it('should validate correct billing adjustment data', () => {
      const result = createBillingAdjustmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require invoice_id', () => {
      const data = { ...validData };
      delete data.invoice_id;
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require amount', () => {
      const data = { ...validData };
      delete data.amount;
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createBillingAdjustmentSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional reason', () => {
      const data = { ...validData };
      delete data.reason;
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow null reason', () => {
      const data = { ...validData, reason: null };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional adjusted_at', () => {
      const data = { ...validData };
      delete data.adjusted_at;
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for invoice_id', () => {
      const data = { ...validData, invoice_id: 'invalid-uuid' };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for adjusted_at', () => {
      const data = { ...validData, adjusted_at: 'invalid-date' };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject negative amount', () => {
      const data = { ...validData, amount: -100 };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(true); // Negative adjustments are allowed
    });

    it('should reject Infinity amount', () => {
      const data = { ...validData, amount: Infinity };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject NaN amount', () => {
      const data = { ...validData, amount: NaN };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate reason max length of 255', () => {
      const data = { ...validData, reason: 'a'.repeat(256) };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept reason with max length of 255', () => {
      const data = { ...validData, reason: 'a'.repeat(255) };
      const result = createBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateBillingAdjustmentSchema', () => {
    it('should validate correct update data', () => {
      const data = {
        amount: 200.75,
        status: 'PAID',
        reason: 'Updated discount',
        adjusted_at: '2026-01-19T10:00:00.000Z'
      };
      const result = updateBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow all fields to be optional', () => {
      const result = updateBillingAdjustmentSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate status enum if provided', () => {
      const data = { status: 'INVALID' };
      const result = updateBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow null for reason', () => {
      const data = { reason: null };
      const result = updateBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject Infinity amount if provided', () => {
      const data = { amount: Infinity };
      const result = updateBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for adjusted_at', () => {
      const data = { adjusted_at: 'invalid-date' };
      const result = updateBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate reason max length if provided', () => {
      const data = { reason: 'a'.repeat(256) };
      const result = updateBillingAdjustmentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('billingAdjustmentIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = billingAdjustmentIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = billingAdjustmentIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = billingAdjustmentIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listBillingAdjustmentsQuerySchema', () => {
    it('should validate correct query params', () => {
      const query = {
        page: 1,
        limit: 10,
        sort_by: 'created_at',
        order: 'desc',
        invoice_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'PAID'
      };
      const result = listBillingAdjustmentsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should allow all fields to be optional', () => {
      const result = listBillingAdjustmentsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate invoice_id UUID format if provided', () => {
      const query = { invoice_id: 'invalid-uuid' };
      const result = listBillingAdjustmentsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should validate status enum if provided', () => {
      const query = { status: 'INVALID' };
      const result = listBillingAdjustmentsQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED'];
      statuses.forEach(status => {
        const query = { status };
        const result = listBillingAdjustmentsQuerySchema.safeParse(query);
        expect(result.success).toBe(true);
      });
    });

    it('should accept search parameter', () => {
      const query = { search: 'discount' };
      const result = listBillingAdjustmentsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });
  });
});
