/**
 * Template Variable schema validation tests
 */

const {
  createTemplateVariableSchema,
  updateTemplateVariableSchema,
  templateVariableIdParamsSchema,
  listTemplateVariablesQuerySchema
} = require('@modules/template-variable/schemas/template-variable.schema');

describe('Template Variable Schemas', () => {
  describe('createTemplateVariableSchema', () => {
    it('should validate correct data', () => {
      const validData = {
        template_id: '123e4567-e89b-12d3-a456-426614174000',
        key: 'test_key',
        description: 'Test description'
      };
      const result = createTemplateVariableSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid template_id', () => {
      const invalidData = {
        template_id: 'invalid',
        key: 'test_key'
      };
      const result = createTemplateVariableSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace', () => {
      const data = {
        template_id: '123e4567-e89b-12d3-a456-426614174000',
        key: '  test_key  '
      };
      const result = createTemplateVariableSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.key).toBe('test_key');
      }
    });
  });

  describe('updateTemplateVariableSchema', () => {
    it('should allow partial updates', () => {
      const result = updateTemplateVariableSchema.safeParse({ key: 'new_key' });
      expect(result.success).toBe(true);
    });
  });

  describe('templateVariableIdParamsSchema', () => {
    it('should validate UUID', () => {
      const result = templateVariableIdParamsSchema.safeParse({ 
        id: '123e4567-e89b-12d3-a456-426614174000' 
      });
      expect(result.success).toBe(true);
    });
  });

  describe('listTemplateVariablesQuerySchema', () => {
    it('should validate query params', () => {
      const result = listTemplateVariablesQuerySchema.safeParse({
        template_id: '123e4567-e89b-12d3-a456-426614174000',
        search: 'test'
      });
      expect(result.success).toBe(true);
    });
  });
});
