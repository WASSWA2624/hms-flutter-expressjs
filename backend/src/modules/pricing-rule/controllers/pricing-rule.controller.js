/**
 * Pricing Rule controller
 *
 * @module modules/pricing-rule/controllers
 * @description Request handlers for pricing rule endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const pricingRuleService = require('@services/pricing-rule/pricing-rule.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List pricing rules with pagination
 * GET /api/v1/pricing-rules
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPricingRules = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    currency,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    name,
    currency,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await pricingRuleService.listPricingRules(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.pricing_rule.list.success', result.pricingRules, result.pagination);
});

/**
 * Get pricing rule by ID
 * GET /api/v1/pricing-rules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPricingRuleById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pricingRule = await pricingRuleService.getPricingRuleById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.pricing_rule.get.success', pricingRule);
});

/**
 * Create new pricing rule
 * POST /api/v1/pricing-rules
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPricingRule = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pricingRule = await pricingRuleService.createPricingRule(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.pricing_rule.create.success', pricingRule);
});

/**
 * Update pricing rule
 * PUT /api/v1/pricing-rules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePricingRule = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pricingRule = await pricingRuleService.updatePricingRule(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.pricing_rule.update.success', pricingRule);
});

/**
 * Delete pricing rule (soft delete)
 * DELETE /api/v1/pricing-rules/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePricingRule = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await pricingRuleService.deletePricingRule(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPricingRules,
  getPricingRuleById,
  createPricingRule,
  updatePricingRule,
  deletePricingRule
};
