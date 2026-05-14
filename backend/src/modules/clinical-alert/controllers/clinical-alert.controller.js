/**
 * Clinical Alert controller
 *
 * @module modules/clinical-alert/controllers
 * @description Request handlers for clinical alert endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const clinicalAlertService = require('@services/clinical-alert/clinical-alert.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List clinical alerts with pagination
 * GET /api/v1/clinical-alerts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listClinicalAlerts = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    severity,
    status,
    source,
    vital_sign_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    severity,
    status,
    source,
    vital_sign_id,
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await clinicalAlertService.listClinicalAlerts(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.clinical_alert.list.success', result.clinicalAlerts, result.pagination);
});

/**
 * Get clinical alert by ID
 * GET /api/v1/clinical-alerts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getClinicalAlertById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const clinicalAlert = await clinicalAlertService.getClinicalAlertById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.clinical_alert.get.success', clinicalAlert);
});

/**
 * Create new clinical alert
 * POST /api/v1/clinical-alerts
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createClinicalAlert = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const clinicalAlert = await clinicalAlertService.createClinicalAlert(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.clinical_alert.create.success', clinicalAlert);
});

/**
 * Update clinical alert
 * PUT /api/v1/clinical-alerts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateClinicalAlert = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const clinicalAlert = await clinicalAlertService.updateClinicalAlert(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.clinical_alert.update.success', clinicalAlert);
});

/**
 * Delete clinical alert (soft delete)
 * DELETE /api/v1/clinical-alerts/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteClinicalAlert = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await clinicalAlertService.deleteClinicalAlert(id, userId, ipAddress);

  sendNoContent(res);
});

const acknowledgeClinicalAlert = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const clinicalAlert = await clinicalAlertService.acknowledgeClinicalAlert(
    id,
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.clinical_alert.update.success', clinicalAlert);
});

const resolveClinicalAlert = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const clinicalAlert = await clinicalAlertService.resolveClinicalAlert(
    id,
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.clinical_alert.update.success', clinicalAlert);
});

module.exports = {
  listClinicalAlerts,
  getClinicalAlertById,
  createClinicalAlert,
  updateClinicalAlert,
  deleteClinicalAlert,
  acknowledgeClinicalAlert,
  resolveClinicalAlert,
};
