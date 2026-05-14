/**
 * Staff position controller
 *
 * @module modules/staff-position/controllers
 * @description Request handlers for staff position endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const staffPositionService = require('@services/staff-position/staff-position.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List staff positions with pagination
 * GET /api/v1/staff-positions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listStaffPositions = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    department_id,
    name,
    is_active,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    department_id,
    name,
    is_active,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await staffPositionService.listStaffPositions(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.staff_position.list.success', result.staffPositions, result.pagination);
});

/**
 * Get staff position by ID
 * GET /api/v1/staff-positions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getStaffPositionById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffPosition = await staffPositionService.getStaffPositionById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.staff_position.get.success', staffPosition);
});

/**
 * Create new staff position
 * POST /api/v1/staff-positions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createStaffPosition = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffPosition = await staffPositionService.createStaffPosition(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.staff_position.create.success', staffPosition);
});

/**
 * Update staff position
 * PUT /api/v1/staff-positions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateStaffPosition = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const staffPosition = await staffPositionService.updateStaffPosition(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.staff_position.update.success', staffPosition);
});

/**
 * Delete staff position (soft delete)
 * DELETE /api/v1/staff-positions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteStaffPosition = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await staffPositionService.deleteStaffPosition(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listStaffPositions,
  getStaffPositionById,
  createStaffPosition,
  updateStaffPosition,
  deleteStaffPosition
};
