/**
 * Insurer Integration controller
 *
 * @module modules/insurer-integration/controllers
 * @description Request handlers for insurer integration endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const insurerIntegrationService = require('@services/insurer-integration/insurer-integration.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List insurer integrations with pagination
 * GET /api/v1/insurer-integrations
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listInsurerIntegrations = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    coverage_plan_id,
    insurance_company_id,
    adapter_type,
    is_enabled,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    coverage_plan_id,
    insurance_company_id,
    adapter_type,
    is_enabled,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await insurerIntegrationService.listInsurerIntegrations(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(
    res,
    'messages.insurer_integration.list.success',
    result.insurerIntegrations,
    result.pagination
  );
});

/**
 * Get insurer integration by ID
 * GET /api/v1/insurer-integrations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getInsurerIntegrationById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insurerIntegration = await insurerIntegrationService.getInsurerIntegrationById(
    id,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.insurer_integration.get.success', insurerIntegration);
});

/**
 * Create new insurer integration
 * POST /api/v1/insurer-integrations
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createInsurerIntegration = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insurerIntegration = await insurerIntegrationService.createInsurerIntegration(
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 201, 'messages.insurer_integration.create.success', insurerIntegration);
});

/**
 * Update insurer integration
 * PUT /api/v1/insurer-integrations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateInsurerIntegration = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insurerIntegration = await insurerIntegrationService.updateInsurerIntegration(
    id,
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.insurer_integration.update.success', insurerIntegration);
});

/**
 * Delete insurer integration (soft delete)
 * DELETE /api/v1/insurer-integrations/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteInsurerIntegration = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await insurerIntegrationService.deleteInsurerIntegration(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listInsurerIntegrations,
  getInsurerIntegrationById,
  createInsurerIntegration,
  updateInsurerIntegration,
  deleteInsurerIntegration
};
