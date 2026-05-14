/**
 * Anesthesia record schema tests
 *
 * @module tests/modules/anesthesia-record/schemas
 * @description Tests for anesthesia record validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createAnesthesiaRecordSchema,
  updateAnesthesiaRecordSchema,
  anesthesiaRecordIdParamsSchema,
  listAnesthesiaRecordsQuerySchema
} = require('@validations/anesthesia-record/anesthesia-record.schema');

describe('Anesthesia Record Schemas', () => {
  describe('createAnesthesiaRecordSchema', () => {
    const validData = {
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440000',
      anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440001',
      notes: 'Anesthesia administered successfully'
    };

    it('should validate correct anesthesia record data', () => {
      const result = createAnesthesiaRecordSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require theatre_case_id', () => {
      const data = { ...validData };
      delete data.theatre_case_id;
      const result = createAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional anesthetist_user_id', () => {
      const data = { ...validData };
      delete data.anesthetist_user_id;
      const result = createAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional notes', () => {
      const data = { ...validData };
      delete data.notes;
      const result = createAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid theatre_case_id format', () => {
      const data = { ...validData, theatre_case_id: 'invalid-uuid' };
      const result = createAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid anesthetist_user_id format', () => {
      const data = { ...validData, anesthetist_user_id: 'invalid-uuid' };
      const result = createAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null anesthetist_user_id', () => {
      const data = { ...validData, anesthetist_user_id: null };
      const result = createAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept null notes', () => {
      const data = { ...validData, notes: null };
      const result = createAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateAnesthesiaRecordSchema', () => {
    it('should validate with all fields', () => {
      const data = {
        theatre_case_id: '550e8400-e29b-41d4-a716-446655440000',
        anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440001',
        notes: 'Updated notes'
      };
      const result = updateAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only theatre_case_id', () => {
      const data = { theatre_case_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updateAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only anesthetist_user_id', () => {
      const data = { anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440001' };
      const result = updateAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only notes', () => {
      const data = { notes: 'Updated notes' };
      const result = updateAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const data = {};
      const result = updateAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid theatre_case_id format', () => {
      const data = { theatre_case_id: 'invalid-uuid' };
      const result = updateAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid anesthetist_user_id format', () => {
      const data = { anesthetist_user_id: 'invalid-uuid' };
      const result = updateAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept null values', () => {
      const data = { anesthetist_user_id: null, notes: null };
      const result = updateAnesthesiaRecordSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('anesthesiaRecordIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = anesthesiaRecordIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = anesthesiaRecordIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const data = {};
      const result = anesthesiaRecordIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listAnesthesiaRecordsQuerySchema', () => {
    it('should validate with no filters', () => {
      const data = {};
      const result = listAnesthesiaRecordsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listAnesthesiaRecordsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with theatre_case_id filter', () => {
      const data = { theatre_case_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listAnesthesiaRecordsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with anesthetist_user_id filter', () => {
      const data = { anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440001' };
      const result = listAnesthesiaRecordsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const data = {
        theatre_case_id: '550e8400-e29b-41d4-a716-446655440000',
        anesthetist_user_id: '550e8400-e29b-41d4-a716-446655440001',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listAnesthesiaRecordsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid theatre_case_id format', () => {
      const data = { theatre_case_id: 'invalid-uuid' };
      const result = listAnesthesiaRecordsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid anesthetist_user_id format', () => {
      const data = { anesthetist_user_id: 'invalid-uuid' };
      const result = listAnesthesiaRecordsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
