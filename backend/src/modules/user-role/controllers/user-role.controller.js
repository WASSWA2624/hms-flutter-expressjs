/**
 * User-Role controller
 *
 * @module modules/user-role/controllers
 * @description Request handlers for user-role endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const userRoleService = require('@services/user-role/user-role.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List user-roles with pagination
 * GET /api/v1/user-roles
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listUserRoles = asyncHandler(async (req, res) => {
  const {
    user_id,
    role_id,
    tenant_id,
    facility_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    user_id,
    role_id,
    tenant_id,
    facility_id
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await userRoleService.listUserRoles(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.user_role.list.success', result.userRoles, result.pagination);
});

/**
 * Get user-role by ID
 * GET /api/v1/user-roles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getUserRoleById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userRole = await userRoleService.getUserRoleById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_role.get.success', userRole);
});

/**
 * Create new user-role
 * POST /api/v1/user-roles
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createUserRole = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userRole = await userRoleService.createUserRole(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.user_role.create.success', userRole);
});

/**
 * Update user-role
 * PUT /api/v1/user-roles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateUserRole = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const userRole = await userRoleService.updateUserRole(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user_role.update.success', userRole);
});

/**
 * Delete user-role (soft delete)
 * DELETE /api/v1/user-roles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteUserRole = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await userRoleService.deleteUserRole(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listUserRoles,
  getUserRoleById,
  createUserRole,
  updateUserRole,
  deleteUserRole
};
