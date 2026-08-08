/**
 * API Key Permission routes
 *
 * @module modules/api-key-permission/routes
 * @description API key permission endpoints mounted at /api/v1/api-key-permissions
 */

const express = require('express');
const router = express.Router();
const apiKeyPermissionController = require('@controllers/api-key-permission/api-key-permission.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { requireAuth } = require('@middlewares/auth.middleware');
const {
  createApiKeyPermissionSchema,
  updateApiKeyPermissionSchema,
  apiKeyPermissionIdParamsSchema,
  listApiKeyPermissionsQuerySchema
} = require('@validations/api-key-permission/api-key-permission.schema');

const ADMIN_ROLE_SET = ['TENANT_ADMIN', 'FACILITY_ADMIN', 'PLATFORM_ADMIN', 'OPERATIONS'];

router.get(
  '/',
  validateRequest({ query: listApiKeyPermissionsQuerySchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyPermissionController.listApiKeyPermissions
);

router.get(
  '/:id',
  validateRequest({ params: apiKeyPermissionIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyPermissionController.getApiKeyPermissionById
);

router.post(
  '/',
  validateRequest({ body: createApiKeyPermissionSchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyPermissionController.createApiKeyPermission
);

router.put(
  '/:id',
  validateRequest({ params: apiKeyPermissionIdParamsSchema, body: updateApiKeyPermissionSchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyPermissionController.updateApiKeyPermission
);

router.delete(
  '/:id',
  validateRequest({ params: apiKeyPermissionIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  apiKeyPermissionController.deleteApiKeyPermission
);

module.exports = router;
