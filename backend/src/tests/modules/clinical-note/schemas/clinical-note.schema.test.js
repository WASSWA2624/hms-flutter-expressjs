/**
 * Clinical note schema tests
 *
 * @module tests/modules/clinical-note/schemas
 * @description Tests for clinical note validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createClinicalNoteSchema,
  updateClinicalNoteSchema,
  clinicalNoteIdParamsSchema,
  listClinicalNotesQuerySchema
} = require('@validations/clinical-note/clinical-note.schema');

describe('Clinical Note Schemas', () => {
  describe('createClinicalNoteSchema', () => {
    const validData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440000',
      author_user_id: '550e8400-e29b-41d4-a716-446655440001',
      note: 'Patient presents with fever and cough. Vital signs stable.'
    };

    it('should validate correct clinical note data', () => {
      const result = createClinicalNoteSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require encounter_id', () => {
      const data = { ...validData };
      delete data.encounter_id;
      const result = createClinicalNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require author_user_id', () => {
      const data = { ...validData };
      delete data.author_user_id;
      const result = createClinicalNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require note', () => {
      const data = { ...validData };
      delete data.note;
      const result = createClinicalNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty note', () => {
      const data = { ...validData, note: '' };
      const result = createClinicalNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for encounter_id', () => {
      const data = { ...validData, encounter_id: 'invalid-uuid' };
      const result = createClinicalNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for author_user_id', () => {
      const data = { ...validData, author_user_id: 'invalid-uuid' };
      const result = createClinicalNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateClinicalNoteSchema', () => {
    it('should validate all fields as optional', () => {
      const result = updateClinicalNoteSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = {
        note: 'Updated clinical note content'
      };
      const result = updateClinicalNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject empty note in update', () => {
      const data = { note: '' };
      const result = updateClinicalNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('clinicalNoteIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const result = clinicalNoteIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = clinicalNoteIdParamsSchema.safeParse({
        id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('listClinicalNotesQuerySchema', () => {
    it('should validate query parameters', () => {
      const result = listClinicalNotesQuerySchema.safeParse({
        page: '1',
        limit: '20',
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        author_user_id: '550e8400-e29b-41d4-a716-446655440001'
      });
      expect(result.success).toBe(true);
    });

    it('should allow all parameters as optional', () => {
      const result = listClinicalNotesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });
});
