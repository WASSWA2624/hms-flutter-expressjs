/**
 * Bed Assignment routes
 *
 * @module modules/bed-assignment/routes
 * @description Bed assignment endpoints mounted at /api/v1/bed-assignments
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const bedAssignmentController = require('@controllers/bed-assignment/bed-assignment.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createBedAssignmentSchema,
  updateBedAssignmentSchema,
  bedAssignmentIdParamsSchema,
  listBedAssignmentsQuerySchema
} = require('@validations/bed-assignment/bed-assignment.schema');

const IPD_READ_SCOPES = [PERMISSIONS.CLINICAL_READ];
const IPD_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];
const IPD_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List bed assignments with pagination and filters
 * @method GET
 * @route /api/v1/bed-assignments/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [admission_id] - Filter by admission ID (UUID)
 * @queryParams {string} [bed_id] - Filter by bed ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of bed assignments
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listBedAssignmentsQuerySchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  bedAssignmentController.listBedAssignments
);

/**
 * @description Get bed assignment by ID
 * @method GET
 * @route /api/v1/bed-assignments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Bed Assignment ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Bed assignment data
 * @throws 401 Unauthorized
 * @throws 404 Bed assignment not found
 */
router.get(
  '/:id',  validateRequest({ params: bedAssignmentIdParamsSchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  bedAssignmentController.getBedAssignmentById
);

/**
 * @description Create new bed assignment
 * @method POST
 * @route /api/v1/bed-assignments/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} admission_id - Admission ID (required, UUID)
 * @bodyParams {string} bed_id - Bed ID (required, UUID)
 * @bodyParams {string} [assigned_at] - Assignment timestamp (ISO 8601 datetime)
 * @returns {Object} Created bed assignment
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createBedAssignmentSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  bedAssignmentController.createBedAssignment
);

/**
 * @description Update bed assignment
 * @method PUT
 * @route /api/v1/bed-assignments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Bed Assignment ID (UUID)
 * @queryParams None
 * @bodyParams {string} [bed_id] - Bed ID (UUID)
 * @bodyParams {string} [assigned_at] - Assignment timestamp (ISO 8601 datetime)
 * @bodyParams {string} [released_at] - Release timestamp (ISO 8601 datetime)
 * @returns {Object} Updated bed assignment
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Bed assignment not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: bedAssignmentIdParamsSchema, body: updateBedAssignmentSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  bedAssignmentController.updateBedAssignment
);

/**
 * @description Delete bed assignment (soft delete)
 * @method DELETE
 * @route /api/v1/bed-assignments/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Bed Assignment ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Bed assignment not found
 */
router.delete(
  '/:id',  validateRequest({ params: bedAssignmentIdParamsSchema }),

  authenticate(),
  authorize(IPD_ADMIN_SCOPES, 'permission'),
  bedAssignmentController.deleteBedAssignment
);

module.exports = router;
