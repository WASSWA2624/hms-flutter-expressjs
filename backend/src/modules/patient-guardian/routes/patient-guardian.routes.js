/**
 * Patient Guardian routes
 *
 * @module modules/patient-guardian/routes
 * @description Patient Guardian endpoints mounted at /api/v1/patient-guardians
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const patientGuardianController = require('@controllers/patient-guardian/patient-guardian.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPatientGuardianSchema,
  updatePatientGuardianSchema,
  patientGuardianIdParamsSchema,
  listPatientGuardiansQuerySchema
} = require('@validations/patient-guardian/patient-guardian.schema');

/**
 * @description List patient guardians with pagination and filters
 * @method GET
 * @route /api/v1/patient-guardians/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [name] - Filter by name (partial match)
 * @queryParams {string} [relationship] - Filter by relationship (partial match)
 * @queryParams {string} [search] - Search in name and relationship fields
 * @bodyParams None
 * @returns {Object} Paginated list of patient guardians
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listPatientGuardiansQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientGuardianController.listPatientGuardians
);

/**
 * @description Get patient guardian by ID
 * @method GET
 * @route /api/v1/patient-guardians/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Guardian ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Patient Guardian data
 * @throws 401 Unauthorized
 * @throws 404 Patient Guardian not found
 */
router.get(
  '/:id',
  validateRequest({ params: patientGuardianIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientGuardianController.getPatientGuardianById
);

/**
 * @description Create new patient guardian
 * @method POST
 * @route /api/v1/patient-guardians/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} name - Guardian name (required, max 255 chars)
 * @bodyParams {string} [relationship] - Relationship to patient (max 120 chars)
 * @bodyParams {string} [phone] - Phone number (max 40 chars)
 * @bodyParams {string} [email] - Email address (valid email, max 255 chars)
 * @returns {Object} Created patient guardian
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createPatientGuardianSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientGuardianController.createPatientGuardian
);

/**
 * @description Update patient guardian
 * @method PUT
 * @route /api/v1/patient-guardians/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Guardian ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Guardian name (max 255 chars)
 * @bodyParams {string} [relationship] - Relationship to patient (max 120 chars)
 * @bodyParams {string} [phone] - Phone number (max 40 chars)
 * @bodyParams {string} [email] - Email address (valid email, max 255 chars)
 * @returns {Object} Updated patient guardian
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Patient Guardian not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: patientGuardianIdParamsSchema, body: updatePatientGuardianSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientGuardianController.updatePatientGuardian
);

/**
 * @description Delete patient guardian (soft delete)
 * @method DELETE
 * @route /api/v1/patient-guardians/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Guardian ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Patient Guardian not found
 */
router.delete(
  '/:id',
  validateRequest({ params: patientGuardianIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  patientGuardianController.deletePatientGuardian
);

module.exports = router;
