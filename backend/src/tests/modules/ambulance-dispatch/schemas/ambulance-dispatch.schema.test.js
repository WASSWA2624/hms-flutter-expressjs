/**
 * Ambulance Dispatch schema validation tests
 *
 * @module tests/modules/ambulance-dispatch/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createAmbulanceDispatchSchema,
  updateAmbulanceDispatchSchema,
  ambulanceDispatchIdParamsSchema,
  listAmbulanceDispatchesQuerySchema
} = require('@validations/ambulance-dispatch/ambulance-dispatch.schema');

describe('Ambulance Dispatch Schema Validation', () => {
  describe('createAmbulanceDispatchSchema', () => {
    it('should validate correct ambulance dispatch data', () => {
      const validData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        dispatched_at: '2026-01-19T10:00:00Z',
        status: 'DISPATCHED'
      };
      const result = createAmbulanceDispatchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (required fields only)', () => {
      const validData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'EN_ROUTE'
      };
      const result = createAmbulanceDispatchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all statuses', () => {
      const statuses = ['AVAILABLE', 'DISPATCHED', 'EN_ROUTE', 'ON_SCENE', 'TRANSPORTING', 'OUT_OF_SERVICE'];
      statuses.forEach(status => {
        const validData = {
          ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
          emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
          status: status
        };
        const result = createAmbulanceDispatchSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should reject missing ambulance_id', () => {
      const invalidData = {
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'DISPATCHED'
      };
      const result = createAmbulanceDispatchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing emergency_case_id', () => {
      const invalidData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        status: 'DISPATCHED'
      };
      const result = createAmbulanceDispatchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        ambulance_id: 'not-a-uuid',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'DISPATCHED'
      };
      const result = createAmbulanceDispatchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'INVALID_STATUS'
      };
      const result = createAmbulanceDispatchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateAmbulanceDispatchSchema', () => {
    it('should validate partial updates', () => {
      const validData = {
        status: 'ON_SCENE'
      };
      const result = updateAmbulanceDispatchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty update object', () => {
      const validData = {};
      const result = updateAmbulanceDispatchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status in update', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = updateAmbulanceDispatchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('ambulanceDispatchIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = ambulanceDispatchIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = ambulanceDispatchIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listAmbulanceDispatchesQuerySchema', () => {
    it('should validate with no filters', () => {
      const validData = {};
      const result = listAmbulanceDispatchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const validData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'DISPATCHED',
        page: '1',
        limit: '20'
      };
      const result = listAmbulanceDispatchesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status filter', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = listAmbulanceDispatchesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
