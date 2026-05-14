/**
 * Facility routes
 *
 * @module modules/facility/routes
 * @description Facility endpoints mounted at /api/v1/facilities
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const facilityController = require('@controllers/facility/facility.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createFacilitySchema,
  updateFacilitySchema,
  facilityIdParamsSchema,
  listFacilitiesQuerySchema
} = require('@validations/facility/facility.schema');
const { listQuerySchema } = require('@lib/validation/zod');

/**
 * @description List facilities with pagination and filters
 * @method GET
 * @route /api/v1/facilities/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_type] - Filter by facility type
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @queryParams {string} [search] - Search by name
 * @bodyParams None
 * @returns {Object} Paginated list of facilities
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listFacilitiesQuerySchema }),

  authenticate(),
  facilityController.listFacilities
);

/**
 * @description Get facility by ID
 * @method GET
 * @route /api/v1/facilities/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Facility ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Facility data
 * @throws 401 Unauthorized
 * @throws 404 Facility not found
 */
router.get(
  '/:id',  validateRequest({ params: facilityIdParamsSchema }),

  authenticate(),
  facilityController.getFacilityById
);

/**
 * @description Create new facility
 * @method POST
 * @route /api/v1/facilities/
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} name - Facility name (required, max 255 chars)
 * @bodyParams {string} facility_type - Facility type (required: HOSPITAL, CLINIC, LAB, PHARMACY, OTHER)
 * @bodyParams {boolean} [is_active=true] - Active status
 * @returns {Object} Created facility
 * @throws 401 Unauthorized
 * @throws 400 Validation error or invalid tenant reference
 * @throws 409 Duplicate facility
 */
router.post(
  '/',  validateRequest({ body: createFacilitySchema }),

  authenticate(),
  facilityController.createFacility
);

/**
 * @description Update facility
 * @method PUT
 * @route /api/v1/facilities/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Facility ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Facility name (max 255 chars)
 * @bodyParams {string} [facility_type] - Facility type (HOSPITAL, CLINIC, LAB, PHARMACY, OTHER)
 * @bodyParams {boolean} [is_active] - Active status
 * @returns {Object} Updated facility
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Facility not found
 * @throws 409 Duplicate facility
 */
router.put(
  '/:id',  validateRequest({ params: facilityIdParamsSchema, body: updateFacilitySchema }),

  authenticate(),
  facilityController.updateFacility
);

/**
 * @description Delete facility (soft delete)
 * @method DELETE
 * @route /api/v1/facilities/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users (admin)
 * @urlParams {string} id - Facility ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Facility not found
 */
router.delete(
  '/:id',  validateRequest({ params: facilityIdParamsSchema }),

  authenticate(),
  facilityController.deleteFacility
);

/**
 * @description Get facility branches with pagination
 * @method GET
 * @route /api/v1/facilities/:id/branches
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Facility ID (UUID)
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @bodyParams None
 * @returns {Object} Paginated list of branches
 * @throws 401 Unauthorized
 * @throws 404 Facility not found
 */
router.get(
  '/:id/branches',
  validateRequest({ 
    params: facilityIdParamsSchema,
    query: listQuerySchema 
  }),
  authenticate(),
  facilityController.getFacilityBranches
);

module.exports = router;
