/**
 * Availability slot routes
 *
 * @module modules/availability-slot/routes
 * @description Availability slot endpoints mounted at /api/v1/availability-slots
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const availabilitySlotController = require('@controllers/availability-slot/availability-slot.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createAvailabilitySlotSchema,
  updateAvailabilitySlotSchema,
  availabilitySlotIdParamsSchema,
  listAvailabilitySlotsQuerySchema
} = require('@validations/availability-slot/availability-slot.schema');

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
  ROLES.OPERATIONS,
  ROLES.HR,
];

/**
 * @description List availability slots with pagination and filters
 * @method GET
 * @route /api/v1/availability-slots/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=asc] - Sort order (asc/desc)
 * @queryParams {string} [schedule_id] - Filter by schedule ID (UUID)
 * @queryParams {string} [is_available] - Filter by availability (true/false)
 * @bodyParams None
 * @returns {Object} Paginated list of availability slots
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAvailabilitySlotsQuerySchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  availabilitySlotController.listAvailabilitySlots
);

/**
 * @description Get availability slot by ID
 * @method GET
 * @route /api/v1/availability-slots/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Availability slot ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Availability slot data
 * @throws 401 Unauthorized
 * @throws 404 Availability slot not found
 */
router.get(
  '/:id',  validateRequest({ params: availabilitySlotIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  availabilitySlotController.getAvailabilitySlotById
);

/**
 * @description Create new availability slot
 * @method POST
 * @route /api/v1/availability-slots/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} schedule_id - Schedule ID (required, UUID)
 * @bodyParams {string} start_time - Start time (required, ISO 8601 datetime)
 * @bodyParams {string} end_time - End time (required, ISO 8601 datetime)
 * @bodyParams {boolean} [is_available=true] - Is slot available (boolean)
 * @returns {Object} Created availability slot
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAvailabilitySlotSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  availabilitySlotController.createAvailabilitySlot
);

/**
 * @description Update availability slot
 * @method PUT
 * @route /api/v1/availability-slots/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Availability slot ID (UUID)
 * @queryParams None
 * @bodyParams {string} [schedule_id] - Schedule ID (UUID)
 * @bodyParams {string} [start_time] - Start time (ISO 8601 datetime)
 * @bodyParams {string} [end_time] - End time (ISO 8601 datetime)
 * @bodyParams {boolean} [is_available] - Is slot available (boolean)
 * @returns {Object} Updated availability slot
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Availability slot not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: availabilitySlotIdParamsSchema, body: updateAvailabilitySlotSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  availabilitySlotController.updateAvailabilitySlot
);

/**
 * @description Delete availability slot (soft delete)
 * @method DELETE
 * @route /api/v1/availability-slots/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Availability slot ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Availability slot not found
 */
router.delete(
  '/:id',  validateRequest({ params: availabilitySlotIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  availabilitySlotController.deleteAvailabilitySlot
);

module.exports = router;
