/**
 * Theatre case schema tests
 *
 * @module tests/modules/theatre-case/schemas
 * @description Tests for theatre case validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createTheatreCaseSchema,
  updateTheatreCaseSchema,
  theatreCaseIdParamsSchema,
  listTheatreCasesQuerySchema
} = require('@validations/theatre-case/theatre-case.schema');

describe('Theatre Case Schemas', () => {
  describe('createTheatreCaseSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      scheduled_at: '2026-01-20T10:00:00.000Z',
      status: 'SCHEDULED'
    };

    it('should validate correct theatre case data', () => {
      const result = createTheatreCaseSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require scheduled_at', () => {
      const data = { ...validData };
      delete data.scheduled_at;
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow omitted status and let the service default it', () => {
      const data = { ...validData };
      delete data.status;
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid encounter_id format', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept friendly encounter identifiers', () => {
      const data = { ...validData, encounter_id: 'ENC-1001' };
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid scheduled_at format', () => {
      const data = { ...validData, scheduled_at: 'invalid-date' };
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum - SCHEDULED', () => {
      const data = { ...validData, status: 'SCHEDULED' };
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - IN_PROGRESS', () => {
      const data = { ...validData, status: 'IN_PROGRESS' };
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - COMPLETED', () => {
      const data = { ...validData, status: 'COMPLETED' };
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate status enum - CANCELLED', () => {
      const data = { ...validData, status: 'CANCELLED' };
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid status', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateTheatreCaseSchema', () => {
    it('should validate with all fields', () => {
      const data = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        scheduled_at: '2026-01-20T10:00:00.000Z',
        status: 'IN_PROGRESS'
      };
      const result = updateTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only encounter_id', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updateTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only scheduled_at', () => {
      const data = { scheduled_at: '2026-01-20T10:00:00.000Z' };
      const result = updateTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only status', () => {
      const data = { status: 'COMPLETED' };
      const result = updateTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const data = {};
      const result = updateTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid encounter_id format', () => {
      const data = { encounter_id: 'invalid-uuid' };
      const result = updateTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid scheduled_at format', () => {
      const data = { scheduled_at: 'invalid-date' };
      const result = updateTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const data = { status: 'INVALID' };
      const result = updateTheatreCaseSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('theatreCaseIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = theatreCaseIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = theatreCaseIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const data = {};
      const result = theatreCaseIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listTheatreCasesQuerySchema', () => {
    it('should validate with no filters', () => {
      const data = {};
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with encounter_id filter', () => {
      const data = { encounter_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with status filter', () => {
      const data = { status: 'SCHEDULED' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with scheduled_from filter', () => {
      const data = { scheduled_from: '2026-01-20T00:00:00.000Z' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with scheduled_to filter', () => {
      const data = { scheduled_to: '2026-01-20T23:59:59.000Z' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const data = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'IN_PROGRESS',
        scheduled_from: '2026-01-20T00:00:00.000Z',
        scheduled_to: '2026-01-20T23:59:59.000Z',
        page: '1',
        limit: '20',
        sort_by: 'scheduled_at',
        order: 'desc'
      };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid encounter_id format', () => {
      const data = { encounter_id: 'invalid-uuid' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const data = { status: 'INVALID' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid scheduled_from format', () => {
      const data = { scheduled_from: 'invalid-date' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid scheduled_to format', () => {
      const data = { scheduled_to: 'invalid-date' };
      const result = listTheatreCasesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
