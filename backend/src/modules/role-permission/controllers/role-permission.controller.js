/**
 * Role-Permission controller
 *
 * @module modules/role-permission/controllers
 * @description Request handlers for role-permission endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const rolePermissionService = require('@services/role-permission/role-permission.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List role-permissions with pagination
 * GET /api/v1/role-permissions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listRolePermissions = asyncHandler(async (req, res) => {
  const {
    role_id,
    permission_id,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    role_id,
    permission_id
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await rolePermissionService.listRolePermissions(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.role_permission.list.success', result.rolePermissions, result.pagination);
});

/**
 * Get role-permission by ID
 * GET /api/v1/role-permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getRolePermissionById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const rolePermission = await rolePermissionService.getRolePermissionById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.role_permission.get.success', rolePermission);
});

/**
 * Create new role-permission
 * POST /api/v1/role-permissions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createRolePermission = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const rolePermission = await rolePermissionService.createRolePermission(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.role_permission.create.success', rolePermission);
});

/**
 * Update role-permission
 * PUT /api/v1/role-permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateRolePermission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const rolePermission = await rolePermissionService.updateRolePermission(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.role_permission.update.success', rolePermission);
});

/**
 * Delete role-permission (soft delete)
 * DELETE /api/v1/role-permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteRolePermission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await rolePermissionService.deleteRolePermission(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listRolePermissions,
  getRolePermissionById,
  createRolePermission,
  updateRolePermission,
  deleteRolePermission
};
