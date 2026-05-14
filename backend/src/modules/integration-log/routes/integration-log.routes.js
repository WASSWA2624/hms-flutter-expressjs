/**
 * Integration log routes
 *
 * @module modules/integration-log/routes
 * @description Express router for integration log endpoints.
 * Per module-creation.mdc: Routes define endpoints and apply middleware.
 * Per api.mdc: All endpoints follow RESTful conventions.
 * Note: This is a READ-ONLY module (only GET operations)
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const { validate } = require('@middlewares/validate.middleware');
const integrationLogController = require('@controllers/integration-log/integration-log.controller');
const {
  integrationLogIdParamsSchema,
  integrationIdParamsSchema,
  listIntegrationLogsQuerySchema,
  replayIntegrationLogSchema
} = require('@validations/integration-log/integration-log.schema');

/**
 * @description List integration logs with pagination
 * @method GET
 * @route /api/v1/integration-logs
 * @authentication Required (JWT)
 * @permissions Read integration logs
 * @urlParams None
 * @queryParams {number} page - Page number (default: 1)
 * @queryParams {number} limit - Items per page (default: 20)
 * @queryParams {string} sort_by - Sort field (default: logged_at)
 * @queryParams {string} order - Sort order: asc/desc (default: desc)
 * @queryParams {string} integration_id - Filter by integration ID
 * @queryParams {string} status - Filter by status
 * @queryParams {string} search - Search across fields
 * @bodyParams None
 * @returns {Object} Paginated list of integration logs
 * @throws 400 Invalid query parameters
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validate({ query: listIntegrationLogsQuerySchema }),
  asyncHandler(integrationLogController.listIntegrationLogs)
);

/**
 * @description Get integration log by ID
 * @method GET
 * @route /api/v1/integration-logs/:id
 * @authentication Required (JWT)
 * @permissions Read integration logs
 * @urlParams {string} id - Integration log ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Integration log object
 * @throws 400 Invalid ID format
 * @throws 401 Unauthorized
 * @throws 404 Integration log not found
 */
router.get(
  '/:id',
  validate({ params: integrationLogIdParamsSchema }),
  asyncHandler(integrationLogController.getIntegrationLog)
);

router.post(
  '/:id/replay',
  validate({ params: integrationLogIdParamsSchema, body: replayIntegrationLogSchema }),
  asyncHandler(integrationLogController.replayIntegrationLog)
);

/**
 * @description Get integration logs by integration ID
 * @method GET
 * @route /api/v1/integration-logs/integration/:integrationId
 * @authentication Required (JWT)
 * @permissions Read integration logs
 * @urlParams {string} integrationId - Integration ID (UUID)
 * @queryParams {number} page - Page number (default: 1)
 * @queryParams {number} limit - Items per page (default: 20)
 * @queryParams {string} sort_by - Sort field (default: logged_at)
 * @queryParams {string} order - Sort order: asc/desc (default: desc)
 * @bodyParams None
 * @returns {Object} Paginated list of integration logs for integration
 * @throws 400 Invalid integration ID format
 * @throws 401 Unauthorized
 */
router.get(
  '/integration/:integrationId',
  validate({ params: integrationIdParamsSchema, query: listIntegrationLogsQuerySchema }),
  asyncHandler(integrationLogController.getIntegrationLogsByIntegrationId)
);

module.exports = router;
