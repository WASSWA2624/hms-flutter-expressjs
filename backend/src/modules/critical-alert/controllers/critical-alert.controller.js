/**
 * Critical Alert controller
 *
 * @module modules/critical-alert/controllers
 * @description Request handlers for critical alert endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const criticalAlertService = require('@services/critical-alert/critical-alert.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List critical alerts with pagination
 * GET /api/v1/critical-alerts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listCriticalAlerts = asyncHandler(async (req, res) => {
  const {
    icu_stay_id,
    severity,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    icu_stay_id,
    severity,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await criticalAlertService.listCriticalAlerts(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.critical_alert.list.success', result.critical_alerts, result.pagination);
});

/**
 * Get critical alert by ID
 * GET /api/v1/critical-alerts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getCriticalAlertById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const criticalAlert = await criticalAlertService.getCriticalAlertById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.critical_alert.get.success', criticalAlert);
});

/**
 * Create new critical alert
 * POST /api/v1/critical-alerts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createCriticalAlert = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const criticalAlert = await criticalAlertService.createCriticalAlert(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.critical_alert.create.success', criticalAlert);
});

/**
 * Update critical alert
 * PUT /api/v1/critical-alerts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateCriticalAlert = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const criticalAlert = await criticalAlertService.updateCriticalAlert(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.critical_alert.update.success', criticalAlert);
});

/**
 * Delete critical alert (soft delete)
 * DELETE /api/v1/critical-alerts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteCriticalAlert = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await criticalAlertService.deleteCriticalAlert(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listCriticalAlerts,
  getCriticalAlertById,
  createCriticalAlert,
  updateCriticalAlert,
  deleteCriticalAlert
};
