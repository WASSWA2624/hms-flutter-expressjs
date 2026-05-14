/**
 * ICU Observation routes
 *
 * @module modules/icu-observation/routes
 * @description ICU observation endpoints mounted at /api/v1/icu-observations
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const icuObservationController = require('@controllers/icu-observation/icu-observation.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createIcuObservationSchema,
  updateIcuObservationSchema,
  icuObservationIdParamsSchema,
  listIcuObservationsQuerySchema
} = require('@validations/icu-observation/icu-observation.schema');

const ICU_ALLOWED_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

/**
 * @description List ICU observations with pagination and filters
 * @method GET
 * @route /api/v1/icu-observations/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [icu_stay_id] - Filter by ICU stay ID (UUID)
 * @queryParams {string} [observed_at_from] - Filter by observed_at from date (ISO 8601)
 * @queryParams {string} [observed_at_to] - Filter by observed_at to date (ISO 8601)
 * @queryParams {string} [search] - Search in observation text
 * @bodyParams None
 * @returns {Object} Paginated list of ICU observations
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listIcuObservationsQuerySchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuObservationController.listIcuObservations
);

/**
 * @description Get ICU observation by ID
 * @method GET
 * @route /api/v1/icu-observations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - ICU Observation ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} ICU observation data
 * @throws 401 Unauthorized
 * @throws 404 ICU observation not found
 */
router.get(
  '/:id',  validateRequest({ params: icuObservationIdParamsSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuObservationController.getIcuObservationById
);

/**
 * @description Create new ICU observation
 * @method POST
 * @route /api/v1/icu-observations/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} icu_stay_id - ICU Stay ID (required, UUID)
 * @bodyParams {string} [observed_at] - Observed at timestamp (ISO 8601 datetime)
 * @bodyParams {string} observation - Observation text (required, max 5000 chars)
 * @returns {Object} Created ICU observation
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createIcuObservationSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuObservationController.createIcuObservation
);

/**
 * @description Update ICU observation
 * @method PUT
 * @route /api/v1/icu-observations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - ICU Observation ID (UUID)
 * @queryParams None
 * @bodyParams {string} [observed_at] - Observed at timestamp (ISO 8601 datetime)
 * @bodyParams {string} [observation] - Observation text (max 5000 chars)
 * @returns {Object} Updated ICU observation
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 ICU observation not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: icuObservationIdParamsSchema, body: updateIcuObservationSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuObservationController.updateIcuObservation
);

/**
 * @description Delete ICU observation (soft delete)
 * @method DELETE
 * @route /api/v1/icu-observations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - ICU Observation ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 ICU observation not found
 */
router.delete(
  '/:id',  validateRequest({ params: icuObservationIdParamsSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuObservationController.deleteIcuObservation
);

module.exports = router;
