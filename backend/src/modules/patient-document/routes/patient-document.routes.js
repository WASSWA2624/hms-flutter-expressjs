/**
 * Patient Document routes
 *
 * @module modules/patient-document/routes
 * @description Patient document endpoints mounted at /api/v1/patient-documents
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const patientDocumentController = require('@controllers/patient-document/patient-document.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPatientDocumentSchema,
  updatePatientDocumentSchema,
  patientDocumentIdParamsSchema,
  listPatientDocumentsQuerySchema
} = require('@validations/patient-document/patient-document.schema');

/**
 * @description List patient documents with pagination and filters
 * @method GET
 * @route /api/v1/patient-documents/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [document_type] - Filter by document type
 * @queryParams {string} [search] - Search in document type and file name fields
 * @bodyParams None
 * @returns {Object} Paginated list of patient documents
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listPatientDocumentsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  asyncHandler(patientDocumentController.listPatientDocuments)
);

/**
 * @description Get patient document by ID
 * @method GET
 * @route /api/v1/patient-documents/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient document ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Patient document data
 * @throws 401 Unauthorized
 * @throws 404 Patient document not found
 */
router.get(
  '/:id',
  validateRequest({ params: patientDocumentIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  asyncHandler(patientDocumentController.getPatientDocumentById)
);

/**
 * @description Upload patient document
 * @method POST
 * @route /api/v1/patient-documents/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} document_type - Document type (required, max 120 chars)
 * @bodyParams {string} storage_key - Storage key (required, max 255 chars)
 * @bodyParams {string} [file_name] - File name (max 255 chars)
 * @bodyParams {string} [content_type] - Content type (max 120 chars)
 * @returns {Object} Created patient document
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createPatientDocumentSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  asyncHandler(patientDocumentController.createPatientDocument)
);

/**
 * @description Update patient document
 * @method PUT
 * @route /api/v1/patient-documents/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient document ID (UUID)
 * @queryParams None
 * @bodyParams {string} [document_type] - Document type (max 120 chars)
 * @bodyParams {string} [storage_key] - Storage key (max 255 chars)
 * @bodyParams {string} [file_name] - File name (max 255 chars)
 * @bodyParams {string} [content_type] - Content type (max 120 chars)
 * @returns {Object} Updated patient document
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Patient document not found
 */
router.put(
  '/:id',
  validateRequest({ params: patientDocumentIdParamsSchema, body: updatePatientDocumentSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  asyncHandler(patientDocumentController.updatePatientDocument)
);

/**
 * @description Delete patient document (soft delete)
 * @method DELETE
 * @route /api/v1/patient-documents/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient document ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Patient document not found
 */
router.delete(
  '/:id',
  validateRequest({ params: patientDocumentIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  asyncHandler(patientDocumentController.deletePatientDocument)
);

module.exports = router;
