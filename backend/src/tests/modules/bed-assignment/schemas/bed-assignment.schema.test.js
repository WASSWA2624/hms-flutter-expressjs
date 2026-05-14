/**
 * Bed Assignment schema tests
 */

const {
  createBedAssignmentSchema,
  updateBedAssignmentSchema,
  bedAssignmentIdParamsSchema,
  listBedAssignmentsQuerySchema
} = require('../../../../modules/bed-assignment/schemas/bed-assignment.schema');

describe('Bed Assignment Schema Validation', () => {
  describe('createBedAssignmentSchema', () => {
    it('should validate valid create data', () => {
      const validData = {
        admission_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        bed_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
      };
      expect(createBedAssignmentSchema.safeParse(validData).success).toBe(true);
    });

    it('should validate with optional assigned_at', () => {
      const validData = {
        admission_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        bed_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        assigned_at: '2026-01-19T10:00:00Z'
      };
      expect(createBedAssignmentSchema.safeParse(validData).success).toBe(true);
    });

    it('should reject missing required fields', () => {
      const invalidData = { admission_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' };
      expect(createBedAssignmentSchema.safeParse(invalidData).success).toBe(false);
    });
  });

  describe('updateBedAssignmentSchema', () => {
    it('should validate valid update data', () => {
      const validData = { released_at: '2026-01-20T10:00:00Z' };
      expect(updateBedAssignmentSchema.safeParse(validData).success).toBe(true);
    });

    it('should validate empty object', () => {
      expect(updateBedAssignmentSchema.safeParse({}).success).toBe(true);
    });
  });

  describe('bedAssignmentIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = { id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' };
      expect(bedAssignmentIdParamsSchema.safeParse(validData).success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      expect(bedAssignmentIdParamsSchema.safeParse({ id: 'invalid' }).success).toBe(false);
    });
  });

  describe('listBedAssignmentsQuerySchema', () => {
    it('should validate with filters', () => {
      const validData = {
        admission_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        bed_id: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        page: '1',
        limit: '20'
      };
      expect(listBedAssignmentsQuerySchema.safeParse(validData).success).toBe(true);
    });
  });
});
