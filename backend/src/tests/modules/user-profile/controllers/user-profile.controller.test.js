/**
 * User profile controller tests
 *
 * @module tests/modules/user-profile/controllers
 * @description Tests for user profile controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const userProfileController = require('@controllers/user-profile/user-profile.controller');
const userProfileService = require('@services/user-profile/user-profile.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/user-profile/user-profile.service');
jest.mock('@lib/response');

describe('User Profile Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listUserProfiles', () => {
    const mockResult = {
      userProfiles: [
        { id: '1', first_name: 'John', last_name: 'Doe' },
        { id: '2', first_name: 'Jane', last_name: 'Smith' }
      ],
      pagination: {
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      }
    };

    it('should list user profiles with default pagination', async () => {
      userProfileService.listUserProfiles.mockResolvedValue(mockResult);

      await userProfileController.listUserProfiles(req, res);

      expect(userProfileService.listUserProfiles).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.user_profile.list.success',
        mockResult.userProfiles,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        gender: 'MALE',
        search: 'john'
      };
      userProfileService.listUserProfiles.mockResolvedValue(mockResult);

      await userProfileController.listUserProfiles(req, res);

      expect(userProfileService.listUserProfiles).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: '550e8400-e29b-41d4-a716-446655440000',
          gender: 'MALE',
          search: 'john'
        }),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });
  });

  describe('getUserProfileById', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const mockProfile = { id: profileId, first_name: 'John', last_name: 'Doe' };

    it('should get user profile by ID', async () => {
      req.params = { id: profileId };
      userProfileService.getUserProfileById.mockResolvedValue(mockProfile);

      await userProfileController.getUserProfileById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.user_profile.get.success',
        mockProfile
      );
    });
  });

  describe('createUserProfile', () => {
    const profileData = {
      user_id: '550e8400-e29b-41d4-a716-446655440000',
      first_name: 'John',
      last_name: 'Doe'
    };

    const createdProfile = { id: '550e8400-e29b-41d4-a716-446655440001', ...profileData };

    it('should create new user profile', async () => {
      req.body = profileData;
      userProfileService.createUserProfile.mockResolvedValue(createdProfile);

      await userProfileController.createUserProfile(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.user_profile.create.success',
        createdProfile
      );
    });
  });

  describe('updateUserProfile', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { first_name: 'Jane' };
    const updatedProfile = { id: profileId, ...updateData };

    it('should update user profile', async () => {
      req.params = { id: profileId };
      req.body = updateData;
      userProfileService.updateUserProfile.mockResolvedValue(updatedProfile);

      await userProfileController.updateUserProfile(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.user_profile.update.success',
        updatedProfile
      );
    });
  });

  describe('deleteUserProfile', () => {
    const profileId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete user profile', async () => {
      req.params = { id: profileId };
      userProfileService.deleteUserProfile.mockResolvedValue(undefined);

      await userProfileController.deleteUserProfile(req, res);

      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
