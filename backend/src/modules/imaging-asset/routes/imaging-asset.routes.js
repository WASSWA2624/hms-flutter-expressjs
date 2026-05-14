/**
 * Imaging asset routes
 *
 * @module modules/imaging-asset/routes
 * @description Imaging asset endpoints mounted at /api/v1/imaging-assets
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const imagingAssetController = require('@controllers/imaging-asset/imaging-asset.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createImagingAssetSchema,
  updateImagingAssetSchema,
  imagingAssetIdParamsSchema,
  listImagingAssetsQuerySchema
} = require('@validations/imaging-asset/imaging-asset.schema');

/**
 * @description List imaging assets with pagination and filters
 * @method GET
 * @route /api/v1/imaging-assets/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [imaging_study_id] - Filter by imaging study ID (UUID)
 * @queryParams {string} [content_type] - Filter by content type (partial match)
 * @bodyParams None
 * @returns {Object} Paginated list of imaging assets
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listImagingAssetsQuerySchema }),

  authenticate(),
  imagingAssetController.listImagingAssets
);

/**
 * @description Get imaging asset by ID
 * @method GET
 * @route /api/v1/imaging-assets/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Imaging asset ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Imaging asset data
 * @throws 401 Unauthorized
 * @throws 404 Imaging asset not found
 */
router.get(
  '/:id',  validateRequest({ params: imagingAssetIdParamsSchema }),

  authenticate(),
  imagingAssetController.getImagingAssetById
);

/**
 * @description Create new imaging asset (upload)
 * @method POST
 * @route /api/v1/imaging-assets/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} imaging_study_id - Imaging study ID (required, UUID)
 * @bodyParams {string} storage_key - Storage key path (required, max 255 chars)
 * @bodyParams {string} [file_name] - File name (max 255 chars)
 * @bodyParams {string} [content_type] - Content type (max 120 chars)
 * @returns {Object} Created imaging asset
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createImagingAssetSchema }),

  authenticate(),
  imagingAssetController.createImagingAsset
);

/**
 * @description Update imaging asset
 * @method PUT
 * @route /api/v1/imaging-assets/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Imaging asset ID (UUID)
 * @queryParams None
 * @bodyParams {string} [file_name] - File name (max 255 chars)
 * @bodyParams {string} [content_type] - Content type (max 120 chars)
 * @returns {Object} Updated imaging asset
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Imaging asset not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: imagingAssetIdParamsSchema, body: updateImagingAssetSchema }),

  authenticate(),
  imagingAssetController.updateImagingAsset
);

/**
 * @description Delete imaging asset (soft delete)
 * @method DELETE
 * @route /api/v1/imaging-assets/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Imaging asset ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Imaging asset not found
 */
router.delete(
  '/:id',  validateRequest({ params: imagingAssetIdParamsSchema }),

  authenticate(),
  imagingAssetController.deleteImagingAsset
);

module.exports = router;
