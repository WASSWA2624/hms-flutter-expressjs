/**
 * Pricing Rule routes
 *
 * @module modules/pricing-rule/routes
 * @description Pricing Rule endpoints mounted at /api/v1/pricing-rules
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const pricingRuleController = require('@controllers/pricing-rule/pricing-rule.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPricingRuleSchema,
  updatePricingRuleSchema,
  pricingRuleIdParamsSchema,
  listPricingRulesQuerySchema
} = require('@validations/pricing-rule/pricing-rule.schema');

/**
 * @description List pricing rules with pagination and filters
 * @method GET
 * @route /api/v1/pricing-rules/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [name] - Filter by name (partial match)
 * @queryParams {string} [currency] - Filter by currency (3-letter code, uppercase)
 * @queryParams {string} [search] - Search in name and description fields
 * @bodyParams None
 * @returns {Object} Paginated list of pricing rules
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listPricingRulesQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  pricingRuleController.listPricingRules
);

/**
 * @description Get pricing rule by ID
 * @method GET
 * @route /api/v1/pricing-rules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pricing Rule ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Pricing rule data
 * @throws 401 Unauthorized
 * @throws 404 Pricing rule not found
 */
router.get(
  '/:id',  validateRequest({ params: pricingRuleIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  pricingRuleController.getPricingRuleById
);

/**
 * @description Create new pricing rule
 * @method POST
 * @route /api/v1/pricing-rules/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} name - Rule name (required, max 255 chars)
 * @bodyParams {string} [description] - Rule description (optional)
 * @bodyParams {number} amount - Amount value (required, min 0)
 * @bodyParams {string} currency - Currency code (required, 3 uppercase letters)
 * @bodyParams {string} [effective_from] - Effective from date (ISO 8601 datetime)
 * @bodyParams {string} [effective_to] - Effective to date (ISO 8601 datetime)
 * @returns {Object} Created pricing rule
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createPricingRuleSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  pricingRuleController.createPricingRule
);

/**
 * @description Update pricing rule
 * @method PUT
 * @route /api/v1/pricing-rules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pricing Rule ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Rule name (max 255 chars)
 * @bodyParams {string} [description] - Rule description
 * @bodyParams {number} [amount] - Amount value (min 0)
 * @bodyParams {string} [currency] - Currency code (3 uppercase letters)
 * @bodyParams {string} [effective_from] - Effective from date (ISO 8601 datetime)
 * @bodyParams {string} [effective_to] - Effective to date (ISO 8601 datetime)
 * @returns {Object} Updated pricing rule
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Pricing rule not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: pricingRuleIdParamsSchema, body: updatePricingRuleSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  pricingRuleController.updatePricingRule
);

/**
 * @description Delete pricing rule (soft delete)
 * @method DELETE
 * @route /api/v1/pricing-rules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pricing Rule ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Pricing rule not found
 */
router.delete(
  '/:id',  validateRequest({ params: pricingRuleIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  pricingRuleController.deletePricingRule
);

module.exports = router;
