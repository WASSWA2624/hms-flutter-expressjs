/**
 * Radiology Order routes
 *
 * @module modules/radiology-order/routes
 * @description Radiology Order endpoints mounted at /api/v1/radiology-orders
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const radiologyOrderController = require('@controllers/radiology-order/radiology-order.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createRadiologyOrderSchema,
  updateRadiologyOrderSchema,
  radiologyOrderIdParamsSchema,
  listRadiologyOrdersQuerySchema
} = require('@validations/radiology-order/radiology-order.schema');

const RADIOLOGY_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
];

const RADIOLOGY_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.LAB_TECH,
];

const RADIOLOGY_REQUEST_ROLES = RADIOLOGY_READ_ROLES;

/**
 * @description List radiology orders with pagination and filters
 * @method GET
 * @route /api/v1/radiology-orders/
 * @authentication Required (JWT)
 * @permissions Authorized radiology users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=asc] - Sort order (asc/desc)
 * @queryParams {string} [encounter_id] - Filter by encounter ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [radiology_test_id] - Filter by radiology test ID (UUID)
 * @queryParams {string} [status] - Filter by status (ORDERED, IN_PROCESS, COMPLETED, CANCELLED)
 * @queryParams {string} [search] - Search filter
 * @bodyParams None
 * @returns {Object} Paginated list of radiology orders
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listRadiologyOrdersQuerySchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_ROLES, 'role'),
  radiologyOrderController.listRadiologyOrders
);

/**
 * @description Get radiology order by ID
 * @method GET
 * @route /api/v1/radiology-orders/:id
 * @authentication Required (JWT)
 * @permissions Authorized radiology users
 * @urlParams {string} id - Radiology Order ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Radiology order data
 * @throws 401 Unauthorized
 * @throws 404 Radiology order not found
 */
router.get(
  '/:id',
  validateRequest({ params: radiologyOrderIdParamsSchema }),
  authenticate(),
  authorize(RADIOLOGY_READ_ROLES, 'role'),
  radiologyOrderController.getRadiologyOrderById
);

/**
 * @description Create new radiology order
 * @method POST
 * @route /api/v1/radiology-orders/
 * @authentication Required (JWT)
 * @permissions Authorized radiology requesters
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} [encounter_id] - Encounter ID (UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} [radiology_test_id] - Radiology test ID (UUID)
 * @bodyParams {string} [status] - Order status (ORDERED/IN_PROCESS/COMPLETED/CANCELLED)
 * @bodyParams {string} [ordered_at] - Order date and time (ISO 8601 datetime)
 * @returns {Object} Created radiology order
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_REQUEST_ROLES, 'role'),
  radiologyOrderController.createRadiologyOrder
);

/**
 * @description Update radiology order
 * @method PUT
 * @route /api/v1/radiology-orders/:id
 * @authentication Required (JWT)
 * @permissions Authorized radiology editors
 * @urlParams {string} id - Radiology Order ID (UUID)
 * @queryParams None
 * @bodyParams {string} [encounter_id] - Encounter ID (UUID)
 * @bodyParams {string} [patient_id] - Patient ID (UUID)
 * @bodyParams {string} [radiology_test_id] - Radiology test ID (UUID)
 * @bodyParams {string} [status] - Order status (ORDERED/IN_PROCESS/COMPLETED/CANCELLED)
 * @bodyParams {string} [ordered_at] - Order date and time (ISO 8601 datetime)
 * @returns {Object} Updated radiology order
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Radiology order not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: radiologyOrderIdParamsSchema, body: updateRadiologyOrderSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_ROLES, 'role'),
  radiologyOrderController.updateRadiologyOrder
);

/**
 * @description Delete radiology order (soft delete)
 * @method DELETE
 * @route /api/v1/radiology-orders/:id
 * @authentication Required (JWT)
 * @permissions Authorized radiology editors
 * @urlParams {string} id - Radiology Order ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Radiology order not found
 */
router.delete(
  '/:id',
  validateRequest({ params: radiologyOrderIdParamsSchema }),
  authenticate(),
  authorize(RADIOLOGY_WRITE_ROLES, 'role'),
  radiologyOrderController.deleteRadiologyOrder
);

module.exports = router;
