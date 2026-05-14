/**
 * Nursing note schema tests
 *
 * @module tests/modules/nursing-note/schemas
 * @description Tests for nursing note validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createNursingNoteSchema,
  updateNursingNoteSchema,
  nursingNoteIdParamsSchema,
  listNursingNotesQuerySchema
} = require('@validations/nursing-note/nursing-note.schema');

describe('Nursing Note Schemas', () => {
  describe('createNursingNoteSchema', () => {
    const validData = {
      admission_id: '550e8400-e29b-41d4-a716-446655440000',
      nurse_user_id: '550e8400-e29b-41d4-a716-446655440001',
      note: 'Patient vitals stable. No complaints. Continue current medications.'
    };

    it('should validate correct nursing note data', () => {
      const result = createNursingNoteSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require admission_id', () => {
      const data = { ...validData };
      delete data.admission_id;
      const result = createNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require nurse_user_id', () => {
      const data = { ...validData };
      delete data.nurse_user_id;
      const result = createNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require note', () => {
      const data = { ...validData };
      delete data.note;
      const result = createNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty note', () => {
      const data = { ...validData, note: '' };
      const result = createNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for admission_id', () => {
      const data = { ...validData, admission_id: 'invalid-uuid' };
      const result = createNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for nurse_user_id', () => {
      const data = { ...validData, nurse_user_id: 'invalid-uuid' };
      const result = createNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from note', () => {
      const data = { ...validData, note: '  Valid note with spaces  ' };
      const result = createNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data?.note).toBe('Valid note with spaces');
    });
  });

  describe('updateNursingNoteSchema', () => {
    it('should validate all fields as optional', () => {
      const result = updateNursingNoteSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = {
        note: 'Updated nursing note content'
      };
      const result = updateNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject empty note in update', () => {
      const data = { note: '' };
      const result = updateNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from note in update', () => {
      const data = { note: '  Updated note  ' };
      const result = updateNursingNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
      expect(result.data?.note).toBe('Updated note');
    });
  });

  describe('nursingNoteIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const result = nursingNoteIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = nursingNoteIdParamsSchema.safeParse({
        id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const result = nursingNoteIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listNursingNotesQuerySchema', () => {
    it('should validate query parameters', () => {
      const result = listNursingNotesQuerySchema.safeParse({
        page: '1',
        limit: '20',
        admission_id: '550e8400-e29b-41d4-a716-446655440000',
        nurse_user_id: '550e8400-e29b-41d4-a716-446655440001'
      });
      expect(result.success).toBe(true);
    });

    it('should allow all parameters as optional', () => {
      const result = listNursingNotesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for admission_id filter', () => {
      const result = listNursingNotesQuerySchema.safeParse({
        admission_id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for nurse_user_id filter', () => {
      const result = listNursingNotesQuerySchema.safeParse({
        nurse_user_id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });
  });
});
