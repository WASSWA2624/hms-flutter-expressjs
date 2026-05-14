/**
 * Shift controller
 *
 * @module modules/shift/controllers
 * @description Request handlers for shift endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const shiftService = require('@services/shift/shift.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List shifts with pagination
 * GET /api/v1/shifts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listShifts = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    shift_type,
    status,
    start_time_from,
    start_time_to,
    end_time_from,
    end_time_to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    shift_type,
    status,
    start_time_from,
    start_time_to,
    end_time_from,
    end_time_to
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await shiftService.listShifts(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.shift.list.success', result.shifts, result.pagination);
});

/**
 * Get shift by ID
 * GET /api/v1/shifts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getShiftById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const shift = await shiftService.getShiftById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.shift.get.success', shift);
});

/**
 * Create new shift
 * POST /api/v1/shifts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createShift = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const shift = await shiftService.createShift(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.shift.create.success', shift);
});

/**
 * Update shift
 * PUT /api/v1/shifts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateShift = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const shift = await shiftService.updateShift(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.shift.update.success', shift);
});

/**
 * Delete shift (soft delete)
 * DELETE /api/v1/shifts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteShift = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await shiftService.deleteShift(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Publish shift
 * POST /api/v1/shifts/:id/publish
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const publishShift = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { notify_staff = true } = req.body;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const shift = await shiftService.publishShift(id, notify_staff, userId, ipAddress);

  sendSuccess(res, 200, 'messages.shift.publish.success', shift);
});

module.exports = {
  listShifts,
  getShiftById,
  createShift,
  updateShift,
  deleteShift,
  publishShift
};
