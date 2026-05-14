/**
 * Ambulance routes
 *
 * @module modules/ambulance/routes
 * @description Ambulance endpoints mounted at /api/v1/ambulances
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const ambulanceController = require('@controllers/ambulance/ambulance.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createAmbulanceSchema,
  updateAmbulanceSchema,
  ambulanceIdParamsSchema,
  listAmbulancesQuerySchema
} = require('@validations/ambulance/ambulance.schema');

/**
 * @description List ambulances with pagination and filters
 * @method GET
 * @route /api/v1/ambulances/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [status] - Filter by status (AVAILABLE, DISPATCHED, EN_ROUTE, ON_SCENE, TRANSPORTING, OUT_OF_SERVICE)
 * @queryParams {string} [search] - Search by identifier
 * @bodyParams None
 * @returns {Object} Paginated list of ambulances
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAmbulancesQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  ambulanceController.listAmbulances
);

/**
 * @description Get ambulance by ID
 * @method GET
 * @route /api/v1/ambulances/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Ambulance ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Ambulance data
 * @throws 401 Unauthorized
 * @throws 404 Ambulance not found
 */
router.get(
  '/:id',  validateRequest({ params: ambulanceIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  ambulanceController.getAmbulanceById
);

/**
 * @description Create new ambulance
 * @method POST
 * @route /api/v1/ambulances/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} identifier - Ambulance identifier (required, max 120 chars)
 * @bodyParams {string} status - Ambulance status (required, AVAILABLE, DISPATCHED, EN_ROUTE, ON_SCENE, TRANSPORTING, OUT_OF_SERVICE)
 * @returns {Object} Created ambulance
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAmbulanceSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  ambulanceController.createAmbulance
);

/**
 * @description Update ambulance
 * @method PUT
 * @route /api/v1/ambulances/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Ambulance ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [identifier] - Ambulance identifier (max 120 chars)
 * @bodyParams {string} [status] - Ambulance status (AVAILABLE, DISPATCHED, EN_ROUTE, ON_SCENE, TRANSPORTING, OUT_OF_SERVICE)
 * @returns {Object} Updated ambulance
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Ambulance not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: ambulanceIdParamsSchema, body: updateAmbulanceSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  ambulanceController.updateAmbulance
);

/**
 * @description Delete ambulance (soft delete)
 * @method DELETE
 * @route /api/v1/ambulances/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Ambulance ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Ambulance not found
 */
router.delete(
  '/:id',  validateRequest({ params: ambulanceIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_DELETE, 'permission'),
  ambulanceController.deleteAmbulance
);

module.exports = router;

