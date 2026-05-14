/**
 * Discharge summary routes
 *
 * @module modules/discharge-summary/routes
 * @description Discharge summary endpoints mounted at /api/v1/discharge-summaries
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const dischargeSummaryController = require('@controllers/discharge-summary/discharge-summary.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createDischargeSummarySchema,
  updateDischargeSummarySchema,
  finalizeDischargeSummarySchema,
  dischargeSummaryIdParamsSchema,
  listDischargeSummariesQuerySchema
} = require('@validations/discharge-summary/discharge-summary.schema');

const IPD_READ_SCOPES = [PERMISSIONS.CLINICAL_READ];
const IPD_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];
const IPD_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List discharge summaries with pagination and filters
 * @method GET
 * @route /api/v1/discharge-summaries/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [admission_id] - Filter by admission ID (UUID)
 * @queryParams {string} [status] - Filter by discharge status (PLANNED, COMPLETED, CANCELLED)
 * @bodyParams None
 * @returns {Object} Paginated list of discharge summaries
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listDischargeSummariesQuerySchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  dischargeSummaryController.listDischargeSummaries
);

/**
 * @description Get discharge summary by ID
 * @method GET
 * @route /api/v1/discharge-summaries/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Discharge summary ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Discharge summary data
 * @throws 401 Unauthorized
 * @throws 404 Discharge summary not found
 */
router.get(
  '/:id',  validateRequest({ params: dischargeSummaryIdParamsSchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  dischargeSummaryController.getDischargeSummaryById
);

/**
 * @description Create new discharge summary
 * @method POST
 * @route /api/v1/discharge-summaries/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} admission_id - Admission ID (required, UUID)
 * @bodyParams {string} summary - Discharge summary content (required, max 65535 chars)
 * @bodyParams {string} status - Discharge status (required, enum: PLANNED, COMPLETED, CANCELLED)
 * @bodyParams {string} [discharged_at] - Discharge timestamp (optional, ISO 8601 datetime)
 * @returns {Object} Created discharge summary
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createDischargeSummarySchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  dischargeSummaryController.createDischargeSummary
);

/**
 * @description Update discharge summary
 * @method PUT
 * @route /api/v1/discharge-summaries/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Discharge summary ID (UUID)
 * @queryParams None
 * @bodyParams {string} [summary] - Discharge summary content (max 65535 chars)
 * @bodyParams {string} [status] - Discharge status (enum: PLANNED, COMPLETED, CANCELLED)
 * @bodyParams {string} [discharged_at] - Discharge timestamp (ISO 8601 datetime)
 * @returns {Object} Updated discharge summary
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Discharge summary not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: dischargeSummaryIdParamsSchema, body: updateDischargeSummarySchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  dischargeSummaryController.updateDischargeSummary
);

/**
 * @description Delete discharge summary (soft delete)
 * @method DELETE
 * @route /api/v1/discharge-summaries/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Discharge summary ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Discharge summary not found
 */
router.delete(
  '/:id',  validateRequest({ params: dischargeSummaryIdParamsSchema }),

  authenticate(),
  authorize(IPD_ADMIN_SCOPES, 'permission'),
  dischargeSummaryController.deleteDischargeSummary
);

/**
 * @description Finalize discharge summary
 * @method POST
 * @route /api/v1/discharge-summaries/:id/finalize
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Discharge summary ID (UUID)
 * @bodyParams {string} [discharged_at] - Final discharge timestamp
 * @bodyParams {string} [notes] - Finalization notes
 * @returns {Object} Updated discharge summary
 * @throws 401 Unauthorized
 * @throws 404 Discharge summary not found
 */
router.post(
  '/:id/finalize',
  validateRequest({ params: dischargeSummaryIdParamsSchema, body: finalizeDischargeSummarySchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  dischargeSummaryController.finalizeDischargeSummary
);

module.exports = router;
