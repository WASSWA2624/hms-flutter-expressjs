/**
 * Lab sample controller
 *
 * @module modules/lab-sample/controllers
 * @description Request handlers for lab sample endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const labSampleService = require('@services/lab-sample/lab-sample.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List lab samples with pagination
 * GET /api/v1/lab-samples
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listLabSamples = asyncHandler(async (req, res) => {
  const {
    lab_order_id,
    status,
    created_at_from,
    created_at_to,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    lab_order_id,
    status,
    created_at_from,
    created_at_to,
    search,
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await labSampleService.listLabSamples(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.lab_sample.list.success', result.labSamples, result.pagination);
});

/**
 * Get lab sample by ID
 * GET /api/v1/lab-samples/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getLabSampleById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labSample = await labSampleService.getLabSampleById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_sample.get.success', labSample);
});

/**
 * Create new lab sample
 * POST /api/v1/lab-samples
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createLabSample = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labSample = await labSampleService.createLabSample(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.lab_sample.create.success', labSample);
});

/**
 * Update lab sample
 * PUT /api/v1/lab-samples/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateLabSample = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labSample = await labSampleService.updateLabSample(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_sample.update.success', labSample);
});

/**
 * Delete lab sample (soft delete)
 * DELETE /api/v1/lab-samples/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteLabSample = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await labSampleService.deleteLabSample(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listLabSamples,
  getLabSampleById,
  createLabSample,
  updateLabSample,
  deleteLabSample
};
