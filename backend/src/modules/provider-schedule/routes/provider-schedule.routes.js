/**
 * Provider schedule routes
 *
 * @module modules/provider-schedule/routes
 * @description Provider schedule endpoints mounted at /api/v1/provider-schedules
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const providerScheduleController = require('@controllers/provider-schedule/provider-schedule.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createProviderScheduleSchema,
  updateProviderScheduleSchema,
  providerScheduleIdParamsSchema,
  listProviderSchedulesQuerySchema
} = require('@validations/provider-schedule/provider-schedule.schema');

const SCHEDULING_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.RECEPTIONIST,
  ROLES.OPERATIONS,
  ROLES.HR,
];
const SCHEDULING_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.HR,
  ROLES.OPERATIONS,
];

/**
 * @description List provider schedules with pagination and filters
 * @method GET
 * @route /api/v1/provider-schedules/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=asc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [provider_user_id] - Filter by provider user ID (UUID)
 * @queryParams {number} [day_of_week] - Filter by day of week (0-6)
 * @bodyParams None
 * @returns {Object} Paginated list of provider schedules
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listProviderSchedulesQuerySchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  providerScheduleController.listProviderSchedules
);

/**
 * @description Get provider schedule by ID
 * @method GET
 * @route /api/v1/provider-schedules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Provider schedule ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Provider schedule data
 * @throws 401 Unauthorized
 * @throws 404 Provider schedule not found
 */
router.get(
  '/:id',  validateRequest({ params: providerScheduleIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  providerScheduleController.getProviderScheduleById
);

/**
 * @description Create new provider schedule
 * @method POST
 * @route /api/v1/provider-schedules/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} provider_user_id - Provider user ID (required, UUID)
 * @bodyParams {number} day_of_week - Day of week (required, 0-6)
 * @bodyParams {string} start_time - Start time (required, ISO 8601 datetime)
 * @bodyParams {string} end_time - End time (required, ISO 8601 datetime)
 * @returns {Object} Created provider schedule
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createProviderScheduleSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  providerScheduleController.createProviderSchedule
);

/**
 * @description Update provider schedule
 * @method PUT
 * @route /api/v1/provider-schedules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Provider schedule ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [provider_user_id] - Provider user ID (UUID)
 * @bodyParams {number} [day_of_week] - Day of week (0-6)
 * @bodyParams {string} [start_time] - Start time (ISO 8601 datetime)
 * @bodyParams {string} [end_time] - End time (ISO 8601 datetime)
 * @returns {Object} Updated provider schedule
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Provider schedule not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: providerScheduleIdParamsSchema, body: updateProviderScheduleSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  providerScheduleController.updateProviderSchedule
);

/**
 * @description Delete provider schedule (soft delete)
 * @method DELETE
 * @route /api/v1/provider-schedules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Provider schedule ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Provider schedule not found
 */
router.delete(
  '/:id',  validateRequest({ params: providerScheduleIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  providerScheduleController.deleteProviderSchedule
);

module.exports = router;

