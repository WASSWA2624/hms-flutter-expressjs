/**
 * Payment schema tests
 */

const {
  createPaymentSchema,
  updatePaymentSchema,
  paymentIdParamsSchema,
  listPaymentsQuerySchema
} = require('@validations/payment/payment.schema');

describe('Payment Schemas', () => {
  const validCreateData = {
    tenant_id: '550e8400-e29b-41d4-a716-446655440000',
    facility_id: '550e8400-e29b-41d4-a716-446655440001',
    patient_id: '550e8400-e29b-41d4-a716-446655440002',
    invoice_id: '550e8400-e29b-41d4-a716-446655440003',
    status: 'COMPLETED',
    method: 'BANK_TRANSFER',
    amount: '120.50',
    paid_at: '2026-02-12T10:00:00.000Z',
    transaction_ref: 'TXN-001'
  };

  describe('createPaymentSchema', () => {
    it('should validate valid payment payload', () => {
      const result = createPaymentSchema.safeParse(validCreateData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id and invoice_id', () => {
      const missingTenant = createPaymentSchema.safeParse({
        ...validCreateData,
        tenant_id: undefined
      });
      const missingInvoice = createPaymentSchema.safeParse({
        ...validCreateData,
        invoice_id: undefined
      });

      expect(missingTenant.success).toBe(false);
      expect(missingInvoice.success).toBe(false);
    });

    it('should validate status and method enums', () => {
      const badStatus = createPaymentSchema.safeParse({
        ...validCreateData,
        status: 'INVALID'
      });
      const badMethod = createPaymentSchema.safeParse({
        ...validCreateData,
        method: 'INVALID'
      });

      expect(badStatus.success).toBe(false);
      expect(badMethod.success).toBe(false);
    });

    it('should allow nullable optional fields', () => {
      const result = createPaymentSchema.safeParse({
        ...validCreateData,
        facility_id: null,
        patient_id: null,
        paid_at: null,
        transaction_ref: null
      });

      expect(result.success).toBe(true);
    });

    it('should reject invalid amount format', () => {
      const result = createPaymentSchema.safeParse({
        ...validCreateData,
        amount: '120.555'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('updatePaymentSchema', () => {
    it('should allow empty payload', () => {
      const result = updatePaymentSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const result = updatePaymentSchema.safeParse({
        status: 'REFUNDED',
        method: 'CASH'
      });
      expect(result.success).toBe(true);
    });
  });

  describe('paymentIdParamsSchema', () => {
    it('should validate valid id', () => {
      const result = paymentIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid id', () => {
      const result = paymentIdParamsSchema.safeParse({ id: 'bad-id' });
      expect(result.success).toBe(false);
    });
  });

  describe('listPaymentsQuerySchema', () => {
    it('should validate query filters', () => {
      const result = listPaymentsQuerySchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING',
        method: 'CREDIT_CARD',
        paid_at_from: '2026-01-01T00:00:00.000Z',
        paid_at_to: '2026-12-31T23:59:59.000Z',
        search: 'TXN',
        page: '1',
        limit: '20',
        sort_by: 'paid_at',
        order: 'desc'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid enum values in query', () => {
      const result = listPaymentsQuerySchema.safeParse({
        status: 'INVALID'
      });
      expect(result.success).toBe(false);
    });
  });
});

