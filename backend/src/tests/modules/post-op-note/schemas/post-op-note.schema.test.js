/**
 * Post-op note schema tests
 *
 * @module tests/modules/post-op-note/schemas
 * @description Tests for post-op note validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPostOpNoteSchema,
  updatePostOpNoteSchema,
  postOpNoteIdParamsSchema,
  listPostOpNotesQuerySchema
} = require('@validations/post-op-note/post-op-note.schema');

describe('Post-Op Note Schemas', () => {
  describe('createPostOpNoteSchema', () => {
    const validData = {
      theatre_case_id: '550e8400-e29b-41d4-a716-446655440000',
      note: 'Post-operative care instructions provided'
    };

    it('should validate correct post-op note data', () => {
      const result = createPostOpNoteSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require theatre_case_id', () => {
      const data = { ...validData };
      delete data.theatre_case_id;
      const result = createPostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require note', () => {
      const data = { ...validData };
      delete data.note;
      const result = createPostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty note', () => {
      const data = { ...validData, note: '' };
      const result = createPostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid theatre_case_id format', () => {
      const data = { ...validData, theatre_case_id: 'invalid-uuid' };
      const result = createPostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim note whitespace', () => {
      const data = { ...validData, note: '  Test note  ' };
      const result = createPostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updatePostOpNoteSchema', () => {
    it('should validate with all fields', () => {
      const data = {
        theatre_case_id: '550e8400-e29b-41d4-a716-446655440000',
        note: 'Updated note'
      };
      const result = updatePostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only theatre_case_id', () => {
      const data = { theatre_case_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updatePostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only note', () => {
      const data = { note: 'Updated note' };
      const result = updatePostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const data = {};
      const result = updatePostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid theatre_case_id format', () => {
      const data = { theatre_case_id: 'invalid-uuid' };
      const result = updatePostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject empty note', () => {
      const data = { note: '' };
      const result = updatePostOpNoteSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('postOpNoteIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = postOpNoteIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = postOpNoteIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const data = {};
      const result = postOpNoteIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listPostOpNotesQuerySchema', () => {
    it('should validate with no filters', () => {
      const data = {};
      const result = listPostOpNotesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listPostOpNotesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with theatre_case_id filter', () => {
      const data = { theatre_case_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listPostOpNotesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const data = {
        theatre_case_id: '550e8400-e29b-41d4-a716-446655440000',
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listPostOpNotesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid theatre_case_id format', () => {
      const data = { theatre_case_id: 'invalid-uuid' };
      const result = listPostOpNotesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });
});
