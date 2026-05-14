/**
 * Visit queue routes
 *
 * @module modules/visit-queue/routes
 * @description Visit queue endpoints mounted at /api/v1/visit-queues
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const visitQueueController = require('@controllers/visit-queue/visit-queue.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createVisitQueueSchema,
  updateVisitQueueSchema,
  prioritizeVisitQueueSchema,
  visitQueueIdParamsSchema,
  listVisitQueuesQuerySchema
} = require('@validations/visit-queue/visit-queue.schema');

const SCHEDULING_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.RECEPTIONIST,
  ROLES.OPERATIONS,
  ROLES.HR,
  ROLES.BILLING,
];
const SCHEDULING_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.RECEPTIONIST,
  ROLES.OPERATIONS,
  ROLES.HR,
];
const SCHEDULING_DELETE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.OPERATIONS,
  ROLES.HR,
];

/**
 * @description List visit queue entries with pagination and filters
 * @method GET
 * @route /api/v1/visit-queues/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=queued_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [appointment_id] - Filter by appointment ID (UUID)
 * @queryParams {string} [provider_user_id] - Filter by provider user ID (UUID)
 * @queryParams {string} [status] - Filter by status (SCHEDULED, CONFIRMED, IN_PROGRESS, COMPLETED, CANCELLED, NO_SHOW)
 * @queryParams {string} [search] - Search query
 * @bodyParams None
 * @returns {Object} Paginated list of visit queue entries
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listVisitQueuesQuerySchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  visitQueueController.listVisitQueues
);

/**
 * @description Get visit queue entry by ID
 * @method GET
 * @route /api/v1/visit-queues/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Visit queue entry ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Visit queue entry data
 * @throws 401 Unauthorized
 * @throws 404 Visit queue entry not found
 */
router.get(
  '/:id',  validateRequest({ params: visitQueueIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  visitQueueController.getVisitQueueById
);

/**
 * @description Create new visit queue entry
 * @method POST
 * @route /api/v1/visit-queues/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} [appointment_id] - Appointment ID (UUID)
 * @bodyParams {string} [provider_user_id] - Provider user ID (UUID)
 * @bodyParams {string} status - Status (required, SCHEDULED, CONFIRMED, IN_PROGRESS, COMPLETED, CANCELLED, NO_SHOW)
 * @bodyParams {string} [queued_at] - Queue time (ISO 8601 datetime)
 * @returns {Object} Created visit queue entry
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createVisitQueueSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  visitQueueController.createVisitQueue
);

/**
 * @description Update visit queue entry
 * @method PUT
 * @route /api/v1/visit-queues/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Visit queue entry ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [appointment_id] - Appointment ID (UUID)
 * @bodyParams {string} [provider_user_id] - Provider user ID (UUID)
 * @bodyParams {string} [status] - Status (SCHEDULED, CONFIRMED, IN_PROGRESS, COMPLETED, CANCELLED, NO_SHOW)
 * @bodyParams {string} [queued_at] - Queue time (ISO 8601 datetime)
 * @returns {Object} Updated visit queue entry
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Visit queue entry not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: visitQueueIdParamsSchema, body: updateVisitQueueSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  visitQueueController.updateVisitQueue
);

/**
 * @description Delete visit queue entry (soft delete)
 * @method DELETE
 * @route /api/v1/visit-queues/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Visit queue entry ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Visit queue entry not found
 */
router.delete(
  '/:id',  validateRequest({ params: visitQueueIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_DELETE_ROLES, 'role'),
  visitQueueController.deleteVisitQueue
);

/**
 * @description Prioritize visit queue entry
 * @method POST
 * @route /api/v1/visit-queues/:id/prioritize
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Visit queue entry ID (UUID)
 * @bodyParams {string} [reason] - Triage reason
 * @bodyParams {string} [status] - Updated queue status
 * @returns {Object} Prioritized visit queue entry
 * @throws 401 Unauthorized
 * @throws 404 Visit queue entry not found
 */
router.post(
  '/:id/prioritize',
  validateRequest({ params: visitQueueIdParamsSchema, body: prioritizeVisitQueueSchema }),
  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  visitQueueController.prioritizeVisitQueue
);

module.exports = router;
