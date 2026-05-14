/**
 * Consent routes
 *
 * @module modules/consent/routes
 * @description Consent endpoints mounted at /api/v1/consents
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const consentController = require('@controllers/consent/consent.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createConsentSchema,
  updateConsentSchema,
  consentIdParamsSchema,
  listConsentsQuerySchema
} = require('@validations/consent/consent.schema');

/**
 * @description List consents with pagination and filters
 * @method GET
 * @route /api/v1/consents/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [consent_type] - Filter by consent type (TREATMENT, DATA_SHARING, RESEARCH, BILLING, OTHER)
 * @queryParams {string} [status] - Filter by status (GRANTED, REVOKED, PENDING)
 * @bodyParams None
 * @returns {Object} Paginated list of consents
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listConsentsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  consentController.listConsents
);

/**
 * @description Get consent by ID
 * @method GET
 * @route /api/v1/consents/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Consent ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Consent data
 * @throws 401 Unauthorized
 * @throws 404 Consent not found
 */
router.get(
  '/:id',
  validateRequest({ params: consentIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_READ, 'permission'),
  consentController.getConsentById
);

/**
 * @description Create new consent
 * @method POST
 * @route /api/v1/consents/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} consent_type - Consent type (required, TREATMENT/DATA_SHARING/RESEARCH/BILLING/OTHER)
 * @bodyParams {string} status - Status (required, GRANTED/REVOKED/PENDING)
 * @bodyParams {string} [granted_at] - Granted timestamp (ISO datetime)
 * @bodyParams {string} [revoked_at] - Revoked timestamp (ISO datetime)
 * @returns {Object} Created consent
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createConsentSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  consentController.createConsent
);

/**
 * @description Update consent
 * @method PUT
 * @route /api/v1/consents/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Consent ID (UUID)
 * @queryParams None
 * @bodyParams {string} [consent_type] - Consent type (TREATMENT/DATA_SHARING/RESEARCH/BILLING/OTHER)
 * @bodyParams {string} [status] - Status (GRANTED/REVOKED/PENDING)
 * @bodyParams {string} [granted_at] - Granted timestamp (ISO datetime)
 * @bodyParams {string} [revoked_at] - Revoked timestamp (ISO datetime)
 * @returns {Object} Updated consent
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Consent not found
 */
router.put(
  '/:id',
  validateRequest({ params: consentIdParamsSchema, body: updateConsentSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_WRITE, 'permission'),
  consentController.updateConsent
);

/**
 * @description Delete consent (soft delete)
 * @method DELETE
 * @route /api/v1/consents/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Consent ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Consent not found
 */
router.delete(
  '/:id',
  validateRequest({ params: consentIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.PATIENT_DELETE, 'permission'),
  consentController.deleteConsent
);

module.exports = router;
