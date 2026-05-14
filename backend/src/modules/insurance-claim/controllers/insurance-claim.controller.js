/**
 * Insurance claim controller
 *
 * @module modules/insurance-claim/controllers
 * @description Request handlers for insurance claim endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const insuranceClaimService = require('@services/insurance-claim/insurance-claim.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List insurance claims with pagination
 * GET /api/v1/insurance-claims
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listInsuranceClaims = asyncHandler(async (req, res) => {
  const {
    coverage_plan_id,
    invoice_id,
    status,
    submitted_at_from,
    submitted_at_to,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    coverage_plan_id,
    invoice_id,
    status,
    submitted_at_from,
    submitted_at_to
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await insuranceClaimService.listInsuranceClaims(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.insurance_claim.list.success', result.insurance_claims, result.pagination);
});

/**
 * Get insurance claim by ID
 * GET /api/v1/insurance-claims/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getInsuranceClaimById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insuranceClaim = await insuranceClaimService.getInsuranceClaimById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.insurance_claim.get.success', insuranceClaim);
});

/**
 * Create new insurance claim
 * POST /api/v1/insurance-claims
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createInsuranceClaim = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insuranceClaim = await insuranceClaimService.createInsuranceClaim(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.insurance_claim.create.success', insuranceClaim);
});

/**
 * Update insurance claim
 * PUT /api/v1/insurance-claims/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateInsuranceClaim = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insuranceClaim = await insuranceClaimService.updateInsuranceClaim(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.insurance_claim.update.success', insuranceClaim);
});

/**
 * Delete insurance claim (soft delete)
 * DELETE /api/v1/insurance-claims/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteInsuranceClaim = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await insuranceClaimService.deleteInsuranceClaim(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Submit insurance claim
 * POST /api/v1/insurance-claims/:id/submit
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const submitInsuranceClaim = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insuranceClaim = await insuranceClaimService.submitInsuranceClaim(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.insurance_claim.submit.success', insuranceClaim);
});

/**
 * Reconcile insurance claim
 * POST /api/v1/insurance-claims/:id/reconcile
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const reconcileInsuranceClaim = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insuranceClaim = await insuranceClaimService.reconcileInsuranceClaim(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.insurance_claim.reconcile.success', insuranceClaim);
});

module.exports = {
  listInsuranceClaims,
  getInsuranceClaimById,
  createInsuranceClaim,
  updateInsuranceClaim,
  deleteInsuranceClaim,
  submitInsuranceClaim,
  reconcileInsuranceClaim
};
