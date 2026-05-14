/**
 * Housekeeping task schema validation tests
 *
 * @module tests/modules/housekeeping-task/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createHousekeepingTaskSchema,
  updateHousekeepingTaskSchema,
  housekeepingTaskIdParamsSchema,
  listHousekeepingTasksQuerySchema
} = require('@validations/housekeeping-task/housekeeping-task.schema');

describe('Housekeeping Task Schema Validation', () => {
  describe('createHousekeepingTaskSchema', () => {
    it('should validate correct housekeeping task data with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        room_id: '123e4567-e89b-12d3-a456-426614174001',
        assigned_to_staff_id: '123e4567-e89b-12d3-a456-426614174002',
        status: 'PENDING',
        scheduled_at: '2026-01-20T10:00:00Z',
        completed_at: '2026-01-20T15:00:00Z'
      };
      const result = createHousekeepingTaskSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only status (required field)', () => {
      const validData = {
        status: 'IN_PROGRESS'
      };
      const result = createHousekeepingTaskSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null optional fields', () => {
      const validData = {
        facility_id: null,
        room_id: null,
        assigned_to_staff_id: null,
        status: 'COMPLETED',
        scheduled_at: null,
        completed_at: null
      };
      const result = createHousekeepingTaskSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all status values', () => {
      const statuses = ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];
      statuses.forEach(status => {
        const validData = { status };
        const result = createHousekeepingTaskSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid',
        status: 'PENDING'
      };
      const result = createHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid room_id UUID', () => {
      const invalidData = {
        room_id: 'not-a-uuid',
        status: 'PENDING'
      };
      const result = createHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid assigned_to_staff_id UUID', () => {
      const invalidData = {
        assigned_to_staff_id: 'not-a-uuid',
        status: 'PENDING'
      };
      const result = createHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing status', () => {
      const invalidData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = createHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = createHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format for scheduled_at', () => {
      const invalidData = {
        status: 'PENDING',
        scheduled_at: 'invalid-date'
      };
      const result = createHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format for completed_at', () => {
      const invalidData = {
        status: 'COMPLETED',
        completed_at: 'invalid-date'
      };
      const result = createHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateHousekeepingTaskSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        room_id: '123e4567-e89b-12d3-a456-426614174001',
        assigned_to_staff_id: '123e4567-e89b-12d3-a456-426614174002',
        status: 'COMPLETED',
        scheduled_at: '2026-01-20T10:00:00Z',
        completed_at: '2026-01-20T15:00:00Z'
      };
      const result = updateHousekeepingTaskSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateHousekeepingTaskSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only status', () => {
      const validData = {
        status: 'IN_PROGRESS'
      };
      const result = updateHousekeepingTaskSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only facility_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = updateHousekeepingTaskSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null values', () => {
      const validData = {
        facility_id: null,
        room_id: null,
        assigned_to_staff_id: null,
        scheduled_at: null,
        completed_at: null
      };
      const result = updateHousekeepingTaskSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = updateHousekeepingTaskSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('housekeepingTaskIdParamsSchema', () => {
    it('should validate correct UUID housekeeping task ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = housekeepingTaskIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = housekeepingTaskIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = housekeepingTaskIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = housekeepingTaskIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listHousekeepingTasksQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with facility_id filter', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with room_id filter', () => {
      const validData = {
        room_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with assigned_to_staff_id filter', () => {
      const validData = {
        assigned_to_staff_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with status filter', () => {
      const validData = {
        status: 'PENDING'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all params', () => {
      const validData = {
        page: 2,
        limit: 50,
        sort_by: 'scheduled_at',
        order: 'asc',
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        room_id: '123e4567-e89b-12d3-a456-426614174001',
        assigned_to_staff_id: '123e4567-e89b-12d3-a456-426614174002',
        status: 'IN_PROGRESS'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid room_id UUID', () => {
      const invalidData = {
        room_id: 'not-a-uuid'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid assigned_to_staff_id UUID', () => {
      const invalidData = {
        assigned_to_staff_id: 'not-a-uuid'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listHousekeepingTasksQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });
  });
});
