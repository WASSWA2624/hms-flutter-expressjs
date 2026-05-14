/**
 * Bed routes
 *
 * @module modules/bed/routes
 * @description Bed endpoints mounted at /api/v1/beds
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const bedController = require('@controllers/bed/bed.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createBedSchema,
  updateBedSchema,
  bedIdParamsSchema,
  listBedsQuerySchema
} = require('@validations/bed/bed.schema');

const BED_MANAGEMENT_READ_SCOPES = [
  PERMISSIONS.CLINICAL_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const BED_MANAGEMENT_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List beds with pagination and filters
 * @method GET
 * @route /api/v1/beds/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [ward_id] - Filter by ward ID (UUID)
 * @queryParams {string} [room_id] - Filter by room ID (UUID)
 * @queryParams {string} [status] - Filter by status (AVAILABLE, OCCUPIED, RESERVED, OUT_OF_SERVICE)
 * @queryParams {string} [search] - Search by label
 * @bodyParams None
 * @returns {Object} Paginated list of beds
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listBedsQuerySchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_READ_SCOPES, 'permission'),
  bedController.listBeds
);

/**
 * @description Get bed by ID
 * @method GET
 * @route /api/v1/beds/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Bed ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Bed data
 * @throws 401 Unauthorized
 * @throws 404 Bed not found
 */
router.get(
  '/:id',  validateRequest({ params: bedIdParamsSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_READ_SCOPES, 'permission'),
  bedController.getBedById
);

/**
 * @description Create new bed
 * @method POST
 * @route /api/v1/beds/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} facility_id - Facility ID (required, UUID)
 * @bodyParams {string} ward_id - Ward ID (required, UUID)
 * @bodyParams {string} [room_id] - Room ID (UUID)
 * @bodyParams {string} label - Bed label (required, max 50 chars)
 * @bodyParams {string} status - Bed status (required, AVAILABLE, OCCUPIED, RESERVED, OUT_OF_SERVICE)
 * @returns {Object} Created bed
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createBedSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  bedController.createBed
);

/**
 * @description Update bed
 * @method PUT
 * @route /api/v1/beds/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Bed ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [ward_id] - Ward ID (UUID)
 * @bodyParams {string} [room_id] - Room ID (UUID)
 * @bodyParams {string} [label] - Bed label (max 50 chars)
 * @bodyParams {string} [status] - Bed status (AVAILABLE, OCCUPIED, RESERVED, OUT_OF_SERVICE)
 * @returns {Object} Updated bed
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Bed not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: bedIdParamsSchema, body: updateBedSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  bedController.updateBed
);

/**
 * @description Delete bed (soft delete)
 * @method DELETE
 * @route /api/v1/beds/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Bed ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Bed not found
 */
router.delete(
  '/:id',  validateRequest({ params: bedIdParamsSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  bedController.deleteBed
);

module.exports = router;
