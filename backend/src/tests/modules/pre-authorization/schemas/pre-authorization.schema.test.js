/**
 * Pre-authorization schema tests
 *
 * @module tests/modules/pre-authorization/schemas
 * @description Tests for pre-authorization validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPreAuthorizationSchema,
  updatePreAuthorizationSchema,
  preAuthorizationIdParamsSchema,
  listPreAuthorizationsQuerySchema
} = require('@validations/pre-authorization/pre-authorization.schema');

describe('Pre-Authorization Schemas', () => {
  describe('createPreAuthorizationSchema', () => {
    const validData = {
      coverage_plan_id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'PENDING',
      requested_at: '2024-01-01T00:00:00.000Z',
      approved_at: null
    };

    it('should validate correct pre-authorization data', () => {
      const result = createPreAuthorizationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require coverage_plan_id', () => {
      const data = { ...validData };
      delete data.coverage_plan_id;
      const result = createPreAuthorizationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createPreAuthorizationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createPreAuthorizationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept all valid statuses', () => {
      ['PENDING', 'APPROVED', 'DENIED', 'EXPIRED'].forEach(status => {
        const data = { ...validData, status };
        const result = createPreAuthorizationSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid UUID for coverage_plan_id', () => {
      const data = { ...validData, coverage_plan_id: 'invalid-uuid' };
      const result = createPreAuthorizationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for requested_at', () => {
      const data = { ...validData, requested_at: 'invalid-datetime' };
      const result = createPreAuthorizationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime for approved_at', () => {
      const data = { ...validData, approved_at: 'invalid-datetime' };
      const result = createPreAuthorizationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updatePreAuthorizationSchema', () => {
    it('should validate correct update data', () => {
      const data = {
        coverage_plan_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'APPROVED'
      };
      const result = updatePreAuthorizationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty object', () => {
      const result = updatePreAuthorizationSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate status enum', () => {
      const data = { status: 'INVALID' };
      const result = updatePreAuthorizationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('preAuthorizationIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = preAuthorizationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = preAuthorizationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = preAuthorizationIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listPreAuthorizationsQuerySchema', () => {
    it('should validate correct query params', () => {
      const data = {
        coverage_plan_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING',
        requested_at_from: '2024-01-01T00:00:00.000Z',
        requested_at_to: '2024-12-31T23:59:59.999Z',
        approved_at_from: '2024-01-01T00:00:00.000Z',
        approved_at_to: '2024-12-31T23:59:59.999Z'
      };
      const result = listPreAuthorizationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional filters', () => {
      const data = {};
      const result = listPreAuthorizationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum', () => {
      const data = { status: 'INVALID' };
      const result = listPreAuthorizationsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
