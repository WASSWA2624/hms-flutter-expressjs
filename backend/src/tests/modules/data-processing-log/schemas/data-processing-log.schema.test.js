/**
 * Data processing log schema tests
 *
 * @module tests/modules/data-processing-log/schemas
 * @description Tests for data processing log validation schemas
 */

const {
  createDataProcessingLogSchema,
  updateDataProcessingLogSchema,
  dataProcessingLogIdParamsSchema,
  listDataProcessingLogsQuerySchema
} = require('@modules/data-processing-log/schemas/data-processing-log.schema');

describe('Data Processing Log Schemas', () => {
  describe('createDataProcessingLogSchema', () => {
    it('should validate valid create data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        purpose: 'TREATMENT',
        legal_basis: 'CONSENT',
        details: 'Patient treatment details'
      };
      const result = createDataProcessingLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate without optional fields', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        purpose: 'BILLING',
        legal_basis: 'CONTRACT'
      };
      const result = createDataProcessingLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all purpose enums', () => {
      const purposes = ['TREATMENT', 'BILLING', 'OPERATIONS', 'RESEARCH', 'MARKETING'];
      purposes.forEach(purpose => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          purpose,
          legal_basis: 'CONSENT'
        };
        const result = createDataProcessingLogSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should validate all legal_basis enums', () => {
      const bases = ['CONSENT', 'CONTRACT', 'LEGAL_OBLIGATION', 'VITAL_INTERESTS', 'PUBLIC_INTEREST', 'LEGITIMATE_INTERESTS'];
      bases.forEach(legal_basis => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          purpose: 'TREATMENT',
          legal_basis
        };
        const result = createDataProcessingLogSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid purpose', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        purpose: 'INVALID',
        legal_basis: 'CONSENT'
      };
      const result = createDataProcessingLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid legal_basis', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        purpose: 'TREATMENT',
        legal_basis: 'INVALID'
      };
      const result = createDataProcessingLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = createDataProcessingLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        purpose: 'TREATMENT',
        legal_basis: 'CONSENT'
      };
      const result = createDataProcessingLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateDataProcessingLogSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        purpose: 'OPERATIONS',
        legal_basis: 'PUBLIC_INTEREST',
        details: 'Updated details'
      };
      const result = updateDataProcessingLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty update data', () => {
      const validData = {};
      const result = updateDataProcessingLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const validData = { purpose: 'RESEARCH' };
      const result = updateDataProcessingLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid purpose', () => {
      const invalidData = { purpose: 'INVALID_PURPOSE' };
      const result = updateDataProcessingLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid legal_basis', () => {
      const invalidData = { legal_basis: 'INVALID_BASIS' };
      const result = updateDataProcessingLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('dataProcessingLogIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = { id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = dataProcessingLogIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = { id: 'invalid-uuid' };
      const result = dataProcessingLogIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = dataProcessingLogIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listDataProcessingLogsQuerySchema', () => {
    it('should validate empty query', () => {
      const validData = {};
      const result = listDataProcessingLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'processed_at',
        order: 'desc'
      };
      const result = listDataProcessingLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with filter params', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        purpose: 'TREATMENT',
        legal_basis: 'CONSENT'
      };
      const result = listDataProcessingLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with date range', () => {
      const validData = {
        date_from: '2026-01-01T00:00:00.000Z',
        date_to: '2026-01-31T23:59:59.999Z'
      };
      const result = listDataProcessingLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid purpose', () => {
      const invalidData = { purpose: 'INVALID' };
      const result = listDataProcessingLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid legal_basis', () => {
      const invalidData = { legal_basis: 'INVALID' };
      const result = listDataProcessingLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format', () => {
      const invalidData = { date_from: '2026-01-01' };
      const result = listDataProcessingLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID in filters', () => {
      const invalidData = { tenant_id: 'not-a-uuid' };
      const result = listDataProcessingLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
