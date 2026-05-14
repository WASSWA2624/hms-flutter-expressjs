/**
 * Housekeeping schedule controller
 *
 * @module modules/housekeeping-schedule/controllers
 * @description Handles HTTP requests for housekeeping schedule endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const housekeepingScheduleService = require('@services/housekeeping-schedule/housekeeping-schedule.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

const buildRequestContext = (req) => ({
  user_id: req.user?.id,
  tenant_id: req.user?.tenant_id,
  facility_id: req.user?.facility_id,
  ip_address: req.ip,
  user_agent: typeof req.get === 'function' ? req.get('user-agent') : req.headers?.['user-agent']
});

/**
 * List housekeeping schedules with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listHousekeepingSchedules = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, facility_id, room_id, frequency } = req.query;

  const filters = {};
  if (facility_id) filters.facility_id = facility_id;
  if (room_id) filters.room_id = room_id;
  if (frequency) filters.frequency = frequency;

  const result = await housekeepingScheduleService.listHousekeepingSchedules(
    filters,
    page,
    limit,
    sort_by,
    order,
    buildRequestContext(req)
  );

  return sendPaginated(
    res,
    'messages.housekeeping_schedule.list.success',
    result.housekeepingSchedules,
    result.pagination
  );
});

/**
 * Get housekeeping schedule by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getHousekeepingScheduleById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const housekeepingSchedule = await housekeepingScheduleService.getHousekeepingScheduleById(id, buildRequestContext(req));

  return sendSuccess(res, 200, 'messages.housekeeping_schedule.get.success', housekeepingSchedule);
});

/**
 * Create housekeeping schedule
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createHousekeepingSchedule = asyncHandler(async (req, res) => {
  const data = req.body;
  
  const housekeepingSchedule = await housekeepingScheduleService.createHousekeepingSchedule(data, buildRequestContext(req));

  return sendSuccess(res, 201, 'messages.housekeeping_schedule.create.success', housekeepingSchedule);
});

/**
 * Update housekeeping schedule
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateHousekeepingSchedule = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  
  const housekeepingSchedule = await housekeepingScheduleService.updateHousekeepingSchedule(id, data, buildRequestContext(req));

  return sendSuccess(res, 200, 'messages.housekeeping_schedule.update.success', housekeepingSchedule);
});

/**
 * Delete housekeeping schedule
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteHousekeepingSchedule = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  await housekeepingScheduleService.deleteHousekeepingSchedule(id, buildRequestContext(req));

  return sendNoContent(res);
});

module.exports = {
  listHousekeepingSchedules,
  getHousekeepingScheduleById,
  createHousekeepingSchedule,
  updateHousekeepingSchedule,
  deleteHousekeepingSchedule
};
