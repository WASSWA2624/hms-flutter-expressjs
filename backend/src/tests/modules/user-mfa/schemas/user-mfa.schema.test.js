/**
 * User MFA schema validation tests
 *
 * @module tests/modules/user-mfa/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createUserMfaSchema,
  updateUserMfaSchema,
  verifyMfaCodeSchema,
  userMfaIdParamsSchema,
  listUserMfasQuerySchema
} = require('@validations/user-mfa/user-mfa.schema');

describe('User MFA Schema Validation', () => {
  describe('createUserMfaSchema', () => {
    it('should validate correct user MFA data', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_string_here',
        is_enabled: true
      };
      const result = createUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (user_id, channel, and secret_encrypted only)', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'EMAIL',
        secret_encrypted: 'encrypted_secret_string'
      };
      const result = createUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate all communication channels', () => {
      const channels = ['EMAIL', 'SMS', 'PUSH', 'WHATSAPP', 'IN_APP'];
      channels.forEach(channel => {
        const validData = {
          user_id: '123e4567-e89b-12d3-a456-426614174000',
          channel: channel,
          secret_encrypted: 'encrypted_secret_string'
        };
        const result = createUserMfaSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    it('should trim secret_encrypted whitespace', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'SMS',
        secret_encrypted: '  encrypted_secret_string  '
      };
      const result = createUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.secret_encrypted).toBe('encrypted_secret_string');
      }
    });

    it('should reject missing user_id', () => {
      const invalidData = {
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_string'
      };
      const result = createUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing channel', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        secret_encrypted: 'encrypted_secret_string'
      };
      const result = createUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing secret_encrypted', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'SMS'
      };
      const result = createUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid user_id format', () => {
      const invalidData = {
        user_id: 'invalid-uuid',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_string'
      };
      const result = createUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid channel', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'INVALID_CHANNEL',
        secret_encrypted: 'encrypted_secret_string'
      };
      const result = createUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty secret_encrypted', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'SMS',
        secret_encrypted: ''
      };
      const result = createUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject secret_encrypted exceeding max length', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'SMS',
        secret_encrypted: 'a'.repeat(256)
      };
      const result = createUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_enabled type', () => {
      const invalidData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'SMS',
        secret_encrypted: 'encrypted_secret_string',
        is_enabled: 'yes'
      };
      const result = createUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateUserMfaSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        channel: 'EMAIL',
        secret_encrypted: 'new_encrypted_secret',
        is_enabled: false
      };
      const result = updateUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with partial data (channel only)', () => {
      const validData = {
        channel: 'PUSH'
      };
      const result = updateUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with partial data (secret_encrypted only)', () => {
      const validData = {
        secret_encrypted: 'new_encrypted_secret'
      };
      const result = updateUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with partial data (is_enabled only)', () => {
      const validData = {
        is_enabled: false
      };
      const result = updateUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object', () => {
      const validData = {};
      const result = updateUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim secret_encrypted whitespace', () => {
      const validData = {
        secret_encrypted: '  new_encrypted_secret  '
      };
      const result = updateUserMfaSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.secret_encrypted).toBe('new_encrypted_secret');
      }
    });

    it('should reject invalid channel', () => {
      const invalidData = {
        channel: 'INVALID_CHANNEL'
      };
      const result = updateUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty secret_encrypted', () => {
      const invalidData = {
        secret_encrypted: ''
      };
      const result = updateUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject secret_encrypted exceeding max length', () => {
      const invalidData = {
        secret_encrypted: 'a'.repeat(256)
      };
      const result = updateUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_enabled type', () => {
      const invalidData = {
        is_enabled: 'no'
      };
      const result = updateUserMfaSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('verifyMfaCodeSchema', () => {
    it('should validate correct 6-digit code', () => {
      const validData = {
        code: '123456'
      };
      const result = verifyMfaCodeSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate correct 10-digit code', () => {
      const validData = {
        code: '1234567890'
      };
      const result = verifyMfaCodeSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim code whitespace', () => {
      const validData = {
        code: '  123456  '
      };
      const result = verifyMfaCodeSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.code).toBe('123456');
      }
    });

    it('should reject missing code', () => {
      const invalidData = {};
      const result = verifyMfaCodeSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject code shorter than 6 characters', () => {
      const invalidData = {
        code: '12345'
      };
      const result = verifyMfaCodeSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject code longer than 10 characters', () => {
      const invalidData = {
        code: '12345678901'
      };
      const result = verifyMfaCodeSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty code', () => {
      const invalidData = {
        code: ''
      };
      const result = verifyMfaCodeSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('userMfaIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = userMfaIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = userMfaIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'invalid-uuid-format'
      };
      const result = userMfaIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject non-string id', () => {
      const invalidData = {
        id: 12345
      };
      const result = userMfaIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listUserMfasQuerySchema', () => {
    it('should validate with no filters', () => {
      const validData = {};
      const result = listUserMfasQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: '1',
        limit: '20'
      };
      const result = listUserMfasQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listUserMfasQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with user_id filter', () => {
      const validData = {
        user_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listUserMfasQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with channel filter', () => {
      const validData = {
        channel: 'SMS'
      };
      const result = listUserMfasQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_enabled filter (true)', () => {
      const validData = {
        is_enabled: 'true'
      };
      const result = listUserMfasQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with is_enabled filter (false)', () => {
      const validData = {
        is_enabled: 'false'
      };
      const result = listUserMfasQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters combined', () => {
      const validData = {
        page: '2',
        limit: '15',
        sort_by: 'channel',
        order: 'asc',
        user_id: '123e4567-e89b-12d3-a456-426614174000',
        channel: 'EMAIL',
        is_enabled: 'true'
      };
      const result = listUserMfasQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid user_id format', () => {
      const invalidData = {
        user_id: 'invalid-uuid'
      };
      const result = listUserMfasQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid channel', () => {
      const invalidData = {
        channel: 'INVALID_CHANNEL'
      };
      const result = listUserMfasQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid is_enabled value', () => {
      const invalidData = {
        is_enabled: 'yes'
      };
      const result = listUserMfasQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid page', () => {
      const invalidData = {
        page: '-1'
      };
      const result = listUserMfasQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid limit', () => {
      const invalidData = {
        limit: '0'
      };
      const result = listUserMfasQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listUserMfasQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
});
