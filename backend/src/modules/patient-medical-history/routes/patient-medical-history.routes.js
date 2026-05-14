/**
 * Patient Medical History routes
 *
 * @module modules/patient-medical-history/routes
 * @description Patient medical history endpoints mounted at /api/v1/patient-medical-histories
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const patientMedicalHistoryController = require('@controllers/patient-medical-history/patient-medical-history.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPatientMedicalHistorySchema,
  updatePatientMedicalHistorySchema,
  patientMedicalHistoryIdParamsSchema,
  listPatientMedicalHistoriesQuerySchema
} = require('@validations/patient-medical-history/patient-medical-history.schema');

/**
 * @description List patient medical histories with pagination and filters
 * @method GET
 * @route /api/v1/patient-medical-histories/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [condition] - Filter by condition (partial match)
 * @queryParams {string} [search] - Search in condition and notes fields
 * @bodyParams None
 * @returns {Object} Paginated list of patient medical histories
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listPatientMedicalHistoriesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  asyncHandler(patientMedicalHistoryController.listPatientMedicalHistories)
);

/**
 * @description Get patient medical history by ID
 * @method GET
 * @route /api/v1/patient-medical-histories/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient medical history ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Patient medical history data
 * @throws 401 Unauthorized
 * @throws 404 Patient medical history not found
 */
router.get(
  '/:id',
  validateRequest({ params: patientMedicalHistoryIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  asyncHandler(patientMedicalHistoryController.getPatientMedicalHistoryById)
);

/**
 * @description Create new patient medical history
 * @method POST
 * @route /api/v1/patient-medical-histories/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} condition - Condition (required, max 255 chars)
 * @bodyParams {string} [diagnosis_date] - Diagnosis date (ISO 8601 format)
 * @bodyParams {string} [notes] - Notes (text)
 * @returns {Object} Created patient medical history
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createPatientMedicalHistorySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  asyncHandler(patientMedicalHistoryController.createPatientMedicalHistory)
);

/**
 * @description Update patient medical history
 * @method PUT
 * @route /api/v1/patient-medical-histories/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient medical history ID (UUID)
 * @queryParams None
 * @bodyParams {string} [condition] - Condition (max 255 chars)
 * @bodyParams {string} [diagnosis_date] - Diagnosis date (ISO 8601 format)
 * @bodyParams {string} [notes] - Notes (text)
 * @returns {Object} Updated patient medical history
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Patient medical history not found
 */
router.put(
  '/:id',
  validateRequest({ params: patientMedicalHistoryIdParamsSchema, body: updatePatientMedicalHistorySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  asyncHandler(patientMedicalHistoryController.updatePatientMedicalHistory)
);

/**
 * @description Delete patient medical history (soft delete)
 * @method DELETE
 * @route /api/v1/patient-medical-histories/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient medical history ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Patient medical history not found
 */
router.delete(
  '/:id',
  validateRequest({ params: patientMedicalHistoryIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  asyncHandler(patientMedicalHistoryController.deletePatientMedicalHistory)
);

module.exports = router;
