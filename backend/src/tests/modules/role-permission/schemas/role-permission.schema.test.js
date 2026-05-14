/**
 * Role-Permission schema validation tests
 *
 * @module tests/modules/role-permission/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createRolePermissionSchema,
  updateRolePermissionSchema,
  rolePermissionIdParamsSchema,
  listRolePermissionsQuerySchema
} = require('@validations/role-permission/role-permission.schema');

describe('Role-Permission Schema Validation', () => {
  describe('createRolePermissionSchema', () => {
    it('should validate correct role-permission data', () => {
      const validData = {
        role_id: '123e4567-e89b-12d3-a456-426614174000',
        permission_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createRolePermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing role_id', () => {
      const invalidData = { permission_id: '123e4567-e89b-12d3-a456-426614174001' };
      const result = createRolePermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid role_id format', () => {
      const invalidData = {
        role_id: 'invalid-uuid',
        permission_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createRolePermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateRolePermissionSchema', () => {
    it('should validate with empty object', () => {
      const validData = {};
      const result = updateRolePermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with single field', () => {
      const validData = { role_id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = updateRolePermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });

  describe('rolePermissionIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = { id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = rolePermissionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = { id: 'invalid-uuid' };
      const result = rolePermissionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listRolePermissionsQuerySchema', () => {
    it('should validate correct query params', () => {
      const validData = {
        role_id: '123e4567-e89b-12d3-a456-426614174000',
        permission_id: '123e4567-e89b-12d3-a456-426614174001',
        page: '1',
        limit: '20'
      };
      const result = listRolePermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with no filters', () => {
      const validData = {};
      const result = listRolePermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });
});
