/**
 * Ward Round routes
 *
 * @module modules/ward-round/routes
 * @description Ward round endpoints mounted at /api/v1/ward-rounds
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const wardRoundController = require('@controllers/ward-round/ward-round.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createWardRoundSchema,
  updateWardRoundSchema,
  wardRoundIdParamsSchema,
  listWardRoundsQuerySchema
} = require('@validations/ward-round/ward-round.schema');

const IPD_READ_SCOPES = [PERMISSIONS.CLINICAL_READ];
const IPD_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];
const IPD_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List ward rounds with pagination and filters
 * @method GET
 * @route /api/v1/ward-rounds/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [admission_id] - Filter by admission ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of ward rounds
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listWardRoundsQuerySchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  wardRoundController.listWardRounds
);

/**
 * @description Get ward round by ID
 * @method GET
 * @route /api/v1/ward-rounds/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Ward Round ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Ward round data
 * @throws 401 Unauthorized
 * @throws 404 Ward round not found
 */
router.get(
  '/:id',  validateRequest({ params: wardRoundIdParamsSchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  wardRoundController.getWardRoundById
);

/**
 * @description Create new ward round
 * @method POST
 * @route /api/v1/ward-rounds/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} admission_id - Admission ID (required, UUID)
 * @bodyParams {string} [round_at] - Round timestamp (ISO 8601 datetime)
 * @bodyParams {string} [notes] - Ward round notes (text)
 * @returns {Object} Created ward round
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createWardRoundSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  wardRoundController.createWardRound
);

/**
 * @description Update ward round
 * @method PUT
 * @route /api/v1/ward-rounds/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Ward Round ID (UUID)
 * @queryParams None
 * @bodyParams {string} [round_at] - Round timestamp (ISO 8601 datetime)
 * @bodyParams {string} [notes] - Ward round notes (text)
 * @returns {Object} Updated ward round
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Ward round not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: wardRoundIdParamsSchema, body: updateWardRoundSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  wardRoundController.updateWardRound
);

/**
 * @description Delete ward round (soft delete)
 * @method DELETE
 * @route /api/v1/ward-rounds/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Ward Round ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Ward round not found
 */
router.delete(
  '/:id',  validateRequest({ params: wardRoundIdParamsSchema }),

  authenticate(),
  authorize(IPD_ADMIN_SCOPES, 'permission'),
  wardRoundController.deleteWardRound
);

module.exports = router;
