/**
 * Integration log schema validation tests
 *
 * @module tests/modules/integration-log/schemas
 * @description Tests for integration log Zod validation schemas
 */

const {
  integrationLogIdParamsSchema,
  integrationIdParamsSchema,
  listIntegrationLogsQuerySchema
} = require('@validations/integration-log/integration-log.schema');

describe('Integration Log Schema Validation', () => {
  describe('integrationLogIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = integrationLogIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate a friendly identifier', () => {
      const validData = {
        id: 'ILG0000001'
      };

      const result = integrationLogIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };

      const result = integrationLogIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};

      const result = integrationLogIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('integrationIdParamsSchema', () => {
    it('should validate valid integration UUID', () => {
      const validData = {
        integrationId: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = integrationIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate a friendly integration identifier', () => {
      const validData = {
        integrationId: 'INT0000001'
      };

      const result = integrationIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        integrationId: 'not-a-uuid'
      };

      const result = integrationIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing integrationId', () => {
      const invalidData = {};

      const result = integrationIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listIntegrationLogsQuerySchema', () => {
    it('should validate valid query parameters', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'logged_at',
        order: 'desc',
        integration_id: '123e4567-e89b-12d3-a456-426614174000',
        status: 'ACTIVE',
        search: 'test'
      };

      const result = listIntegrationLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal parameters', () => {
      const validData = {};

      const result = listIntegrationLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate a friendly integration_id filter', () => {
      const validData = {
        integration_id: 'INT0000001'
      };

      const result = listIntegrationLogsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should apply default values for page and limit', () => {
      const validData = {};

      const result = listIntegrationLogsQuerySchema.parse(validData);
      expect(result.page).toBeDefined();
      expect(result.limit).toBeDefined();
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID_STATUS'
      };

      const result = listIntegrationLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for integration_id', () => {
      const invalidData = {
        integration_id: 'invalid-uuid'
      };

      const result = listIntegrationLogsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['ACTIVE', 'INACTIVE', 'ERROR'];
      
      statuses.forEach(status => {
        const result = listIntegrationLogsQuerySchema.safeParse({ status });
        expect(result.success).toBe(true);
      });
    });
  });
});
