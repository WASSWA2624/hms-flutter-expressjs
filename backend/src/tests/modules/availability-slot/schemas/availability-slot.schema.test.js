/**
 * Availability slot schema tests
 *
 * @module tests/modules/availability-slot/schemas
 * @description Tests for availability slot validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createAvailabilitySlotSchema,
  updateAvailabilitySlotSchema,
  availabilitySlotIdParamsSchema,
  listAvailabilitySlotsQuerySchema
} = require('@validations/availability-slot/availability-slot.schema');

describe('Availability Slot Schemas', () => {
  describe('createAvailabilitySlotSchema', () => {
    const validData = {
      schedule_id: '550e8400-e29b-41d4-a716-446655440000',
      start_time: '2026-01-20T08:00:00.000Z',
      end_time: '2026-01-20T09:00:00.000Z',
      is_available: true
    };

    it('should validate correct availability slot data', () => {
      const result = createAvailabilitySlotSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require schedule_id', () => {
      const data = { ...validData };
      delete data.schedule_id;
      const result = createAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require start_time', () => {
      const data = { ...validData };
      delete data.start_time;
      const result = createAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require end_time', () => {
      const data = { ...validData };
      delete data.end_time;
      const result = createAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional is_available', () => {
      const data = { ...validData };
      delete data.is_available;
      const result = createAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional override_date', () => {
      const data = { ...validData, override_date: '2026-01-20T00:00:00.000Z' };
      const result = createAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for schedule_id', () => {
      const data = { ...validData, schedule_id: 'invalid-uuid' };
      const result = createAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for start_time', () => {
      const data = { ...validData, start_time: 'invalid-datetime' };
      const result = createAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for end_time', () => {
      const data = { ...validData, end_time: 'invalid-datetime' };
      const result = createAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate is_available as boolean', () => {
      const validValues = [true, false];
      validValues.forEach(value => {
        const data = { ...validData, is_available: value };
        const result = createAvailabilitySlotSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject non-boolean is_available', () => {
      const invalidValues = ['true', 'false', 1, 0, 'yes', 'no'];
      invalidValues.forEach(value => {
        const data = { ...validData, is_available: value };
        const result = createAvailabilitySlotSchema.safeParse(data);
        expect(result.success).toBe(false);
      });
    });
  });

  describe('updateAvailabilitySlotSchema', () => {
    it('should accept all fields as optional', () => {
      const result = updateAvailabilitySlotSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept partial updates', () => {
      const data = { is_available: false };
      const result = updateAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate schedule_id if provided', () => {
      const data = { schedule_id: 'invalid-uuid' };
      const result = updateAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime if provided', () => {
      const data = { start_time: 'invalid-datetime' };
      const result = updateAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate is_available if provided', () => {
      const data = { is_available: 'invalid' };
      const result = updateAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid UUID for schedule_id', () => {
      const data = { schedule_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = updateAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid datetime for times', () => {
      const data = {
        start_time: '2026-01-20T08:00:00.000Z',
        end_time: '2026-01-20T09:00:00.000Z'
      };
      const result = updateAvailabilitySlotSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('availabilitySlotIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = availabilitySlotIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should require id', () => {
      const result = availabilitySlotIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = availabilitySlotIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept friendly id', () => {
      const data = { id: 'AVL0000123' };
      const result = availabilitySlotIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('listAvailabilitySlotsQuerySchema', () => {
    it('should accept empty query params', () => {
      const result = listAvailabilitySlotsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_available).toBeUndefined();
      }
    });

    it('should accept valid pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listAvailabilitySlotsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid filter params', () => {
      const data = {
        schedule_id: '550e8400-e29b-41d4-a716-446655440000',
        override_date: '2026-01-20T00:00:00.000Z',
        is_available: 'true'
      };
      const result = listAvailabilitySlotsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid sort params', () => {
      const data = { sort_by: 'start_time', order: 'asc' };
      const result = listAvailabilitySlotsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID filters', () => {
      const data = { schedule_id: 'invalid-uuid' };
      const result = listAvailabilitySlotsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should transform is_available string to boolean', () => {
      const trueData = { is_available: 'true' };
      const trueResult = listAvailabilitySlotsQuerySchema.safeParse(trueData);
      expect(trueResult.success).toBe(true);
      if (trueResult.success) {
        expect(trueResult.data.is_available).toBe(true);
      }

      const falseData = { is_available: 'false' };
      const falseResult = listAvailabilitySlotsQuerySchema.safeParse(falseData);
      expect(falseResult.success).toBe(true);
      if (falseResult.success) {
        expect(falseResult.data.is_available).toBe(false);
      }
    });

    it('should preserve missing is_available filter as undefined', () => {
      const result = listAvailabilitySlotsQuerySchema.safeParse({
        page: '1',
        limit: '20',
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_available).toBeUndefined();
      }
    });

    it('should reject invalid is_available values', () => {
      const invalidValues = ['yes', 'no', '1', '0', 'TRUE', 'FALSE'];
      invalidValues.forEach(value => {
        const data = { is_available: value };
        const result = listAvailabilitySlotsQuerySchema.safeParse(data);
        expect(result.success).toBe(false);
      });
    });
  });
});
