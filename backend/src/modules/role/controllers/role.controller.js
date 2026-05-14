/**
 * Role controller
 *
 * @module modules/role/controllers
 * @description Request handlers for role endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const roleService = require('@services/role/role.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List roles with pagination
 * GET /api/v1/roles
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listRoles = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    name,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    name,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await roleService.listRoles(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.role.list.success', result.roles, result.pagination);
});

/**
 * Get role by ID
 * GET /api/v1/roles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getRoleById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const role = await roleService.getRoleById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.role.get.success', role);
});

/**
 * Create new role
 * POST /api/v1/roles
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createRole = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const role = await roleService.createRole(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.role.create.success', role);
});

/**
 * Update role
 * PUT /api/v1/roles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateRole = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const role = await roleService.updateRole(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.role.update.success', role);
});

/**
 * Delete role (soft delete)
 * DELETE /api/v1/roles/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteRole = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await roleService.deleteRole(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listRoles,
  getRoleById,
  createRole,
  updateRole,
  deleteRole
};
