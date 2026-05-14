/**
 * Consent controller
 *
 * @module modules/consent/controllers
 * @description Request handlers for consent endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const consentService = require('@services/consent/consent.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List consents with pagination
 * GET /api/v1/consents
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listConsents = asyncHandler(async (req, res) => {
  const {
    patient_id,
    consent_type,
    status,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    patient_id,
    consent_type,
    status
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await consentService.listConsents(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.consent.list.success', result.consents, result.pagination);
});

/**
 * Get consent by ID
 * GET /api/v1/consents/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getConsentById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const consent = await consentService.getConsentById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.consent.get.success', consent);
});

/**
 * Create new consent
 * POST /api/v1/consents
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createConsent = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  // Add tenant_id from authenticated user context
  const data = {
    ...req.body,
    tenant_id: req.user?.tenant_id
  };

  const consent = await consentService.createConsent(data, userId, ipAddress);

  sendSuccess(res, 201, 'messages.consent.create.success', consent);
});

/**
 * Update consent
 * PUT /api/v1/consents/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateConsent = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const consent = await consentService.updateConsent(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.consent.update.success', consent);
});

/**
 * Delete consent (soft delete)
 * DELETE /api/v1/consents/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteConsent = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await consentService.deleteConsent(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listConsents,
  getConsentById,
  createConsent,
  updateConsent,
  deleteConsent
};
