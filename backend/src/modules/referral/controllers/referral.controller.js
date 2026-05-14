/**
 * Referral controller
 *
 * @module modules/referral/controllers
 * @description Request handlers for referral endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const referralService = require('@services/referral/referral.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List referrals with pagination
 * GET /api/v1/referrals
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listReferrals = asyncHandler(async (req, res) => {
  const {
    encounter_id,
    from_department_id,
    to_department_id,
    external_facility_name,
    referral_reason_code,
    status,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    encounter_id,
    from_department_id,
    to_department_id,
    external_facility_name,
    referral_reason_code,
    status
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await referralService.listReferrals(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.referral.list.success', result.referrals, result.pagination);
});

/**
 * Get referral by ID
 * GET /api/v1/referrals/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getReferralById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const referral = await referralService.getReferralById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.referral.get.success', referral);
});

/**
 * Create new referral
 * POST /api/v1/referrals
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createReferral = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const referral = await referralService.createReferral(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.referral.create.success', referral);
});

/**
 * Update referral
 * PUT /api/v1/referrals/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateReferral = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const referral = await referralService.updateReferral(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.referral.update.success', referral);
});

/**
 * Delete referral (soft delete)
 * DELETE /api/v1/referrals/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteReferral = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await referralService.deleteReferral(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Redeem referral
 * POST /api/v1/referrals/:id/redeem
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const redeemReferral = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const referral = await referralService.redeemReferral(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.referral.redeem.success', referral);
});

/**
 * Approve referral
 * POST /api/v1/referrals/:id/approve
 */
const approveReferral = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const referral = await referralService.approveReferral(id, req.body, userId, ipAddress);
  sendSuccess(res, 200, 'messages.referral.update.success', referral);
});

/**
 * Start referral transfer
 * POST /api/v1/referrals/:id/start
 */
const startReferral = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const referral = await referralService.startReferral(id, req.body, userId, ipAddress);
  sendSuccess(res, 200, 'messages.referral.update.success', referral);
});

/**
 * Cancel referral
 * POST /api/v1/referrals/:id/cancel
 */
const cancelReferral = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const referral = await referralService.cancelReferral(id, req.body, userId, ipAddress);
  sendSuccess(res, 200, 'messages.referral.update.success', referral);
});

module.exports = {
  listReferrals,
  getReferralById,
  createReferral,
  updateReferral,
  deleteReferral,
  redeemReferral,
  approveReferral,
  startReferral,
  cancelReferral,
};
