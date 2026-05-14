/**
 * Template schema validation tests
 *
 * @module tests/modules/template/schemas
 * @description Tests for Zod validation schemas
 */

const {
  createTemplateSchema,
  updateTemplateSchema,
  templateIdParamsSchema,
  listTemplatesQuerySchema
} = require('@modules/template/schemas/template.schema');

describe('Template Schemas', () => {
  describe('createTemplateSchema', () => {
    it('should validate correct template creation data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Template',
        channel: 'EMAIL',
        body: 'Template body content'
      };

      const result = createTemplateSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for tenant_id', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        name: 'Test Template',
        channel: 'EMAIL',
        body: 'Template body'
      };

      const result = createTemplateSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid channel type', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Template',
        channel: 'INVALID',
        body: 'Template body'
      };

      const result = createTemplateSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing required fields', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = createTemplateSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from strings', () => {
      const dataWithSpaces = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: '  Test Template  ',
        channel: 'EMAIL',
        body: '  Template body  '
      };

      const result = createTemplateSchema.safeParse(dataWithSpaces);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Test Template');
        expect(result.data.body).toBe('Template body');
      }
    });
  });

  describe('updateTemplateSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        name: 'Updated Template',
        channel: 'SMS',
        body: 'Updated body'
      };

      const result = updateTemplateSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const partialData = {
        name: 'Updated Template'
      };

      const result = updateTemplateSchema.safeParse(partialData);
      expect(result.success).toBe(true);
    });

    it('should allow empty object for optional updates', () => {
      const result = updateTemplateSchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });

  describe('templateIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validParams = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };

      const result = templateIdParamsSchema.safeParse(validParams);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidParams = {
        id: 'not-a-uuid'
      };

      const result = templateIdParamsSchema.safeParse(invalidParams);
      expect(result.success).toBe(false);
    });
  });

  describe('listTemplatesQuerySchema', () => {
    it('should validate correct query parameters', () => {
      const validQuery = {
        page: '1',
        limit: '20',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'EMAIL',
        search: 'test'
      };

      const result = listTemplatesQuerySchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('should allow optional query parameters', () => {
      const minimalQuery = {};

      const result = listTemplatesQuerySchema.safeParse(minimalQuery);
      expect(result.success).toBe(true);
    });

    it('should reject invalid channel in query', () => {
      const invalidQuery = {
        channel: 'INVALID'
      };

      const result = listTemplatesQuerySchema.safeParse(invalidQuery);
      expect(result.success).toBe(false);
    });
  });
});
