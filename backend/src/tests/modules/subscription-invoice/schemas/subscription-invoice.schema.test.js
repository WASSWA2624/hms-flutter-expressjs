/**
 * Subscription Invoice schema tests
 *
 * @module tests/modules/subscription-invoice/schemas
 * @description Tests for subscription invoice validation schemas
 */

const {
  createSubscriptionInvoiceSchema,
  updateSubscriptionInvoiceSchema,
  subscriptionInvoiceIdParamsSchema,
  listSubscriptionInvoicesQuerySchema
} = require('../../../../modules/subscription-invoice/schemas/subscription-invoice.schema');

describe('Subscription Invoice Schemas', () => {
  describe('createSubscriptionInvoiceSchema', () => {
    it('should validate correct create data', () => {
      const validData = {
        subscription_id: '123e4567-e89b-12d3-a456-426614174000',
        invoice_id: '123e4567-e89b-12d3-a456-426614174001'
      };

      const result = createSubscriptionInvoiceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing subscription_id', () => {
      const invalidData = {
        invoice_id: '123e4567-e89b-12d3-a456-426614174001'
      };

      const result = createSubscriptionInvoiceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing invoice_id', () => {
      const invalidData = {
        subscription_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createSubscriptionInvoiceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        subscription_id: 'invalid-uuid',
        invoice_id: '123e4567-e89b-12d3-a456-426614174001'
      };

      const result = createSubscriptionInvoiceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateSubscriptionInvoiceSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        subscription_id: '123e4567-e89b-12d3-a456-426614174000',
        invoice_id: '123e4567-e89b-12d3-a456-426614174001'
      };

      const result = updateSubscriptionInvoiceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const validData = {
        subscription_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = updateSubscriptionInvoiceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow empty update', () => {
      const validData = {};

      const result = updateSubscriptionInvoiceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        subscription_id: 'invalid-uuid'
      };

      const result = updateSubscriptionInvoiceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('subscriptionInvoiceIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = subscriptionInvoiceIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };

      const result = subscriptionInvoiceIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};

      const result = subscriptionInvoiceIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listSubscriptionInvoicesQuerySchema', () => {
    it('should validate correct query params', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc',
        subscription_id: '123e4567-e89b-12d3-a456-426614174000',
        invoice_id: '123e4567-e89b-12d3-a456-426614174001'
      };

      const result = listSubscriptionInvoicesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow minimal query params', () => {
      const validData = {};

      const result = listSubscriptionInvoicesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID in filters', () => {
      const invalidData = {
        subscription_id: 'invalid-uuid'
      };

      const result = listSubscriptionInvoicesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
