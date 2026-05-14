/**
 * Terms acceptance schema tests
 *
 * @module tests/modules/terms-acceptance/schemas
 * @description Tests for terms acceptance validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createTermsAcceptanceSchema,
  termsAcceptanceIdParamsSchema,
  listTermsAcceptancesQuerySchema
} = require('@validations/terms-acceptance/terms-acceptance.schema');

describe('Terms Acceptance Schemas', () => {
  describe('createTermsAcceptanceSchema', () => {
    const validData = {
      user_id: '550e8400-e29b-41d4-a716-446655440000',
      version_label: 'v1.0.0'
    };

    it('should validate correct terms acceptance data', () => {
      const result = createTermsAcceptanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require user_id', () => {
      const data = { ...validData };
      delete data.user_id;
      const result = createTermsAcceptanceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require version_label', () => {
      const data = { ...validData };
      delete data.version_label;
      const result = createTermsAcceptanceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for user_id', () => {
      const data = { ...validData, user_id: 'invalid-uuid' };
      const result = createTermsAcceptanceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty version_label', () => {
      const data = { ...validData, version_label: '' };
      const result = createTermsAcceptanceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject version_label longer than 40 characters', () => {
      const data = { ...validData, version_label: 'a'.repeat(41) };
      const result = createTermsAcceptanceSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim version_label', () => {
      const data = { ...validData, version_label: '  v1.0.0  ' };
      const result = createTermsAcceptanceSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.version_label).toBe('v1.0.0');
      }
    });
  });

  describe('termsAcceptanceIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = termsAcceptanceIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = termsAcceptanceIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = termsAcceptanceIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listTermsAcceptancesQuerySchema', () => {
    it('should validate correct query params', () => {
      const query = {
        page: 1,
        limit: 10,
        sort_by: 'created_at',
        order: 'desc',
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        version_label: 'v1.0.0'
      };
      const result = listTermsAcceptancesQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should allow all fields to be optional', () => {
      const result = listTermsAcceptancesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate user_id UUID format if provided', () => {
      const query = { user_id: 'invalid-uuid' };
      const result = listTermsAcceptancesQuerySchema.safeParse(query);
      expect(result.success).toBe(false);
    });

    it('should accept valid version_label', () => {
      const query = { version_label: 'v2.5.1' };
      const result = listTermsAcceptancesQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should accept standard pagination parameters', () => {
      const query = { page: 1, limit: 50, sort_by: 'accepted_at', order: 'asc' };
      const result = listTermsAcceptancesQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });
  });
});
