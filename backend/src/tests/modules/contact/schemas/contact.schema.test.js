/**
 * Contact schema validation tests
 *
 * @module tests/modules/contact/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createContactSchema,
  updateContactSchema,
  contactIdParamsSchema,
  listContactsQuerySchema
} = require('@validations/contact/contact.schema');

describe('Contact Schema Validation', () => {
  describe('createContactSchema', () => {
    it('should validate correct contact data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'PHONE',
        value: '+1234567890',
        is_primary: true,
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (tenant_id, contact_type, and value only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'EMAIL',
        value: 'user@example.com'
      };
      const result = createContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all contact types', () => {
      const types = ['PHONE', 'EMAIL', 'FAX', 'OTHER'];
      types.forEach(type => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          contact_type: type,
          value: 'test-value'
        };
        const result = createContactSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should validate with null optional fields', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'PHONE',
        value: '+1234567890',
        facility_id: null,
        branch_id: null,
        patient_id: null,
        user_profile_id: null,
        staff_profile_id: null,
        supplier_id: null
      };
      const result = createContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim value whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'EMAIL',
        value: '  user@example.com  '
      };
      const result = createContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.value).toBe('user@example.com');
      }
    });

    it('should default is_primary to false when not provided', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'PHONE',
        value: '+1234567890'
      };
      const result = createContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_primary).toBe(false);
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        contact_type: 'PHONE',
        value: '+1234567890'
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing contact_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        value: '+1234567890'
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing value', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'PHONE'
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        contact_type: 'PHONE',
        value: '+1234567890'
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid contact_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'INVALID_TYPE',
        value: '+1234567890'
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty value', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'PHONE',
        value: ''
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject value exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'EMAIL',
        value: 'a'.repeat(256)
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_primary type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'PHONE',
        value: '+1234567890',
        is_primary: 'yes'
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'PHONE',
        value: '+1234567890',
        facility_id: 'not-a-uuid'
      };
      const result = createContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateContactSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        contact_type: 'EMAIL',
        value: 'new@example.com',
        is_primary: true,
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with single field', () => {
      const validData = {
        value: 'updated@example.com'
      };
      const result = updateContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty object', () => {
      const validData = {};
      const result = updateContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null values', () => {
      const validData = {
        facility_id: null,
        branch_id: null
      };
      const result = updateContactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid contact_type', () => {
      const invalidData = {
        contact_type: 'INVALID'
      };
      const result = updateContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty value', () => {
      const invalidData = {
        value: ''
      };
      const result = updateContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject value exceeding max length', () => {
      const invalidData = {
        value: 'a'.repeat(256)
      };
      const result = updateContactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('contactIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = contactIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = contactIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = contactIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listContactsQuerySchema', () => {
    it('should validate with no filters', () => {
      const validData = {};
      const result = listContactsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination', () => {
      const validData = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listContactsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        contact_type: 'PHONE',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        branch_id: '123e4567-e89b-12d3-a456-426614174002',
        patient_id: '123e4567-e89b-12d3-a456-426614174003',
        user_profile_id: '123e4567-e89b-12d3-a456-426614174004',
        staff_profile_id: '123e4567-e89b-12d3-a456-426614174005',
        supplier_id: '123e4567-e89b-12d3-a456-426614174006',
        is_primary: 'true',
        search: 'test'
      };
      const result = listContactsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate is_primary as string', () => {
      const validData = {
        is_primary: 'false'
      };
      const result = listContactsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid contact_type', () => {
      const invalidData = {
        contact_type: 'INVALID'
      };
      const result = listContactsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_primary', () => {
      const invalidData = {
        is_primary: 'invalid'
      };
      const result = listContactsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID filters', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listContactsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
