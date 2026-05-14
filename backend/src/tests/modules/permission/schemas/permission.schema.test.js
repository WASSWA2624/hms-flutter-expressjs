/**
 * Permission schema validation tests
 *
 * @module tests/modules/permission/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createPermissionSchema,
  updatePermissionSchema,
  permissionIdParamsSchema,
  listPermissionsQuerySchema
} = require('@validations/permission/permission.schema');

describe('Permission Schema Validation', () => {
  describe('createPermissionSchema', () => {
    it('should validate correct permission data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'view_users',
        description: 'Permission to view users'
      };
      const result = createPermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'edit_settings'
      };
      const result = createPermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing tenant_id', () => {
      const invalidData = { name: 'test' };
      const result = createPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing name', () => {
      const invalidData = { tenant_id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = createPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'a'.repeat(121)
      };
      const result = createPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updatePermissionSchema', () => {
    it('should validate correct update data', () => {
      const validData = { name: 'updated_permission', description: 'Updated' };
      const result = updatePermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const validData = {};
      const result = updatePermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject empty name', () => {
      const invalidData = { name: '' };
      const result = updatePermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('permissionIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = { id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = permissionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = { id: 'invalid-uuid' };
      const result = permissionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listPermissionsQuerySchema', () => {
    it('should validate correct query params', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'view',
        search: 'user',
        page: '1',
        limit: '20'
      };
      const result = listPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with no filters', () => {
      const validData = {};
      const result = listPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });
  });
});
