/**
 * Follow-up controller
 *
 * @module modules/follow-up/controllers
 * @description Request handlers for follow-up endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const followUpService = require('@services/follow-up/follow-up.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List follow-ups with pagination
 * GET /api/v1/follow-ups
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listFollowUps = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    status,
    scheduled_before,
    scheduled_after,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    status,
    scheduled_before,
    scheduled_after,
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await followUpService.listFollowUps(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.follow_up.list.success', result.followUps, result.pagination);
});

/**
 * Get follow-up by ID
 * GET /api/v1/follow-ups/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getFollowUpById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const followUp = await followUpService.getFollowUpById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.follow_up.get.success', followUp);
});

/**
 * Create new follow-up
 * POST /api/v1/follow-ups
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createFollowUp = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const followUp = await followUpService.createFollowUp(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.follow_up.create.success', followUp);
});

/**
 * Update follow-up
 * PUT /api/v1/follow-ups/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateFollowUp = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const followUp = await followUpService.updateFollowUp(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.follow_up.update.success', followUp);
});

/**
 * Delete follow-up (soft delete)
 * DELETE /api/v1/follow-ups/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteFollowUp = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await followUpService.deleteFollowUp(id, userId, ipAddress);

  sendNoContent(res);
});

const completeFollowUp = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const followUp = await followUpService.completeFollowUp(id, req.body, userId, ipAddress);
  sendSuccess(res, 200, 'messages.follow_up.update.success', followUp);
});

const cancelFollowUp = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const followUp = await followUpService.cancelFollowUp(id, req.body, userId, ipAddress);
  sendSuccess(res, 200, 'messages.follow_up.update.success', followUp);
});

const dispatchFollowUpReminders = asyncHandler(async (req, res) => {
  const result = await followUpService.dispatchFollowUpReminders({
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip,
  });
  sendSuccess(res, 200, 'messages.follow_up.reminders.dispatch.success', result);
});

const getFollowUpReminderDueSummary = asyncHandler(async (_req, res) => {
  const result = await followUpService.getFollowUpReminderDueSummary();
  sendSuccess(res, 200, 'messages.follow_up.reminders.summary.success', result);
});

module.exports = {
  listFollowUps,
  getFollowUpById,
  createFollowUp,
  updateFollowUp,
  deleteFollowUp,
  completeFollowUp,
  cancelFollowUp,
  dispatchFollowUpReminders,
  getFollowUpReminderDueSummary,
};
