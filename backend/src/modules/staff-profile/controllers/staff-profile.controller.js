/**
 * Staff profile controller
 *
 * @module modules/staff-profile/controllers
 * @description Request handlers for staff profile endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const staffProfileService = require('@services/staff-profile/staff-profile.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List staff profiles with pagination
 * GET /api/v1/staff-profiles
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listStaffProfiles = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    user_id,
    department_id,
    staff_number,
    position,
    practitioner_type,
    is_fee_overridden,
    has_consultation_fee,
    hired_from,
    hired_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    user_id,
    department_id,
    staff_number,
    position,
    practitioner_type,
    is_fee_overridden,
    has_consultation_fee,
    hired_from,
    hired_to,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await staffProfileService.listStaffProfiles(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.staff_profile.list.success', result.staffProfiles, result.pagination);
});

/**
 * Get staff profile by ID
 * GET /api/v1/staff-profiles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getStaffProfileById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffProfile = await staffProfileService.getStaffProfileById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.staff_profile.get.success', staffProfile);
});

/**
 * Create new staff profile
 * POST /api/v1/staff-profiles
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createStaffProfile = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffProfile = await staffProfileService.createStaffProfile(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.staff_profile.create.success', staffProfile);
});

/**
 * Update staff profile
 * PUT /api/v1/staff-profiles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateStaffProfile = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffProfile = await staffProfileService.updateStaffProfile(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.staff_profile.update.success', staffProfile);
});

/**
 * Delete staff profile (soft delete)
 * DELETE /api/v1/staff-profiles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteStaffProfile = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await staffProfileService.deleteStaffProfile(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listStaffProfiles,
  getStaffProfileById,
  createStaffProfile,
  updateStaffProfile,
  deleteStaffProfile
};
