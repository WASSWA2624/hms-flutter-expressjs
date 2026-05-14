/**
 * Drug controller
 *
 * @module modules/drug/controllers
 * @description Request handlers for drug endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const drugService = require('@services/drug/drug.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List drugs with pagination
 * GET /api/v1/drugs
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listDrugs = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    name,
    code,
    form,
    strength,
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
    form,
    strength,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await drugService.listDrugs(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress,
    req.user || {}
  );

  sendPaginated(res, 'messages.drug.list.success', result.drugs, result.pagination);
});

/**
 * Get drug by ID
 * GET /api/v1/drugs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getDrugById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const drug = await drugService.getDrugById(id, userId, ipAddress, req.user || {});

  sendSuccess(res, 200, 'messages.drug.get.success', drug);
});

/**
 * Create new drug
 * POST /api/v1/drugs
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createDrug = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const drug = await drugService.createDrug(req.body, userId, ipAddress, req.user || {});

  sendSuccess(res, 201, 'messages.drug.create.success', drug);
});

/**
 * Update drug
 * PUT /api/v1/drugs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateDrug = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const drug = await drugService.updateDrug(id, req.body, userId, ipAddress, req.user || {});

  sendSuccess(res, 200, 'messages.drug.update.success', drug);
});

/**
 * Delete drug (soft delete)
 * DELETE /api/v1/drugs/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteDrug = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await drugService.deleteDrug(id, userId, ipAddress, req.user || {});

  sendNoContent(res);
});

module.exports = {
  listDrugs,
  getDrugById,
  createDrug,
  updateDrug,
  deleteDrug
};
