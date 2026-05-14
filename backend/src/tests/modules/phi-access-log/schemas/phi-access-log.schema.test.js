/**
 * PHI access log schema tests
 *
 * @module tests/modules/phi-access-log/schemas
 * @description Tests for PHI access log validation schemas
 */

const {
  createPhiAccessLogSchema,
  updatePhiAccessLogSchema,
  phiAccessLogIdParamsSchema,
  userIdParamsSchema,
  listPhiAccessLogsQuerySchema
} = require('@modules/phi-access-log/schemas/phi-access-log.schema');

describe('PHI Access Log Schemas', () => {
  describe('createPhiAccessLogSchema', () => {
    it('should validate valid create data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        patient_id: '123e4567-e89b-12d3-a456-426614174002',
        access_scope: 'PATIENT',
        reason: 'Treatment review'
      };
      const result = createPhiAccessLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate without optional reason', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        patient_id: '123e4567-e89b-12d3-a456-426614174002',
        access_scope: 'PATIENT'
      };
      const result = createPhiAccessLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all access_scope enums', () => {
      const scopes = ['TENANT', 'FACILITY', 'DEPARTMENT', 'PATIENT'];
      scopes.forEach(scope => {
        const validData = {
          tenant_id: '123e4567-e89b-12d3-a456-426614174000',
          user_id: '123e4567-e89b-12d3-a456-426614174001',
          patient_id: '123e4567-e89b-12d3-a456-426614174002',
          access_scope: scope
        };
        const result = createPhiAccessLogSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid access_scope', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        patient_id: '123e4567-e89b-12d3-a456-426614174002',
        access_scope: 'INVALID'
      };
      const result = createPhiAccessLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = createPhiAccessLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUIDs', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        patient_id: '123e4567-e89b-12d3-a456-426614174002',
        access_scope: 'PATIENT'
      };
      const result = createPhiAccessLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject reason exceeding max length', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        patient_id: '123e4567-e89b-12d3-a456-426614174002',
        access_scope: 'PATIENT',
        reason: 'a'.repeat(256)
      };
      const result = createPhiAccessLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updatePhiAccessLogSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        access_scope: 'FACILITY',
        reason: 'Updated reason'
      };
      const result = updatePhiAccessLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty update data', () => {
      const validData = {};
      const result = updatePhiAccessLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate partial updates', () => {
      const validData = { access_scope: 'DEPARTMENT' };
      const result = updatePhiAccessLogSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid access_scope', () => {
      const invalidData = { access_scope: 'INVALID_SCOPE' };
      const result = updatePhiAccessLogSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('phiAccessLogIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = { id: '123e4567-e89b-12d3-a456-426614174000' };
      const result = phiAccessLogIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = { id: 'invalid-uuid' };
      const result = phiAccessLogIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = phiAccessLogIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('userIdParamsSchema', () => {
    it('should validate valid user ID', () => {
      const validData = { userId: '123e4567-e89b-12d3-a456-426614174000' };
      const result = userIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid user ID', () => {
      const invalidData = { userId: 'not-a-uuid' };
      const result = userIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listPhiAccessLogsQuerySchema', () => {
    it('should validate empty query', () => {
      const validData = {};
      const result = listPhiAccessLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'accessed_at',
        order: 'desc'
      };
      const result = listPhiAccessLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with filter params', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        patient_id: '123e4567-e89b-12d3-a456-426614174002',
        access_scope: 'PATIENT'
      };
      const result = listPhiAccessLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with date range', () => {
      const validData = {
        date_from: '2026-01-01T00:00:00.000Z',
        date_to: '2026-01-31T23:59:59.999Z'
      };
      const result = listPhiAccessLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid access_scope', () => {
      const invalidData = { access_scope: 'INVALID' };
      const result = listPhiAccessLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format', () => {
      const invalidData = { date_from: '2026-01-01' };
      const result = listPhiAccessLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID in filters', () => {
      const invalidData = { tenant_id: 'not-a-uuid' };
      const result = listPhiAccessLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
