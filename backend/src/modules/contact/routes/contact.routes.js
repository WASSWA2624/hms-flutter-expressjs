/**
 * Contact routes
 *
 * @module modules/contact/routes
 * @description Contact endpoints mounted at /api/v1/contacts
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const contactController = require('@controllers/contact/contact.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createContactSchema,
  updateContactSchema,
  contactIdParamsSchema,
  listContactsQuerySchema
} = require('@validations/contact/contact.schema');

const CONTACT_READ_SCOPES = [
  PERMISSIONS.PROFILE_READ,
  PERMISSIONS.PATIENT_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const CONTACT_WRITE_SCOPES = [
  PERMISSIONS.PROFILE_UPDATE,
  PERMISSIONS.PATIENT_WRITE,
  PERMISSIONS.OPERATIONS_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const CONTACT_DELETE_SCOPES = [
  PERMISSIONS.PATIENT_DELETE,
  PERMISSIONS.OPERATIONS_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List contacts with pagination and filters
 * @method GET
 * @route /api/v1/contacts/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [contact_type] - Filter by contact type (PHONE, EMAIL, FAX, OTHER)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [branch_id] - Filter by branch ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [user_profile_id] - Filter by user profile ID (UUID)
 * @queryParams {string} [staff_profile_id] - Filter by staff profile ID (UUID)
 * @queryParams {string} [supplier_id] - Filter by supplier ID (UUID)
 * @queryParams {string} [is_primary] - Filter by is_primary (true/false)
 * @queryParams {string} [search] - Search in contact value field
 * @bodyParams None
 * @returns {Object} Paginated list of contacts
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listContactsQuerySchema }),

  authenticate(),
  authorize(CONTACT_READ_SCOPES, 'permission'),
  contactController.listContacts
);

/**
 * @description Get contact by ID
 * @method GET
 * @route /api/v1/contacts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Contact ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Contact data
 * @throws 401 Unauthorized
 * @throws 404 Contact not found
 */
router.get(
  '/:id',  validateRequest({ params: contactIdParamsSchema }),

  authenticate(),
  authorize(CONTACT_READ_SCOPES, 'permission'),
  contactController.getContactById
);

/**
 * @description Create new contact
 * @method POST
 * @route /api/v1/contacts/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} contact_type - Contact type (required, PHONE/EMAIL/FAX/OTHER)
 * @bodyParams {string} value - Contact value (required, max 255 chars)
 * @bodyParams {boolean} [is_primary=false] - Is primary contact
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [branch_id] - Branch ID (UUID)
 * @bodyParams {string} [patient_id] - Patient ID (UUID)
 * @bodyParams {string} [user_profile_id] - User profile ID (UUID)
 * @bodyParams {string} [staff_profile_id] - Staff profile ID (UUID)
 * @bodyParams {string} [supplier_id] - Supplier ID (UUID)
 * @returns {Object} Created contact
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createContactSchema }),

  authenticate(),
  authorize(CONTACT_WRITE_SCOPES, 'permission'),
  contactController.createContact
);

/**
 * @description Update contact
 * @method PUT
 * @route /api/v1/contacts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Contact ID (UUID)
 * @queryParams None
 * @bodyParams {string} [contact_type] - Contact type (PHONE/EMAIL/FAX/OTHER)
 * @bodyParams {string} [value] - Contact value (max 255 chars)
 * @bodyParams {boolean} [is_primary] - Is primary contact
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [branch_id] - Branch ID (UUID)
 * @bodyParams {string} [patient_id] - Patient ID (UUID)
 * @bodyParams {string} [user_profile_id] - User profile ID (UUID)
 * @bodyParams {string} [staff_profile_id] - Staff profile ID (UUID)
 * @bodyParams {string} [supplier_id] - Supplier ID (UUID)
 * @returns {Object} Updated contact
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Contact not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: contactIdParamsSchema, body: updateContactSchema }),

  authenticate(),
  authorize(CONTACT_WRITE_SCOPES, 'permission'),
  contactController.updateContact
);

/**
 * @description Delete contact (soft delete)
 * @method DELETE
 * @route /api/v1/contacts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Contact ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Contact not found
 */
router.delete(
  '/:id',  validateRequest({ params: contactIdParamsSchema }),

  authenticate(),
  authorize(CONTACT_DELETE_SCOPES, 'permission'),
  contactController.deleteContact
);

module.exports = router;
