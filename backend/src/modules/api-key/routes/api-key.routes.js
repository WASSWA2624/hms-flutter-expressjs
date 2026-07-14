/**
 * API Key routes
 *
 * @module modules/api-key/routes
 * @description API key endpoints mounted at /api/v1/api-keys
 */

const express = require('express');
const router = express.Router();
const apiKeyController = require('@controllers/api-key/api-key.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { requireAuth } = require('@middlewares/auth.middleware');
const {
  createApiKeySchema,
  updateApiKeySchema,
  apiKeyIdParamsSchema,
  listApiKeysQuerySchema
} = require('@validations/api-key/api-key.schema');

const ADMIN_ROLE_SET = ['TENANT_ADMIN', 'FACILITY_ADMIN', 'SUPER_ADMIN', 'OPERATIONS'];

router.get(
  '/',
  validateRequest({ query: listApiKeysQuerySchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyController.listApiKeys
);

router.get(
  '/:id',
  validateRequest({ params: apiKeyIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyController.getApiKeyById
);

router.post(
  '/',
  validateRequest({ body: createApiKeySchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyController.createApiKey
);

router.put(
  '/:id',
  validateRequest({ params: apiKeyIdParamsSchema, body: updateApiKeySchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyController.updateApiKey
);

router.delete(
  '/:id',
  validateRequest({ params: apiKeyIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyController.deleteApiKey
);

module.exports = router;
