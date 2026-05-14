/**
 * Address schema validation tests
 *
 * @module tests/modules/address/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createAddressSchema,
  updateAddressSchema,
  addressIdParamsSchema,
  listAddressesQuerySchema
} = require('@validations/address/address.schema');

describe('Address Schema Validation', () => {
  describe('createAddressSchema', () => {
    it('should validate correct address data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: '123 Main Street',
        line2: 'Apt 4B',
        city: 'New York',
        state: 'NY',
        postal_code: '10001',
        country: 'USA',
        latitude: 40.7128,
        longitude: -74.0060,
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createAddressSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (tenant_id, address_type, and line1 only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'WORK',
        line1: '456 Business Ave'
      };
      const result = createAddressSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all address types', () => {
      const types = ['HOME', 'WORK', 'BILLING', 'SHIPPING', 'OTHER'];
      types.forEach(type => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          address_type: type,
          line1: '123 Main Street'
        };
        const result = createAddressSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should validate with null optional fields', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: '123 Main Street',
        line2: null,
        city: null,
        state: null,
        postal_code: null,
        country: null,
        latitude: null,
        longitude: null,
        facility_id: null
      };
      const result = createAddressSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim line1 whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: '  123 Main Street  '
      };
      const result = createAddressSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.line1).toBe('123 Main Street');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        address_type: 'HOME',
        line1: '123 Main Street'
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing address_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        line1: '123 Main Street'
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing line1', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME'
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        address_type: 'HOME',
        line1: '123 Main Street'
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid address_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'INVALID_TYPE',
        line1: '123 Main Street'
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty line1', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: ''
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject line1 exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: 'a'.repeat(256)
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject latitude out of range (< -90)', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: '123 Main Street',
        latitude: -91
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject latitude out of range (> 90)', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: '123 Main Street',
        latitude: 91
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject longitude out of range (< -180)', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: '123 Main Street',
        longitude: -181
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject longitude out of range (> 180)', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        line1: '123 Main Street',
        longitude: 181
      };
      const result = createAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateAddressSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        address_type: 'WORK',
        line1: '456 Business Ave',
        line2: 'Suite 200',
        city: 'Boston',
        state: 'MA',
        postal_code: '02101',
        country: 'USA',
        latitude: 42.3601,
        longitude: -71.0589
      };
      const result = updateAddressSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with partial fields', () => {
      const validData = {
        line1: '456 Business Ave',
        city: 'Boston'
      };
      const result = updateAddressSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with no fields (all optional)', () => {
      const validData = {};
      const result = updateAddressSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid address_type', () => {
      const invalidData = {
        address_type: 'INVALID_TYPE'
      };
      const result = updateAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty line1', () => {
      const invalidData = {
        line1: ''
      };
      const result = updateAddressSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('addressIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = addressIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = addressIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = addressIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listAddressesQuerySchema', () => {
    it('should validate with all filters', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        address_type: 'HOME',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        branch_id: '123e4567-e89b-12d3-a456-426614174002',
        patient_id: '123e4567-e89b-12d3-a456-426614174003',
        city: 'New York',
        state: 'NY',
        country: 'USA',
        search: 'Main Street'
      };
      const result = listAddressesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with no filters', () => {
      const validData = {};
      const result = listAddressesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with partial filters', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        city: 'New York'
      };
      const result = listAddressesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listAddressesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid address_type', () => {
      const invalidData = {
        address_type: 'INVALID_TYPE'
      };
      const result = listAddressesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listAddressesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
