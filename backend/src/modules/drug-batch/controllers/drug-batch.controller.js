/**
 * Drug batch controller
 *
 * @module modules/drug-batch/controllers
 * @description Request handlers for drug batch endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const drugBatchService = require('@services/drug-batch/drug-batch.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List drug batches with pagination
 * GET /api/v1/drug-batches
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listDrugBatches = asyncHandler(async (req, res) => {
  const {
    drug_id,
    batch_number,
    expired,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    drug_id,
    batch_number,
    expired,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await drugBatchService.listDrugBatches(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.drug_batch.list.success', result.drugBatches, result.pagination);
});

/**
 * Get drug batch by ID
 * GET /api/v1/drug-batches/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getDrugBatchById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const drugBatch = await drugBatchService.getDrugBatchById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.drug_batch.get.success', drugBatch);
});

/**
 * Create new drug batch
 * POST /api/v1/drug-batches
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createDrugBatch = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const drugBatch = await drugBatchService.createDrugBatch(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.drug_batch.create.success', drugBatch);
});

/**
 * Update drug batch
 * PUT /api/v1/drug-batches/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateDrugBatch = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const drugBatch = await drugBatchService.updateDrugBatch(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.drug_batch.update.success', drugBatch);
});

/**
 * Delete drug batch (soft delete)
 * DELETE /api/v1/drug-batches/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteDrugBatch = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await drugBatchService.deleteDrugBatch(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listDrugBatches,
  getDrugBatchById,
  createDrugBatch,
  updateDrugBatch,
  deleteDrugBatch
};
