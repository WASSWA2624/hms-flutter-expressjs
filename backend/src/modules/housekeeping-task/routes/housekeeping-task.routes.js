/**
 * Housekeeping task routes
 *
 * @module modules/housekeeping-task/routes
 * @description Housekeeping task endpoints mounted at /api/v1/housekeeping-tasks
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const housekeepingTaskController = require('@controllers/housekeeping-task/housekeeping-task.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createHousekeepingTaskSchema,
  updateHousekeepingTaskSchema,
  housekeepingTaskIdParamsSchema,
  listHousekeepingTasksQuerySchema
} = require('@validations/housekeeping-task/housekeeping-task.schema');

/**
 * @description List housekeeping tasks with pagination and filters
 * @method GET
 * @route /api/v1/housekeeping-tasks/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [room_id] - Filter by room ID (UUID)
 * @queryParams {string} [assigned_to_staff_id] - Filter by assigned staff ID (UUID)
 * @queryParams {string} [status] - Filter by status (PENDING, IN_PROGRESS, COMPLETED, CANCELLED)
 * @bodyParams None
 * @returns {Object} Paginated list of housekeeping tasks
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listHousekeepingTasksQuerySchema }),

  authenticate(),
  housekeepingTaskController.listHousekeepingTasks
);

/**
 * @description Get housekeeping task by ID
 * @method GET
 * @route /api/v1/housekeeping-tasks/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Housekeeping task ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Housekeeping task data
 * @throws 401 Unauthorized
 * @throws 404 Housekeeping task not found
 */
router.get(
  '/:id',  validateRequest({ params: housekeepingTaskIdParamsSchema }),

  authenticate(),
  housekeepingTaskController.getHousekeepingTaskById
);

/**
 * @description Create new housekeeping task
 * @method POST
 * @route /api/v1/housekeeping-tasks/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [room_id] - Room ID (UUID)
 * @bodyParams {string} [assigned_to_staff_id] - Assigned staff ID (UUID)
 * @bodyParams {string} status - Status (required, PENDING, IN_PROGRESS, COMPLETED, CANCELLED)
 * @bodyParams {string} [scheduled_at] - Scheduled date/time (ISO 8601)
 * @bodyParams {string} [completed_at] - Completed date/time (ISO 8601)
 * @returns {Object} Created housekeeping task
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createHousekeepingTaskSchema }),

  authenticate(),
  housekeepingTaskController.createHousekeepingTask
);

/**
 * @description Update housekeeping task
 * @method PUT
 * @route /api/v1/housekeeping-tasks/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Housekeeping task ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [room_id] - Room ID (UUID)
 * @bodyParams {string} [assigned_to_staff_id] - Assigned staff ID (UUID)
 * @bodyParams {string} [status] - Status (PENDING, IN_PROGRESS, COMPLETED, CANCELLED)
 * @bodyParams {string} [scheduled_at] - Scheduled date/time (ISO 8601)
 * @bodyParams {string} [completed_at] - Completed date/time (ISO 8601)
 * @returns {Object} Updated housekeeping task
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Housekeeping task not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: housekeepingTaskIdParamsSchema, body: updateHousekeepingTaskSchema }),

  authenticate(),
  housekeepingTaskController.updateHousekeepingTask
);

/**
 * @description Delete housekeeping task (soft delete)
 * @method DELETE
 * @route /api/v1/housekeeping-tasks/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Housekeeping task ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Housekeeping task not found
 */
router.delete(
  '/:id',  validateRequest({ params: housekeepingTaskIdParamsSchema }),

  authenticate(),
  housekeepingTaskController.deleteHousekeepingTask
);

module.exports = router;
