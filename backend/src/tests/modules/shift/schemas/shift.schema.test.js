/**
 * Shift schema tests
 *
 * @module tests/modules/shift/schemas
 * @description Tests for shift validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createShiftSchema,
  updateShiftSchema,
  publishShiftSchema,
  shiftIdParamsSchema,
  listShiftsQuerySchema
} = require('@validations/shift/shift.schema');

describe('Shift Schemas', () => {
  describe('createShiftSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      shift_type: 'DAY',
      status: 'SCHEDULED',
      start_time: '2026-01-20T08:00:00.000Z',
      end_time: '2026-01-20T16:00:00.000Z'
    };

    it('should validate correct shift data', () => {
      const result = createShiftSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require shift_type', () => {
      const data = { ...validData };
      delete data.shift_type;
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require start_time', () => {
      const data = { ...validData };
      delete data.start_time;
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require end_time', () => {
      const data = { ...validData };
      delete data.end_time;
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should default status to SCHEDULED', () => {
      const data = { ...validData };
      delete data.status;
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.status).toBe('SCHEDULED');
      }
    });

    it('should validate shift_type enum', () => {
      const data = { ...validData, shift_type: 'INVALID' };
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid shift_type values', () => {
      const types = ['DAY', 'NIGHT', 'SWING', 'ON_CALL'];
      types.forEach(type => {
        const data = { ...validData, shift_type: type };
        const result = createShiftSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should validate status enum', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['SCHEDULED', 'COMPLETED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createShiftSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject end_time before start_time', () => {
      const data = {
        ...validData,
        start_time: '2026-01-20T16:00:00.000Z',
        end_time: '2026-01-20T08:00:00.000Z'
      };
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept end_time after start_time', () => {
      const data = {
        ...validData,
        start_time: '2026-01-20T08:00:00.000Z',
        end_time: '2026-01-20T16:00:00.000Z'
      };
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate datetime format for start_time', () => {
      const data = { ...validData, start_time: 'invalid-date' };
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime format for end_time', () => {
      const data = { ...validData, end_time: 'invalid-date' };
      const result = createShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateShiftSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateShiftSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = { shift_type: 'NIGHT' };
      const result = updateShiftSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate shift_type enum when provided', () => {
      const data = { shift_type: 'INVALID' };
      const result = updateShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum when provided', () => {
      const data = { status: 'INVALID' };
      const result = updateShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject end_time before start_time when both provided', () => {
      const data = {
        start_time: '2026-01-20T16:00:00.000Z',
        end_time: '2026-01-20T08:00:00.000Z'
      };
      const result = updateShiftSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid partial datetime updates', () => {
      const data = { start_time: '2026-01-21T09:00:00.000Z' };
      const result = updateShiftSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('publishShiftSchema', () => {
    it('should default notify_staff to true', () => {
      const result = publishShiftSchema.safeParse({});
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.notify_staff).toBe(true);
      }
    });

    it('should accept notify_staff boolean', () => {
      const result = publishShiftSchema.safeParse({ notify_staff: false });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.notify_staff).toBe(false);
      }
    });

    it('should reject non-boolean notify_staff', () => {
      const result = publishShiftSchema.safeParse({ notify_staff: 'invalid' });
      expect(result.success).toBe(false);
    });
  });

  describe('shiftIdParamsSchema', () => {
    it('should validate UUID id param', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = shiftIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = shiftIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const result = shiftIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listShiftsQuerySchema', () => {
    it('should validate valid query params', () => {
      const data = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'asc'
      };
      const result = listShiftsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept optional filter params', () => {
      const data = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        shift_type: 'DAY',
        status: 'SCHEDULED',
        start_time_from: '2026-01-20T00:00:00.000Z',
        start_time_to: '2026-01-21T00:00:00.000Z',
        end_time_from: '2026-01-20T00:00:00.000Z',
        end_time_to: '2026-01-21T00:00:00.000Z'
      };
      const result = listShiftsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate shift_type enum in query', () => {
      const data = { shift_type: 'INVALID' };
      const result = listShiftsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum in query', () => {
      const data = { status: 'INVALID' };
      const result = listShiftsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate datetime format for date filters', () => {
      const data = { start_time_from: 'invalid-date' };
      const result = listShiftsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow all filter params to be optional', () => {
      const result = listShiftsQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });
});
