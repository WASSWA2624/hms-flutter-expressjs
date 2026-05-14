/**
 * OAuth Account schema validation tests
 *
 * @module tests/modules/oauth-account/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createOAuthAccountSchema,
  updateOAuthAccountSchema,
  oauthAccountIdParamsSchema,
  userIdParamsSchema,
  listOAuthAccountsQuerySchema
} = require('@validations/oauth-account/oauth-account.schema');

describe('OAuth Account Schema Validation', () => {
  describe('createOAuthAccountSchema', () => {
    it('should validate correct OAuth account data', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'google',
        provider_user_id: 'google-123456',
        access_token_encrypted: 'encrypted_access_token_here',
        refresh_token_encrypted: 'encrypted_refresh_token_here',
        expires_at: '2026-12-31T23:59:59.000Z'
      };
      const result = createOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (user_id, provider, and provider_user_id only)', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'google',
        provider_user_id: 'google-123456'
      };
      const result = createOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null optional fields', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'microsoft',
        provider_user_id: 'ms-789',
        access_token_encrypted: null,
        refresh_token_encrypted: null,
        expires_at: null
      };
      const result = createOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim provider whitespace', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: '  linkedin  ',
        provider_user_id: 'linkedin-123'
      };
      const result = createOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.provider).toBe('linkedin');
      }
    });

    it('should trim provider_user_id whitespace', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'github',
        provider_user_id: '  github-123456  '
      };
      const result = createOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.provider_user_id).toBe('github-123456');
      }
    });

    it('should reject missing user_id', () => {
      const invalidData = {
        provider: 'google',
        provider_user_id: 'google-123'
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing provider', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider_user_id: 'google-123'
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing provider_user_id', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'google'
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid user_id format', () => {
      const invalidData = {
        user_id: 'invalid-uuid',
        provider: 'google',
        provider_user_id: 'google-123'
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty provider', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: '',
        provider_user_id: 'google-123'
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty provider_user_id', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'google',
        provider_user_id: ''
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject provider exceeding max length', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'a'.repeat(81),
        provider_user_id: 'google-123'
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject provider_user_id exceeding max length', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'google',
        provider_user_id: 'a'.repeat(192)
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format for expires_at', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'google',
        provider_user_id: 'google-123',
        expires_at: 'invalid-date'
      };
      const result = createOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateOAuthAccountSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        provider: 'google',
        provider_user_id: 'google-new-123',
        access_token_encrypted: 'new_encrypted_access_token',
        refresh_token_encrypted: 'new_encrypted_refresh_token',
        expires_at: '2027-01-01T00:00:00.000Z'
      };
      const result = updateOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with partial data (provider only)', () => {
      const validData = {
        provider: 'microsoft'
      };
      const result = updateOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with partial data (tokens only)', () => {
      const validData = {
        access_token_encrypted: 'new_access_token',
        refresh_token_encrypted: 'new_refresh_token'
      };
      const result = updateOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const validData = {};
      const result = updateOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null tokens', () => {
      const validData = {
        access_token_encrypted: null,
        refresh_token_encrypted: null,
        expires_at: null
      };
      const result = updateOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim provider whitespace', () => {
      const validData = {
        provider: '  github  '
      };
      const result = updateOAuthAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.provider).toBe('github');
      }
    });

    it('should reject empty provider', () => {
      const invalidData = {
        provider: ''
      };
      const result = updateOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject provider exceeding max length', () => {
      const invalidData = {
        provider: 'a'.repeat(81)
      };
      const result = updateOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid datetime format', () => {
      const invalidData = {
        expires_at: 'not-a-date'
      };
      const result = updateOAuthAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('oauthAccountIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = oauthAccountIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = oauthAccountIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'invalid-uuid-format'
      };
      const result = oauthAccountIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('userIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        userId: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = userIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing userId', () => {
      const invalidData = {};
      const result = userIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        userId: 'invalid-uuid'
      };
      const result = userIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listOAuthAccountsQuerySchema', () => {
    it('should validate with no filters', () => {
      const validData = {};
      const result = listOAuthAccountsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: '1',
        limit: '20'
      };
      const result = listOAuthAccountsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listOAuthAccountsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with user_id filter', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listOAuthAccountsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with provider filter', () => {
      const validData = {
        provider: 'google'
      };
      const result = listOAuthAccountsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters combined', () => {
      const validData = {
        page: '2',
        limit: '15',
        sort_by: 'provider',
        order: 'asc',
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        provider: 'microsoft'
      };
      const result = listOAuthAccountsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid user_id format', () => {
      const invalidData = {
        user_id: 'invalid-uuid'
      };
      const result = listOAuthAccountsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid page', () => {
      const invalidData = {
        page: '-1'
      };
      const result = listOAuthAccountsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid limit', () => {
      const invalidData = {
        limit: '0'
      };
      const result = listOAuthAccountsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
