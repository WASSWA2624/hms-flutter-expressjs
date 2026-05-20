/**
 * Patient routes
 *
 * @module modules/patient/routes
 * @description Patient endpoints mounted at /api/v1/patients
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const multer = require('multer');
const router = express.Router();
const patientController = require('@controllers/patient/patient.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPatientSchema,
  updatePatientSchema,
  patientIdParamsSchema,
  listPatientsQuerySchema,
  patientWorkspaceParamsSchema,
  patientDocumentParamsSchema,
  patientDuplicateDismissParamsSchema,
  patientWorkspaceOverviewQuerySchema,
  patientWorkspaceReferenceDataQuerySchema,
  patientWorkspaceListQuerySchema,
  patientDuplicateListQuerySchema,
  patientMergePreviewSchema,
  patientMergeSchema,
  patientDuplicateDismissSchema,
  patientDocumentUploadBodySchema,
} = require('@validations/patient/patient.schema');
const { listQuerySchema } = require('@lib/validation/zod');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    files: 5,
    fileSize: 10 * 1024 * 1024,
  },
});

/**
 * @description List patients with pagination and filters
 * @method GET
 * @route /api/v1/patients/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient human-friendly ID (partial match)
 * @queryParams {string} [first_name] - Filter by first name (partial match)
 * @queryParams {string} [last_name] - Filter by last name (partial match)
 * @queryParams {string} [date_of_birth] - Filter by exact date of birth (date or datetime)
 * @queryParams {string} [date_of_birth_from] - Filter by date of birth from range start
 * @queryParams {string} [date_of_birth_to] - Filter by date of birth to range end
 * @queryParams {string} [gender] - Filter by gender (MALE, FEMALE, OTHER, UNKNOWN)
 * @queryParams {string} [contact] - Filter by linked contact value or contact human-friendly ID
 * @queryParams {string} [appointment_status] - Filter by linked appointment status
 * @queryParams {string} [created_at] - Filter by exact patient creation timestamp/date
 * @queryParams {string} [created_from] - Filter by patient creation range start
 * @queryParams {string} [created_to] - Filter by patient creation range end
 * @queryParams {string} [appointment_from] - Filter by linked appointment scheduled start range start
 * @queryParams {string} [appointment_to] - Filter by linked appointment scheduled start range end
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @queryParams {string} [search] - Deep relational search across patient and linked resources
 * @bodyParams None
 * @returns {Object} Paginated list of patients
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listPatientsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatients
);

router.get(
  '/workspace/overview',
  validateRequest({ query: patientWorkspaceOverviewQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientWorkspaceOverview
);

router.get(
  '/workspace/reference-data',
  validateRequest({ query: patientWorkspaceReferenceDataQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientWorkspaceReferenceData
);

router.get(
  '/duplicates',
  validateRequest({ query: patientDuplicateListQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listDuplicateCandidates
);

router.post(
  '/merge/preview',
  validateRequest({ body: patientMergePreviewSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.previewPatientMerge
);

router.post(
  '/merge',
  validateRequest({ body: patientMergeSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientController.mergePatients
);

router.post(
  '/duplicates/:reviewId/dismiss',
  validateRequest({
    params: patientDuplicateDismissParamsSchema,
    body: patientDuplicateDismissSchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientController.dismissDuplicateCandidate
);

router.get(
  '/:patientId/workspace',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientWorkspace
);

router.get(
  '/:patientId/timeline',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientTimeline
);

router.get(
  '/:patientId/consents',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientConsents
);

router.get(
  '/:patientId/appointments',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientAppointments
);

router.get(
  '/:patientId/visit-queue',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientVisitQueueEntries
);

router.get(
  '/:patientId/encounters',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientEncounters
);

router.get(
  '/:patientId/admissions',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientAdmissions
);

router.get(
  '/:patientId/follow-ups',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientFollowUps
);

router.get(
  '/:patientId/referrals',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientReferrals
);

router.get(
  '/:patientId/invoices',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientInvoices
);

router.get(
  '/:patientId/payments',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientPayments
);

router.get(
  '/:patientId/phi-access-logs',
  validateRequest({
    params: patientWorkspaceParamsSchema,
    query: patientWorkspaceListQuerySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.listPatientPhiAccessLogs
);

router.post(
  '/:patientId/documents/upload',
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  upload.array('files', 5),
  validateRequest({
    params: patientWorkspaceParamsSchema,
    body: patientDocumentUploadBodySchema,
  }),
  patientController.uploadPatientDocuments
);

router.get(
  '/:patientId/documents/:documentId/preview',
  validateRequest({ params: patientDocumentParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.previewPatientDocument
);

router.get(
  '/:patientId/documents/:documentId/download',
  validateRequest({ params: patientDocumentParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.downloadPatientDocument
);

/**
 * @description Get patient by ID
 * @method GET
 * @route /api/v1/patients/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Patient data
 * @throws 401 Unauthorized
 * @throws 404 Patient not found
 */
