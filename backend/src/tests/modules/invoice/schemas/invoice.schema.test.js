/**
 * Invoice schema tests
 *
 * @module tests/modules/invoice/schemas
 * @description Tests for invoice validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createInvoiceSchema,
  updateInvoiceSchema,
  invoiceIdParamsSchema,
  listInvoicesQuerySchema
} = require('@validations/invoice/invoice.schema');

describe('Invoice Schemas', () => {
  describe('createInvoiceSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'DRAFT',
      billing_status: 'DRAFT',
      total_amount: '1500.50',
      currency: 'USD'
    };

    it('should validate correct invoice data', () => {
      const result = createInvoiceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require total_amount', () => {
      const data = { ...validData };
      delete data.total_amount;
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require currency', () => {
      const data = { ...validData };
      delete data.currency;
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createInvoiceSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should validate billing_status enum values', () => {
      const data = { ...validData, billing_status: 'INVALID' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid billing_status values', () => {
      const billingStatuses = ['DRAFT', 'ISSUED', 'PAID', 'PARTIAL', 'CANCELLED'];
      billingStatuses.forEach(billing_status => {
        const data = { ...validData, billing_status };
        const result = createInvoiceSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should default billing_status to DRAFT', () => {
      const data = { ...validData };
      delete data.billing_status;
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.billing_status).toBe('DRAFT');
      }
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional issued_at', () => {
      const data = { ...validData };
      delete data.issued_at;
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept nullable facility_id', () => {
      const data = { ...validData, facility_id: null };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept nullable patient_id', () => {
      const data = { ...validData, patient_id: null };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for facility_id', () => {
      const data = { ...validData, facility_id: 'invalid-uuid' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for patient_id', () => {
      const data = { ...validData, patient_id: 'invalid-uuid' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate decimal format for total_amount', () => {
      const data = { ...validData, total_amount: 'invalid-amount' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid decimal values for total_amount', () => {
      const validAmounts = ['0.00', '100', '1500.50', '999999.99'];
      validAmounts.forEach(total_amount => {
        const data = { ...validData, total_amount };
        const result = createInvoiceSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should trim whitespace from currency', () => {
      const data = { ...validData, currency: '  USD  ' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.currency).toBe('USD');
      }
    });

    it('should enforce currency max length', () => {
      const data = { ...validData, currency: 'A'.repeat(11) };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate issued_at datetime format', () => {
      const data = { ...validData, issued_at: '2026-01-19T12:00:00Z' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid datetime format for issued_at', () => {
      const data = { ...validData, issued_at: '2026-01-19' };
      const result = createInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateInvoiceSchema', () => {
    const validData = {
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'SENT',
      billing_status: 'ISSUED',
      total_amount: '2000.00',
      currency: 'EUR'
    };

    it('should validate correct update data', () => {
      const result = updateInvoiceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { status: 'PAID' };
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty object for no updates', () => {
      const data = {};
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum when provided', () => {
      const data = { status: 'INVALID' };
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate billing_status enum when provided', () => {
      const data = { billing_status: 'INVALID' };
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format when facility_id provided', () => {
      const data = { facility_id: 'invalid-uuid' };
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUID format when patient_id provided', () => {
      const data = { patient_id: 'invalid-uuid' };
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate decimal format when total_amount provided', () => {
      const data = { total_amount: 'invalid' };
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow nullable facility_id', () => {
      const data = { facility_id: null };
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable patient_id', () => {
      const data = { patient_id: null };
      const result = updateInvoiceSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('invoiceIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = invoiceIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = invoiceIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const data = {};
      const result = invoiceIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listInvoicesQuerySchema', () => {
    it('should validate correct query params', () => {
      const data = {
        page: '1',
        limit: '10',
        sort_by: 'created_at',
        order: 'asc',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'DRAFT'
      };
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional filters', () => {
      const data = {};
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate tenant_id UUID format', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate facility_id UUID format', () => {
      const data = { facility_id: 'invalid-uuid' };
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate patient_id UUID format', () => {
      const data = { patient_id: 'invalid-uuid' };
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum', () => {
      const data = { status: 'INVALID' };
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate billing_status enum', () => {
      const data = { billing_status: 'INVALID' };
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept search param', () => {
      const data = { search: 'invoice search term' };
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should trim search param', () => {
      const data = { search: '  invoice search  ' };
      const result = listInvoicesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('invoice search');
      }
    });
  });
});
