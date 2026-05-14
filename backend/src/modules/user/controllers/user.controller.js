/**
 * User controller
 *
 * @module modules/user/controllers
 * @description Request handlers for user endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const userService = require('@services/user/user.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List users with pagination
 * GET /api/v1/users
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listUsers = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    position_title,
    email,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    position_title,
    email,
    status,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await userService.listUsers(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.user.list.success', result.users, result.pagination);
});

/**
 * Get user by ID
 * GET /api/v1/users/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getUserById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const user = await userService.getUserById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user.get.success', user);
});

/**
 * Create new user
 * POST /api/v1/users
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createUser = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const user = await userService.createUser(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.user.create.success', user);
});

/**
 * Update user
 * PUT /api/v1/users/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateUser = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const user = await userService.updateUser(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.user.update.success', user);
});

/**
 * Delete user (soft delete)
 * DELETE /api/v1/users/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteUser = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await userService.deleteUser(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser
};
