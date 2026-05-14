/**
 * ICU Stay routes
 *
 * @module modules/icu-stay/routes
 * @description ICU stay endpoints mounted at /api/v1/icu-stays
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const icuStayController = require('@controllers/icu-stay/icu-stay.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createIcuStaySchema,
  updateIcuStaySchema,
  icuStayIdParamsSchema,
  listIcuStaysQuerySchema
} = require('@validations/icu-stay/icu-stay.schema');

const ICU_ALLOWED_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

/**
 * @description List ICU stays with pagination and filters
 * @method GET
 * @route /api/v1/icu-stays/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [admission_id] - Filter by admission ID (UUID)
 * @queryParams {string} [started_at_from] - Filter by started_at from date (ISO 8601)
 * @queryParams {string} [started_at_to] - Filter by started_at to date (ISO 8601)
 * @queryParams {string} [ended_at_from] - Filter by ended_at from date (ISO 8601)
 * @queryParams {string} [ended_at_to] - Filter by ended_at to date (ISO 8601)
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @bodyParams None
 * @returns {Object} Paginated list of ICU stays
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listIcuStaysQuerySchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuStayController.listIcuStays
);

/**
 * @description Get ICU stay by ID
 * @method GET
 * @route /api/v1/icu-stays/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - ICU Stay ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} ICU stay data
 * @throws 401 Unauthorized
 * @throws 404 ICU stay not found
 */
router.get(
  '/:id',  validateRequest({ params: icuStayIdParamsSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuStayController.getIcuStayById
);

/**
 * @description Create new ICU stay
 * @method POST
 * @route /api/v1/icu-stays/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} admission_id - Admission ID (required, UUID)
 * @bodyParams {string} [started_at] - Started at timestamp (ISO 8601 datetime)
 * @bodyParams {string} [ended_at] - Ended at timestamp (ISO 8601 datetime)
 * @returns {Object} Created ICU stay
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createIcuStaySchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuStayController.createIcuStay
);

/**
 * @description Update ICU stay
 * @method PUT
 * @route /api/v1/icu-stays/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - ICU Stay ID (UUID)
 * @queryParams None
 * @bodyParams {string} [started_at] - Started at timestamp (ISO 8601 datetime)
 * @bodyParams {string} [ended_at] - Ended at timestamp (ISO 8601 datetime)
 * @returns {Object} Updated ICU stay
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 ICU stay not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: icuStayIdParamsSchema, body: updateIcuStaySchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuStayController.updateIcuStay
);

/**
 * @description Delete ICU stay (soft delete)
 * @method DELETE
 * @route /api/v1/icu-stays/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - ICU Stay ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 ICU stay not found
 */
router.delete(
  '/:id',  validateRequest({ params: icuStayIdParamsSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  icuStayController.deleteIcuStay
);

module.exports = router;
