/**
 * Asset routes
 *
 * @module modules/asset/routes
 * @description Asset endpoints mounted at /api/v1/assets
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const assetController = require('@controllers/asset/asset.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createAssetSchema,
  updateAssetSchema,
  assetIdParamsSchema,
  listAssetsQuerySchema
} = require('@validations/asset/asset.schema');

/**
 * @description List assets with pagination and filters
 * @method GET
 * @route /api/v1/assets/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [name] - Filter by asset name (partial match)
 * @queryParams {string} [asset_tag] - Filter by asset tag (partial match)
 * @queryParams {string} [status] - Filter by status (OPEN, IN_PROGRESS, COMPLETED, CANCELLED)
 * @queryParams {string} [search] - Search in name and asset_tag fields
 * @bodyParams None
 * @returns {Object} Paginated list of assets
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAssetsQuerySchema }),

  authenticate(),
  assetController.listAssets
);

/**
 * @description Get asset by ID
 * @method GET
 * @route /api/v1/assets/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Asset ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Asset data
 * @throws 401 Unauthorized
 * @throws 404 Asset not found
 */
router.get(
  '/:id',  validateRequest({ params: assetIdParamsSchema }),

  authenticate(),
  assetController.getAssetById
);

/**
 * @description Create new asset
 * @method POST
 * @route /api/v1/assets/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (optional, UUID)
 * @bodyParams {string} name - Asset name (required, max 255 chars)
 * @bodyParams {string} [asset_tag] - Asset tag (optional, max 80 chars)
 * @bodyParams {string} status - Status (required, OPEN, IN_PROGRESS, COMPLETED, CANCELLED)
 * @returns {Object} Created asset
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAssetSchema }),

  authenticate(),
  assetController.createAsset
);

/**
 * @description Update asset
 * @method PUT
 * @route /api/v1/assets/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Asset ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (optional, UUID)
 * @bodyParams {string} [name] - Asset name (optional, max 255 chars)
 * @bodyParams {string} [asset_tag] - Asset tag (optional, max 80 chars)
 * @bodyParams {string} [status] - Status (optional, OPEN, IN_PROGRESS, COMPLETED, CANCELLED)
 * @returns {Object} Updated asset
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Asset not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: assetIdParamsSchema, body: updateAssetSchema }),

  authenticate(),
  assetController.updateAsset
);

/**
 * @description Delete asset (soft delete)
 * @method DELETE
 * @route /api/v1/assets/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Asset ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Asset not found
 */
router.delete(
  '/:id',  validateRequest({ params: assetIdParamsSchema }),

  authenticate(),
  assetController.deleteAsset
);

module.exports = router;
