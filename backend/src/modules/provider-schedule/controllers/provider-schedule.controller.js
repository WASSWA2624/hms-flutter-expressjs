/**
 * Provider schedule controller
 *
 * @module modules/provider-schedule/controllers
 * @description Request handlers for provider schedule endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const providerScheduleService = require('@services/provider-schedule/provider-schedule.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List provider schedules with pagination
 * GET /api/v1/provider-schedules
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listProviderSchedules = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    provider_user_id,
    schedule_type,
    day_of_week,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    provider_user_id,
    schedule_type,
    day_of_week
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await providerScheduleService.listProviderSchedules(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.provider_schedule.list.success', result.schedules, result.pagination);
});

/**
 * Get provider schedule by ID
 * GET /api/v1/provider-schedules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getProviderScheduleById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const schedule = await providerScheduleService.getProviderScheduleById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.provider_schedule.get.success', schedule);
});

/**
 * Create new provider schedule
 * POST /api/v1/provider-schedules
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createProviderSchedule = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const schedule = await providerScheduleService.createProviderSchedule(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.provider_schedule.create.success', schedule);
});

/**
 * Update provider schedule
 * PUT /api/v1/provider-schedules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateProviderSchedule = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const schedule = await providerScheduleService.updateProviderSchedule(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.provider_schedule.update.success', schedule);
});

/**
 * Delete provider schedule (soft delete)
 * DELETE /api/v1/provider-schedules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteProviderSchedule = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await providerScheduleService.deleteProviderSchedule(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listProviderSchedules,
  getProviderScheduleById,
  createProviderSchedule,
  updateProviderSchedule,
  deleteProviderSchedule
};
