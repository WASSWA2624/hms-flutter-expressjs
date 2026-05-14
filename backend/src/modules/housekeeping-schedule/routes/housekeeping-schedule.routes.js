/**
 * Housekeeping schedule routes
 *
 * @module modules/housekeeping-schedule/routes
 * @description Housekeeping schedule endpoints mounted at /api/v1/housekeeping-schedules
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const housekeepingScheduleController = require('@controllers/housekeeping-schedule/housekeeping-schedule.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createHousekeepingScheduleSchema,
  updateHousekeepingScheduleSchema,
  housekeepingScheduleIdParamsSchema,
  listHousekeepingSchedulesQuerySchema
} = require('@validations/housekeeping-schedule/housekeeping-schedule.schema');

/**
 * @description List housekeeping schedules with pagination and filters
 * @method GET
 * @route /api/v1/housekeeping-schedules/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [room_id] - Filter by room ID (UUID)
 * @queryParams {string} [frequency] - Filter by frequency
 * @bodyParams None
 * @returns {Object} Paginated list of housekeeping schedules
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listHousekeepingSchedulesQuerySchema }),

  authenticate(),
  housekeepingScheduleController.listHousekeepingSchedules
);

/**
 * @description Get housekeeping schedule by ID
 * @method GET
 * @route /api/v1/housekeeping-schedules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Housekeeping schedule ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Housekeeping schedule data
 * @throws 401 Unauthorized
 * @throws 404 Housekeeping schedule not found
 */
router.get(
  '/:id',  validateRequest({ params: housekeepingScheduleIdParamsSchema }),

  authenticate(),
  housekeepingScheduleController.getHousekeepingScheduleById
);

/**
 * @description Create new housekeeping schedule
 * @method POST
 * @route /api/v1/housekeeping-schedules/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [room_id] - Room ID (UUID)
 * @bodyParams {string} [frequency] - Frequency (max 80 chars)
 * @bodyParams {string} [start_date] - Start date (ISO 8601)
 * @bodyParams {string} [end_date] - End date (ISO 8601)
 * @returns {Object} Created housekeeping schedule
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createHousekeepingScheduleSchema }),

  authenticate(),
  housekeepingScheduleController.createHousekeepingSchedule
);

/**
 * @description Update housekeeping schedule
 * @method PUT
 * @route /api/v1/housekeeping-schedules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Housekeeping schedule ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [room_id] - Room ID (UUID)
 * @bodyParams {string} [frequency] - Frequency (max 80 chars)
 * @bodyParams {string} [start_date] - Start date (ISO 8601)
 * @bodyParams {string} [end_date] - End date (ISO 8601)
 * @returns {Object} Updated housekeeping schedule
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Housekeeping schedule not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: housekeepingScheduleIdParamsSchema, body: updateHousekeepingScheduleSchema }),

  authenticate(),
  housekeepingScheduleController.updateHousekeepingSchedule
);

/**
 * @description Delete housekeeping schedule (soft delete)
 * @method DELETE
 * @route /api/v1/housekeeping-schedules/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Housekeeping schedule ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Housekeeping schedule not found
 */
router.delete(
  '/:id',  validateRequest({ params: housekeepingScheduleIdParamsSchema }),

  authenticate(),
  housekeepingScheduleController.deleteHousekeepingSchedule
);

module.exports = router;
