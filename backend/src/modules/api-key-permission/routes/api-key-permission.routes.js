/**
 * API Key Permission routes
 *
 * @module modules/api-key-permission/routes
 * @description API key permission endpoints mounted at /api/v1/api-key-permissions
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const apiKeyPermissionController = require('@controllers/api-key-permission/api-key-permission.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createApiKeyPermissionSchema,
  updateApiKeyPermissionSchema,
  apiKeyPermissionIdParamsSchema,
  listApiKeyPermissionsQuerySchema
} = require('@validations/api-key-permission/api-key-permission.schema');

/**
 * @description List API key permissions with pagination and filters
 * @method GET
 * @route /api/v1/api-key-permissions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [api_key_id] - Filter by API key ID (UUID)
 * @queryParams {string} [permission_id] - Filter by permission ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of API key permissions
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listApiKeyPermissionsQuerySchema }),

  authenticate(),
  apiKeyPermissionController.listApiKeyPermissions
);

/**
 * @description Get API key permission by ID
 * @method GET
 * @route /api/v1/api-key-permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - API key permission ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} API key permission data
 * @throws 401 Unauthorized
 * @throws 404 API key permission not found
 */
router.get(
  '/:id',  validateRequest({ params: apiKeyPermissionIdParamsSchema }),

  authenticate(),
  apiKeyPermissionController.getApiKeyPermissionById
);

/**
 * @description Create new API key permission
 * @method POST
 * @route /api/v1/api-key-permissions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} api_key_id - API key ID (required, UUID)
 * @bodyParams {string} permission_id - Permission ID (required, UUID)
 * @returns {Object} Created API key permission
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation (duplicate assignment)
 */
router.post(
  '/',  validateRequest({ body: createApiKeyPermissionSchema }),

  authenticate(),
  apiKeyPermissionController.createApiKeyPermission
);

/**
 * @description Update API key permission
 * @method PUT
 * @route /api/v1/api-key-permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - API key permission ID (UUID)
 * @queryParams None
 * @bodyParams {string} [api_key_id] - API key ID (UUID)
 * @bodyParams {string} [permission_id] - Permission ID (UUID)
 * @returns {Object} Updated API key permission
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 API key permission not found
 */
router.put(
  '/:id',  validateRequest({ params: apiKeyPermissionIdParamsSchema, body: updateApiKeyPermissionSchema }),

  authenticate(),
  apiKeyPermissionController.updateApiKeyPermission
);

/**
 * @description Delete API key permission (soft delete)
 * @method DELETE
 * @route /api/v1/api-key-permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - API key permission ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 API key permission not found
 */
router.delete(
  '/:id',  validateRequest({ params: apiKeyPermissionIdParamsSchema }),

  authenticate(),
  apiKeyPermissionController.deleteApiKeyPermission
);

module.exports = router;
