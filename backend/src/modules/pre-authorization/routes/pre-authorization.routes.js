/**
 * Pre-authorization routes
 *
 * @module modules/pre-authorization/routes
 * @description Pre-authorization endpoints mounted at /api/v1/pre-authorizations
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const preAuthorizationController = require('@controllers/pre-authorization/pre-authorization.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPreAuthorizationSchema,
  updatePreAuthorizationSchema,
  preAuthorizationIdParamsSchema,
  listPreAuthorizationsQuerySchema
} = require('@validations/pre-authorization/pre-authorization.schema');

/**
 * @description List pre-authorizations with pagination and filters
 * @method GET
 * @route /api/v1/pre-authorizations/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [coverage_plan_id] - Filter by coverage plan ID (UUID)
 * @queryParams {string} [status] - Filter by status (PENDING/APPROVED/DENIED/EXPIRED)
 * @queryParams {string} [requested_at_from] - Filter by requested date from (ISO 8601 datetime)
 * @queryParams {string} [requested_at_to] - Filter by requested date to (ISO 8601 datetime)
 * @queryParams {string} [approved_at_from] - Filter by approved date from (ISO 8601 datetime)
 * @queryParams {string} [approved_at_to] - Filter by approved date to (ISO 8601 datetime)
 * @bodyParams None
 * @returns {Object} Paginated list of pre-authorizations
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listPreAuthorizationsQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  preAuthorizationController.listPreAuthorizations
);

/**
 * @description Get pre-authorization by ID
 * @method GET
 * @route /api/v1/pre-authorizations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pre-authorization ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Pre-authorization data
 * @throws 401 Unauthorized
 * @throws 404 Pre-authorization not found
 */
router.get(
  '/:id',  validateRequest({ params: preAuthorizationIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  preAuthorizationController.getPreAuthorizationById
);

/**
 * @description Create new pre-authorization
 * @method POST
 * @route /api/v1/pre-authorizations/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} coverage_plan_id - Coverage plan ID (required, UUID)
 * @bodyParams {string} [status=PENDING] - Authorization status (PENDING/APPROVED/DENIED/EXPIRED)
 * @bodyParams {string} [requested_at] - Request date/time (ISO 8601 datetime)
 * @bodyParams {string} [approved_at] - Approval date/time (ISO 8601 datetime)
 * @returns {Object} Created pre-authorization
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createPreAuthorizationSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  preAuthorizationController.createPreAuthorization
);

/**
 * @description Update pre-authorization
 * @method PUT
 * @route /api/v1/pre-authorizations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pre-authorization ID (UUID)
 * @queryParams None
 * @bodyParams {string} [coverage_plan_id] - Coverage plan ID (UUID)
 * @bodyParams {string} [status] - Authorization status (PENDING/APPROVED/DENIED/EXPIRED)
 * @bodyParams {string} [requested_at] - Request date/time (ISO 8601 datetime)
 * @bodyParams {string} [approved_at] - Approval date/time (ISO 8601 datetime)
 * @returns {Object} Updated pre-authorization
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Pre-authorization not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: preAuthorizationIdParamsSchema, body: updatePreAuthorizationSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  preAuthorizationController.updatePreAuthorization
);

/**
 * @description Delete pre-authorization (soft delete)
 * @method DELETE
 * @route /api/v1/pre-authorizations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pre-authorization ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Pre-authorization not found
 */
router.delete(
  '/:id',  validateRequest({ params: preAuthorizationIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  preAuthorizationController.deletePreAuthorization
);

module.exports = router;
