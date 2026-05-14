/**
 * User routes
 *
 * @module modules/user/routes
 * @description User endpoints mounted at /api/v1/users
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const userController = require('@controllers/user/user.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, requireAuth } = require('@middlewares/auth.middleware');
const {
  createUserSchema,
  updateUserSchema,
  userIdParamsSchema,
  listUsersQuerySchema
} = require('@validations/user/user.schema');

const ADMIN_ROLE_SET = ['TENANT_ADMIN', 'FACILITY_ADMIN', 'SUPER_ADMIN', 'OPERATIONS'];

/**
 * @description List users with pagination and filters
 * @method GET
 * @route /api/v1/users/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [email] - Filter by email (partial match)
 * @queryParams {string} [status] - Filter by status (ACTIVE, INACTIVE, SUSPENDED, PENDING)
 * @queryParams {string} [search] - Search in email and phone fields
 * @bodyParams None
 * @returns {Object} Paginated list of users
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listUsersQuerySchema }),
  authenticate(),
  userController.listUsers
);

/**
 * @description Get user by ID
 * @method GET
 * @route /api/v1/users/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} User data
 * @throws 401 Unauthorized
 * @throws 404 User not found
 */
router.get(
  '/:id',
  validateRequest({ params: userIdParamsSchema }),
  authenticate(),
  userController.getUserById
);

/**
 * @description Create new user
 * @method POST
 * @route /api/v1/users/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} email - User email (required, valid email format, max 255 chars)
 * @bodyParams {string} [phone] - User phone (max 40 chars)
 * @bodyParams {string} password - User password (required when password_hash not provided)
 * @bodyParams {string} [password_hash] - Password hash or plain password
 * @bodyParams {string} status - User status (required, ACTIVE/INACTIVE/SUSPENDED/PENDING)
 * @bodyParams {string[]} [permission_ids] - Direct permission IDs to assign to the user
 * @returns {Object} Created user
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation (duplicate email in tenant)
 */
router.post(
  '/',
  validateRequest({ body: createUserSchema }),
  requireAuth(ADMIN_ROLE_SET),
  userController.createUser
);

/**
 * @description Update user
 * @method PUT
 * @route /api/v1/users/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [email] - User email (valid email format, max 255 chars)
 * @bodyParams {string} [phone] - User phone (max 40 chars)
 * @bodyParams {string} [password_hash] - Password hash (max 255 chars)
 * @bodyParams {string} [status] - User status (ACTIVE/INACTIVE/SUSPENDED/PENDING)
 * @bodyParams {string[]} [permission_ids] - Direct permission IDs to assign to the user
 * @returns {Object} Updated user
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 User not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',
  validateRequest({ params: userIdParamsSchema, body: updateUserSchema }),
  requireAuth(ADMIN_ROLE_SET),
  userController.updateUser
);

/**
 * @description Delete user (soft delete)
 * @method DELETE
 * @route /api/v1/users/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 User not found
 */
router.delete(
  '/:id',
  validateRequest({ params: userIdParamsSchema }),
  requireAuth(ADMIN_ROLE_SET),
  userController.deleteUser
);

module.exports = router;
