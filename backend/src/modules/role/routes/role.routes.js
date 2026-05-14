/**
 * Role routes
 *
 * @module modules/role/routes
 * @description Role endpoints mounted at /api/v1/roles
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const roleController = require('@controllers/role/role.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, requireAuth } = require('@middlewares/auth.middleware');
const {
  createRoleSchema,
  updateRoleSchema,
  roleIdParamsSchema,
  listRolesQuerySchema
} = require('@validations/role/role.schema');

const ADMIN_ROLE_SET = ['TENANT_ADMIN', 'FACILITY_ADMIN', 'SUPER_ADMIN', 'OPERATIONS'];

/**
 * @description List roles with pagination and filters
 * @method GET
 * @route /api/v1/roles/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [name] - Filter by role name
 * @queryParams {string} [search] - Search in role name and description
 * @bodyParams None
 * @returns {Object} Paginated list of roles
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listRolesQuerySchema }),
  authenticate(),
  roleController.listRoles
);

/**
 * @description Get role by ID
 * @method GET
 * @route /api/v1/roles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Role ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Role data
 * @throws 401 Unauthorized
 * @throws 404 Role not found
 */
router.get(
  '/:id',
  validateRequest({ params: roleIdParamsSchema }),
  authenticate(),
  roleController.getRoleById
);

/**
 * @description Create new role
 * @method POST
 * @route /api/v1/roles/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} name - Role name (required, max 120 chars)
 * @bodyParams {string} [description] - Role description (max 255 chars)
 * @returns {Object} Created role
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createRoleSchema }),
  requireAuth(ADMIN_ROLE_SET),
  roleController.createRole
);

/**
 * @description Update role
 * @method PUT
 * @route /api/v1/roles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Role ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [name] - Role name (max 120 chars)
 * @bodyParams {string} [description] - Role description (max 255 chars)
 * @returns {Object} Updated role
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Role not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: roleIdParamsSchema, body: updateRoleSchema }),
  requireAuth(ADMIN_ROLE_SET),
  roleController.updateRole
);

/**
 * @description Delete role (soft delete)
 * @method DELETE
 * @route /api/v1/roles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Role ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Role not found
 */
router.delete(
  '/:id',
  validateRequest({ params: roleIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  roleController.deleteRole
);

module.exports = router;
