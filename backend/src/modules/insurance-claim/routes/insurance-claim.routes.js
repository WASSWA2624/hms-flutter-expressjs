/**
 * Insurance claim routes
 *
 * @module modules/insurance-claim/routes
 * @description Insurance claim endpoints mounted at /api/v1/insurance-claims
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const insuranceClaimController = require('@controllers/insurance-claim/insurance-claim.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createInsuranceClaimSchema,
  updateInsuranceClaimSchema,
  submitInsuranceClaimSchema,
  reconcileInsuranceClaimSchema,
  insuranceClaimIdParamsSchema,
  listInsuranceClaimsQuerySchema
} = require('@validations/insurance-claim/insurance-claim.schema');

/**
 * @description List insurance claims with pagination and filters
 * @method GET
 * @route /api/v1/insurance-claims/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [coverage_plan_id] - Filter by coverage plan ID (UUID)
 * @queryParams {string} [invoice_id] - Filter by invoice ID (UUID)
 * @queryParams {string} [status] - Filter by status (SUBMITTED/APPROVED/REJECTED/PAID/CANCELLED)
 * @queryParams {string} [submitted_at_from] - Filter by submitted date from (ISO 8601 datetime)
 * @queryParams {string} [submitted_at_to] - Filter by submitted date to (ISO 8601 datetime)
 * @bodyParams None
 * @returns {Object} Paginated list of insurance claims
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listInsuranceClaimsQuerySchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  insuranceClaimController.listInsuranceClaims
);

/**
 * @description Get insurance claim by ID
 * @method GET
 * @route /api/v1/insurance-claims/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Insurance claim ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Insurance claim data
 * @throws 401 Unauthorized
 * @throws 404 Insurance claim not found
 */
router.get(
  '/:id',
  validateRequest({ params: insuranceClaimIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  insuranceClaimController.getInsuranceClaimById
);

/**
 * @description Create new insurance claim
 * @method POST
 * @route /api/v1/insurance-claims/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} coverage_plan_id - Coverage plan ID (required, UUID)
 * @bodyParams {string} invoice_id - Invoice ID (required, UUID)
 * @bodyParams {string} [status=SUBMITTED] - Claim status (SUBMITTED/APPROVED/REJECTED/PAID/CANCELLED)
 * @bodyParams {string} [submitted_at] - Submission date/time (ISO 8601 datetime)
 * @returns {Object} Created insurance claim
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createInsuranceClaimSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insuranceClaimController.createInsuranceClaim
);

/**
 * @description Update insurance claim
 * @method PUT
 * @route /api/v1/insurance-claims/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Insurance claim ID (UUID)
 * @queryParams None
 * @bodyParams {string} [coverage_plan_id] - Coverage plan ID (UUID)
 * @bodyParams {string} [invoice_id] - Invoice ID (UUID)
 * @bodyParams {string} [status] - Claim status (SUBMITTED/APPROVED/REJECTED/PAID/CANCELLED)
 * @bodyParams {string} [submitted_at] - Submission date/time (ISO 8601 datetime)
 * @returns {Object} Updated insurance claim
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Insurance claim not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: insuranceClaimIdParamsSchema, body: updateInsuranceClaimSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insuranceClaimController.updateInsuranceClaim
);

/**
 * @description Delete insurance claim (soft delete)
 * @method DELETE
 * @route /api/v1/insurance-claims/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Insurance claim ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Insurance claim not found
 */
router.delete(
  '/:id',
  validateRequest({ params: insuranceClaimIdParamsSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insuranceClaimController.deleteInsuranceClaim
);

/**
 * @description Submit insurance claim
 * @method POST
 * @route /api/v1/insurance-claims/:id/submit
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Insurance claim ID (UUID)
 * @bodyParams {string} [submitted_at] - Submission timestamp
 * @bodyParams {string} [notes] - Submission notes
 * @returns {Object} Updated insurance claim
 * @throws 401 Unauthorized
 * @throws 404 Insurance claim not found
 */
router.post(
  '/:id/submit',
  validateRequest({ params: insuranceClaimIdParamsSchema, body: submitInsuranceClaimSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insuranceClaimController.submitInsuranceClaim
);

/**
 * @description Reconcile insurance claim
 * @method POST
 * @route /api/v1/insurance-claims/:id/reconcile
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Insurance claim ID (UUID)
 * @bodyParams {string} [status] - Reconciled status (APPROVED/REJECTED/PAID)
 * @bodyParams {string} [notes] - Reconciliation notes
 * @returns {Object} Updated insurance claim
 * @throws 401 Unauthorized
 * @throws 404 Insurance claim not found
 */
router.post(
  '/:id/reconcile',
  validateRequest({ params: insuranceClaimIdParamsSchema, body: reconcileInsuranceClaimSchema }),

  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insuranceClaimController.reconcileInsuranceClaim
);

module.exports = router;
