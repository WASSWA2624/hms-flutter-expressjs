/**
 * Branch controller
 *
 * @module modules/branch/controllers
 * @description Handles HTTP requests for branch endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const branchService = require('@services/branch/branch.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const toPositiveInt = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
};

/**
 * List branches with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listBranches = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, tenant_id, facility_id, is_active, search } = req.query;
  const normalizedPage = toPositiveInt(page, DEFAULT_PAGE);
  const normalizedLimit = toPositiveInt(limit, DEFAULT_PAGE_LIMIT);

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (facility_id) filters.facility_id = facility_id;
  if (is_active) filters.is_active = is_active;
  if (search) filters.search = search;

  const result = await branchService.listBranches(
    filters,
    normalizedPage,
    normalizedLimit,
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.branch.list.success',
    result.branches,
    result.pagination
  );
});

/**
 * Get branch by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getBranchById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const branch = await branchService.getBranchById(id);

  return sendSuccess(res, 200, 'messages.branch.get.success', branch);
});

/**
 * Create branch
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createBranch = asyncHandler(async (req, res) => {
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const branch = await branchService.createBranch(data, context);

  return sendSuccess(res, 201, 'messages.branch.create.success', branch);
});

/**
 * Update branch
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateBranch = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  const branch = await branchService.updateBranch(id, data, context);

  return sendSuccess(res, 200, 'messages.branch.update.success', branch);
});

/**
 * Delete branch
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteBranch = asyncHandler(async (req, res) => {
  const { id } = req.params;
  
  // Build context for audit log
  const context = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    facility_id: req.user?.facility_id,
    ip_address: req.ip,
    user_agent: req.get('user-agent')
  };

  await branchService.deleteBranch(id, context);

  return sendNoContent(res);
});

module.exports = {
  listBranches,
  getBranchById,
  createBranch,
  updateBranch,
  deleteBranch
};
