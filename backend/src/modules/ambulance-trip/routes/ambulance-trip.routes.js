/**
 * Ambulance Trip routes
 *
 * @module modules/ambulance-trip/routes
 * @description Ambulance Trip endpoints mounted at /api/v1/ambulance-trips
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const ambulanceTripController = require('@controllers/ambulance-trip/ambulance-trip.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createAmbulanceTripSchema,
  updateAmbulanceTripSchema,
  ambulanceTripIdParamsSchema,
  listAmbulanceTripsQuerySchema
} = require('@validations/ambulance-trip/ambulance-trip.schema');

/**
 * @description List ambulance trips with pagination and filters
 * @method GET
 * @route /api/v1/ambulance-trips/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [ambulance_id] - Filter by ambulance ID (UUID)
 * @queryParams {string} [emergency_case_id] - Filter by emergency case ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of ambulance trips
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAmbulanceTripsQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  ambulanceTripController.listAmbulanceTrips
);

/**
 * @description Get ambulance trip by ID
 * @method GET
 * @route /api/v1/ambulance-trips/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Ambulance Trip ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Ambulance Trip data
 * @throws 401 Unauthorized
 * @throws 404 Ambulance Trip not found
 */
router.get(
  '/:id',  validateRequest({ params: ambulanceTripIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_READ, 'permission'),
  ambulanceTripController.getAmbulanceTripById
);

/**
 * @description Create new ambulance trip
 * @method POST
 * @route /api/v1/ambulance-trips/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} ambulance_id - Ambulance ID (required, UUID)
 * @bodyParams {string} emergency_case_id - Emergency Case ID (required, UUID)
 * @bodyParams {string} [started_at] - Started at timestamp (ISO 8601)
 * @bodyParams {string} [ended_at] - Ended at timestamp (ISO 8601)
 * @returns {Object} Created ambulance trip
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAmbulanceTripSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  ambulanceTripController.createAmbulanceTrip
);

/**
 * @description Update ambulance trip
 * @method PUT
 * @route /api/v1/ambulance-trips/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Ambulance Trip ID (UUID)
 * @queryParams None
 * @bodyParams {string} [ambulance_id] - Ambulance ID (UUID)
 * @bodyParams {string} [emergency_case_id] - Emergency Case ID (UUID)
 * @bodyParams {string} [started_at] - Started at timestamp (ISO 8601)
 * @bodyParams {string} [ended_at] - Ended at timestamp (ISO 8601)
 * @returns {Object} Updated ambulance trip
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Ambulance Trip not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: ambulanceTripIdParamsSchema, body: updateAmbulanceTripSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_WRITE, 'permission'),
  ambulanceTripController.updateAmbulanceTrip
);

/**
 * @description Delete ambulance trip (soft delete)
 * @method DELETE
 * @route /api/v1/ambulance-trips/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Ambulance Trip ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Ambulance Trip not found
 */
router.delete(
  '/:id',  validateRequest({ params: ambulanceTripIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.EMERGENCY_DELETE, 'permission'),
  ambulanceTripController.deleteAmbulanceTrip
);

module.exports = router;

