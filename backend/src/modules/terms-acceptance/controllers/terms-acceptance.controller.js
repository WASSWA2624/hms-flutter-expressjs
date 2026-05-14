/**
 * Terms acceptance controller
 *
 * @module modules/terms-acceptance/controllers
 * @description Request handlers for terms acceptance endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 * Note: Terms acceptance has no update endpoint per API spec
 */

const termsAcceptanceService = require('@services/terms-acceptance/terms-acceptance.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List terms acceptances with pagination
 * GET /api/v1/terms-acceptances
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listTermsAcceptances = asyncHandler(async (req, res) => {
  const {
    user_id,
    version_label,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    user_id,
    version_label
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await termsAcceptanceService.listTermsAcceptances(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.terms_acceptance.list.success', result.termsAcceptances, result.pagination);
});

/**
 * Get terms acceptance by ID
 * GET /api/v1/terms-acceptances/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getTermsAcceptanceById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const termsAcceptance = await termsAcceptanceService.getTermsAcceptanceById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.terms_acceptance.get.success', termsAcceptance);
});

/**
 * Create new terms acceptance
 * POST /api/v1/terms-acceptances
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createTermsAcceptance = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  // Add tenant_id from authenticated user context
  const data = {
    ...req.body,
    tenant_id: req.user?.tenant_id
  };

  const termsAcceptance = await termsAcceptanceService.createTermsAcceptance(data, userId, ipAddress);

  sendSuccess(res, 201, 'messages.terms_acceptance.create.success', termsAcceptance);
});

/**
 * Delete terms acceptance (soft delete)
 * DELETE /api/v1/terms-acceptances/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteTermsAcceptance = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await termsAcceptanceService.deleteTermsAcceptance(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listTermsAcceptances,
  getTermsAcceptanceById,
  createTermsAcceptance,
  deleteTermsAcceptance
};
