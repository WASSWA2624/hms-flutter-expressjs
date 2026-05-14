/**
 * Integration routes
 *
 * @module modules/integration/routes
 * @description Express router for integration endpoints.
 * Per module-creation.mdc: Routes define endpoints and apply middleware.
 * Per api.mdc: All endpoints follow RESTful conventions.
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const { validate } = require('@middlewares/validate.middleware');
const integrationController = require('@controllers/integration/integration.controller');
const {
  createIntegrationSchema,
  updateIntegrationSchema,
  testConnectionSchema,
  syncNowSchema,
  integrationIdParamsSchema,
  listIntegrationsQuerySchema
} = require('@validations/integration/integration.schema');

/**
 * @description List integrations with pagination
 * @method GET
 * @route /api/v1/integrations
 * @authentication Required (JWT)
 * @permissions Read integrations
 * @urlParams None
 * @queryParams {number} page - Page number (default: 1)
 * @queryParams {number} limit - Items per page (default: 20)
 * @queryParams {string} sort_by - Sort field (default: created_at)
 * @queryParams {string} order - Sort order: asc/desc (default: desc)
 * @queryParams {string} tenant_id - Filter by tenant ID
 * @queryParams {string} integration_type - Filter by integration type
 * @queryParams {string} status - Filter by status
 * @queryParams {string} name - Filter by name (partial match)
 * @queryParams {string} search - Search across fields
 * @bodyParams None
 * @returns {Object} Paginated list of integrations
 * @throws 400 Invalid query parameters
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validate({ query: listIntegrationsQuerySchema }),
  asyncHandler(integrationController.listIntegrations)
);

/**
 * @description Get integration by ID
 * @method GET
 * @route /api/v1/integrations/:id
 * @authentication Required (JWT)
 * @permissions Read integrations
 * @urlParams {string} id - Integration ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Integration object
 * @throws 400 Invalid ID format
 * @throws 401 Unauthorized
 * @throws 404 Integration not found
 */
router.get(
  '/:id',
  validate({ params: integrationIdParamsSchema }),
  asyncHandler(integrationController.getIntegration)
);

router.post(
  '/:id/test-connection',
  validate({ params: integrationIdParamsSchema, body: testConnectionSchema }),
  asyncHandler(integrationController.testIntegrationConnection)
);

router.post(
  '/:id/sync-now',
  validate({ params: integrationIdParamsSchema, body: syncNowSchema }),
  asyncHandler(integrationController.syncIntegrationNow)
);

/**
 * @description Create new integration
 * @method POST
 * @route /api/v1/integrations
 * @authentication Required (JWT)
 * @permissions Create integrations
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (UUID)
 * @bodyParams {string} integration_type - Integration type (HL7, FHIR, LAB, RADIOLOGY, BILLING, OTHER)
 * @bodyParams {string} status - Status (ACTIVE, INACTIVE, ERROR)
 * @bodyParams {string} name - Integration name (max 120 chars)
 * @bodyParams {Object} config_json - Configuration JSON (optional)
 * @returns {Object} Created integration
 * @throws 400 Validation error
 * @throws 401 Unauthorized
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',
  validate({ body: createIntegrationSchema }),
  asyncHandler(integrationController.createIntegration)
);

/**
 * @description Update integration
 * @method PUT
 * @route /api/v1/integrations/:id
 * @authentication Required (JWT)
 * @permissions Update integrations
 * @urlParams {string} id - Integration ID (UUID)
 * @queryParams None
 * @bodyParams {string} integration_type - Integration type (optional)
 * @bodyParams {string} status - Status (optional)
 * @bodyParams {string} name - Integration name (optional)
 * @bodyParams {Object} config_json - Configuration JSON (optional)
 * @returns {Object} Updated integration
 * @throws 400 Validation error
 * @throws 401 Unauthorized
 * @throws 404 Integration not found
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validate({ params: integrationIdParamsSchema, body: updateIntegrationSchema }),
  asyncHandler(integrationController.updateIntegration)
);

/**
 * @description Delete integration (soft delete)
 * @method DELETE
 * @route /api/v1/integrations/:id
 * @authentication Required (JWT)
 * @permissions Delete integrations
 * @urlParams {string} id - Integration ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 400 Invalid ID format
 * @throws 401 Unauthorized
 * @throws 404 Integration not found
 */
router.delete(
  '/:id',
  validate({ params: integrationIdParamsSchema }),
  asyncHandler(integrationController.deleteIntegration)
);

module.exports = router;
