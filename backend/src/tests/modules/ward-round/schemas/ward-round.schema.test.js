/**
 * Ward Round schema tests
 */

const {
  createWardRoundSchema,
  updateWardRoundSchema,
  wardRoundIdParamsSchema,
  listWardRoundsQuerySchema
} = require('../../../../modules/ward-round/schemas/ward-round.schema');

describe('Ward Round Schema Validation', () => {
  describe('createWardRoundSchema', () => {
    it('should validate valid create data', () => {
      const validData = { admission_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' };
      expect(createWardRoundSchema.safeParse(validData).success).toBe(true);
    });

    it('should validate with optional fields', () => {
      const validData = {
        admission_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        round_at: '2026-01-19T10:00:00Z',
        notes: 'Patient stable'
      };
      expect(createWardRoundSchema.safeParse(validData).success).toBe(true);
    });

    it('should reject missing admission_id', () => {
      const invalidData = { notes: 'Some notes' };
      expect(createWardRoundSchema.safeParse(invalidData).success).toBe(false);
    });

    it('should reject invalid UUID', () => {
      const invalidData = { admission_id: 'invalid-uuid' };
      expect(createWardRoundSchema.safeParse(invalidData).success).toBe(false);
    });
  });

  describe('updateWardRoundSchema', () => {
    it('should validate valid update data', () => {
      const validData = { notes: 'Updated notes', round_at: '2026-01-20T10:00:00Z' };
      expect(updateWardRoundSchema.safeParse(validData).success).toBe(true);
    });

    it('should validate empty object', () => {
      expect(updateWardRoundSchema.safeParse({}).success).toBe(true);
    });

    it('should reject invalid date', () => {
      const invalidData = { round_at: 'invalid-date' };
      expect(updateWardRoundSchema.safeParse(invalidData).success).toBe(false);
    });
  });

  describe('wardRoundIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = { id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' };
      expect(wardRoundIdParamsSchema.safeParse(validData).success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      expect(wardRoundIdParamsSchema.safeParse({ id: 'invalid' }).success).toBe(false);
    });

    it('should reject missing id', () => {
      expect(wardRoundIdParamsSchema.safeParse({}).success).toBe(false);
    });
  });

  describe('listWardRoundsQuerySchema', () => {
    it('should validate with no filters', () => {
      const validData = {};
      expect(listWardRoundsQuerySchema.safeParse(validData).success).toBe(true);
    });

    it('should validate with filters', () => {
      const validData = {
        admission_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        page: '1',
        limit: '20',
        sort_by: 'round_at',
        order: 'desc'
      };
      expect(listWardRoundsQuerySchema.safeParse(validData).success).toBe(true);
    });

    it('should reject invalid UUID filter', () => {
      const invalidData = { admission_id: 'not-a-uuid' };
      expect(listWardRoundsQuerySchema.safeParse(invalidData).success).toBe(false);
    });
  });
});
