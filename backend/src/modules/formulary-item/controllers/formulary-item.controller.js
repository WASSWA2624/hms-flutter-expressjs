/**
 * Formulary item controller
 *
 * @module modules/formulary-item/controllers
 * @description Request handlers for formulary item endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const formularyItemService = require('@services/formulary-item/formulary-item.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List formulary items with pagination
 * GET /api/v1/formulary-items
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listFormularyItems = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    drug_id,
    is_active,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    drug_id,
    is_active
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await formularyItemService.listFormularyItems(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.formulary_item.list.success', result.formularyItems, result.pagination);
});

/**
 * Get formulary item by ID
 * GET /api/v1/formulary-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getFormularyItemById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const formularyItem = await formularyItemService.getFormularyItemById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.formulary_item.get.success', formularyItem);
});

/**
 * Create new formulary item
 * POST /api/v1/formulary-items
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createFormularyItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const formularyItem = await formularyItemService.createFormularyItem(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.formulary_item.create.success', formularyItem);
});

/**
 * Update formulary item
 * PUT /api/v1/formulary-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateFormularyItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const formularyItem = await formularyItemService.updateFormularyItem(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.formulary_item.update.success', formularyItem);
});

/**
 * Delete formulary item (soft delete)
 * DELETE /api/v1/formulary-items/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteFormularyItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await formularyItemService.deleteFormularyItem(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listFormularyItems,
  getFormularyItemById,
  createFormularyItem,
  updateFormularyItem,
  deleteFormularyItem
};
