/**
 * Lab panel controller
 *
 * @module modules/lab-panel/controllers
 * @description Request handlers for lab panel endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const labPanelService = require('@services/lab-panel/lab-panel.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List lab panels with pagination
 * GET /api/v1/lab-panels
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listLabPanels = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    code,
    category,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    name,
    code,
    category,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await labPanelService.listLabPanels(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.lab_panel.list.success', result.labPanels, result.pagination);
});

/**
 * Get lab panel by ID
 * GET /api/v1/lab-panels/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getLabPanelById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labPanel = await labPanelService.getLabPanelById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_panel.get.success', labPanel);
});

/**
 * Create new lab panel
 * POST /api/v1/lab-panels
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createLabPanel = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labPanel = await labPanelService.createLabPanel(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.lab_panel.create.success', labPanel);
});

/**
 * Update lab panel
 * PUT /api/v1/lab-panels/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateLabPanel = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labPanel = await labPanelService.updateLabPanel(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_panel.update.success', labPanel);
});

/**
 * Delete lab panel (soft delete)
 * DELETE /api/v1/lab-panels/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteLabPanel = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await labPanelService.deleteLabPanel(id, userId, ipAddress);

  sendSuccess(res, 204, null, null);
});

module.exports = {
  listLabPanels,
  getLabPanelById,
  createLabPanel,
  updateLabPanel,
  deleteLabPanel
};
