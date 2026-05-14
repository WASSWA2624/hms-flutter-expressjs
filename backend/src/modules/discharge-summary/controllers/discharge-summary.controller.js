/**
 * Discharge summary controller
 *
 * @module modules/discharge-summary/controllers
 * @description Request handlers for discharge summary endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const dischargeSummaryService = require('@services/discharge-summary/discharge-summary.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List discharge summaries with pagination
 * GET /api/v1/discharge-summaries
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listDischargeSummaries = asyncHandler(async (req, res) => {
  const {
    admission_id,
    status,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    admission_id,
    status
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await dischargeSummaryService.listDischargeSummaries(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.discharge_summary.list.success', result.dischargeSummaries, result.pagination);
});

/**
 * Get discharge summary by ID
 * GET /api/v1/discharge-summaries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getDischargeSummaryById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const dischargeSummary = await dischargeSummaryService.getDischargeSummaryById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.discharge_summary.get.success', dischargeSummary);
});

/**
 * Create new discharge summary
 * POST /api/v1/discharge-summaries
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createDischargeSummary = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const dischargeSummary = await dischargeSummaryService.createDischargeSummary(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.discharge_summary.create.success', dischargeSummary);
});

/**
 * Update discharge summary
 * PUT /api/v1/discharge-summaries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateDischargeSummary = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const dischargeSummary = await dischargeSummaryService.updateDischargeSummary(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.discharge_summary.update.success', dischargeSummary);
});

/**
 * Delete discharge summary (soft delete)
 * DELETE /api/v1/discharge-summaries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteDischargeSummary = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await dischargeSummaryService.deleteDischargeSummary(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Finalize discharge summary
 * POST /api/v1/discharge-summaries/:id/finalize
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const finalizeDischargeSummary = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const dischargeSummary = await dischargeSummaryService.finalizeDischargeSummary(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.discharge_summary.finalize.success', dischargeSummary);
});

module.exports = {
  listDischargeSummaries,
  getDischargeSummaryById,
  createDischargeSummary,
  updateDischargeSummary,
  deleteDischargeSummary,
  finalizeDischargeSummary
};
