/**
 * User Session schema validation tests
 *
 * @module tests/modules/user-session/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  sessionIdParamsSchema,
  listSessionsQuerySchema
} = require('@validations/user-session/user-session.schema');

describe('User Session Schema Validation', () => {
  describe('sessionIdParamsSchema', () => {
    it('should validate correct UUID session ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = sessionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = sessionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = sessionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = sessionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listSessionsQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listSessionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listSessionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listSessionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with user_id filter', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listSessionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_active filter', () => {
      const validData = {
        is_active: 'true'
      };
      const result = listSessionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all params', () => {
      const validData = {
        page: 2,
        limit: 50,
        sort_by: 'expires_at',
        order: 'asc',
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        is_active: 'false'
      };
      const result = listSessionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid user_id format', () => {
      const invalidData = {
        user_id: 'not-a-uuid'
      };
      const result = listSessionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active value', () => {
      const invalidData = {
        is_active: 'maybe'
      };
      const result = listSessionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listSessionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listSessionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listSessionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listSessionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });
  });
});
