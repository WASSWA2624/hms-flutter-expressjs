/**
 * Housekeeping task controller
 *
 * @module modules/housekeeping-task/controllers
 * @description Handles HTTP requests for housekeeping task endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const housekeepingTaskService = require('@services/housekeeping-task/housekeeping-task.service');
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
 * List housekeeping tasks with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listHousekeepingTasks = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, facility_id, room_id, assigned_to_staff_id, status } = req.query;

  const filters = {};
  if (facility_id) filters.facility_id = facility_id;
  if (room_id) filters.room_id = room_id;
  if (assigned_to_staff_id) filters.assigned_to_staff_id = assigned_to_staff_id;
  if (status) filters.status = status;

  const result = await housekeepingTaskService.listHousekeepingTasks(
    filters,
    page,
    limit,
    sort_by,
    order,
    buildRequestContext(req)
  );

  return sendPaginated(
    res,
    'messages.housekeeping_task.list.success',
    result.housekeepingTasks,
    result.pagination
  );
});

/**
 * Get housekeeping task by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getHousekeepingTaskById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const housekeepingTask = await housekeepingTaskService.getHousekeepingTaskById(id, buildRequestContext(req));

  return sendSuccess(res, 200, 'messages.housekeeping_task.get.success', housekeepingTask);
});

/**
 * Create housekeeping task
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createHousekeepingTask = asyncHandler(async (req, res) => {
  const data = req.body;
  
  const housekeepingTask = await housekeepingTaskService.createHousekeepingTask(data, buildRequestContext(req));

  return sendSuccess(res, 201, 'messages.housekeeping_task.create.success', housekeepingTask);
});

/**
 * Update housekeeping task
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateHousekeepingTask = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  
  const housekeepingTask = await housekeepingTaskService.updateHousekeepingTask(id, data, buildRequestContext(req));

  return sendSuccess(res, 200, 'messages.housekeeping_task.update.success', housekeepingTask);
});

/**
 * Delete housekeeping task
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteHousekeepingTask = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  await housekeepingTaskService.deleteHousekeepingTask(id, buildRequestContext(req));

  return sendNoContent(res);
});

module.exports = {
  listHousekeepingTasks,
  getHousekeepingTaskById,
  createHousekeepingTask,
  updateHousekeepingTask,
  deleteHousekeepingTask
};
