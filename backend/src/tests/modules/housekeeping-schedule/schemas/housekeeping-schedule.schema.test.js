/**
 * Housekeeping schedule schema validation tests
 *
 * @module tests/modules/housekeeping-schedule/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createHousekeepingScheduleSchema,
  updateHousekeepingScheduleSchema,
  housekeepingScheduleIdParamsSchema,
  listHousekeepingSchedulesQuerySchema
} = require('@validations/housekeeping-schedule/housekeeping-schedule.schema');

describe('Housekeeping Schedule Schema Validation', () => {
  describe('createHousekeepingScheduleSchema', () => {
    it('should validate correct housekeeping schedule data with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        room_id: '123e4567-e89b-12d3-a456-426614174001',
        frequency: 'Daily',
        start_date: '2026-01-20T10:00:00Z',
        end_date: '2026-12-31T23:59:59Z'
      };
      const result = createHousekeepingScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = createHousekeepingScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null optional fields', () => {
      const validData = {
        facility_id: null,
        room_id: null,
        frequency: null,
        start_date: null,
        end_date: null
      };
      const result = createHousekeepingScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim frequency whitespace', () => {
      const validData = {
        frequency: '  Daily  '
      };
      const result = createHousekeepingScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.frequency).toBe('Daily');
      }
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = createHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid room_id UUID', () => {
      const invalidData = {
        room_id: 'not-a-uuid'
      };
      const result = createHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty frequency', () => {
      const invalidData = {
        frequency: ''
      };
      const result = createHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject frequency exceeding 80 characters', () => {
      const invalidData = {
        frequency: 'a'.repeat(81)
      };
      const result = createHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format for start_date', () => {
      const invalidData = {
        start_date: 'invalid-date'
      };
      const result = createHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format for end_date', () => {
      const invalidData = {
        end_date: 'invalid-date'
      };
      const result = createHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateHousekeepingScheduleSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        room_id: '123e4567-e89b-12d3-a456-426614174001',
        frequency: 'Weekly',
        start_date: '2026-01-20T10:00:00Z',
        end_date: '2026-12-31T23:59:59Z'
      };
      const result = updateHousekeepingScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateHousekeepingScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only frequency', () => {
      const validData = {
        frequency: 'Monthly'
      };
      const result = updateHousekeepingScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null values', () => {
      const validData = {
        facility_id: null,
        room_id: null,
        frequency: null,
        start_date: null,
        end_date: null
      };
      const result = updateHousekeepingScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty frequency', () => {
      const invalidData = {
        frequency: ''
      };
      const result = updateHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject frequency exceeding 80 characters', () => {
      const invalidData = {
        frequency: 'a'.repeat(81)
      };
      const result = updateHousekeepingScheduleSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('housekeepingScheduleIdParamsSchema', () => {
    it('should validate correct UUID housekeeping schedule ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = housekeepingScheduleIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = housekeepingScheduleIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = housekeepingScheduleIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listHousekeepingSchedulesQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listHousekeepingSchedulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listHousekeepingSchedulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const validData = {
        page: 2,
        limit: 50,
        sort_by: 'start_date',
        order: 'asc',
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        room_id: '123e4567-e89b-12d3-a456-426614174001',
        frequency: 'Daily'
      };
      const result = listHousekeepingSchedulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = listHousekeepingSchedulesQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listHousekeepingSchedulesQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });
  });
});
