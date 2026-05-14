/**
 * Permission routes
 *
 * @module modules/permission/routes
 * @description Permission endpoints mounted at /api/v1/permissions
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const permissionController = require('@controllers/permission/permission.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createPermissionSchema,
  updatePermissionSchema,
  permissionIdParamsSchema,
  listPermissionsQuerySchema
} = require('@validations/permission/permission.schema');

/**
 * @description List permissions with pagination and filters
 * @method GET
 * @route /api/v1/permissions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [name] - Filter by permission name
 * @queryParams {string} [search] - Search in permission name and description
 * @bodyParams None
 * @returns {Object} Paginated list of permissions
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listPermissionsQuerySchema }),

  authenticate(),
  permissionController.listPermissions
);

/**
 * @description Get permission by ID
 * @method GET
 * @route /api/v1/permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Permission ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Permission data
 * @throws 401 Unauthorized
 * @throws 404 Permission not found
 */
router.get(
  '/:id',  validateRequest({ params: permissionIdParamsSchema }),

  authenticate(),
  permissionController.getPermissionById
);

/**
 * @description Create new permission
 * @method POST
 * @route /api/v1/permissions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} name - Permission name (required, max 120 chars)
 * @bodyParams {string} [description] - Permission description (max 255 chars)
 * @returns {Object} Created permission
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createPermissionSchema }),

  authenticate(),
  permissionController.createPermission
);

/**
 * @description Update permission
 * @method PUT
 * @route /api/v1/permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Permission ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Permission name (max 120 chars)
 * @bodyParams {string} [description] - Permission description (max 255 chars)
 * @returns {Object} Updated permission
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Permission not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: permissionIdParamsSchema, body: updatePermissionSchema }),

  authenticate(),
  permissionController.updatePermission
);

/**
 * @description Delete permission (soft delete)
 * @method DELETE
 * @route /api/v1/permissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Permission ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Permission not found
 */
router.delete(
  '/:id',  validateRequest({ params: permissionIdParamsSchema }),

  authenticate(),
  permissionController.deletePermission
);

module.exports = router;
