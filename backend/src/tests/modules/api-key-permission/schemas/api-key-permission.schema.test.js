/**
 * API Key Permission schema validation tests
 *
 * @module tests/modules/api-key-permission/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createApiKeyPermissionSchema,
  updateApiKeyPermissionSchema,
  apiKeyPermissionIdParamsSchema,
  listApiKeyPermissionsQuerySchema
} = require('@validations/api-key-permission/api-key-permission.schema');

describe('API Key Permission Schema Validation', () => {
  describe('createApiKeyPermissionSchema', () => {
    it('should validate correct API key permission data', () => {
      const validData = {
        api_key_id: '123e4567-e89b-12d3-a456-426614174000',
        permission_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createApiKeyPermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing api_key_id', () => {
      const invalidData = {
        permission_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createApiKeyPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing permission_id', () => {
      const invalidData = {
        api_key_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = createApiKeyPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid api_key_id UUID', () => {
      const invalidData = {
        api_key_id: 'invalid-uuid',
        permission_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createApiKeyPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid permission_id UUID', () => {
      const invalidData = {
        api_key_id: '123e4567-e89b-12d3-a456-426614174000',
        permission_id: 'invalid-uuid'
      };
      const result = createApiKeyPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateApiKeyPermissionSchema', () => {
    it('should validate correct update data', () => {
      const validData = {
        api_key_id: '123e4567-e89b-12d3-a456-426614174000',
        permission_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateApiKeyPermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only api_key_id', () => {
      const validData = {
        api_key_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = updateApiKeyPermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only permission_id', () => {
      const validData = {
        permission_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateApiKeyPermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateApiKeyPermissionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid api_key_id UUID', () => {
      const invalidData = {
        api_key_id: 'invalid-uuid'
      };
      const result = updateApiKeyPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid permission_id UUID', () => {
      const invalidData = {
        permission_id: 'invalid-uuid'
      };
      const result = updateApiKeyPermissionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('apiKeyPermissionIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = apiKeyPermissionIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const invalidData = {
        id: 'invalid-uuid'
      };
      const result = apiKeyPermissionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = apiKeyPermissionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject numeric id', () => {
      const invalidData = {
        id: 123
      };
      const result = apiKeyPermissionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject null id', () => {
      const invalidData = {
        id: null
      };
      const result = apiKeyPermissionIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listApiKeyPermissionsQuerySchema', () => {
    it('should validate with all query parameters', () => {
      const validData = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc',
        api_key_id: '123e4567-e89b-12d3-a456-426614174000',
        permission_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with no query parameters', () => {
      const validData = {};
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only pagination', () => {
      const validData = {
        page: '2',
        limit: '50'
      };
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only filters', () => {
      const validData = {
        api_key_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should apply default page', () => {
      const validData = {};
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(1);
      }
    });

    it('should apply default limit', () => {
      const validData = {};
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.limit).toBe(20);
      }
    });

    it('should apply default sort order', () => {
      const validData = {};
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.order).toBe('asc');
      }
    });

    it('should reject invalid api_key_id UUID', () => {
      const invalidData = {
        api_key_id: 'invalid-uuid'
      };
      const result = listApiKeyPermissionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid permission_id UUID', () => {
      const invalidData = {
        permission_id: 'invalid-uuid'
      };
      const result = listApiKeyPermissionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid order value', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listApiKeyPermissionsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce page string to number', () => {
      const validData = {
        page: '5'
      };
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
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
      const result = listApiKeyPermissionsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.limit).toBe(50);
        expect(typeof result.data.limit).toBe('number');
      }
    });
  });
});
