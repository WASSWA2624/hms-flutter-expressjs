/**
 * Role-Permission routes
 *
 * @module modules/role-permission/routes
 * @description Role-Permission endpoints mounted at /api/v1/role-permissions
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const rolePermissionController = require('@controllers/role-permission/role-permission.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createRolePermissionSchema,
  updateRolePermissionSchema,
  rolePermissionIdParamsSchema,
  listRolePermissionsQuerySchema
} = require('@validations/role-permission/role-permission.schema');

/**
 * @description List role-permissions with pagination and filters
 * @method GET
 * @route /api/v1/role-permissions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [role_id] - Filter by role ID (UUID)
 * @queryParams {string} [permission_id] - Filter by permission ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of role-permissions
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listRolePermissionsQuerySchema }),

  authenticate(),
  rolePermissionController.listRolePermissions
);

/**
 * @description Get role-permission by ID
 * @method GET
 * @route /api/v1/role-permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Role-Permission ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Role-Permission data
 * @throws 401 Unauthorized
 * @throws 404 Role-Permission not found
 */
router.get(
  '/:id',  validateRequest({ params: rolePermissionIdParamsSchema }),

  authenticate(),
  rolePermissionController.getRolePermissionById
);

/**
 * @description Create new role-permission
 * @method POST
 * @route /api/v1/role-permissions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} role_id - Role ID (required, UUID)
 * @bodyParams {string} permission_id - Permission ID (required, UUID)
 * @returns {Object} Created role-permission
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createRolePermissionSchema }),

  authenticate(),
  rolePermissionController.createRolePermission
);

/**
 * @description Update role-permission
 * @method PUT
 * @route /api/v1/role-permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Role-Permission ID (UUID)
 * @queryParams None
 * @bodyParams {string} [role_id] - Role ID (UUID)
 * @bodyParams {string} [permission_id] - Permission ID (UUID)
 * @returns {Object} Updated role-permission
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Role-Permission not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: rolePermissionIdParamsSchema, body: updateRolePermissionSchema }),

  authenticate(),
  rolePermissionController.updateRolePermission
);

/**
 * @description Delete role-permission (soft delete)
 * @method DELETE
 * @route /api/v1/role-permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Role-Permission ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Role-Permission not found
 */
router.delete(
  '/:id',  validateRequest({ params: rolePermissionIdParamsSchema }),

  authenticate(),
  rolePermissionController.deleteRolePermission
);

module.exports = router;
