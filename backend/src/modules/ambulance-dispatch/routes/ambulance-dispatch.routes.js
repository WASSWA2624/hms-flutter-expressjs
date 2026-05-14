/**
 * Ambulance Dispatch routes
 *
 * @module modules/ambulance-dispatch/routes
 * @description Ambulance Dispatch endpoints mounted at /api/v1/ambulance-dispatches
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const ambulanceDispatchController = require('@controllers/ambulance-dispatch/ambulance-dispatch.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createAmbulanceDispatchSchema,
  updateAmbulanceDispatchSchema,
  ambulanceDispatchIdParamsSchema,
  listAmbulanceDispatchesQuerySchema
} = require('@validations/ambulance-dispatch/ambulance-dispatch.schema');

/**
 * @description List ambulance dispatches with pagination and filters
 * @method GET
 * @route /api/v1/ambulance-dispatches/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [ambulance_id] - Filter by ambulance ID (UUID)
 * @queryParams {string} [emergency_case_id] - Filter by emergency case ID (UUID)
 * @queryParams {string} [status] - Filter by status (AVAILABLE, DISPATCHED, EN_ROUTE, ON_SCENE, TRANSPORTING, OUT_OF_SERVICE)
 * @bodyParams None
 * @returns {Object} Paginated list of ambulance dispatches
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAmbulanceDispatchesQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  ambulanceDispatchController.listAmbulanceDispatches
);

/**
 * @description Get ambulance dispatch by ID
 * @method GET
 * @route /api/v1/ambulance-dispatches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Ambulance Dispatch ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Ambulance Dispatch data
 * @throws 401 Unauthorized
 * @throws 404 Ambulance Dispatch not found
 */
router.get(
  '/:id',  validateRequest({ params: ambulanceDispatchIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  ambulanceDispatchController.getAmbulanceDispatchById
);

/**
 * @description Create new ambulance dispatch
 * @method POST
 * @route /api/v1/ambulance-dispatches/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} ambulance_id - Ambulance ID (required, UUID)
 * @bodyParams {string} emergency_case_id - Emergency Case ID (required, UUID)
 * @bodyParams {string} [dispatched_at] - Dispatched at timestamp (ISO 8601)
 * @bodyParams {string} status - Dispatch status (required, AVAILABLE, DISPATCHED, EN_ROUTE, ON_SCENE, TRANSPORTING, OUT_OF_SERVICE)
 * @returns {Object} Created ambulance dispatch
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAmbulanceDispatchSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  ambulanceDispatchController.createAmbulanceDispatch
);

/**
 * @description Update ambulance dispatch
 * @method PUT
 * @route /api/v1/ambulance-dispatches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Ambulance Dispatch ID (UUID)
 * @queryParams None
 * @bodyParams {string} [ambulance_id] - Ambulance ID (UUID)
 * @bodyParams {string} [emergency_case_id] - Emergency Case ID (UUID)
 * @bodyParams {string} [dispatched_at] - Dispatched at timestamp (ISO 8601)
 * @bodyParams {string} [status] - Dispatch status (AVAILABLE, DISPATCHED, EN_ROUTE, ON_SCENE, TRANSPORTING, OUT_OF_SERVICE)
 * @returns {Object} Updated ambulance dispatch
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Ambulance Dispatch not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: ambulanceDispatchIdParamsSchema, body: updateAmbulanceDispatchSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  ambulanceDispatchController.updateAmbulanceDispatch
);

/**
 * @description Delete ambulance dispatch (soft delete)
 * @method DELETE
 * @route /api/v1/ambulance-dispatches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Ambulance Dispatch ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Ambulance Dispatch not found
 */
router.delete(
  '/:id',  validateRequest({ params: ambulanceDispatchIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_DELETE, 'permission'),
  ambulanceDispatchController.deleteAmbulanceDispatch
);

module.exports = router;

