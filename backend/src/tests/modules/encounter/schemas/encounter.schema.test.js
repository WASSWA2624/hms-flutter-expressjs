/**
 * Encounter schema tests
 *
 * @module tests/modules/encounter/schemas
 * @description Tests for encounter validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createEncounterSchema,
  updateEncounterSchema,
  encounterIdParamsSchema,
  listEncountersQuerySchema
} = require('@validations/encounter/encounter.schema');

describe('Encounter Schemas', () => {
  describe('createEncounterSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      provider_user_id: '550e8400-e29b-41d4-a716-446655440003',
      encounter_type: 'OPD',
      status: 'OPEN',
      started_at: '2026-01-19T10:00:00Z',
      ended_at: null
    };

    it('should validate correct encounter data', () => {
      const result = createEncounterSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require encounter_type', () => {
      const data = { ...validData };
      delete data.encounter_type;
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require started_at', () => {
      const data = { ...validData };
      delete data.started_at;
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate encounter_type enum values', () => {
      const types = ['OPD', 'IPD', 'ICU', 'THEATRE', 'EMERGENCY', 'TELEMEDICINE'];
      types.forEach(type => {
        const data = { ...validData, encounter_type: type };
        const result = createEncounterSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid encounter_type', () => {
      const data = { ...validData, encounter_type: 'INVALID' };
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const statuses = ['OPEN', 'CLOSED', 'CANCELLED'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createEncounterSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional provider_user_id', () => {
      const data = { ...validData };
      delete data.provider_user_id;
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional ended_at', () => {
      const data = { ...validData };
      delete data.ended_at;
      const result = createEncounterSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateEncounterSchema', () => {
    it('should validate all fields as optional', () => {
      const result = updateEncounterSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const data = {
        status: 'CLOSED',
        ended_at: '2026-01-19T11:00:00Z'
      };
      const result = updateEncounterSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('encounterIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const result = encounterIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = encounterIdParamsSchema.safeParse({
        id: 'invalid-uuid'
      });
      expect(result.success).toBe(false);
    });
  });

  describe('listEncountersQuerySchema', () => {
    it('should validate query parameters', () => {
      const result = listEncountersQuerySchema.safeParse({
        page: '1',
        limit: '20',
        encounter_type: 'OPD',
        status: 'OPEN'
      });
      expect(result.success).toBe(true);
    });

    it('should allow all parameters as optional', () => {
      const result = listEncountersQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });
});
