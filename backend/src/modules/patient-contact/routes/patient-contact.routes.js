/**
 * Patient Contact routes
 *
 * @module modules/patient-contact/routes
 * @description Patient Contact endpoints mounted at /api/v1/patient-contacts
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const patientContactController = require('@controllers/patient-contact/patient-contact.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPatientContactSchema,
  updatePatientContactSchema,
  patientContactIdParamsSchema,
  listPatientContactsQuerySchema
} = require('@validations/patient-contact/patient-contact.schema');

/**
 * @description List patient contacts with pagination and filters
 * @method GET
 * @route /api/v1/patient-contacts/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [contact_type] - Filter by contact type (PHONE, EMAIL, FAX, OTHER)
 * @queryParams {string} [value] - Filter by value (partial match)
 * @queryParams {string} [is_primary] - Filter by primary status (true/false)
 * @bodyParams None
 * @returns {Object} Paginated list of patient contacts
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listPatientContactsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientContactController.listPatientContacts
);

/**
 * @description Get patient contact by ID
 * @method GET
 * @route /api/v1/patient-contacts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Contact ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Patient Contact data
 * @throws 401 Unauthorized
 * @throws 404 Patient Contact not found
 */
router.get(
  '/:id',
  validateRequest({ params: patientContactIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientContactController.getPatientContactById
);

/**
 * @description Create new patient contact
 * @method POST
 * @route /api/v1/patient-contacts/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} contact_type - Contact type (required, PHONE/EMAIL/FAX/OTHER)
 * @bodyParams {string} value - Contact value (required, max 255 chars)
 * @bodyParams {boolean} [is_primary=false] - Primary contact flag
 * @returns {Object} Created patient contact
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createPatientContactSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientContactController.createPatientContact
);

/**
 * @description Update patient contact
 * @method PUT
 * @route /api/v1/patient-contacts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Contact ID (UUID)
 * @queryParams None
 * @bodyParams {string} [contact_type] - Contact type (PHONE/EMAIL/FAX/OTHER)
 * @bodyParams {string} [value] - Contact value (max 255 chars)
 * @bodyParams {boolean} [is_primary] - Primary contact flag
 * @returns {Object} Updated patient contact
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Patient Contact not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: patientContactIdParamsSchema, body: updatePatientContactSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientContactController.updatePatientContact
);

/**
 * @description Delete patient contact (soft delete)
 * @method DELETE
 * @route /api/v1/patient-contacts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Contact ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Patient Contact not found
 */
router.delete(
  '/:id',
  validateRequest({ params: patientContactIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  patientContactController.deletePatientContact
);

module.exports = router;
