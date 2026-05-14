/**
 * User profile service tests
 *
 * @module tests/modules/user-profile/services
 * @description Tests for user profile service
 * Per testing.mdc: Mock repository, test business logic
 */

const userProfileService = require('@services/user-profile/user-profile.service');
const userProfileRepository = require('@repositories/user-profile/user-profile.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/user-profile/user-profile.repository');
jest.mock('@lib/audit');

describe('User Profile Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listUserProfiles', () => {
    const mockProfiles = [
      { id: '1', first_name: 'John', last_name: 'Doe', gender: 'MALE' },
      { id: '2', first_name: 'Jane', last_name: 'Smith', gender: 'FEMALE' }
    ];

    it('should list user profiles with pagination', async () => {
      userProfileRepository.findMany.mockResolvedValue(mockProfiles);
      userProfileRepository.count.mockResolvedValue(2);

      const result = await userProfileService.listUserProfiles({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('userProfiles', mockProfiles);
      expect(result).toHaveProperty('pagination');
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply search filter with OR clause', async () => {
      const filters = { search: 'john' };
      userProfileRepository.findMany.mockResolvedValue(mockProfiles);
      userProfileRepository.count.mockResolvedValue(2);

      await userProfileService.listUserProfiles(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(userProfileRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            { first_name: { contains: 'john' } },
            { last_name: { contains: 'john' } }
          ])
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle repository errors', async () => {
      userProfileRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        userProfileService.listUserProfiles({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getUserProfileById', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const mockProfile = { id: profileId, first_name: 'John', last_name: 'Doe' };

    it('should get user profile by ID', async () => {
      userProfileRepository.findById.mockResolvedValue(mockProfile);

      const result = await userProfileService.getUserProfileById(profileId, 'requester-id', '127.0.0.1');

      expect(result).toEqual(mockProfile);
    });

    it('should throw HttpError if user profile not found', async () => {
      userProfileRepository.findById.mockResolvedValue(null);

      await expect(
        userProfileService.getUserProfileById(profileId, 'requester-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.user_profile.not_found',
        statusCode: 404
      });
    });
  });

  describe('createUserProfile', () => {
    const profileData = {
      user_id: '550e8400-e29b-41d4-a716-446655440000',
      first_name: 'John',
      last_name: 'Doe',
      gender: 'MALE'
    };

    const createdProfile = { id: '550e8400-e29b-41d4-a716-446655440001', ...profileData };

    it('should create new user profile', async () => {
      userProfileRepository.create.mockResolvedValue(createdProfile);
      createAuditLog.mockResolvedValue(true);

      const result = await userProfileService.createUserProfile(profileData, 'creator-id', '127.0.0.1');

      expect(result).toEqual(createdProfile);
    });

    it('should create audit log for user profile creation', async () => {
      userProfileRepository.create.mockResolvedValue(createdProfile);
      createAuditLog.mockResolvedValue(true);

      await userProfileService.createUserProfile(profileData, 'creator-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'creator-id',
        action: 'CREATE',
        entity: 'user_profile',
        entity_id: createdProfile.id,
        diff: { after: createdProfile },
        ip_address: '127.0.0.1'
      });
    });
  });

  describe('updateUserProfile', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { first_name: 'Jane', gender: 'FEMALE' };
    const beforeProfile = { id: profileId, first_name: 'John', gender: 'MALE' };
    const afterProfile = { id: profileId, first_name: 'Jane', gender: 'FEMALE' };

    it('should update user profile', async () => {
      userProfileRepository.findById.mockResolvedValue(beforeProfile);
      userProfileRepository.update.mockResolvedValue(afterProfile);
      createAuditLog.mockResolvedValue(true);

      const result = await userProfileService.updateUserProfile(profileId, updateData, 'updater-id', '127.0.0.1');

      expect(result).toEqual(afterProfile);
    });

    it('should throw HttpError if user profile not found', async () => {
      userProfileRepository.findById.mockResolvedValue(null);

      await expect(
        userProfileService.updateUserProfile(profileId, updateData, 'updater-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.user_profile.not_found',
        statusCode: 404
      });
    });
  });

  describe('deleteUserProfile', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const mockProfile = { id: profileId, first_name: 'John', last_name: 'Doe' };

    it('should soft delete user profile', async () => {
      userProfileRepository.findById.mockResolvedValue(mockProfile);
      userProfileRepository.softDelete.mockResolvedValue({ ...mockProfile, deleted_at: new Date() });
      createAuditLog.mockResolvedValue(true);

      await userProfileService.deleteUserProfile(profileId, 'deleter-id', '127.0.0.1');

      expect(userProfileRepository.softDelete).toHaveBeenCalledWith(profileId);
    });

    it('should throw HttpError if user profile not found', async () => {
      userProfileRepository.findById.mockResolvedValue(null);

      await expect(
        userProfileService.deleteUserProfile(profileId, 'deleter-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.user_profile.not_found',
        statusCode: 404
      });
    });
  });
});
