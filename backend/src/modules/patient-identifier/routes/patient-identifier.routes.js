/**
 * Patient Identifier routes
 *
 * @module modules/patient-identifier/routes
 * @description Patient Identifier endpoints mounted at /api/v1/patient-identifiers
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const patientIdentifierController = require('@controllers/patient-identifier/patient-identifier.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPatientIdentifierSchema,
  updatePatientIdentifierSchema,
  patientIdentifierIdParamsSchema,
  listPatientIdentifiersQuerySchema
} = require('@validations/patient-identifier/patient-identifier.schema');

/**
 * @description List patient identifiers with pagination and filters
 * @method GET
 * @route /api/v1/patient-identifiers/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [identifier_type] - Filter by identifier type (partial match)
 * @queryParams {string} [identifier_value] - Filter by identifier value (partial match)
 * @queryParams {string} [is_primary] - Filter by primary status (true/false)
 * @bodyParams None
 * @returns {Object} Paginated list of patient identifiers
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listPatientIdentifiersQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientIdentifierController.listPatientIdentifiers
);

/**
 * @description Get patient identifier by ID
 * @method GET
 * @route /api/v1/patient-identifiers/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Identifier ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Patient Identifier data
 * @throws 401 Unauthorized
 * @throws 404 Patient Identifier not found
 */
router.get(
  '/:id',
  validateRequest({ params: patientIdentifierIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  patientIdentifierController.getPatientIdentifierById
);

/**
 * @description Create new patient identifier
 * @method POST
 * @route /api/v1/patient-identifiers/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} identifier_type - Identifier type (required, max 80 chars)
 * @bodyParams {string} identifier_value - Identifier value (required, max 120 chars)
 * @bodyParams {boolean} [is_primary=false] - Primary identifier flag
 * @returns {Object} Created patient identifier
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation (duplicate identifier_value in tenant)
 */
router.post(
  '/',
  validateRequest({ body: createPatientIdentifierSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientIdentifierController.createPatientIdentifier
);

/**
 * @description Update patient identifier
 * @method PUT
 * @route /api/v1/patient-identifiers/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Identifier ID (UUID)
 * @queryParams None
 * @bodyParams {string} [identifier_type] - Identifier type (max 80 chars)
 * @bodyParams {string} [identifier_value] - Identifier value (max 120 chars)
 * @bodyParams {boolean} [is_primary] - Primary identifier flag
 * @returns {Object} Updated patient identifier
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Patient Identifier not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: patientIdentifierIdParamsSchema, body: updatePatientIdentifierSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  patientIdentifierController.updatePatientIdentifier
);

/**
 * @description Delete patient identifier (soft delete)
 * @method DELETE
 * @route /api/v1/patient-identifiers/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient Identifier ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Patient Identifier not found
 */
router.delete(
  '/:id',
  validateRequest({ params: patientIdentifierIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  patientIdentifierController.deletePatientIdentifier
);

module.exports = router;
