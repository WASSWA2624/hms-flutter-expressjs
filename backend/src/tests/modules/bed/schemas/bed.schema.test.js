/**
 * Bed schema validation tests
 *
 * @module tests/modules/bed/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createBedSchema,
  updateBedSchema,
  bedIdParamsSchema,
  listBedsQuerySchema
} = require('@validations/bed/bed.schema');

describe('Bed Schema Validation', () => {
  describe('createBedSchema', () => {
    it('should validate correct bed data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        room_id: '123e4567-e89b-12d3-a456-426614174003',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (required fields only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null room_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        room_id: null,
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all bed statuses', () => {
      const statuses = ['AVAILABLE', 'OCCUPIED', 'RESERVED', 'OUT_OF_SERVICE'];
      statuses.forEach(status => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          facility_id: '123e4567-e89b-12d3-a456-426614174001',
          ward_id: '123e4567-e89b-12d3-a456-426614174002',
          label: `Bed ${status}`,
          status: status
        };
        const result = createBedSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should trim label whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: '  Bed 101  ',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.label).toBe('Bed 101');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing facility_id', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing ward_id', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: 'not-a-uuid',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: 'not-a-uuid',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid room_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        room_id: 'not-a-uuid',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing label', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty label', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: '',
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject label exceeding 50 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: 'a'.repeat(51),
        status: 'AVAILABLE'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing status', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: 'Bed 101'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        label: 'Bed 101',
        status: 'INVALID_STATUS'
      };
      const result = createBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateBedSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        room_id: '123e4567-e89b-12d3-a456-426614174003',
        label: 'Updated Bed',
        status: 'OCCUPIED'
      };
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only label', () => {
      const validData = {
        label: 'Updated Bed'
      };
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only facility_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only ward_id', () => {
      const validData = {
        ward_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only room_id', () => {
      const validData = {
        room_id: '123e4567-e89b-12d3-a456-426614174003'
      };
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only status', () => {
      const validData = {
        status: 'RESERVED'
      };
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null room_id', () => {
      const validData = {
        room_id: null
      };
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim label whitespace', () => {
      const validData = {
        label: '  Updated Bed  '
      };
      const result = updateBedSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.label).toBe('Updated Bed');
      }
    });

    it('should reject empty label', () => {
      const invalidData = {
        label: ''
      };
      const result = updateBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject label exceeding 50 characters', () => {
      const invalidData = {
        label: 'a'.repeat(51)
      };
      const result = updateBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_id UUID', () => {
      const invalidData = {
        ward_id: 'not-a-uuid'
      };
      const result = updateBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid room_id UUID', () => {
      const invalidData = {
        room_id: 'not-a-uuid'
      };
      const result = updateBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = updateBedSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('bedIdParamsSchema', () => {
    it('should validate correct UUID bed ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = bedIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = bedIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = bedIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = bedIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listBedsQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with tenant_id filter', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with facility_id filter', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with ward_id filter', () => {
      const validData = {
        ward_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with room_id filter', () => {
      const validData = {
        room_id: '123e4567-e89b-12d3-a456-426614174003'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with status filter', () => {
      const validData = {
        status: 'AVAILABLE'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const validData = {
        search: 'bed'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all params', () => {
      const validData = {
        page: 2,
        limit: 50,
        sort_by: 'label',
        order: 'asc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        room_id: '123e4567-e89b-12d3-a456-426614174003',
        status: 'OCCUPIED',
        search: 'bed'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listBedsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = listBedsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_id UUID', () => {
      const invalidData = {
        ward_id: 'not-a-uuid'
      };
      const result = listBedsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid room_id UUID', () => {
      const invalidData = {
        room_id: 'not-a-uuid'
      };
      const result = listBedsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = listBedsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listBedsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listBedsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listBedsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  bed  '
      };
      const result = listBedsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('bed');
      }
    });
  });
});
