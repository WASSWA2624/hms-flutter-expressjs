/**
 * Staff assignment controller
 *
 * @module modules/staff-assignment/controllers
 * @description Request handlers for staff assignment endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const staffAssignmentService = require('@services/staff-assignment/staff-assignment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List staff assignments with pagination
 * GET /api/v1/staff-assignments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listStaffAssignments = asyncHandler(async (req, res) => {
  const {
    staff_profile_id,
    department_id,
    unit_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    staff_profile_id,
    department_id,
    unit_id
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await staffAssignmentService.listStaffAssignments(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.staff_assignment.list.success', result.staffAssignments, result.pagination);
});

/**
 * Get staff assignment by ID
 * GET /api/v1/staff-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getStaffAssignmentById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffAssignment = await staffAssignmentService.getStaffAssignmentById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.staff_assignment.get.success', staffAssignment);
});

/**
 * Create new staff assignment
 * POST /api/v1/staff-assignments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createStaffAssignment = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffAssignment = await staffAssignmentService.createStaffAssignment(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.staff_assignment.create.success', staffAssignment);
});

/**
 * Update staff assignment
 * PUT /api/v1/staff-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateStaffAssignment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffAssignment = await staffAssignmentService.updateStaffAssignment(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.staff_assignment.update.success', staffAssignment);
});

/**
 * Delete staff assignment (soft delete)
 * DELETE /api/v1/staff-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteStaffAssignment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await staffAssignmentService.deleteStaffAssignment(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listStaffAssignments,
  getStaffAssignmentById,
  createStaffAssignment,
  updateStaffAssignment,
  deleteStaffAssignment
};
