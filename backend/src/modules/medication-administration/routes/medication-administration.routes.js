/**
 * Medication administration routes
 *
 * @module modules/medication-administration/routes
 * @description Medication administration endpoints mounted at /api/v1/medication-administrations
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const medicationAdministrationController = require('@controllers/medication-administration/medication-administration.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createMedicationAdministrationSchema,
  updateMedicationAdministrationSchema,
  medicationAdministrationIdParamsSchema,
  listMedicationAdministrationsQuerySchema
} = require('@validations/medication-administration/medication-administration.schema');

const IPD_READ_SCOPES = [PERMISSIONS.CLINICAL_READ];
const IPD_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];
const IPD_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List medication administrations with pagination and filters
 * @method GET
 * @route /api/v1/medication-administrations/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [admission_id] - Filter by admission ID (UUID)
 * @queryParams {string} [prescription_id] - Filter by prescription ID (UUID)
 * @queryParams {string} [route] - Filter by medication route (ORAL, IV, IM, SC, TOPICAL, INHALATION, RECTAL, OTHER)
 * @bodyParams None
 * @returns {Object} Paginated list of medication administrations
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listMedicationAdministrationsQuerySchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  medicationAdministrationController.listMedicationAdministrations
);

/**
 * @description Get medication administration by ID
 * @method GET
 * @route /api/v1/medication-administrations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Medication administration ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Medication administration data
 * @throws 401 Unauthorized
 * @throws 404 Medication administration not found
 */
router.get(
  '/:id',  validateRequest({ params: medicationAdministrationIdParamsSchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  medicationAdministrationController.getMedicationAdministrationById
);

/**
 * @description Create new medication administration
 * @method POST
 * @route /api/v1/medication-administrations/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} admission_id - Admission ID (required, UUID)
 * @bodyParams {string} [prescription_id] - Prescription ID (optional, UUID)
 * @bodyParams {string} [administered_at] - Administration timestamp (optional, ISO 8601 datetime)
 * @bodyParams {string} dose - Medication dose (required, max 80 chars)
 * @bodyParams {string} [unit] - Dose unit (optional, max 40 chars)
 * @bodyParams {string} route - Medication route (required, enum: ORAL, IV, IM, SC, TOPICAL, INHALATION, RECTAL, OTHER)
 * @returns {Object} Created medication administration
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createMedicationAdministrationSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  medicationAdministrationController.createMedicationAdministration
);

/**
 * @description Update medication administration
 * @method PUT
 * @route /api/v1/medication-administrations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Medication administration ID (UUID)
 * @queryParams None
 * @bodyParams {string} [administered_at] - Administration timestamp (optional, ISO 8601 datetime)
 * @bodyParams {string} [dose] - Medication dose (optional, max 80 chars)
 * @bodyParams {string} [unit] - Dose unit (optional, max 40 chars)
 * @bodyParams {string} [route] - Medication route (optional, enum: ORAL, IV, IM, SC, TOPICAL, INHALATION, RECTAL, OTHER)
 * @returns {Object} Updated medication administration
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Medication administration not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: medicationAdministrationIdParamsSchema, body: updateMedicationAdministrationSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  medicationAdministrationController.updateMedicationAdministration
);

/**
 * @description Delete medication administration (soft delete)
 * @method DELETE
 * @route /api/v1/medication-administrations/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Medication administration ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Medication administration not found
 */
router.delete(
  '/:id',  validateRequest({ params: medicationAdministrationIdParamsSchema }),

  authenticate(),
  authorize(IPD_ADMIN_SCOPES, 'permission'),
  medicationAdministrationController.deleteMedicationAdministration
);

module.exports = router;
