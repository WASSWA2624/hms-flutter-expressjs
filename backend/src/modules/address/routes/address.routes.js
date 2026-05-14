/**
 * Address routes
 *
 * @module modules/address/routes
 * @description Address endpoints mounted at /api/v1/addresses
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const addressController = require('@controllers/address/address.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createAddressSchema,
  updateAddressSchema,
  addressIdParamsSchema,
  listAddressesQuerySchema
} = require('@validations/address/address.schema');

const ADDRESS_READ_SCOPES = [
  PERMISSIONS.PROFILE_READ,
  PERMISSIONS.PATIENT_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const ADDRESS_WRITE_SCOPES = [
  PERMISSIONS.PROFILE_UPDATE,
  PERMISSIONS.PATIENT_WRITE,
  PERMISSIONS.OPERATIONS_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const ADDRESS_DELETE_SCOPES = [
  PERMISSIONS.PATIENT_DELETE,
  PERMISSIONS.OPERATIONS_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List addresses with pagination and filters
 * @method GET
 * @route /api/v1/addresses/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [address_type] - Filter by address type (HOME, WORK, BILLING, SHIPPING, OTHER)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [branch_id] - Filter by branch ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [user_profile_id] - Filter by user profile ID (UUID)
 * @queryParams {string} [staff_profile_id] - Filter by staff profile ID (UUID)
 * @queryParams {string} [supplier_id] - Filter by supplier ID (UUID)
 * @queryParams {string} [city] - Filter by city
 * @queryParams {string} [state] - Filter by state
 * @queryParams {string} [country] - Filter by country
 * @queryParams {string} [search] - Search in address fields
 * @bodyParams None
 * @returns {Object} Paginated list of addresses
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAddressesQuerySchema }),

  authenticate(),
  authorize(ADDRESS_READ_SCOPES, 'permission'),
  addressController.listAddresses
);

/**
 * @description Get address by ID
 * @method GET
 * @route /api/v1/addresses/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Address ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Address data
 * @throws 401 Unauthorized
 * @throws 404 Address not found
 */
router.get(
  '/:id',  validateRequest({ params: addressIdParamsSchema }),

  authenticate(),
  authorize(ADDRESS_READ_SCOPES, 'permission'),
  addressController.getAddressById
);

/**
 * @description Create new address
 * @method POST
 * @route /api/v1/addresses/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} address_type - Address type (required, HOME/WORK/BILLING/SHIPPING/OTHER)
 * @bodyParams {string} line1 - Address line 1 (required, max 255 chars)
 * @bodyParams {string} [line2] - Address line 2 (max 255 chars)
 * @bodyParams {string} [city] - City (max 120 chars)
 * @bodyParams {string} [state] - State/Province (max 120 chars)
 * @bodyParams {string} [postal_code] - Postal/ZIP code (max 40 chars)
 * @bodyParams {string} [country] - Country (max 120 chars)
 * @bodyParams {number} [latitude] - Latitude (-90 to 90)
 * @bodyParams {number} [longitude] - Longitude (-180 to 180)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [branch_id] - Branch ID (UUID)
 * @bodyParams {string} [patient_id] - Patient ID (UUID)
 * @bodyParams {string} [user_profile_id] - User profile ID (UUID)
 * @bodyParams {string} [staff_profile_id] - Staff profile ID (UUID)
 * @bodyParams {string} [supplier_id] - Supplier ID (UUID)
 * @returns {Object} Created address
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAddressSchema }),

  authenticate(),
  authorize(ADDRESS_WRITE_SCOPES, 'permission'),
  addressController.createAddress
);

/**
 * @description Update address
 * @method PUT
 * @route /api/v1/addresses/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Address ID (UUID)
 * @queryParams None
 * @bodyParams {string} [address_type] - Address type (HOME/WORK/BILLING/SHIPPING/OTHER)
 * @bodyParams {string} [line1] - Address line 1 (max 255 chars)
 * @bodyParams {string} [line2] - Address line 2 (max 255 chars)
 * @bodyParams {string} [city] - City (max 120 chars)
 * @bodyParams {string} [state] - State/Province (max 120 chars)
 * @bodyParams {string} [postal_code] - Postal/ZIP code (max 40 chars)
 * @bodyParams {string} [country] - Country (max 120 chars)
 * @bodyParams {number} [latitude] - Latitude (-90 to 90)
 * @bodyParams {number} [longitude] - Longitude (-180 to 180)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [branch_id] - Branch ID (UUID)
 * @bodyParams {string} [patient_id] - Patient ID (UUID)
 * @bodyParams {string} [user_profile_id] - User profile ID (UUID)
 * @bodyParams {string} [staff_profile_id] - Staff profile ID (UUID)
 * @bodyParams {string} [supplier_id] - Supplier ID (UUID)
 * @returns {Object} Updated address
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Address not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: addressIdParamsSchema, body: updateAddressSchema }),

  authenticate(),
  authorize(ADDRESS_WRITE_SCOPES, 'permission'),
  addressController.updateAddress
);

/**
 * @description Delete address (soft delete)
 * @method DELETE
 * @route /api/v1/addresses/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Address ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Address not found
 */
router.delete(
  '/:id',  validateRequest({ params: addressIdParamsSchema }),

  authenticate(),
  authorize(ADDRESS_DELETE_SCOPES, 'permission'),
  addressController.deleteAddress
);

module.exports = router;
