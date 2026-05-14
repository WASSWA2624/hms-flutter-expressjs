/**
 * Permission controller
 *
 * @module modules/permission/controllers
 * @description Request handlers for permission endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const permissionService = require('@services/permission/permission.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List permissions with pagination
 * GET /api/v1/permissions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPermissions = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    name,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await permissionService.listPermissions(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.permission.list.success', result.permissions, result.pagination);
});

/**
 * Get permission by ID
 * GET /api/v1/permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPermissionById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const permission = await permissionService.getPermissionById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.permission.get.success', permission);
});

/**
 * Create new permission
 * POST /api/v1/permissions
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPermission = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const permission = await permissionService.createPermission(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.permission.create.success', permission);
});

/**
 * Update permission
 * PUT /api/v1/permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePermission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const permission = await permissionService.updatePermission(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.permission.update.success', permission);
});

/**
 * Delete permission (soft delete)
 * DELETE /api/v1/permissions/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePermission = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await permissionService.deletePermission(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPermissions,
  getPermissionById,
  createPermission,
  updatePermission,
  deletePermission
};
