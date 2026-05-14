/**
 * Emergency response schema tests
 *
 * @module tests/modules/emergency-response/schemas
 * @description Tests for emergency response validation schemas
 */

const {
  createEmergencyResponseSchema,
  updateEmergencyResponseSchema,
  emergencyResponseIdParamsSchema,
  listEmergencyResponsesQuerySchema
} = require('../../../../modules/emergency-response/schemas/emergency-response.schema');

describe('Emergency Response Schema Validation', () => {
  describe('createEmergencyResponseSchema', () => {
    it('should validate valid create data', () => {
      const validData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        response_at: '2026-01-19T10:30:00Z',
        notes: 'Emergency response initiated'
      };

      const result = createEmergencyResponseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal required fields', () => {
      const validData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = createEmergencyResponseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept optional response_at', () => {
      const validData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        response_at: '2026-01-19T10:30:00Z'
      };

      const result = createEmergencyResponseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept notes up to 5000 characters', () => {
      const validData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        notes: 'a'.repeat(5000)
      };

      const result = createEmergencyResponseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject notes exceeding 5000 characters', () => {
      const invalidData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        notes: 'a'.repeat(5001)
      };

      const result = createEmergencyResponseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        notes: 'some notes'
      };

      const result = createEmergencyResponseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        emergency_case_id: 'invalid-uuid'
      };

      const result = createEmergencyResponseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format', () => {
      const invalidData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        response_at: 'invalid-date'
      };

      const result = createEmergencyResponseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateEmergencyResponseSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        response_at: '2026-01-19T11:00:00Z',
        notes: 'Updated response notes'
      };

      const result = updateEmergencyResponseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const validData = {};

      const result = updateEmergencyResponseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only notes', () => {
      const validData = {
        notes: 'Updated notes'
      };

      const result = updateEmergencyResponseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid date format', () => {
      const invalidData = {
        response_at: 'not-a-date'
      };

      const result = updateEmergencyResponseSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('emergencyResponseIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = {
        id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = emergencyResponseIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };

      const result = emergencyResponseIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listEmergencyResponsesQuerySchema', () => {
    it('should validate valid query params', () => {
      const validData = {
        page: 1,
        limit: 20,
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = listEmergencyResponsesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal params', () => {
      const validData = {};

      const result = listEmergencyResponsesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID in filters', () => {
      const invalidData = {
        emergency_case_id: 'invalid-uuid'
      };

      const result = listEmergencyResponsesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
