/**
 * User profile repository tests
 *
 * @module tests/modules/user-profile/repositories
 * @description Tests for user profile repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const userProfileRepository = require('@repositories/user-profile/user-profile.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  user_profile: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('User Profile Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const mockProfile = {
      id: profileId,
      user_id: '550e8400-e29b-41d4-a716-446655440001',
      first_name: 'John',
      last_name: 'Doe',
      gender: 'MALE'
    };

    it('should find user profile by ID', async () => {
      prisma.user_profile.findFirst.mockResolvedValue(mockProfile);

      const result = await userProfileRepository.findById(profileId);

      expect(result).toEqual(mockProfile);
      expect(prisma.user_profile.findFirst).toHaveBeenCalledWith({
        where: { id: profileId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if user profile not found', async () => {
      prisma.user_profile.findFirst.mockResolvedValue(null);

      const result = await userProfileRepository.findById(profileId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted user profiles', async () => {
      prisma.user_profile.findFirst.mockResolvedValue(null);

      await userProfileRepository.findById(profileId);

      expect(prisma.user_profile.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { user: true, addresses: true };
      prisma.user_profile.findFirst.mockResolvedValue(mockProfile);

      await userProfileRepository.findById(profileId, include);

      expect(prisma.user_profile.findFirst).toHaveBeenCalledWith({
        where: { id: profileId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_profile.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(userProfileRepository.findById(profileId)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.findById(profileId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockProfiles = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        first_name: 'John',
        last_name: 'Doe',
        gender: 'MALE'
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440001',
        first_name: 'Jane',
        last_name: 'Smith',
        gender: 'FEMALE'
      }
    ];

    it('should find many user profiles with default params', async () => {
      prisma.user_profile.findMany.mockResolvedValue(mockProfiles);

      const result = await userProfileRepository.findMany();

      expect(result).toEqual(mockProfiles);
      expect(prisma.user_profile.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { user_id: '550e8400-e29b-41d4-a716-446655440002', gender: 'MALE' };
      prisma.user_profile.findMany.mockResolvedValue(mockProfiles);

      await userProfileRepository.findMany(filters);

      expect(prisma.user_profile.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.user_profile.findMany.mockResolvedValue(mockProfiles);

      await userProfileRepository.findMany({}, 20, 10);

      expect(prisma.user_profile.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { last_name: 'asc' };
      prisma.user_profile.findMany.mockResolvedValue(mockProfiles);

      await userProfileRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.user_profile.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy })
      );
    });

    it('should apply include parameter', async () => {
      const include = { user: true, addresses: true };
      prisma.user_profile.findMany.mockResolvedValue(mockProfiles);

      await userProfileRepository.findMany({}, 0, 20, { created_at: 'desc' }, include);

      expect(prisma.user_profile.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ include })
      );
    });

    it('should return empty array if no profiles found', async () => {
      prisma.user_profile.findMany.mockResolvedValue([]);

      const result = await userProfileRepository.findMany();

      expect(result).toEqual([]);
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_profile.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(userProfileRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count user profiles with default filters', async () => {
      prisma.user_profile.count.mockResolvedValue(42);

      const result = await userProfileRepository.count();

      expect(result).toBe(42);
      expect(prisma.user_profile.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count user profiles with filters', async () => {
      const filters = { gender: 'MALE', user_id: '550e8400-e29b-41d4-a716-446655440000' };
      prisma.user_profile.count.mockResolvedValue(10);

      const result = await userProfileRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.user_profile.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should return 0 if no profiles found', async () => {
      prisma.user_profile.count.mockResolvedValue(0);

      const result = await userProfileRepository.count();

      expect(result).toBe(0);
    });

    it('should throw HttpError on database error', async () => {
      prisma.user_profile.count.mockRejectedValue(new Error('DB Error'));

      await expect(userProfileRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const profileData = {
      user_id: '550e8400-e29b-41d4-a716-446655440000',
      first_name: 'John',
      last_name: 'Doe',
      gender: 'MALE'
    };

    const createdProfile = {
      id: '550e8400-e29b-41d4-a716-446655440001',
      ...profileData,
      created_at: new Date(),
      updated_at: new Date()
    };

    it('should create new user profile', async () => {
      prisma.user_profile.create.mockResolvedValue(createdProfile);

      const result = await userProfileRepository.create(profileData);

      expect(result).toEqual(createdProfile);
      expect(prisma.user_profile.create).toHaveBeenCalledWith({ data: profileData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['user_id'] } };
      prisma.user_profile.create.mockRejectedValue(error);

      await expect(userProfileRepository.create(profileData)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.create(profileData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'user_id' } };
      prisma.user_profile.create.mockRejectedValue(error);

      await expect(userProfileRepository.create(profileData)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.create(profileData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.user_profile.create.mockRejectedValue(new Error('DB Error'));

      await expect(userProfileRepository.create(profileData)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.create(profileData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { first_name: 'Jane', gender: 'FEMALE' };
    const updatedProfile = {
      id: profileId,
      user_id: '550e8400-e29b-41d4-a716-446655440001',
      ...updateData,
      last_name: 'Doe',
      updated_at: new Date()
    };

    it('should update user profile', async () => {
      prisma.user_profile.update.mockResolvedValue(updatedProfile);

      const result = await userProfileRepository.update(profileId, updateData);

      expect(result).toEqual(updatedProfile);
      expect(prisma.user_profile.update).toHaveBeenCalledWith({
        where: { id: profileId },
        data: updateData
      });
    });

    it('should throw HttpError if user profile not found', async () => {
      const error = { code: 'P2025' };
      prisma.user_profile.update.mockRejectedValue(error);

      await expect(userProfileRepository.update(profileId, updateData)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.update(profileId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.user_profile.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['user_id'] } };
      prisma.user_profile.update.mockRejectedValue(error);

      await expect(userProfileRepository.update(profileId, updateData)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.update(profileId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'facility_id' } };
      prisma.user_profile.update.mockRejectedValue(error);

      await expect(userProfileRepository.update(profileId, updateData)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.update(profileId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.user_profile.update.mockRejectedValue(new Error('DB Error'));

      await expect(userProfileRepository.update(profileId, updateData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const deletedProfile = {
      id: profileId,
      user_id: '550e8400-e29b-41d4-a716-446655440001',
      first_name: 'John',
      last_name: 'Doe',
      deleted_at: new Date()
    };

    it('should soft delete user profile', async () => {
      prisma.user_profile.update.mockResolvedValue(deletedProfile);

      const result = await userProfileRepository.softDelete(profileId);

      expect(result).toEqual(deletedProfile);
      expect(prisma.user_profile.update).toHaveBeenCalledWith({
        where: { id: profileId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if user profile not found', async () => {
      const error = { code: 'P2025' };
      prisma.user_profile.update.mockRejectedValue(error);

      await expect(userProfileRepository.softDelete(profileId)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.softDelete(profileId)).rejects.toMatchObject({
        messageKey: 'errors.user_profile.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.user_profile.update.mockRejectedValue(new Error('DB Error'));

      await expect(userProfileRepository.softDelete(profileId)).rejects.toThrow(HttpError);
      await expect(userProfileRepository.softDelete(profileId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });
});
