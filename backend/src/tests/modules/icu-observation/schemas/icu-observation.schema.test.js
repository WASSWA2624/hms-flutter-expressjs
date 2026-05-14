/**
 * ICU Observation schema tests
 *
 * @module tests/modules/icu-observation/schemas
 * @description Tests for ICU observation validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createIcuObservationSchema,
  updateIcuObservationSchema,
  icuObservationIdParamsSchema,
  listIcuObservationsQuerySchema
} = require('@validations/icu-observation/icu-observation.schema');

describe('ICU Observation Schemas', () => {
  describe('createIcuObservationSchema', () => {
    const validData = {
      icu_stay_id: '550e8400-e29b-41d4-a716-446655440000',
      observed_at: '2024-01-01T10:00:00.000Z',
      observation: 'Patient vital signs stable'
    };

    it('should validate correct ICU observation data', () => {
      const result = createIcuObservationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require icu_stay_id', () => {
      const data = { ...validData };
      delete data.icu_stay_id;
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require observation', () => {
      const data = { ...validData };
      delete data.observation;
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept optional observed_at', () => {
      const data = { ...validData };
      delete data.observed_at;
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate icu_stay_id format', () => {
      const data = { ...validData, icu_stay_id: 'invalid-uuid' };
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate observed_at datetime format', () => {
      const data = { ...validData, observed_at: 'invalid-date' };
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim observation text', () => {
      const data = { ...validData, observation: '  Test observation  ' };
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.observation).toBe('Test observation');
      }
    });

    it('should enforce min length for observation', () => {
      const data = { ...validData, observation: '' };
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for observation', () => {
      const data = { ...validData, observation: 'a'.repeat(5001) };
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept max length of 5000 chars', () => {
      const data = { ...validData, observation: 'a'.repeat(5000) };
      const result = createIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateIcuObservationSchema', () => {
    it('should validate with all fields', () => {
      const data = {
        observed_at: '2024-01-01T10:00:00.000Z',
        observation: 'Updated observation'
      };
      const result = updateIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only observed_at', () => {
      const data = { observed_at: '2024-01-01T10:00:00.000Z' };
      const result = updateIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with only observation', () => {
      const data = { observation: 'New observation text' };
      const result = updateIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const data = {};
      const result = updateIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate observed_at datetime format', () => {
      const data = { observed_at: 'invalid-date' };
      const result = updateIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce min length for observation when provided', () => {
      const data = { observation: '' };
      const result = updateIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce max length for observation when provided', () => {
      const data = { observation: 'a'.repeat(5001) };
      const result = updateIcuObservationSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('icuObservationIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const data = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = icuObservationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const data = { id: 'invalid-uuid' };
      const result = icuObservationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const data = {};
      const result = icuObservationIdParamsSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('listIcuObservationsQuerySchema', () => {
    it('should validate with no filters', () => {
      const data = {};
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with icu_stay_id filter', () => {
      const data = { icu_stay_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with date range filters', () => {
      const data = {
        observed_at_from: '2024-01-01T00:00:00.000Z',
        observed_at_to: '2024-01-31T23:59:59.999Z'
      };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const data = { search: 'vital signs' };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination parameters', () => {
      const data = { page: '2', limit: '50' };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with sort parameters', () => {
      const data = { sort_by: 'observed_at', order: 'desc' };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate with all parameters combined', () => {
      const data = {
        icu_stay_id: '550e8400-e29b-41d4-a716-446655440000',
        observed_at_from: '2024-01-01T00:00:00.000Z',
        observed_at_to: '2024-01-31T23:59:59.999Z',
        search: 'test',
        page: '1',
        limit: '20',
        sort_by: 'observed_at',
        order: 'asc'
      };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid icu_stay_id UUID', () => {
      const data = { icu_stay_id: 'invalid-uuid' };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid observed_at_from datetime', () => {
      const data = { observed_at_from: 'invalid-date' };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim search text', () => {
      const data = { search: '  test search  ' };
      const result = listIcuObservationsQuerySchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('test search');
      }
    });
  });
});
