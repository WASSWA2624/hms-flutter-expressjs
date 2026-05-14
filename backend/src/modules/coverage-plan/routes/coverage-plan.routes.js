/**
 * Coverage Plan routes
 *
 * @module modules/coverage-plan/routes
 * @description Coverage Plan endpoints mounted at /api/v1/coverage-plans
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const coveragePlanController = require('@controllers/coverage-plan/coverage-plan.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createCoveragePlanSchema,
  updateCoveragePlanSchema,
  coveragePlanIdParamsSchema,
  listCoveragePlansQuerySchema
} = require('@validations/coverage-plan/coverage-plan.schema');

/**
 * @description List coverage plans with pagination and filters
 * @method GET
 * @route /api/v1/coverage-plans/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [name] - Filter by name (partial match)
 * @queryParams {string} [provider_name] - Filter by provider name (partial match)
 * @queryParams {string} [search] - Search in name and provider_name fields
 * @bodyParams None
 * @returns {Object} Paginated list of coverage plans
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listCoveragePlansQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  coveragePlanController.listCoveragePlans
);

/**
 * @description Get coverage plan by ID
 * @method GET
 * @route /api/v1/coverage-plans/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Coverage Plan ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Coverage plan data
 * @throws 401 Unauthorized
 * @throws 404 Coverage plan not found
 */
router.get(
  '/:id',  validateRequest({ params: coveragePlanIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  coveragePlanController.getCoveragePlanById
);

/**
 * @description Create new coverage plan
 * @method POST
 * @route /api/v1/coverage-plans/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} name - Plan name (required, max 255 chars)
 * @bodyParams {string} [provider_name] - Insurance provider name (optional, max 255 chars)
 * @bodyParams {number} [coverage_percentage] - Coverage percentage (optional, 0-100)
 * @returns {Object} Created coverage plan
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createCoveragePlanSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  coveragePlanController.createCoveragePlan
);

/**
 * @description Update coverage plan
 * @method PUT
 * @route /api/v1/coverage-plans/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Coverage Plan ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Plan name (max 255 chars)
 * @bodyParams {string} [provider_name] - Insurance provider name (max 255 chars)
 * @bodyParams {number} [coverage_percentage] - Coverage percentage (0-100)
 * @returns {Object} Updated coverage plan
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Coverage plan not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: coveragePlanIdParamsSchema, body: updateCoveragePlanSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  coveragePlanController.updateCoveragePlan
);

/**
 * @description Delete coverage plan (soft delete)
 * @method DELETE
 * @route /api/v1/coverage-plans/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Coverage Plan ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Coverage plan not found
 */
router.delete(
  '/:id',  validateRequest({ params: coveragePlanIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  coveragePlanController.deleteCoveragePlan
);

module.exports = router;
