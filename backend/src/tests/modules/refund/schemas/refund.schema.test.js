/**
 * Refund schema tests
 */

const {
  createRefundSchema,
  updateRefundSchema,
  refundIdParamsSchema,
  listRefundsQuerySchema
} = require('@validations/refund/refund.schema');

describe('Refund Schemas', () => {
  const validCreateData = {
    payment_id: '550e8400-e29b-41d4-a716-446655440000',
    amount: '25.00',
    refunded_at: '2026-02-12T10:00:00.000Z',
    reason: 'Duplicate charge'
  };

  describe('createRefundSchema', () => {
    it('should validate valid refund payload', () => {
      const result = createRefundSchema.safeParse(validCreateData);
      expect(result.success).toBe(true);
    });

    it('should require payment_id and amount', () => {
      const missingPayment = createRefundSchema.safeParse({
        ...validCreateData,
        payment_id: undefined
      });
      const missingAmount = createRefundSchema.safeParse({
        ...validCreateData,
        amount: undefined
      });

      expect(missingPayment.success).toBe(false);
      expect(missingAmount.success).toBe(false);
    });

    it('should validate amount decimal format', () => {
      const result = createRefundSchema.safeParse({
        ...validCreateData,
        amount: '10.999'
      });
      expect(result.success).toBe(false);
    });

    it('should allow nullable reason', () => {
      const result = createRefundSchema.safeParse({
        ...validCreateData,
        reason: null
      });
      expect(result.success).toBe(true);
    });
  });

  describe('updateRefundSchema', () => {
    it('should allow empty payload', () => {
      const result = updateRefundSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial payload', () => {
      const result = updateRefundSchema.safeParse({
        amount: '15.00',
        reason: 'Partial refund'
      });
      expect(result.success).toBe(true);
    });
  });

  describe('refundIdParamsSchema', () => {
    it('should validate valid id', () => {
      const result = refundIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid id', () => {
      const result = refundIdParamsSchema.safeParse({ id: 'bad-id' });
      expect(result.success).toBe(false);
    });
  });

  describe('listRefundsQuerySchema', () => {
    it('should validate query filters', () => {
      const result = listRefundsQuerySchema.safeParse({
        payment_id: '550e8400-e29b-41d4-a716-446655440000',
        refunded_at_from: '2026-01-01T00:00:00.000Z',
        refunded_at_to: '2026-12-31T23:59:59.000Z',
        search: 'Duplicate',
        page: '1',
        limit: '20'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid payment_id', () => {
      const result = listRefundsQuerySchema.safeParse({ payment_id: 'bad-id' });
      expect(result.success).toBe(false);
    });
  });
});

