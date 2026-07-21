/**
 * Radiology Result routes
 *
 * @module modules/radiology-result/routes
 * @description Radiology Result endpoints mounted at /api/v1/radiology-results
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const radiologyResultController = require('@controllers/radiology-result/radiology-result.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createRadiologyResultSchema,
  updateRadiologyResultSchema,
  signOffRadiologyResultSchema,
  radiologyResultIdParamsSchema,
  listRadiologyResultsQuerySchema
} = require('@validations/radiology-result/radiology-result.schema');

const RADIOLOGY_RESULT_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
  ROLES.RADIOLOGY_TECH,
  ROLES.RADIOLOGIST,
  ROLES.MEDICAL_RECORDS_CLERK];

const RADIOLOGY_RESULT_MUTATION_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.RADIOLOGY_TECH,
  ROLES.RADIOLOGIST];

/**
 * @description List radiology results with pagination and filters
 * @method GET
 * @route /api/v1/radiology-results/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=asc] - Sort order (asc/desc)
 * @queryParams {string} [radiology_order_id] - Filter by radiology order ID (UUID)
 * @queryParams {string} [status] - Filter by status (DRAFT, FINAL, AMENDED)
 * @queryParams {string} [search] - Search in report text
 * @bodyParams None
 * @returns {Object} Paginated list of radiology results
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listRadiologyResultsQuerySchema }),

  authenticate(),
  authorize(RADIOLOGY_RESULT_READ_ROLES, 'role'),
  radiologyResultController.listRadiologyResults
);

/**
 * @description Get radiology result by ID
 * @method GET
 * @route /api/v1/radiology-results/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Radiology Result ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Radiology result data
 * @throws 401 Unauthorized
 * @throws 404 Radiology result not found
 */
router.get(
  '/:id',
  validateRequest({ params: radiologyResultIdParamsSchema }),

  authenticate(),
  authorize(RADIOLOGY_RESULT_READ_ROLES, 'role'),
  radiologyResultController.getRadiologyResultById
);

/**
 * @description Create new radiology result
 * @method POST
 * @route /api/v1/radiology-results/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} radiology_order_id - Radiology order ID (required, UUID)
 * @bodyParams {string} status - Result status (required, DRAFT/FINAL/AMENDED)
 * @bodyParams {string} [report_text] - Report text (max 65535 chars)
 * @bodyParams {string} [reported_at] - Report date and time (ISO 8601 datetime)
 * @returns {Object} Created radiology result
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createRadiologyResultSchema }),

  authenticate(),
  authorize(RADIOLOGY_RESULT_MUTATION_ROLES, 'role'),
  radiologyResultController.createRadiologyResult
);

/**
 * @description Update radiology result
 * @method PUT
 * @route /api/v1/radiology-results/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Radiology Result ID (UUID)
 * @queryParams None
 * @bodyParams {string} [radiology_order_id] - Radiology order ID (UUID)
 * @bodyParams {string} [status] - Result status (DRAFT/FINAL/AMENDED)
 * @bodyParams {string} [report_text] - Report text (max 65535 chars)
 * @bodyParams {string} [reported_at] - Report date and time (ISO 8601 datetime)
 * @returns {Object} Updated radiology result
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Radiology result not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: radiologyResultIdParamsSchema, body: updateRadiologyResultSchema }),

  authenticate(),
  authorize(RADIOLOGY_RESULT_MUTATION_ROLES, 'role'),
  radiologyResultController.updateRadiologyResult
);

/**
 * @description Delete radiology result (soft delete)
 * @method DELETE
 * @route /api/v1/radiology-results/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Radiology Result ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Radiology result not found
 */
router.delete(
  '/:id',
  validateRequest({ params: radiologyResultIdParamsSchema }),

  authenticate(),
  authorize(RADIOLOGY_RESULT_MUTATION_ROLES, 'role'),
  radiologyResultController.deleteRadiologyResult
);

/**
 * @description Sign off radiology result
 * @method POST
 * @route /api/v1/radiology-results/:id/sign-off
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Radiology Result ID (UUID)
 * @bodyParams {string} [reported_at] - Sign-off timestamp (ISO 8601 datetime)
 * @bodyParams {string} [notes] - Sign-off notes
 * @returns {Object} Signed-off radiology result
 * @throws 401 Unauthorized
 * @throws 404 Radiology result not found
 */
router.post(
  '/:id/sign-off',
  validateRequest({ params: radiologyResultIdParamsSchema, body: signOffRadiologyResultSchema }),

  authenticate(),
  authorize(RADIOLOGY_RESULT_MUTATION_ROLES, 'role'),
  radiologyResultController.signOffRadiologyResult
);

module.exports = router;
