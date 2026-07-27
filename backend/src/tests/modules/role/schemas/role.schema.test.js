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
        display_name: 'Administrator',
        description: 'Administrator role with full permissions'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject null display_name on create', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Role',
        display_name: null
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject display_name exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Role',
        display_name: 'a'.repeat(161)
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing display_name', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Basic Role'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(false);
    });

    it('should validate friendly tenant identifiers', () => {
      const validData = {
        tenant_id: 'TEN0001',
        name: 'Basic Role',
        display_name: 'Basic Role'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null optional description', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: null,
        name: 'Test Role',
        display_name: 'Test Role',
        description: null
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept confirm_similar on create', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Role',
        display_name: 'Test Role',
        confirm_similar: true
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
      expect(result.data.confirm_similar).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '  Admin Role  ',
        display_name: 'Administrator'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Admin Role');
      }
    });

    it('should accept platform create without tenant_id', () => {
      const validData = {
        name: 'Platform Role',
        display_name: 'Platform Role',
        tenant_id: null,
        facility_id: null
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept platform create when tenant_id is omitted', () => {
      const validData = {
        name: 'Platform Role',
        display_name: 'Platform Role'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept explicit scope=platform even with tenant_id present', () => {
      const validData = {
        scope: 'platform',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Platform Role',
        display_name: 'Platform Role'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept facility-scoped create without tenant_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Facility Role',
        display_name: 'Facility Role'
      };
      const result = createRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        display_name: 'Test Role'
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        name: 'Test Role',
        display_name: 'Test Role'
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'a'.repeat(121),
        display_name: 'Test Role'
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject description exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Role',
        display_name: 'Test Role',
        description: 'a'.repeat(256)
      };
      const result = createRoleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '',
        display_name: 'Test Role'
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
        display_name: 'Updated Display Name',
        description: 'Updated description'
      };
      const result = updateRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate display_name-only update', () => {
      const validData = {
        display_name: 'Front Desk'
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

    it('should validate scope and tenant_id updates', () => {
      const validData = {
        scope: 'tenant',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: null,
        name: 'Updated Role'
      };
      const result = updateRoleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate platform scope update', () => {
      const validData = {
        scope: 'platform',
        tenant_id: null,
        facility_id: null
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