router.get(
  '/:id',
  validateRequest({ params: patientIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientById
);

/**
 * @description Get patient identifiers
 * @method GET
 * @route /api/v1/patients/:id/identifiers
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams {number} [page=1], {number} [limit=20], {string} [sort_by], {string} [order]
 * @returns {Object} Paginated list of patient identifiers
 * @throws 401 Unauthorized
 * @throws 404 Patient not found
 */
router.get(
  '/:id/identifiers',
  validateRequest({ params: patientIdParamsSchema, query: listQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientIdentifiers
);

/**
 * @description Get patient contacts
 * @method GET
 * @route /api/v1/patients/:id/contacts
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams {number} [page=1], {number} [limit=20], {string} [sort_by], {string} [order]
 * @returns {Object} Paginated list of patient contacts
 * @throws 401 Unauthorized
 * @throws 404 Patient not found
 */
router.get(
  '/:id/contacts',
  validateRequest({ params: patientIdParamsSchema, query: listQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientContacts
);

/**
 * @description Get patient guardians
 * @method GET
 * @route /api/v1/patients/:id/guardians
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams {number} [page=1], {number} [limit=20], {string} [sort_by], {string} [order]
 * @returns {Object} Paginated list of patient guardians
 * @throws 401 Unauthorized
 * @throws 404 Patient not found
 */
router.get(
  '/:id/guardians',
  validateRequest({ params: patientIdParamsSchema, query: listQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientGuardians
);

/**
 * @description Get patient allergies
 * @method GET
 * @route /api/v1/patients/:id/allergies
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams {number} [page=1], {number} [limit=20], {string} [sort_by], {string} [order]
 * @returns {Object} Paginated list of patient allergies
 * @throws 401 Unauthorized
 * @throws 404 Patient not found
 */
router.get(
  '/:id/allergies',
  validateRequest({ params: patientIdParamsSchema, query: listQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientAllergies
);

/**
 * @description Get patient medical histories
 * @method GET
 * @route /api/v1/patients/:id/medical-histories
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams {number} [page=1], {number} [limit=20], {string} [sort_by], {string} [order]
 * @returns {Object} Paginated list of patient medical histories
 * @throws 401 Unauthorized
 * @throws 404 Patient not found
 */
router.get(
  '/:id/medical-histories',
  validateRequest({ params: patientIdParamsSchema, query: listQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientMedicalHistories
);

/**
 * @description Get patient documents
 * @method GET
 * @route /api/v1/patients/:id/documents
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams {number} [page=1], {number} [limit=20], {string} [sort_by], {string} [order]
 * @returns {Object} Paginated list of patient documents
 * @throws 401 Unauthorized
 * @throws 404 Patient not found
 */
router.get(
  '/:id/documents',
  validateRequest({ params: patientIdParamsSchema, query: listQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientController.getPatientDocuments
);

/**
 * @description Create new patient
 * @method POST
 * @route /api/v1/patients/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} [tenant_id] - Tenant ID (required for global users, inferred from auth scope otherwise)
 * @bodyParams {string} [facility_id] - Facility ID (optional, inferred from auth scope for facility-scoped users)
 * @bodyParams {string} first_name - Patient first name (required, max 120 chars)
 * @bodyParams {string} [last_name] - Patient last name (max 120 chars)
 * @bodyParams {string} [date_of_birth] - Date of birth (ISO 8601 datetime)
 * @bodyParams {string} [gender] - Gender (MALE/FEMALE/OTHER/UNKNOWN)
 * @bodyParams {boolean} [is_active=true] - Active status
 * @returns {Object} Created patient
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createPatientSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientController.createPatient
);

/**
 * @description Update patient
 * @method PUT
 * @route /api/v1/patients/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [first_name] - Patient first name (max 120 chars)
 * @bodyParams {string} [last_name] - Patient last name (max 120 chars)
 * @bodyParams {string} [date_of_birth] - Date of birth (ISO 8601 datetime)
 * @bodyParams {string} [gender] - Gender (MALE/FEMALE/OTHER/UNKNOWN)
 * @bodyParams {boolean} [is_active] - Active status
 * @returns {Object} Updated patient
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Patient not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: patientIdParamsSchema, body: updatePatientSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientController.updatePatient
);

/**
 * @description Delete patient (soft delete)
 * @method DELETE
 * @route /api/v1/patients/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient ID (UUID or human-friendly ID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Patient not found
 */
router.delete(
  '/:id',
  validateRequest({ params: patientIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  patientController.deletePatient
);

module.exports = router;
