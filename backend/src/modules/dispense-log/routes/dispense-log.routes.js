/**
 * Dispense Log routes
 *
 * @module modules/dispense-log/routes
 * @description Dispense log endpoints mounted at /api/v1/dispense-logs
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const dispenseLogController = require('@controllers/dispense-log/dispense-log.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createDispenseLogSchema,
  updateDispenseLogSchema,
  dispenseLogIdParamsSchema,
  listDispenseLogsQuerySchema
} = require('@validations/dispense-log/dispense-log.schema');

/**
 * @description List dispense logs with pagination and filters
 * @method GET
 * @route /api/v1/dispense-logs/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [pharmacy_order_item_id] - Filter by pharmacy order item ID (UUID)
 * @queryParams {string} [status] - Filter by status (PENDING, DISPENSED, RETURNED, CANCELLED)
 * @queryParams {string} [dispensed_at_from] - Filter by dispensed_at start date (ISO 8601)
 * @queryParams {string} [dispensed_at_to] - Filter by dispensed_at end date (ISO 8601)
 * @bodyParams None
 * @returns {Object} Paginated list of dispense logs
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listDispenseLogsQuerySchema }),

  authenticate(),
  asyncHandler(dispenseLogController.listDispenseLogs)
);

/**
 * @description Get dispense log by ID
 * @method GET
 * @route /api/v1/dispense-logs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Dispense log ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Dispense log data
 * @throws 401 Unauthorized
 * @throws 404 Dispense log not found
 */
router.get(
  '/:id',  validateRequest({ params: dispenseLogIdParamsSchema }),

  authenticate(),
  asyncHandler(dispenseLogController.getDispenseLogById)
);

/**
 * @description Create new dispense log
 * @method POST
 * @route /api/v1/dispense-logs/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} pharmacy_order_item_id - Pharmacy order item ID (required, UUID)
 * @bodyParams {string} status - Status (required, PENDING/DISPENSED/RETURNED/CANCELLED)
 * @bodyParams {string} [dispensed_at] - Dispensed timestamp (ISO 8601)
 * @bodyParams {number} [quantity_dispensed=0] - Quantity dispensed (integer >= 0)
 * @returns {Object} Created dispense log
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createDispenseLogSchema }),

  authenticate(),
  asyncHandler(dispenseLogController.createDispenseLog)
);

/**
 * @description Update dispense log
 * @method PUT
 * @route /api/v1/dispense-logs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Dispense log ID (UUID)
 * @queryParams None
 * @bodyParams {string} [status] - Status (PENDING/DISPENSED/RETURNED/CANCELLED)
 * @bodyParams {string} [dispensed_at] - Dispensed timestamp (ISO 8601)
 * @bodyParams {number} [quantity_dispensed] - Quantity dispensed (integer >= 0)
 * @returns {Object} Updated dispense log
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Dispense log not found
 */
router.put(
  '/:id',  validateRequest({ params: dispenseLogIdParamsSchema, body: updateDispenseLogSchema }),

  authenticate(),
  asyncHandler(dispenseLogController.updateDispenseLog)
);

/**
 * @description Delete dispense log (soft delete)
 * @method DELETE
 * @route /api/v1/dispense-logs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Dispense log ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Dispense log not found
 */
router.delete(
  '/:id',  validateRequest({ params: dispenseLogIdParamsSchema }),

  authenticate(),
  asyncHandler(dispenseLogController.deleteDispenseLog)
);

module.exports = router;
