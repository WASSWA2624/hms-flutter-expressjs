/**
 * Role schema validation tests
 *
 * @module tests/modules/role/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createRoleSchema,
  updateRoleSchema,
  roleIdParamsSchema,
  listRolesQuerySchema
} = require('@validations/role/role.schema');

describe('Role Schema Validation', () => {
  describe('createRoleSchema', () => {
    it('should validate correct role data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Admin Role',
        description: 'Administrator role with full permissions'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (tenant_id and name only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Basic Role'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null optional fields', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: null,
        name: 'Test Role',
        description: null
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '  Admin Role  '
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Admin Role');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        name: 'Test Role'
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        name: 'Test Role'
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'a'.repeat(121)
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject description exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Role',
        description: 'a'.repeat(256)
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: ''
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateRoleSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Updated Role',
        description: 'Updated description'
      };
      const result = updateRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with single field', () => {
      const validData = {
        name: 'New Name'
      };
      const result = updateRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid facility_id format', () => {
      const invalidData = {
        facility_id: 'invalid-uuid'
      };
      const result = updateRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding max length', () => {
      const invalidData = {
        name: 'a'.repeat(121)
      };
      const result = updateRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('roleIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = roleIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };
      const result = roleIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = roleIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listRolesQuerySchema', () => {
    it('should validate correct query params', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Admin',
        search: 'role',
        page: '1',
        limit: '20',
        sort_by: 'name',
        order: 'asc'
      };
      const result = listRolesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with no filters', () => {
      const validData = {};
      const result = listRolesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only tenant_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listRolesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid'
      };
      const result = listRolesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id format', () => {
      const invalidData = {
        facility_id: 'invalid-uuid'
      };
      const result = listRolesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  test search  '
      };
      const result = listRolesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('test search');
      }
    });
  });
});
