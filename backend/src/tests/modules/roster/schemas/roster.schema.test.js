/**
 * Roster schema tests
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createRosterSchema,
  updateRosterSchema,
  publishRosterSchema,
  rosterIdParamsSchema,
  listRostersQuerySchema
} = require('@validations/roster/roster.schema');

describe('Roster Schemas', () => {
  describe('createRosterSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      name: 'February nursing roster',
      period_start: '2026-02-01T00:00:00.000Z',
      period_end: '2026-02-28T23:59:59.000Z',
      status: 'DRAFT'
    };

    it('should validate correct roster data', () => {
      const result = createRosterSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createRosterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require period_start', () => {
      const data = { ...validData };
      delete data.period_start;
      const result = createRosterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require period_end', () => {
      const data = { ...validData };
      delete data.period_end;
      const result = createRosterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject period_end before period_start', () => {
      const data = { ...validData, period_start: '2026-02-28T00:00:00.000Z', period_end: '2026-02-01T00:00:00.000Z' };
      const result = createRosterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should default status to DRAFT', () => {
      const data = { ...validData };
      delete data.status;
      const result = createRosterSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.status).toBe('DRAFT');
    });
  });

  describe('rosterIdParamsSchema', () => {
    it('should validate UUID id', () => {
      const result = rosterIdParamsSchema.safeParse({ id: '550e8400-e29b-41d4-a716-446655440000' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = rosterIdParamsSchema.safeParse({ id: 'invalid' });
      expect(result.success).toBe(false);
    });
  });

  describe('publishRosterSchema', () => {
    it('should accept empty body', () => {
      const result = publishRosterSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should default notify_staff to true', () => {
      const result = publishRosterSchema.safeParse({});
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.notify_staff).toBe(true);
    });
  });
});
