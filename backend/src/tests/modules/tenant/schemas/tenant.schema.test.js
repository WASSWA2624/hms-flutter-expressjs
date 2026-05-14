/**
 * Tenant schema validation tests
 *
 * @module tests/modules/tenant/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createTenantSchema,
  updateTenantSchema,
  tenantIdParamsSchema,
  listTenantsQuerySchema
} = require('@validations/tenant/tenant.schema');

describe('Tenant Schema Validation', () => {
  describe('createTenantSchema', () => {
    it('should validate correct tenant data', () => {
      const validData = {
        name: 'Test Hospital',
        slug: 'test-hospital',
        is_active: true
      };
      const result = createTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (name only)', () => {
      const validData = {
        name: 'Test Hospital'
      };
      const result = createTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept extension_json branding metadata', () => {
      const validData = {
        name: 'Test Hospital',
        extension_json: {
          logo_url: 'https://example.com/logo.png',
          website: 'https://example.com',
          timezone: 'Africa/Kampala',
          currency: 'UGX'
        }
      };
      const result = createTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.extension_json).toEqual(validData.extension_json);
      }
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Test Hospital  '
      };
      const result = createTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Test Hospital');
      }
    });

    it('should trim slug whitespace', () => {
      const validData = {
        name: 'Test Hospital',
        slug: '  test-hospital  '
      };
      const result = createTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.slug).toBe('test-hospital');
      }
    });

    it('should reject missing name', () => {
      const invalidData = {};
      const result = createTenantSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = createTenantSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        name: 'a'.repeat(256)
      };
      const result = createTenantSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject slug exceeding 191 characters', () => {
      const invalidData = {
        name: 'Test Hospital',
        slug: 'a'.repeat(192)
      };
      const result = createTenantSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active type', () => {
      const invalidData = {
        name: 'Test Hospital',
        is_active: 'yes'
      };
      const result = createTenantSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateTenantSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        name: 'Updated Hospital',
        slug: 'updated-hospital',
        is_active: false
      };
      const result = updateTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only name', () => {
      const validData = {
        name: 'Updated Hospital'
      };
      const result = updateTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only slug', () => {
      const validData = {
        slug: 'updated-hospital'
      };
      const result = updateTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only is_active', () => {
      const validData = {
        is_active: false
      };
      const result = updateTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null slug', () => {
      const validData = {
        slug: null
      };
      const result = updateTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept extension_json updates and allow clearing metadata', () => {
      const validUpdate = updateTenantSchema.safeParse({
        extension_json: {
          email: 'support@example.com',
          phone: '+256700000000'
        }
      });
      const clearUpdate = updateTenantSchema.safeParse({
        extension_json: null
      });

      expect(validUpdate.success).toBe(true);
      expect(clearUpdate.success).toBe(true);
      if (validUpdate.success) {
        expect(validUpdate.data.extension_json).toEqual({
          email: 'support@example.com',
          phone: '+256700000000'
        });
      }
      if (clearUpdate.success) {
        expect(clearUpdate.data.extension_json).toBeNull();
      }
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Updated Hospital  '
      };
      const result = updateTenantSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Hospital');
      }
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateTenantSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        name: 'a'.repeat(256)
      };
      const result = updateTenantSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject slug exceeding 191 characters', () => {
      const invalidData = {
        slug: 'a'.repeat(192)
      };
      const result = updateTenantSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('tenantIdParamsSchema', () => {
    it('should validate correct UUID tenant ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = tenantIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = tenantIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = tenantIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = tenantIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listTenantsQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listTenantsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listTenantsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listTenantsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_active filter', () => {
      const validData = {
        is_active: 'true'
      };
      const result = listTenantsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const validData = {
        search: 'hospital'
      };
      const result = listTenantsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all params', () => {
      const validData = {
        page: 2,
        limit: 50,
        sort_by: 'name',
        order: 'asc',
        is_active: 'false',
        search: 'clinic'
      };
      const result = listTenantsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid is_active value', () => {
      const invalidData = {
        is_active: 'maybe'
      };
      const result = listTenantsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listTenantsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listTenantsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listTenantsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listTenantsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  hospital  '
      };
      const result = listTenantsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('hospital');
      }
    });
  });
});
