/**
 * Ward routes
 *
 * @module modules/ward/routes
 * @description Ward endpoints mounted at /api/v1/wards
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const wardController = require('@controllers/ward/ward.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createWardSchema,
  updateWardSchema,
  wardIdParamsSchema,
  listWardsQuerySchema
} = require('@validations/ward/ward.schema');

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
 * @description List wards with pagination and filters
 * @method GET
 * @route /api/v1/wards/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [department_id] - Filter by department ID (UUID)
 * @queryParams {string} [ward_type] - Filter by ward type (GENERAL, ICU, MATERNITY, PEDIATRIC, SURGICAL, OTHER)
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @queryParams {string} [search] - Search by name
 * @bodyParams None
 * @returns {Object} Paginated list of wards
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listWardsQuerySchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_READ_SCOPES, 'permission'),
  wardController.listWards
);

/**
 * @description Get ward by ID
 * @method GET
 * @route /api/v1/wards/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Ward ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Ward data
 * @throws 401 Unauthorized
 * @throws 404 Ward not found
 */
router.get(
  '/:id',  validateRequest({ params: wardIdParamsSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_READ_SCOPES, 'permission'),
  wardController.getWardById
);

/**
 * @description Create new ward
 * @method POST
 * @route /api/v1/wards/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} facility_id - Facility ID (required, UUID)
 * @bodyParams {string} [department_id] - Department ID (UUID)
 * @bodyParams {string} name - Ward name (required, max 255 chars)
 * @bodyParams {string} ward_type - Ward type (required, GENERAL, ICU, MATERNITY, PEDIATRIC, SURGICAL, OTHER)
 * @bodyParams {boolean} [is_active=true] - Active status
 * @returns {Object} Created ward
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createWardSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  wardController.createWard
);

/**
 * @description Update ward
 * @method PUT
 * @route /api/v1/wards/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Ward ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [department_id] - Department ID (UUID)
 * @bodyParams {string} [name] - Ward name (max 255 chars)
 * @bodyParams {string} [ward_type] - Ward type (GENERAL, ICU, MATERNITY, PEDIATRIC, SURGICAL, OTHER)
 * @bodyParams {boolean} [is_active] - Active status
 * @returns {Object} Updated ward
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Ward not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: wardIdParamsSchema, body: updateWardSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  wardController.updateWard
);

/**
 * @description Delete ward (soft delete)
 * @method DELETE
 * @route /api/v1/wards/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Ward ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Ward not found
 */
router.delete(
  '/:id',  validateRequest({ params: wardIdParamsSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_ADMIN_SCOPES, 'permission'),
  wardController.deleteWard
);

/**
 * @description Get ward beds (nested resource)
 * @method GET
 * @route /api/v1/wards/:id/beds
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Ward ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Ward with beds
 * @throws 401 Unauthorized
 * @throws 404 Ward not found
 */
router.get(
  '/:id/beds',  validateRequest({ params: wardIdParamsSchema }),

  authenticate(),
  authorize(BED_MANAGEMENT_READ_SCOPES, 'permission'),
  wardController.getWardBeds
);

module.exports = router;
