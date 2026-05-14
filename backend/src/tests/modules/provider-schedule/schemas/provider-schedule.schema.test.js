/**
 * Provider schedule schema tests
 *
 * @module tests/modules/provider-schedule/schemas
 * @description Tests for provider schedule validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createProviderScheduleSchema,
  updateProviderScheduleSchema,
  providerScheduleIdParamsSchema,
  listProviderSchedulesQuerySchema
} = require('@validations/provider-schedule/provider-schedule.schema');

describe('Provider Schedule Schemas', () => {
  describe('createProviderScheduleSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
      day_of_week: 1,
      start_time: '2026-01-20T08:00:00.000Z',
      end_time: '2026-01-20T17:00:00.000Z'
    };

    it('should validate correct provider schedule data', () => {
      const result = createProviderScheduleSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require provider_user_id', () => {
      const data = { ...validData };
      delete data.provider_user_id;
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require day_of_week', () => {
      const data = { ...validData };
      delete data.day_of_week;
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require start_time', () => {
      const data = { ...validData };
      delete data.start_time;
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require end_time', () => {
      const data = { ...validData };
      delete data.end_time;
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate day_of_week is between 0 and 6', () => {
      const invalidDays = [-1, 7, 8, 10];
      invalidDays.forEach(day => {
        const data = { ...validData, day_of_week: day };
        const result = createProviderScheduleSchema.safeParse(data);
        expect(result.success).toBe(false);
      });
    });

    it('should accept valid day_of_week values', () => {
      const validDays = [0, 1, 2, 3, 4, 5, 6];
      validDays.forEach(day => {
        const data = { ...validData, day_of_week: day };
        const result = createProviderScheduleSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept nullable facility_id', () => {
      const data = { ...validData, facility_id: null };
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for facility_id', () => {
      const data = { ...validData, facility_id: 'invalid-uuid' };
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for provider_user_id', () => {
      const data = { ...validData, provider_user_id: 'invalid-uuid' };
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for start_time', () => {
      const data = { ...validData, start_time: 'invalid-datetime' };
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for end_time', () => {
      const data = { ...validData, end_time: 'invalid-datetime' };
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject non-integer day_of_week', () => {
      const data = { ...validData, day_of_week: 1.5 };
      const result = createProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateProviderScheduleSchema', () => {
    it('should accept all fields as optional', () => {
      const result = updateProviderScheduleSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept partial updates', () => {
      const data = { day_of_week: 3 };
      const result = updateProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate day_of_week if provided', () => {
      const data = { day_of_week: 10 };
      const result = updateProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate UUIDs if provided', () => {
      const data = { provider_user_id: 'invalid-uuid' };
      const result = updateProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime if provided', () => {
      const data = { start_time: 'invalid-datetime' };
      const result = updateProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept nullable facility_id', () => {
      const data = { facility_id: null };
      const result = updateProviderScheduleSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('providerScheduleIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = providerScheduleIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should require id', () => {
      const result = providerScheduleIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = providerScheduleIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listProviderSchedulesQuerySchema', () => {
    it('should accept empty query params', () => {
      const result = listProviderSchedulesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept valid pagination params', () => {
      const data = { page: '1', limit: '20' };
      const result = listProviderSchedulesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid filter params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
        day_of_week: '1'
      };
      const result = listProviderSchedulesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept valid sort params', () => {
      const data = { sort_by: 'day_of_week', order: 'asc' };
      const result = listProviderSchedulesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID filters', () => {
      const data = { tenant_id: 'invalid-uuid' };
      const result = listProviderSchedulesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid day_of_week', () => {
      const data = { day_of_week: '10' };
      const result = listProviderSchedulesQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should coerce day_of_week to number', () => {
      const data = { day_of_week: '3' };
      const result = listProviderSchedulesQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(typeof result.data.day_of_week).toBe('number');
        expect(result.data.day_of_week).toBe(3);
      }
    });
  });
});
