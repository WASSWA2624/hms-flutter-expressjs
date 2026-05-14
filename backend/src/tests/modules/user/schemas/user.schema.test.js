/**
 * User schema tests
 *
 * @module tests/modules/user/schemas
 * @description Tests for user validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createUserSchema,
  updateUserSchema,
  userIdParamsSchema,
  listUsersQuerySchema
} = require('@validations/user/user.schema');

describe('User Schemas', () => {
  describe('createUserSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      position_title: 'Charge Nurse',
      email: 'test@example.com',
      phone: '+256700000000',
      password_hash: '$2b$10$abcdefghijklmnopqrstuvwxyz',
      status: 'ACTIVE'
    };

    it('should validate correct user data', () => {
      const result = createUserSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require email', () => {
      const data = { ...validData };
      delete data.email;
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require position_title', () => {
      const data = { ...validData };
      delete data.position_title;
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate email format', () => {
      const data = { ...validData, email: 'invalid-email' };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require password_hash', () => {
      const data = { ...validData };
      delete data.password_hash;
      delete data.password;
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept password when password_hash is omitted', () => {
      const data = { ...validData };
      delete data.password_hash;
      data.password = 'StrongPass123!';
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should require status', () => {
      const data = { ...validData };
      delete data.status;
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should validate status enum values', () => {
      const data = { ...validData, status: 'INVALID' };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING'];
      statuses.forEach(status => {
        const data = { ...validData, status };
        const result = createUserSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional phone', () => {
      const data = { ...validData };
      delete data.phone;
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format for tenant_id', () => {
      const data = { ...validData, tenant_id: 'invalid-uuid' };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for facility_id', () => {
      const data = { ...validData, facility_id: 'invalid-uuid' };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from email', () => {
      const data = { ...validData, email: '  test@example.com  ' };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.email).toBe('test@example.com');
      }
    });

    it('should trim whitespace from phone', () => {
      const data = { ...validData, phone: '  +256700000000  ' };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.phone).toBe('+256700000000');
      }
    });

    it('should trim whitespace from position_title', () => {
      const data = { ...validData, position_title: '  Charge Nurse  ' };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.position_title).toBe('Charge Nurse');
      }
    });

    it('should enforce email max length', () => {
      const data = { ...validData, email: 'a'.repeat(250) + '@example.com' };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce phone max length', () => {
      const data = { ...validData, phone: '1'.repeat(41) };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce position_title max length', () => {
      const data = { ...validData, position_title: 'a'.repeat(121) };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce password_hash max length', () => {
      const data = { ...validData, password_hash: 'a'.repeat(256) };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce password min length when provided', () => {
      const data = { ...validData };
      delete data.password_hash;
      data.password = 'short';
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept nullable facility_id', () => {
      const data = { ...validData, facility_id: null };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept nullable phone', () => {
      const data = { ...validData, phone: null };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept multiple permission_ids', () => {
      const data = {
        ...validData,
        permission_ids: [
          '550e8400-e29b-41d4-a716-446655440010',
          '550e8400-e29b-41d4-a716-446655440011',
        ],
      };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should reject invalid permission_ids', () => {
      const data = {
        ...validData,
        permission_ids: ['not-a-uuid'],
      };
      const result = createUserSchema.safeParse(data);
      expect(result.success).toBe(false);
    });
  });

  describe('updateUserSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateUserSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate email format when provided', () => {
      const result = updateUserSchema.safeParse({ email: 'invalid-email' });
      expect(result.success).toBe(false);
    });

    it('should validate status enum when provided', () => {
      const result = updateUserSchema.safeParse({ status: 'INVALID' });
      expect(result.success).toBe(false);
    });

    it('should accept valid status values', () => {
      const statuses = ['ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING'];
      statuses.forEach(status => {
        const result = updateUserSchema.safeParse({ status });
        expect(result.success).toBe(true);
      });
    });

    it('should accept valid facility_id UUID', () => {
      const result = updateUserSchema.safeParse({
        facility_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid facility_id UUID', () => {
      const result = updateUserSchema.safeParse({ facility_id: 'invalid-uuid' });
      expect(result.success).toBe(false);
    });

    it('should accept partial updates', () => {
      const result = updateUserSchema.safeParse({
        email: 'newemail@example.com',
        status: 'INACTIVE'
      });
      expect(result.success).toBe(true);
    });

    it('should trim whitespace from fields', () => {
      const result = updateUserSchema.safeParse({
        position_title: '  Head Nurse  ',
        email: '  test@example.com  ',
        phone: '  +256700000000  '
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.position_title).toBe('Head Nurse');
        expect(result.data.email).toBe('test@example.com');
        expect(result.data.phone).toBe('+256700000000');
      }
    });

    it('should accept nullable fields', () => {
      const result = updateUserSchema.safeParse({
        facility_id: null,
        phone: null
      });
      expect(result.success).toBe(true);
    });

    it('should accept permission_ids on update', () => {
      const result = updateUserSchema.safeParse({
        permission_ids: [
          '550e8400-e29b-41d4-a716-446655440010',
          '550e8400-e29b-41d4-a716-446655440011',
        ],
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid permission_ids on update', () => {
      const result = updateUserSchema.safeParse({
        permission_ids: ['invalid'],
      });
      expect(result.success).toBe(false);
    });
  });

  describe('userIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const result = userIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = userIdParamsSchema.safeParse({ id: 'invalid-uuid' });
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const result = userIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listUsersQuerySchema', () => {
    it('should validate with no query params', () => {
      const result = listUsersQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept valid tenant_id', () => {
      const result = listUsersQuerySchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept valid facility_id', () => {
      const result = listUsersQuerySchema.safeParse({
        facility_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept email filter', () => {
      const result = listUsersQuerySchema.safeParse({
        email: 'test@example.com'
      });
      expect(result.success).toBe(true);
    });

    it('should accept position_title filter', () => {
      const result = listUsersQuerySchema.safeParse({
        position_title: 'Charge Nurse'
      });
      expect(result.success).toBe(true);
    });

    it('should accept status filter', () => {
      const result = listUsersQuerySchema.safeParse({ status: 'ACTIVE' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid status filter', () => {
      const result = listUsersQuerySchema.safeParse({ status: 'INVALID' });
      expect(result.success).toBe(false);
    });

    it('should accept search parameter', () => {
      const result = listUsersQuerySchema.safeParse({ search: 'john' });
      expect(result.success).toBe(true);
    });

    it('should accept pagination params', () => {
      const result = listUsersQuerySchema.safeParse({
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      });
      expect(result.success).toBe(true);
    });

    it('should accept all filters combined', () => {
      const result = listUsersQuerySchema.safeParse({
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        email: 'test@example.com',
        status: 'ACTIVE',
        search: 'john',
        page: '1',
        limit: '20'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for tenant_id', () => {
      const result = listUsersQuerySchema.safeParse({ tenant_id: 'invalid' });
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for facility_id', () => {
      const result = listUsersQuerySchema.safeParse({ facility_id: 'invalid' });
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from search', () => {
      const result = listUsersQuerySchema.safeParse({ search: '  john  ' });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('john');
      }
    });
  });
});
