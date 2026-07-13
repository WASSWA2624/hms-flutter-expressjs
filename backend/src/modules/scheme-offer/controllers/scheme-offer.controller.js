/**
 * Scheme Offer controller
 *
 * @module modules/scheme-offer/controllers
 * @description Request handlers for scheme offer endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const schemeOfferService = require('@services/scheme-offer/scheme-offer.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List scheme offers with pagination
 * GET /api/v1/scheme-offers
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listSchemeOffers = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    coverage_plan_id,
    catalog_type,
    catalog_item_id,
    billing_entity,
    is_excluded,
    requires_pre_auth,
    is_active,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    coverage_plan_id,
    catalog_type,
    catalog_item_id,
    billing_entity,
    is_excluded,
    requires_pre_auth,
    is_active,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await schemeOfferService.listSchemeOffers(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.scheme_offer.list.success', result.schemeOffers, result.pagination);
});

/**
 * Get scheme offer by ID
 * GET /api/v1/scheme-offers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getSchemeOfferById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const schemeOffer = await schemeOfferService.getSchemeOfferById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.scheme_offer.get.success', schemeOffer);
});

/**
 * Create new scheme offer
 * POST /api/v1/scheme-offers
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createSchemeOffer = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const schemeOffer = await schemeOfferService.createSchemeOffer(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.scheme_offer.create.success', schemeOffer);
});

/**
 * Update scheme offer
 * PUT /api/v1/scheme-offers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateSchemeOffer = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const schemeOffer = await schemeOfferService.updateSchemeOffer(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.scheme_offer.update.success', schemeOffer);
});

/**
 * Delete scheme offer (soft delete)
 * DELETE /api/v1/scheme-offers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteSchemeOffer = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await schemeOfferService.deleteSchemeOffer(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listSchemeOffers,
  getSchemeOfferById,
  createSchemeOffer,
  updateSchemeOffer,
  deleteSchemeOffer
};
