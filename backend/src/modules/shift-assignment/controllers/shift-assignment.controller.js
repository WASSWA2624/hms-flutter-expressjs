/**
 * Shift assignment controller
 *
 * @module modules/shift-assignment/controllers
 * @description Request handlers for shift assignment endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const shiftAssignmentService = require('@services/shift-assignment/shift-assignment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List shift assignments with pagination
 * GET /api/v1/shift-assignments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listShiftAssignments = asyncHandler(async (req, res) => {
  const {
    shift_id,
    staff_profile_id,
    assigned_at_from,
    assigned_at_to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    shift_id,
    staff_profile_id,
    assigned_at_from,
    assigned_at_to
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await shiftAssignmentService.listShiftAssignments(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.shift_assignment.list.success', result.shiftAssignments, result.pagination);
});

/**
 * Get shift assignment by ID
 * GET /api/v1/shift-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getShiftAssignmentById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const shiftAssignment = await shiftAssignmentService.getShiftAssignmentById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.shift_assignment.get.success', shiftAssignment);
});

/**
 * Create new shift assignment
 * POST /api/v1/shift-assignments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createShiftAssignment = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const shiftAssignment = await shiftAssignmentService.createShiftAssignment(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.shift_assignment.create.success', shiftAssignment);
});

/**
 * Update shift assignment
 * PUT /api/v1/shift-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateShiftAssignment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const shiftAssignment = await shiftAssignmentService.updateShiftAssignment(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.shift_assignment.update.success', shiftAssignment);
});

/**
 * Delete shift assignment (soft delete)
 * DELETE /api/v1/shift-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteShiftAssignment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await shiftAssignmentService.deleteShiftAssignment(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listShiftAssignments,
  getShiftAssignmentById,
  createShiftAssignment,
  updateShiftAssignment,
  deleteShiftAssignment
};
