/**
 * API Key routes
 *
 * @module modules/api-key/routes
 * @description API key endpoints mounted at /api/v1/api-keys
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const apiKeyController = require('@controllers/api-key/api-key.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createApiKeySchema,
  updateApiKeySchema,
  apiKeyIdParamsSchema,
  listApiKeysQuerySchema
} = require('@validations/api-key/api-key.schema');

/**
 * @description List API keys with pagination and filters
 * @method GET
 * @route /api/v1/api-keys/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [user_id] - Filter by user ID (UUID)
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @queryParams {string} [search] - Search in API key name
 * @bodyParams None
 * @returns {Object} Paginated list of API keys (without key_hash)
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listApiKeysQuerySchema }),

  authenticate(),
  apiKeyController.listApiKeys
);

/**
 * @description Get API key by ID
 * @method GET
 * @route /api/v1/api-keys/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - API key ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} API key data (without key_hash)
 * @throws 401 Unauthorized
 * @throws 404 API key not found
 */
router.get(
  '/:id',  validateRequest({ params: apiKeyIdParamsSchema }),

  authenticate(),
  apiKeyController.getApiKeyById
);

/**
 * @description Create new API key
 * @method POST
 * @route /api/v1/api-keys/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} user_id - User ID (required, UUID)
 * @bodyParams {string} name - API key name (required, max 120 chars)
 * @bodyParams {string} [expires_at] - Expiration date (ISO 8601 format)
 * @returns {Object} Created API key with plain key (only shown once)
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createApiKeySchema }),

  authenticate(),
  apiKeyController.createApiKey
);

/**
 * @description Update API key
 * @method PUT
 * @route /api/v1/api-keys/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - API key ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - API key name (max 120 chars)
 * @bodyParams {boolean} [is_active] - Active status
 * @bodyParams {string} [expires_at] - Expiration date (ISO 8601 format)
 * @returns {Object} Updated API key (without key_hash)
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 API key not found
 */
router.put(
  '/:id',  validateRequest({ params: apiKeyIdParamsSchema, body: updateApiKeySchema }),

  authenticate(),
  apiKeyController.updateApiKey
);

/**
 * @description Delete API key (soft delete)
 * @method DELETE
 * @route /api/v1/api-keys/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - API key ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 API key not found
 */
router.delete(
  '/:id',  validateRequest({ params: apiKeyIdParamsSchema }),

  authenticate(),
  apiKeyController.deleteApiKey
);

module.exports = router;
