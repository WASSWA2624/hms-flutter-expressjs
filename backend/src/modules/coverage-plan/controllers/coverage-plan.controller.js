/**
 * Coverage Plan controller
 *
 * @module modules/coverage-plan/controllers
 * @description Request handlers for coverage plan endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const coveragePlanService = require('@services/coverage-plan/coverage-plan.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List coverage plans with pagination
 * GET /api/v1/coverage-plans
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listCoveragePlans = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    provider_name,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    name,
    provider_name,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await coveragePlanService.listCoveragePlans(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.coverage_plan.list.success', result.coveragePlans, result.pagination);
});

/**
 * Get coverage plan by ID
 * GET /api/v1/coverage-plans/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getCoveragePlanById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const coveragePlan = await coveragePlanService.getCoveragePlanById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.coverage_plan.get.success', coveragePlan);
});

/**
 * Create new coverage plan
 * POST /api/v1/coverage-plans
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createCoveragePlan = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const coveragePlan = await coveragePlanService.createCoveragePlan(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.coverage_plan.create.success', coveragePlan);
});

/**
 * Update coverage plan
 * PUT /api/v1/coverage-plans/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateCoveragePlan = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const coveragePlan = await coveragePlanService.updateCoveragePlan(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.coverage_plan.update.success', coveragePlan);
});

/**
 * Delete coverage plan (soft delete)
 * DELETE /api/v1/coverage-plans/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteCoveragePlan = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await coveragePlanService.deleteCoveragePlan(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listCoveragePlans,
  getCoveragePlanById,
  createCoveragePlan,
  updateCoveragePlan,
  deleteCoveragePlan
};
