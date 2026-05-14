/**
 * Patient Allergy routes
 *
 * @module modules/patient-allergy/routes
 * @description Patient allergy endpoints mounted at /api/v1/patient-allergies
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const patientAllergyController = require('@controllers/patient-allergy/patient-allergy.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPatientAllergySchema,
  updatePatientAllergySchema,
  patientAllergyIdParamsSchema,
  listPatientAllergiesQuerySchema
} = require('@validations/patient-allergy/patient-allergy.schema');

/**
 * @description List patient allergies with pagination and filters
 * @method GET
 * @route /api/v1/patient-allergies/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [allergen] - Filter by allergen (partial match)
 * @queryParams {string} [severity] - Filter by severity (MILD, MODERATE, SEVERE)
 * @queryParams {string} [search] - Search in allergen and reaction fields
 * @bodyParams None
 * @returns {Object} Paginated list of patient allergies
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listPatientAllergiesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  asyncHandler(patientAllergyController.listPatientAllergies)
);

/**
 * @description Get patient allergy by ID
 * @method GET
 * @route /api/v1/patient-allergies/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient allergy ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Patient allergy data
 * @throws 401 Unauthorized
 * @throws 404 Patient allergy not found
 */
router.get(
  '/:id',
  validateRequest({ params: patientAllergyIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  asyncHandler(patientAllergyController.getPatientAllergyById)
);

/**
 * @description Create new patient allergy
 * @method POST
 * @route /api/v1/patient-allergies/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} allergen - Allergen (required, max 255 chars)
 * @bodyParams {string} severity - Severity (required, MILD/MODERATE/SEVERE)
 * @bodyParams {string} [reaction] - Reaction (max 255 chars)
 * @bodyParams {string} [notes] - Notes (text)
 * @returns {Object} Created patient allergy
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createPatientAllergySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  asyncHandler(patientAllergyController.createPatientAllergy)
);

/**
 * @description Update patient allergy
 * @method PUT
 * @route /api/v1/patient-allergies/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient allergy ID (UUID)
 * @queryParams None
 * @bodyParams {string} [allergen] - Allergen (max 255 chars)
 * @bodyParams {string} [severity] - Severity (MILD/MODERATE/SEVERE)
 * @bodyParams {string} [reaction] - Reaction (max 255 chars)
 * @bodyParams {string} [notes] - Notes (text)
 * @returns {Object} Updated patient allergy
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Patient allergy not found
 */
router.put(
  '/:id',
  validateRequest({ params: patientAllergyIdParamsSchema, body: updatePatientAllergySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  asyncHandler(patientAllergyController.updatePatientAllergy)
);

/**
 * @description Delete patient allergy (soft delete)
 * @method DELETE
 * @route /api/v1/patient-allergies/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Patient allergy ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Patient allergy not found
 */
router.delete(
  '/:id',
  validateRequest({ params: patientAllergyIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  asyncHandler(patientAllergyController.deletePatientAllergy)
);

module.exports = router;
