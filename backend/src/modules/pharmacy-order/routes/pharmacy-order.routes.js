/**
 * Pharmacy order routes
 *
 * @module modules/pharmacy-order/routes
 * @description Pharmacy order endpoints mounted at /api/v1/pharmacy-orders
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const pharmacyOrderController = require('@controllers/pharmacy-order/pharmacy-order.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createPharmacyOrderSchema,
  updatePharmacyOrderSchema,
  dispensePharmacyOrderSchema,
  pharmacyOrderIdParamsSchema,
  listPharmacyOrdersQuerySchema
} = require('@validations/pharmacy-order/pharmacy-order.schema');

/**
 * @description List pharmacy orders with pagination and filters
 * @method GET
 * @route /api/v1/pharmacy-orders/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=ordered_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [encounter_id] - Filter by encounter ID (UUID)
 * @queryParams {string} [status] - Filter by status (ORDERED/DISPENSED/PARTIALLY_DISPENSED/CANCELLED)
 * @queryParams {string} [ordered_at_from] - Filter by ordered date from (ISO 8601 datetime)
 * @queryParams {string} [ordered_at_to] - Filter by ordered date to (ISO 8601 datetime)
 * @bodyParams None
 * @returns {Object} Paginated list of pharmacy orders
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listPharmacyOrdersQuerySchema }),

  authenticate(),
  pharmacyOrderController.listPharmacyOrders
);

/**
 * @description Get pharmacy order by ID
 * @method GET
 * @route /api/v1/pharmacy-orders/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pharmacy order ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Pharmacy order data
 * @throws 401 Unauthorized
 * @throws 404 Pharmacy order not found
 */
router.get(
  '/:id',
  validateRequest({ params: pharmacyOrderIdParamsSchema }),

  authenticate(),
  pharmacyOrderController.getPharmacyOrderById
);

/**
 * @description Create new pharmacy order
 * @method POST
 * @route /api/v1/pharmacy-orders/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} [encounter_id] - Encounter ID (UUID)
 * @bodyParams {string} [status] - Order status (ORDERED/DISPENSED/PARTIALLY_DISPENSED/CANCELLED)
 * @bodyParams {string} [ordered_at] - Order date (ISO 8601 datetime)
 * @returns {Object} Created pharmacy order
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createPharmacyOrderSchema }),

  authenticate(),
  pharmacyOrderController.createPharmacyOrder
);

/**
 * @description Update pharmacy order
 * @method PUT
 * @route /api/v1/pharmacy-orders/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pharmacy order ID (UUID)
 * @queryParams None
 * @bodyParams {string} [patient_id] - Patient ID (UUID)
 * @bodyParams {string} [encounter_id] - Encounter ID (UUID)
 * @bodyParams {string} [status] - Order status (ORDERED/DISPENSED/PARTIALLY_DISPENSED/CANCELLED)
 * @bodyParams {string} [ordered_at] - Order date (ISO 8601 datetime)
 * @returns {Object} Updated pharmacy order
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Pharmacy order not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: pharmacyOrderIdParamsSchema, body: updatePharmacyOrderSchema }),

  authenticate(),
  pharmacyOrderController.updatePharmacyOrder
);

/**
 * @description Delete pharmacy order (soft delete)
 * @method DELETE
 * @route /api/v1/pharmacy-orders/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pharmacy order ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Pharmacy order not found
 */
router.delete(
  '/:id',
  validateRequest({ params: pharmacyOrderIdParamsSchema }),

  authenticate(),
  pharmacyOrderController.deletePharmacyOrder
);

/**
 * @description Dispense pharmacy order
 * @method POST
 * @route /api/v1/pharmacy-orders/:id/dispense
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Pharmacy order ID (UUID)
 * @bodyParams {string} [status] - Dispense status override (DISPENSED/PARTIALLY_DISPENSED)
 * @bodyParams {string} [notes] - Dispense notes
 * @returns {Object} Updated pharmacy order
 * @throws 401 Unauthorized
 * @throws 404 Pharmacy order not found
 */
router.post(
  '/:id/dispense',
  validateRequest({ params: pharmacyOrderIdParamsSchema, body: dispensePharmacyOrderSchema }),

  authenticate(),
  pharmacyOrderController.dispensePharmacyOrder
);

module.exports = router;
