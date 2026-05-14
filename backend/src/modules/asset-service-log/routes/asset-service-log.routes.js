/**
 * Asset service log routes
 *
 * @module modules/asset-service-log/routes
 * @description Asset service log endpoints mounted at /api/v1/asset-service-logs
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const assetServiceLogController = require('@controllers/asset-service-log/asset-service-log.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createAssetServiceLogSchema,
  updateAssetServiceLogSchema,
  assetServiceLogIdParamsSchema,
  listAssetServiceLogsQuerySchema
} = require('@validations/asset-service-log/asset-service-log.schema');

/**
 * @description List asset service logs with pagination and filters
 * @method GET
 * @route /api/v1/asset-service-logs/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [asset_id] - Filter by asset ID (UUID)
 * @queryParams {string} [search] - Search in notes field
 * @bodyParams None
 * @returns {Object} Paginated list of asset service logs
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAssetServiceLogsQuerySchema }),

  authenticate(),
  assetServiceLogController.listAssetServiceLogs
);

/**
 * @description Get asset service log by ID
 * @method GET
 * @route /api/v1/asset-service-logs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Asset service log ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Asset service log data
 * @throws 401 Unauthorized
 * @throws 404 Asset service log not found
 */
router.get(
  '/:id',  validateRequest({ params: assetServiceLogIdParamsSchema }),

  authenticate(),
  assetServiceLogController.getAssetServiceLogById
);

/**
 * @description Create new asset service log
 * @method POST
 * @route /api/v1/asset-service-logs/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} asset_id - Asset ID (required, UUID)
 * @bodyParams {string} [serviced_at] - Service datetime (optional, ISO 8601)
 * @bodyParams {string} [notes] - Service notes (optional)
 * @returns {Object} Created asset service log
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAssetServiceLogSchema }),

  authenticate(),
  assetServiceLogController.createAssetServiceLog
);

/**
 * @description Update asset service log
 * @method PUT
 * @route /api/v1/asset-service-logs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Asset service log ID (UUID)
 * @queryParams None
 * @bodyParams {string} [serviced_at] - Service datetime (optional, ISO 8601)
 * @bodyParams {string} [notes] - Service notes (optional)
 * @returns {Object} Updated asset service log
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Asset service log not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: assetServiceLogIdParamsSchema, body: updateAssetServiceLogSchema }),

  authenticate(),
  assetServiceLogController.updateAssetServiceLog
);

/**
 * @description Delete asset service log (soft delete)
 * @method DELETE
 * @route /api/v1/asset-service-logs/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Asset service log ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Asset service log not found
 */
router.delete(
  '/:id',  validateRequest({ params: assetServiceLogIdParamsSchema }),

  authenticate(),
  assetServiceLogController.deleteAssetServiceLog
);

module.exports = router;
