/**
 * Ambulance Trip schema validation tests
 *
 * @module tests/modules/ambulance-trip/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createAmbulanceTripSchema,
  updateAmbulanceTripSchema,
  ambulanceTripIdParamsSchema,
  listAmbulanceTripsQuerySchema
} = require('@validations/ambulance-trip/ambulance-trip.schema');

describe('Ambulance Trip Schema Validation', () => {
  describe('createAmbulanceTripSchema', () => {
    it('should validate correct ambulance trip data', () => {
      const validData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        started_at: '2026-01-19T10:00:00Z',
        ended_at: '2026-01-19T11:00:00Z'
      };
      const result = createAmbulanceTripSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (required fields only)', () => {
      const validData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createAmbulanceTripSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null timestamps', () => {
      const validData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        started_at: null,
        ended_at: null
      };
      const result = createAmbulanceTripSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing ambulance_id', () => {
      const invalidData = {
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createAmbulanceTripSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing emergency_case_id', () => {
      const invalidData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = createAmbulanceTripSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        ambulance_id: 'not-a-uuid',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createAmbulanceTripSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateAmbulanceTripSchema', () => {
    it('should validate partial updates', () => {
      const validData = {
        started_at: '2026-01-19T10:00:00Z'
      };
      const result = updateAmbulanceTripSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty update object', () => {
      const validData = {};
      const result = updateAmbulanceTripSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID in update', () => {
      const invalidData = {
        ambulance_id: 'not-a-uuid'
      };
      const result = updateAmbulanceTripSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('ambulanceTripIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = ambulanceTripIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = ambulanceTripIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listAmbulanceTripsQuerySchema', () => {
    it('should validate with no filters', () => {
      const validData = {};
      const result = listAmbulanceTripsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const validData = {
        ambulance_id: '123e4567-e89b-12d3-a456-426614174000',
        emergency_case_id: '123e4567-e89b-12d3-a456-426614174001',
        page: '1',
        limit: '20'
      };
      const result = listAmbulanceTripsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid ambulance_id format', () => {
      const invalidData = {
        ambulance_id: 'not-a-uuid'
      };
      const result = listAmbulanceTripsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
