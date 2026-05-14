/**
 * Triage assessment schema tests
 *
 * @module tests/modules/triage-assessment/schemas
 * @description Tests for triage assessment validation schemas
 */

const {
  createTriageAssessmentSchema,
  updateTriageAssessmentSchema,
  triageAssessmentIdParamsSchema,
  listTriageAssessmentsQuerySchema
} = require('../../../../modules/triage-assessment/schemas/triage-assessment.schema');

describe('Triage Assessment Schema Validation', () => {
  describe('createTriageAssessmentSchema', () => {
    it('should validate valid create data', () => {
      const validData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        triage_level: 'URGENT',
        notes: 'Patient experiencing chest pain'
      };

      const result = createTriageAssessmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal required fields', () => {
      const validData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        triage_level: 'IMMEDIATE'
      };

      const result = createTriageAssessmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should accept all valid triage levels', () => {
      const levels = ['IMMEDIATE', 'URGENT', 'LESS_URGENT', 'NON_URGENT'];
      
      levels.forEach(triage_level => {
        const data = {
          emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          triage_level
        };
        
        const result = createTriageAssessmentSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should accept notes up to 5000 characters', () => {
      const validData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        triage_level: 'URGENT',
        notes: 'a'.repeat(5000)
      };

      const result = createTriageAssessmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject notes exceeding 5000 characters', () => {
      const invalidData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        triage_level: 'URGENT',
        notes: 'a'.repeat(5001)
      };

      const result = createTriageAssessmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        notes: 'some notes'
      };

      const result = createTriageAssessmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        emergency_case_id: 'invalid-uuid',
        triage_level: 'URGENT'
      };

      const result = createTriageAssessmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid triage level', () => {
      const invalidData = {
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        triage_level: 'INVALID_LEVEL'
      };

      const result = createTriageAssessmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateTriageAssessmentSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        triage_level: 'IMMEDIATE',
        notes: 'Updated assessment'
      };

      const result = updateTriageAssessmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const validData = {};

      const result = updateTriageAssessmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only triage_level', () => {
      const validData = {
        triage_level: 'NON_URGENT'
      };

      const result = updateTriageAssessmentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid triage level', () => {
      const invalidData = {
        triage_level: 'INVALID'
      };

      const result = updateTriageAssessmentSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('triageAssessmentIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = {
        id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };

      const result = triageAssessmentIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };

      const result = triageAssessmentIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listTriageAssessmentsQuerySchema', () => {
    it('should validate valid query params', () => {
      const validData = {
        page: 1,
        limit: 20,
        emergency_case_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        triage_level: 'URGENT'
      };

      const result = listTriageAssessmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal params', () => {
      const validData = {};

      const result = listTriageAssessmentsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID in filters', () => {
      const invalidData = {
        emergency_case_id: 'invalid-uuid'
      };

      const result = listTriageAssessmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid triage level', () => {
      const invalidData = {
        triage_level: 'INVALID'
      };

      const result = listTriageAssessmentsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
