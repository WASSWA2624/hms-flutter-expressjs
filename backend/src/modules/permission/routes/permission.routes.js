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
const { requireAuth } = require('@middlewares/auth.middleware');
const {
  createPermissionSchema,
  updatePermissionSchema,
  permissionIdParamsSchema,
  listPermissionsQuerySchema
} = require('@validations/permission/permission.schema');

const ADMIN_ROLE_SET = ['TENANT_ADMIN', 'FACILITY_ADMIN', 'SUPER_ADMIN', 'OPERATIONS', 'HR'];

router.get(
  '/',
  validateRequest({ query: listPermissionsQuerySchema }),
  requireAuth(ADMIN_ROLE_SET),
  permissionController.listPermissions
);

router.get(
  '/:id',
  validateRequest({ params: permissionIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  permissionController.getPermissionById
);

router.post(
  '/',
  validateRequest({ body: createPermissionSchema }),
  requireAuth(ADMIN_ROLE_SET),
  permissionController.createPermission
);

router.put(
  '/:id',
  validateRequest({ params: permissionIdParamsSchema, body: updatePermissionSchema }),
  requireAuth(ADMIN_ROLE_SET),
  permissionController.updatePermission
);

router.delete(
  '/:id',
  validateRequest({ params: permissionIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  permissionController.deletePermission
);

module.exports = router;
