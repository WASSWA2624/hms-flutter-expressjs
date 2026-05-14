/**
 * PACS link controller
 *
 * @module modules/pacs-link/controllers
 * @description Request handlers for PACS link endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const pacsLinkService = require('@services/pacs-link/pacs-link.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List PACS links with pagination
 * GET /api/v1/pacs-links
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPacsLinks = asyncHandler(async (req, res) => {
  const {
    imaging_study_id,
    expires_at,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    imaging_study_id,
    expires_at
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await pacsLinkService.listPacsLinks(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.pacs_link.list.success', result.pacsLinks, result.pagination);
});

/**
 * Get PACS link by ID
 * GET /api/v1/pacs-links/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPacsLinkById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pacsLink = await pacsLinkService.getPacsLinkById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.pacs_link.get.success', pacsLink);
});

/**
 * Create new PACS link
 * POST /api/v1/pacs-links
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPacsLink = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pacsLink = await pacsLinkService.createPacsLink(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.pacs_link.create.success', pacsLink);
});

/**
 * Update PACS link
 * PUT /api/v1/pacs-links/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePacsLink = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const pacsLink = await pacsLinkService.updatePacsLink(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.pacs_link.update.success', pacsLink);
});

/**
 * Delete PACS link (soft delete)
 * DELETE /api/v1/pacs-links/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePacsLink = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await pacsLinkService.deletePacsLink(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listPacsLinks,
  getPacsLinkById,
  createPacsLink,
  updatePacsLink,
  deletePacsLink
};
