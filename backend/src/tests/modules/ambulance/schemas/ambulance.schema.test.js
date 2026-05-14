/**
 * Ambulance schema validation tests
 *
 * @module tests/modules/ambulance/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createAmbulanceSchema,
  updateAmbulanceSchema,
  ambulanceIdParamsSchema,
  listAmbulancesQuerySchema
} = require('@validations/ambulance/ambulance.schema');

describe('Ambulance Schema Validation', () => {
  describe('createAmbulanceSchema', () => {
    it('should validate correct ambulance data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };
      const result = createAmbulanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (required fields only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        identifier: 'AMB-002',
        status: 'DISPATCHED'
      };
      const result = createAmbulanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null facility_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: null,
        identifier: 'AMB-003',
        status: 'AVAILABLE'
      };
      const result = createAmbulanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all ambulance statuses', () => {
      const statuses = ['AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE'];
      statuses.forEach(status => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          identifier: `AMB-${status}`,
          status: status
        };
        const result = createAmbulanceSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should trim identifier whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        identifier: '  AMB-TRIM  ',
        status: 'AVAILABLE'
      };
      const result = createAmbulanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.identifier).toBe('AMB-TRIM');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };
      const result = createAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing identifier', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        status: 'AVAILABLE'
      };
      const result = createAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing status', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        identifier: 'AMB-001'
      };
      const result = createAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id format', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };
      const result = createAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        identifier: 'AMB-001',
        status: 'INVALID_STATUS'
      };
      const result = createAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty identifier', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        identifier: '',
        status: 'AVAILABLE'
      };
      const result = createAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject identifier exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        identifier: 'A'.repeat(121),
        status: 'AVAILABLE'
      };
      const result = createAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateAmbulanceSchema', () => {
    it('should validate partial updates', () => {
      const validData = {
        status: 'EN_ROUTE'
      };
      const result = updateAmbulanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate updating facility_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateAmbulanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate updating identifier', () => {
      const validData = {
        identifier: 'AMB-UPDATED'
      };
      const result = updateAmbulanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty update object', () => {
      const validData = {};
      const result = updateAmbulanceSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status in update', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = updateAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID in update', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateAmbulanceSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('ambulanceIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = ambulanceIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = ambulanceIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = ambulanceIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listAmbulancesQuerySchema', () => {
    it('should validate with no filters', () => {
      const validData = {};
      const result = listAmbulancesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: '1',
        limit: '20'
      };
      const result = listAmbulancesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sort params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listAmbulancesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'AVAILABLE',
        search: 'AMB',
        page: '1',
        limit: '20',
        sort_by: 'identifier',
        order: 'asc'
      };
      const result = listAmbulancesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status filter', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = listAmbulancesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id format', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listAmbulancesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
