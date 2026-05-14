/**
 * Terms acceptance routes
 *
 * @module modules/terms-acceptance/routes
 * @description Terms acceptance endpoints mounted at /api/v1/terms-acceptances
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 * Note: Terms acceptance has no PUT endpoint (no updates) per API spec
 */

const express = require('express');
const router = express.Router();
const termsAcceptanceController = require('@controllers/terms-acceptance/terms-acceptance.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createTermsAcceptanceSchema,
  termsAcceptanceIdParamsSchema,
  listTermsAcceptancesQuerySchema
} = require('@validations/terms-acceptance/terms-acceptance.schema');

/**
 * @description List terms acceptances with pagination and filters
 * @method GET
 * @route /api/v1/terms-acceptances/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [user_id] - Filter by user ID (UUID)
 * @queryParams {string} [version_label] - Filter by version label
 * @bodyParams None
 * @returns {Object} Paginated list of terms acceptances
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listTermsAcceptancesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  termsAcceptanceController.listTermsAcceptances
);

/**
 * @description Get terms acceptance by ID
 * @method GET
 * @route /api/v1/terms-acceptances/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Terms acceptance ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Terms acceptance data
 * @throws 401 Unauthorized
 * @throws 404 Terms acceptance not found
 */
router.get(
  '/:id',
  validateRequest({ params: termsAcceptanceIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  termsAcceptanceController.getTermsAcceptanceById
);

/**
 * @description Create new terms acceptance
 * @method POST
 * @route /api/v1/terms-acceptances/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} user_id - User ID (required, UUID)
 * @bodyParams {string} version_label - Version label (required, max 40 chars)
 * @returns {Object} Created terms acceptance
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createTermsAcceptanceSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  termsAcceptanceController.createTermsAcceptance
);

/**
 * @description Delete terms acceptance (soft delete)
 * @method DELETE
 * @route /api/v1/terms-acceptances/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Terms acceptance ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Terms acceptance not found
 */
router.delete(
  '/:id',
  validateRequest({ params: termsAcceptanceIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  termsAcceptanceController.deleteTermsAcceptance
);

module.exports = router;
