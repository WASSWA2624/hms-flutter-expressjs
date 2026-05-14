/**
 * Integration schema validation tests
 *
 * @module tests/modules/integration/schemas
 * @description Tests for integration Zod validation schemas
 */

const {
  createIntegrationSchema,
  updateIntegrationSchema,
  integrationIdParamsSchema,
  listIntegrationsQuerySchema
} = require('@validations/integration/integration.schema');

describe('Integration Schema Validation', () => {
  describe('createIntegrationSchema', () => {
    it('should validate a friendly tenant identifier', () => {
      const validData = {
        tenant_id: 'TEN0000001',
        integration_type: 'HL7',
        status: 'ACTIVE',
        name: 'Test Integration',
      };

      const result = createIntegrationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate valid integration creation data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_type: 'HL7',
        status: 'ACTIVE',
        name: 'Test Integration',
        config_json: { key: 'value' }
      };

      const result = createIntegrationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate without optional config_json', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_type: 'FHIR',
        status: 'INACTIVE',
        name: 'Test Integration'
      };

      const result = createIntegrationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id format', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        integration_type: 'LAB',
        status: 'ACTIVE',
        name: 'Test'
      };

      const result = createIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid integration_type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_type: 'INVALID_TYPE',
        status: 'ACTIVE',
        name: 'Test'
      };

      const result = createIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_type: 'HL7',
        status: 'INVALID_STATUS',
        name: 'Test'
      };

      const result = createIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_type: 'HL7',
        status: 'ACTIVE',
        name: ''
      };

      const result = createIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 120 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_type: 'HL7',
        status: 'ACTIVE',
        name: 'a'.repeat(121)
      };

      const result = createIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateIntegrationSchema', () => {
    it('should validate valid update data', () => {
      const validData = {
        integration_type: 'FHIR',
        status: 'ERROR',
        name: 'Updated Integration',
        config_json: { updated: true }
      };

      const result = updateIntegrationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate partial update data', () => {
      const validData = {
        status: 'INACTIVE'
      };

      const result = updateIntegrationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate empty object (all optional)', () => {
      const validData = {};

      const result = updateIntegrationSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid integration_type', () => {
      const invalidData = {
        integration_type: 'INVALID'
      };

      const result = updateIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID'
      };

      const result = updateIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };

      const result = updateIntegrationSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('integrationIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = integrationIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate a friendly identifier', () => {
      const validData = {
        id: 'INT0000001'
      };

      const result = integrationIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };

      const result = integrationIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};

      const result = integrationIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listIntegrationsQuerySchema', () => {
    it('should validate valid query parameters', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'name',
        order: 'asc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        integration_type: 'HL7',
        status: 'ACTIVE',
        name: 'Test',
        search: 'integration'
      };

      const result = listIntegrationsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal parameters', () => {
      const validData = {};

      const result = listIntegrationsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate a friendly tenant_id filter', () => {
      const validData = {
        tenant_id: 'TEN0000001'
      };

      const result = listIntegrationsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should apply default values for page and limit', () => {
      const validData = {};

      const result = listIntegrationsQuerySchema.parse(validData);
      expect(result.page).toBeDefined();
      expect(result.limit).toBeDefined();
    });

    it('should reject invalid integration_type', () => {
      const invalidData = {
        integration_type: 'INVALID'
      };

      const result = listIntegrationsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid status', () => {
      const invalidData = {
        status: 'INVALID'
      };

      const result = listIntegrationsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for tenant_id', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid'
      };

      const result = listIntegrationsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
