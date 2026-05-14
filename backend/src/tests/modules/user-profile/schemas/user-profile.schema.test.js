/**
 * User profile schema tests
 *
 * @module tests/modules/user-profile/schemas
 * @description Tests for user profile validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createUserProfileSchema,
  updateUserProfileSchema,
  userProfileIdParamsSchema,
  listUserProfilesQuerySchema
} = require('@validations/user-profile/user-profile.schema');

describe('User Profile Schemas', () => {
  describe('createUserProfileSchema', () => {
    const validData = {
      user_id: '550e8400-e29b-41d4-a716-446655440000',
      facility_id: '550e8400-e29b-41d4-a716-446655440001',
      first_name: 'John',
      last_name: 'Doe',
      gender: 'MALE',
      date_of_birth: '1990-01-01T00:00:00.000Z'
    };

    it('should validate correct user profile data', () => {
      const result = createUserProfileSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require user_id', () => {
      const data = { ...validData };
      delete data.user_id;
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require first_name', () => {
      const data = { ...validData };
      delete data.first_name;
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional last_name', () => {
      const data = { ...validData };
      delete data.last_name;
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional middle_name', () => {
      const data = { ...validData };
      data.middle_name = 'Middle';
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable middle_name', () => {
      const data = { ...validData, middle_name: null };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow nullable last_name', () => {
      const data = { ...validData, last_name: null };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional facility_id', () => {
      const data = { ...validData };
      delete data.facility_id;
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional gender', () => {
      const data = { ...validData };
      delete data.gender;
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional date_of_birth', () => {
      const data = { ...validData };
      delete data.date_of_birth;
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate gender enum values', () => {
      const data = { ...validData, gender: 'INVALID' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid gender values', () => {
      const genders = ['MALE', 'FEMALE', 'OTHER', 'UNKNOWN'];
      genders.forEach(gender => {
        const data = { ...validData, gender };
        const result = createUserProfileSchema.safeParse(data);
        expect(result.success).toBe(true);
      });
    });

    it('should reject invalid UUID format for user_id', () => {
      const data = { ...validData, user_id: 'invalid-uuid' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID format for facility_id', () => {
      const data = { ...validData, facility_id: 'invalid-uuid' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from first_name', () => {
      const data = { ...validData, first_name: '  John  ' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.first_name).toBe('John');
      }
    });

    it('should trim whitespace from last_name', () => {
      const data = { ...validData, last_name: '  Doe  ' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.last_name).toBe('Doe');
      }
    });

    it('should enforce first_name max length', () => {
      const data = { ...validData, first_name: 'a'.repeat(121) };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce last_name max length', () => {
      const data = { ...validData, last_name: 'a'.repeat(121) };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce first_name min length', () => {
      const data = { ...validData, first_name: '' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce last_name min length when provided', () => {
      const data = { ...validData, last_name: '' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce middle_name min length when provided', () => {
      const data = { ...validData, middle_name: '' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should enforce middle_name max length', () => {
      const data = { ...validData, middle_name: 'a'.repeat(121) };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept nullable facility_id', () => {
      const data = { ...validData, facility_id: null };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept nullable gender', () => {
      const data = { ...validData, gender: null };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should accept nullable date_of_birth', () => {
      const data = { ...validData, date_of_birth: null };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should validate date_of_birth format', () => {
      const data = { ...validData, date_of_birth: 'invalid-date' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should accept valid ISO datetime for date_of_birth', () => {
      const data = { ...validData, date_of_birth: '2000-12-31T23:59:59.999Z' };
      const result = createUserProfileSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updateUserProfileSchema', () => {
    it('should allow all fields to be optional', () => {
      const result = updateUserProfileSchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should validate gender enum when provided', () => {
      const result = updateUserProfileSchema.safeParse({ gender: 'INVALID' });
      expect(result.success).toBe(false);
    });

    it('should accept valid gender values', () => {
      const genders = ['MALE', 'FEMALE', 'OTHER', 'UNKNOWN'];
      genders.forEach(gender => {
        const result = updateUserProfileSchema.safeParse({ gender });
        expect(result.success).toBe(true);
      });
    });

    it('should accept valid facility_id UUID', () => {
      const result = updateUserProfileSchema.safeParse({
        facility_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid facility_id UUID', () => {
      const result = updateUserProfileSchema.safeParse({ facility_id: 'invalid-uuid' });
      expect(result.success).toBe(false);
    });

    it('should accept partial updates', () => {
      const result = updateUserProfileSchema.safeParse({
        first_name: 'Jane',
        gender: 'FEMALE'
      });
      expect(result.success).toBe(true);
    });

    it('should trim whitespace from fields', () => {
      const result = updateUserProfileSchema.safeParse({
        first_name: '  Jane  ',
        last_name: '  Smith  '
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.first_name).toBe('Jane');
        expect(result.data.last_name).toBe('Smith');
      }
    });

    it('should accept nullable fields', () => {
      const result = updateUserProfileSchema.safeParse({
        facility_id: null,
        middle_name: null,
        last_name: null,
        gender: null,
        date_of_birth: null
      });
      expect(result.success).toBe(true);
    });

    it('should validate date_of_birth format when provided', () => {
      const result = updateUserProfileSchema.safeParse({ date_of_birth: 'invalid-date' });
      expect(result.success).toBe(false);
    });

    it('should enforce max length constraints', () => {
      const result = updateUserProfileSchema.safeParse({
        first_name: 'a'.repeat(121)
      });
      expect(result.success).toBe(false);
    });

    it('should enforce min length constraints', () => {
      const result = updateUserProfileSchema.safeParse({
        first_name: ''
      });
      expect(result.success).toBe(false);
    });
  });

  describe('userProfileIdParamsSchema', () => {
    it('should validate correct UUID', () => {
      const result = userProfileIdParamsSchema.safeParse({
        id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const result = userProfileIdParamsSchema.safeParse({ id: 'invalid-uuid' });
      expect(result.success).toBe(false);
    });

    it('should require id field', () => {
      const result = userProfileIdParamsSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('listUserProfilesQuerySchema', () => {
    it('should validate with no query params', () => {
      const result = listUserProfilesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it('should accept valid user_id', () => {
      const result = listUserProfilesQuerySchema.safeParse({
        user_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept valid facility_id', () => {
      const result = listUserProfilesQuerySchema.safeParse({
        facility_id: '550e8400-e29b-41d4-a716-446655440000'
      });
      expect(result.success).toBe(true);
    });

    it('should accept gender filter', () => {
      const result = listUserProfilesQuerySchema.safeParse({ gender: 'MALE' });
      expect(result.success).toBe(true);
    });

    it('should reject invalid gender filter', () => {
      const result = listUserProfilesQuerySchema.safeParse({ gender: 'INVALID' });
      expect(result.success).toBe(false);
    });

    it('should accept search parameter', () => {
      const result = listUserProfilesQuerySchema.safeParse({ search: 'john' });
      expect(result.success).toBe(true);
    });

    it('should accept pagination params', () => {
      const result = listUserProfilesQuerySchema.safeParse({
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      });
      expect(result.success).toBe(true);
    });

    it('should accept all filters combined', () => {
      const result = listUserProfilesQuerySchema.safeParse({
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        gender: 'MALE',
        search: 'john',
        page: '1',
        limit: '20'
      });
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID for user_id', () => {
      const result = listUserProfilesQuerySchema.safeParse({ user_id: 'invalid' });
      expect(result.success).toBe(false);
    });

    it('should reject invalid UUID for facility_id', () => {
      const result = listUserProfilesQuerySchema.safeParse({ facility_id: 'invalid' });
      expect(result.success).toBe(false);
    });

    it('should trim whitespace from search', () => {
      const result = listUserProfilesQuerySchema.safeParse({ search: '  john  ' });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('john');
      }
    });
  });
});
