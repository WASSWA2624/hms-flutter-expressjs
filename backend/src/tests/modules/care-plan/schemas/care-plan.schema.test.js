/**
 * Care Plan schema tests
 *
 * @module tests/modules/care-plan/schemas
 * @description Tests for care plan validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createCarePlanSchema,
  updateCarePlanSchema,
  carePlanIdParamsSchema,
  listCarePlansQuerySchema
} = require('@validations/care-plan/care-plan.schema');

describe('Care Plan Schemas', () => {
  describe('createCarePlanSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      plan: 'Patient care plan details',
      start_date: '2026-01-19T10:30:00.000Z',
      end_date: '2026-02-19T10:30:00.000Z'
    };

    it('should validate correct care plan data', () => {
      const result = createCarePlanSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require plan', () => {
      const data = { ...validData };
      delete data.plan;
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional start_date', () => {
      const data = { ...validData };
      delete data.start_date;
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional end_date', () => {
      const data = { ...validData };
      delete data.end_date;
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for encounter_id', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from plan', () => {
      const data = { ...validData, plan: '  Care plan  ' };
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.plan).toBe('Care plan');
      }
    });

    it('should accept nullable start_date', () => {
      const data = { ...validData, start_date: null };
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept nullable end_date', () => {
      const data = { ...validData, end_date: null };
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate datetime format for start_date', () => {
      const data = { ...validData, start_date: 'invalid-date' };
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime format for end_date', () => {
      const data = { ...validData, end_date: 'invalid-date' };
      const result = createCarePlanSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateCarePlanSchema', () => {
    it('should validate with all optional fields', () => {
      const data = { plan: 'Updated care plan' };
      const result = updateCarePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept empty update data', () => {
      const result = updateCarePlanSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate optional encounter_id', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updateCarePlanSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('carePlanIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = carePlanIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = carePlanIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listCarePlansQuerySchema', () => {
    it('should validate with no filters', () => {
      const result = listCarePlansQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate with encounter_id filter', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listCarePlansQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with start_date filter', () => {
      const data = { start_date: '2026-01-19T10:30:00.000Z' };
      const result = listCarePlansQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with end_date filter', () => {
      const data = { end_date: '2026-02-19T10:30:00.000Z' };
      const result = listCarePlansQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });
});
