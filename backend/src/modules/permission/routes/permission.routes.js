/**
 * Permission routes
 *
 * @module modules/permission/routes
 * @description Permission endpoints mounted at /api/v1/permissions
 */

const express = require('express');
const router = express.Router();
const permissionController = require('@controllers/permission/permission.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPermissionSchema,
  updatePermissionSchema,
  permissionIdParamsSchema,
  listPermissionsQuerySchema
} = require('@validations/permission/permission.schema');

const ACCESS_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN];

router.get(
  '/',
  validateRequest({ query: listPermissionsQuerySchema }),
  authenticate(),
  authorize(ACCESS_ADMIN_SCOPES, 'permission'),
  permissionController.listPermissions
);

router.get(
  '/:id',
  validateRequest({ params: permissionIdParamsSchema }),
  authenticate(),
  authorize(ACCESS_ADMIN_SCOPES, 'permission'),
  permissionController.getPermissionById
);

router.post(
  '/',
  validateRequest({ body: createPermissionSchema }),
  authenticate(),
  authorize(ACCESS_ADMIN_SCOPES, 'permission'),
  permissionController.createPermission
);

router.put(
  '/:id',
  validateRequest({ params: permissionIdParamsSchema, body: updatePermissionSchema }),
  authenticate(),
  authorize(ACCESS_ADMIN_SCOPES, 'permission'),
  permissionController.updatePermission
);

router.delete(
  '/:id',
  validateRequest({ params: permissionIdParamsSchema }),
  authenticate(),
  authorize(ACCESS_ADMIN_SCOPES, 'permission'),
  permissionController.deletePermission
);

module.exports = router;
