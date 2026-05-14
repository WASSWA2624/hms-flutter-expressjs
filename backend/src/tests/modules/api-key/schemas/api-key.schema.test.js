/**
 * API Key schema validation tests
 *
 * @module tests/modules/api-key/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createApiKeySchema,
  updateApiKeySchema,
  apiKeyIdParamsSchema,
  listApiKeysQuerySchema
} = require('@validations/api-key/api-key.schema');

describe('API Key Schema Validation', () => {
  describe('createApiKeySchema', () => {
    it('should validate correct API key data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Production API Key',
        expires_at: '2026-12-31T23:59:59Z'
      };
      const result = createApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (without expires_at)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Test API Key'
      };
      const result = createApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null expires_at', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Test API Key',
        expires_at: null
      };
      const result = createApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: '  Production API Key  '
      };
      const result = createApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Production API Key');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Test API Key'
      };
      const result = createApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing user_id', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test API Key'
      };
      const result = createApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: ''
      };
      const result = createApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 120 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'A'.repeat(121)
      };
      const result = createApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Test API Key'
      };
      const result = createApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid user_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: 'invalid-uuid',
        name: 'Test API Key'
      };
      const result = createApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format for expires_at', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Test API Key',
        expires_at: 'invalid-date'
      };
      const result = createApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateApiKeySchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        name: 'Updated API Key',
        is_active: false,
        expires_at: '2027-12-31T23:59:59Z'
      };
      const result = updateApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only name', () => {
      const validData = {
        name: 'Updated API Key'
      };
      const result = updateApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only is_active', () => {
      const validData = {
        is_active: true
      };
      const result = updateApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only expires_at', () => {
      const validData = {
        expires_at: '2027-12-31T23:59:59Z'
      };
      const result = updateApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null expires_at', () => {
      const validData = {
        expires_at: null
      };
      const result = updateApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Updated API Key  '
      };
      const result = updateApiKeySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated API Key');
      }
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 120 characters', () => {
      const invalidData = {
        name: 'A'.repeat(121)
      };
      const result = updateApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid boolean for is_active', () => {
      const invalidData = {
        is_active: 'not-a-boolean'
      };
      const result = updateApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid date format for expires_at', () => {
      const invalidData = {
        expires_at: 'invalid-date'
      };
      const result = updateApiKeySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('apiKeyIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = apiKeyIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };
      const result = apiKeyIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = apiKeyIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject numeric id', () => {
      const invalidData = {
        id: 123
      };
      const result = apiKeyIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject null id', () => {
      const invalidData = {
        id: null
      };
      const result = apiKeyIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listApiKeysQuerySchema', () => {
    it('should validate with all query parameters', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        user_id: '123e4567-e89b-12d3-a456-426614174001',
        is_active: 'true',
        search: 'production'
      };
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with no query parameters', () => {
      const validData = {};
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only pagination', () => {
      const validData = {
        page: '2',
        limit: '50'
      };
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only filters', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        is_active: 'false'
      };
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should transform is_active "true" to boolean true', () => {
      const validData = {
        is_active: 'true'
      };
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_active).toBe(true);
      }
    });

    it('should transform is_active "false" to boolean false', () => {
      const validData = {
        is_active: 'false'
      };
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.is_active).toBe(false);
      }
    });

    it('should trim search query', () => {
      const validData = {
        search: '  production  '
      };
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('production');
      }
    });

    it('should apply default page', () => {
      const validData = {};
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(1);
      }
    });

    it('should apply default limit', () => {
      const validData = {};
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.limit).toBe(20);
      }
    });

    it('should apply default sort order', () => {
      const validData = {};
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.order).toBe('asc');
      }
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'invalid-uuid'
      };
      const result = listApiKeysQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid user_id UUID', () => {
      const invalidData = {
        user_id: 'invalid-uuid'
      };
      const result = listApiKeysQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_active value', () => {
      const invalidData = {
        is_active: 'maybe'
      };
      const result = listApiKeysQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid order value', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listApiKeysQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce page string to number', () => {
      const validData = {
        page: '5'
      };
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(5);
        expect(typeof result.data.page).toBe('number');
      }
    });

    it('should coerce limit string to number', () => {
      const validData = {
        limit: '50'
      };
      const result = listApiKeysQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.limit).toBe(50);
        expect(typeof result.data.limit).toBe('number');
      }
    });
  });
});
