/**
 * Nurse roster schema tests
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createNurseRosterSchema,
  updateNurseRosterSchema,
  publishNurseRosterSchema,
  nurseRosterIdParamsSchema,
  listNurseRostersQuerySchema
} = require('@validations/nurse-roster/nurse-roster.schema');

describe('Nurse Roster Schemas', () => {
  describe('createNurseRosterSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      period_start: '2026-02-01T00:00:00.000Z',
      period_end: '2026-02-28T23:59:59.000Z',
      status: 'DRAFT'
    };

    it('should validate correct roster data', () => {
      const result = createNurseRosterSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createNurseRosterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require period_start', () => {
      const data = { ...validData };
      delete data.period_start;
      const result = createNurseRosterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require period_end', () => {
      const data = { ...validData };
      delete data.period_end;
      const result = createNurseRosterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject period_end before period_start', () => {
      const data = { ...validData, period_start: '2026-02-28T00:00:00.000Z', period_end: '2026-02-01T00:00:00.000Z' };
      const result = createNurseRosterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should default status to DRAFT', () => {
      const data = { ...validData };
      delete data.status;
      const result = createNurseRosterSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.status).toBe('DRAFT');
    });
  });

  describe('nurseRosterIdParamsSchema', () => {
    it('should validate UUID id', () => {
      const result = nurseRosterIdParamsSchema.safeParse({ id: '550e8400-e29b-41d4-a716-446655440000' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = nurseRosterIdParamsSchema.safeParse({ id: 'invalid' });
      expect(result.success).toBe(false);
    });
  });

  describe('publishNurseRosterSchema', () => {
    it('should accept empty body', () => {
      const result = publishNurseRosterSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should default notify_staff to true', () => {
      const result = publishNurseRosterSchema.safeParse({});
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.notify_staff).toBe(true);
    });
  });
});
