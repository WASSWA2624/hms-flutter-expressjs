/**
 * Insurance claim schema tests
 *
 * @module tests/modules/insurance-claim/schemas
 * @description Tests for insurance claim validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createInsuranceClaimSchema,
  updateInsuranceClaimSchema,
  insuranceClaimIdParamsSchema,
  listInsuranceClaimsQuerySchema
} = require('@validations/insurance-claim/insurance-claim.schema');

describe('Insurance Claim Schemas', () => {
  describe('createInsuranceClaimSchema', () => {
    const validData = {
      coverage_plan_id: '550e8400-e29b-41d4-a716-446655440000',
      invoice_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'SUBMITTED',
      submitted_at: '2024-01-01T00:00:00.000Z'
    };

    it('should validate correct insurance claim data', () => {
      const result = createInsuranceClaimSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require coverage_plan_id', () => {
      const data = { ...validData };
      delete data.coverage_plan_id;
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require invoice_id', () => {
      const data = { ...validData };
      delete data.invoice_id;
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional submitted_at', () => {
      const data = { ...validData };
      delete data.submitted_at;
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept SUBMITTED status', () => {
      const data = { ...validData, status: 'SUBMITTED' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept APPROVED status', () => {
      const data = { ...validData, status: 'APPROVED' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept REJECTED status', () => {
      const data = { ...validData, status: 'REJECTED' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept PAID status', () => {
      const data = { ...validData, status: 'PAID' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept CANCELLED status', () => {
      const data = { ...validData, status: 'CANCELLED' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for coverage_plan_id', () => {
      const data = { ...validData, coverage_plan_id: 'invalid-uuid' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for invoice_id', () => {
      const data = { ...validData, invoice_id: 'invalid-uuid' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for submitted_at', () => {
      const data = { ...validData, submitted_at: 'invalid-datetime' };
      const result = createInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateInsuranceClaimSchema', () => {
    const validData = {
      coverage_plan_id: '550e8400-e29b-41d4-a716-446655440000',
      invoice_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'APPROVED',
      submitted_at: '2024-01-01T00:00:00.000Z'
    };

    it('should validate correct update data', () => {
      const result = updateInsuranceClaimSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept optional coverage_plan_id', () => {
      const data = { ...validData };
      delete data.coverage_plan_id;
      const result = updateInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional invoice_id', () => {
      const data = { ...validData };
      delete data.invoice_id;
      const result = updateInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional status', () => {
      const data = { ...validData };
      delete data.status;
      const result = updateInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional submitted_at', () => {
      const data = { ...validData };
      delete data.submitted_at;
      const result = updateInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty object', () => {
      const result = updateInsuranceClaimSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate status enum', () => {
      const data = { status: 'INVALID' };
      const result = updateInsuranceClaimSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('insuranceClaimIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = insuranceClaimIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = insuranceClaimIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = insuranceClaimIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listInsuranceClaimsQuerySchema', () => {
    it('should validate correct query params', () => {
      const data = {
        coverage_plan_id: '550e8400-e29b-41d4-a716-446655440000',
        invoice_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'SUBMITTED',
        submitted_at_from: '2024-01-01T00:00:00.000Z',
        submitted_at_to: '2024-12-31T23:59:59.999Z',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listInsuranceClaimsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional filters', () => {
      const data = {};
      const result = listInsuranceClaimsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum', () => {
      const data = { status: 'INVALID' };
      const result = listInsuranceClaimsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for coverage_plan_id', () => {
      const data = { coverage_plan_id: 'invalid-uuid' };
      const result = listInsuranceClaimsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for invoice_id', () => {
      const data = { invoice_id: 'invalid-uuid' };
      const result = listInsuranceClaimsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for submitted_at_from', () => {
      const data = { submitted_at_from: 'invalid-datetime' };
      const result = listInsuranceClaimsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for submitted_at_to', () => {
      const data = { submitted_at_to: 'invalid-datetime' };
      const result = listInsuranceClaimsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
