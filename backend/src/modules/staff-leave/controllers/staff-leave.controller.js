/**
 * Staff leave controller
 *
 * @module modules/staff-leave/controllers
 * @description Request handlers for staff leave endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const staffLeaveService = require('@services/staff-leave/staff-leave.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List staff leaves with pagination
 * GET /api/v1/staff-leaves
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listStaffLeaves = asyncHandler(async (req, res) => {
  const {
    staff_profile_id,
    status,
    leave_type,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    staff_profile_id,
    status,
    leave_type
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await staffLeaveService.listStaffLeaves(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.staff_leave.list.success', result.staffLeaves, result.pagination);
});

/**
 * Get staff leave by ID
 * GET /api/v1/staff-leaves/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getStaffLeaveById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffLeave = await staffLeaveService.getStaffLeaveById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.staff_leave.get.success', staffLeave);
});

/**
 * Create new staff leave
 * POST /api/v1/staff-leaves
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createStaffLeave = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffLeave = await staffLeaveService.createStaffLeave(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.staff_leave.create.success', staffLeave);
});

/**
 * List the authenticated user's own leave requests.
 * GET /api/v1/staff-leaves/me
 */
const listMyStaffLeaves = asyncHandler(async (req, res) => {
  const {
    status,
    leave_type,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const result = await staffLeaveService.listMyStaffLeaves(
    req.user?.id,
    { status, leave_type },
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order
  );

  sendPaginated(res, 'messages.staff_leave.list.success', result.staffLeaves, result.pagination);
});

/**
 * Create a leave request for the authenticated user's staff profile.
 * POST /api/v1/staff-leaves/me
 */
const createMyStaffLeave = asyncHandler(async (req, res) => {
  const staffLeave = await staffLeaveService.createMyStaffLeave(
    req.body,
    req.user?.id,
    req.ip
  );

  sendSuccess(res, 201, 'messages.staff_leave.create.success', staffLeave);
});

/**
 * Update staff leave
 * PUT /api/v1/staff-leaves/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateStaffLeave = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffLeave = await staffLeaveService.updateStaffLeave(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.staff_leave.update.success', staffLeave);
});

/**
 * Delete staff leave (soft delete)
 * DELETE /api/v1/staff-leaves/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteStaffLeave = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await staffLeaveService.deleteStaffLeave(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listStaffLeaves,
  listMyStaffLeaves,
  getStaffLeaveById,
  createStaffLeave,
  createMyStaffLeave,
  updateStaffLeave,
  deleteStaffLeave
};
