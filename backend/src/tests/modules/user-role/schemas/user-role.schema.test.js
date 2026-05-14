/**
 * User-Role schema validation tests
 *
 * @module tests/modules/user-role/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createUserRoleSchema,
  updateUserRoleSchema,
  userRoleIdParamsSchema,
  listUserRolesQuerySchema
} = require('@validations/user-role/user-role.schema');

describe('User-Role Schema Validation', () => {
  describe('createUserRoleSchema', () => {
    it('should validate correct user-role data', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        role_id: '123e4567-e89b-12d3-a456-426614174001',
        tenant_id: '123e4567-e89b-12d3-a456-426614174002',
        facility_id: '123e4567-e89b-12d3-a456-426614174003'
      };
      const result = createUserRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        role_id: '123e4567-e89b-12d3-a456-426614174001',
        tenant_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = createUserRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing required fields', () => {
      const invalidData = { user_id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = createUserRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        user_id: 'invalid-uuid',
        role_id: '123e4567-e89b-12d3-a456-426614174001',
        tenant_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = createUserRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateUserRoleSchema', () => {
    it('should validate with empty object', () => {
      const validData = {};
      const result = updateUserRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with single field', () => {
      const validData = { role_id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = updateUserRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });

  describe('userRoleIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = { id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = userRoleIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = { id: 'invalid-uuid' };
      const result = userRoleIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listUserRolesQuerySchema', () => {
    it('should validate correct query params', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        role_id: '123e4567-e89b-12d3-a456-426614174001',
        tenant_id: '123e4567-e89b-12d3-a456-426614174002',
        facility_id: '123e4567-e89b-12d3-a456-426614174003',
        page: '1',
        limit: '20'
      };
      const result = listUserRolesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with no filters', () => {
      const validData = {};
      const result = listUserRolesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });
});
