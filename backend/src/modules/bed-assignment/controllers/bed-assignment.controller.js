/**
 * Bed Assignment controller
 *
 * @module modules/bed-assignment/controllers
 * @description Request handlers for bed assignment endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const bedAssignmentService = require('@services/bed-assignment/bed-assignment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List bed assignments with pagination
 * GET /api/v1/bed-assignments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listBedAssignments = asyncHandler(async (req, res) => {
  const {
    admission_id,
    bed_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    admission_id,
    bed_id
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await bedAssignmentService.listBedAssignments(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.bed_assignment.list.success', result.bedAssignments, result.pagination);
});

/**
 * Get bed assignment by ID
 * GET /api/v1/bed-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getBedAssignmentById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const bedAssignment = await bedAssignmentService.getBedAssignmentById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.bed_assignment.get.success', bedAssignment);
});

/**
 * Create new bed assignment
 * POST /api/v1/bed-assignments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createBedAssignment = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const bedAssignment = await bedAssignmentService.createBedAssignment(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.bed_assignment.create.success', bedAssignment);
});

/**
 * Update bed assignment
 * PUT /api/v1/bed-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateBedAssignment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const bedAssignment = await bedAssignmentService.updateBedAssignment(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.bed_assignment.update.success', bedAssignment);
});

/**
 * Delete bed assignment (soft delete)
 * DELETE /api/v1/bed-assignments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteBedAssignment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await bedAssignmentService.deleteBedAssignment(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listBedAssignments,
  getBedAssignmentById,
  createBedAssignment,
  updateBedAssignment,
  deleteBedAssignment
};
