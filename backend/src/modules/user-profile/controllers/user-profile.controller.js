/**
 * User profile controller
 *
 * @module modules/user-profile/controllers
 * @description Request handlers for user profile endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const userProfileService = require('@services/user-profile/user-profile.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List user profiles with pagination
 * GET /api/v1/user-profiles
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listUserProfiles = asyncHandler(async (req, res) => {
  const {
    user_id,
    facility_id,
    gender,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    user_id,
    facility_id,
    gender,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await userProfileService.listUserProfiles(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.user_profile.list.success', result.userProfiles, result.pagination);
});

/**
 * Get user profile by ID
 * GET /api/v1/user-profiles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getUserProfileById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userProfile = await userProfileService.getUserProfileById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_profile.get.success', userProfile);
});

/**
 * Create new user profile
 * POST /api/v1/user-profiles
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createUserProfile = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userProfile = await userProfileService.createUserProfile(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.user_profile.create.success', userProfile);
});

/**
 * Update user profile
 * PUT /api/v1/user-profiles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateUserProfile = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userProfile = await userProfileService.updateUserProfile(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_profile.update.success', userProfile);
});

/**
 * Delete user profile (soft delete)
 * DELETE /api/v1/user-profiles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteUserProfile = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await userProfileService.deleteUserProfile(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listUserProfiles,
  getUserProfileById,
  createUserProfile,
  updateUserProfile,
  deleteUserProfile
};
