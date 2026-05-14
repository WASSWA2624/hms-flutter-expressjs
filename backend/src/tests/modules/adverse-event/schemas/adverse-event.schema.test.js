/**
 * Adverse Event schema tests
 *
 * @module tests/modules/adverse-event/schemas
 * @description Tests for adverse event validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createAdverseEventSchema,
  updateAdverseEventSchema,
  adverseEventIdParamsSchema,
  listAdverseEventsQuerySchema
} = require('@validations/adverse-event/adverse-event.schema');

describe('Adverse Event Schemas', () => {
  describe('createAdverseEventSchema', () => {
    const validData = {
      patient_id: '550e8400-e29b-41d4-a716-446655440000',
      drug_id: '550e8400-e29b-41d4-a716-446655440001',
      severity: 'MODERATE',
      description: 'Patient experienced mild headache after medication',
      reported_at: '2026-01-19T10:00:00.000Z'
    };

    it('should validate correct adverse event data', () => {
      const result = createAdverseEventSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require severity', () => {
      const data = { ...validData };
      delete data.severity;
      const result = createAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate severity enum values', () => {
      const data = { ...validData, severity: 'INVALID' };
      const result = createAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid severity values', () => {
      const severities = ['MILD', 'MODERATE', 'SEVERE'];
      severities.forEach(severity => {
        const data = { ...validData, severity };
        const result = createAdverseEventSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional drug_id', () => {
      const data = { ...validData };
      delete data.drug_id;
      const result = createAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional description', () => {
      const data = { ...validData };
      delete data.description;
      const result = createAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional reported_at', () => {
      const data = { ...validData };
      delete data.reported_at;
      const result = createAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateAdverseEventSchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        drug_id: '550e8400-e29b-41d4-a716-446655440001',
        severity: 'SEVERE',
        description: 'Updated description',
        reported_at: '2026-01-19T11:00:00.000Z'
      };
      const result = updateAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { severity: 'SEVERE' };
      const result = updateAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty update object', () => {
      const result = updateAdverseEventSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate severity enum if provided', () => {
      const data = { severity: 'INVALID_SEVERITY' };
      const result = updateAdverseEventSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('adverseEventIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = adverseEventIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = adverseEventIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const result = adverseEventIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listAdverseEventsQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'desc',
        patient_id: '550e8400-e29b-41d4-a716-446655440000',
        drug_id: '550e8400-e29b-41d4-a716-446655440001',
        severity: 'MODERATE',
        reported_at_from: '2026-01-01T00:00:00.000Z',
        reported_at_to: '2026-12-31T23:59:59.999Z',
        search: 'headache'
      };
      const result = listAdverseEventsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow empty query params', () => {
      const result = listAdverseEventsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate severity enum if provided', () => {
      const data = { severity: 'INVALID' };
      const result = listAdverseEventsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should coerce page and limit to numbers', () => {
      const data = { page: '2', limit: '50' };
      const result = listAdverseEventsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(typeof result.data.page).toBe('number');
      expect(typeof result.data.limit).toBe('number');
    });
  });
});
