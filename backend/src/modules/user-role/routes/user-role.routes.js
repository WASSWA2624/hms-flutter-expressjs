/**
 * User-Role routes
 *
 * @module modules/user-role/routes
 * @description User-Role endpoints mounted at /api/v1/user-roles
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const userRoleController = require('@controllers/user-role/user-role.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, requireAuth } = require('@middlewares/auth.middleware');
const {
  createUserRoleSchema,
  updateUserRoleSchema,
  userRoleIdParamsSchema,
  listUserRolesQuerySchema
} = require('@validations/user-role/user-role.schema');

const ADMIN_ROLE_SET = ['TENANT_ADMIN', 'FACILITY_ADMIN', 'SUPER_ADMIN', 'OPERATIONS'];

/**
 * @description List user-roles with pagination and filters
 * @method GET
 * @route /api/v1/user-roles/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [user_id] - Filter by user ID (UUID)
 * @queryParams {string} [role_id] - Filter by role ID (UUID)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of user-roles
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listUserRolesQuerySchema }),
  authenticate(),
  userRoleController.listUserRoles
);

/**
 * @description Get user-role by ID
 * @method GET
 * @route /api/v1/user-roles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User-Role ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} User-Role data
 * @throws 401 Unauthorized
 * @throws 404 User-Role not found
 */
router.get(
  '/:id',
  validateRequest({ params: userRoleIdParamsSchema }),
  authenticate(),
  userRoleController.getUserRoleById
);

/**
 * @description Create new user-role
 * @method POST
 * @route /api/v1/user-roles/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} user_id - User ID (required, UUID)
 * @bodyParams {string} role_id - Role ID (required, UUID)
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @returns {Object} Created user-role
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',
  validateRequest({ body: createUserRoleSchema }),
  requireAuth(ADMIN_ROLE_SET),
  userRoleController.createUserRole
);

/**
 * @description Update user-role
 * @method PUT
 * @route /api/v1/user-roles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User-Role ID (UUID)
 * @queryParams None
 * @bodyParams {string} [user_id] - User ID (UUID)
 * @bodyParams {string} [role_id] - Role ID (UUID)
 * @bodyParams {string} [tenant_id] - Tenant ID (UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @returns {Object} Updated user-role
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 User-Role not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: userRoleIdParamsSchema, body: updateUserRoleSchema }),
  requireAuth(ADMIN_ROLE_SET),
  userRoleController.updateUserRole
);

/**
 * @description Delete user-role (soft delete)
 * @method DELETE
 * @route /api/v1/user-roles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User-Role ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 User-Role not found
 */
router.delete(
  '/:id',
  validateRequest({ params: userRoleIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  userRoleController.deleteUserRole
);

module.exports = router;
