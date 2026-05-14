/**
 * Lab result controller
 */

const labResultService = require('@services/lab-result/lab-result.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listLabResults = asyncHandler(async (req, res) => {
  const {
    lab_order_item_id,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    lab_order_item_id,
    status,
    search,
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await labResultService.listLabResults(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.lab_result.list.success', result.labResults, result.pagination);
});

const getLabResultById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labResult = await labResultService.getLabResultById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_result.get.success', labResult);
});

const createLabResult = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labResult = await labResultService.createLabResult(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.lab_result.create.success', labResult);
});

const updateLabResult = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labResult = await labResultService.updateLabResult(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_result.update.success', labResult);
});

const deleteLabResult = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await labResultService.deleteLabResult(id, userId, ipAddress);

  sendNoContent(res);
});

const releaseLabResult = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labResult = await labResultService.releaseLabResult(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_result.release.success', labResult);
});

module.exports = {
  listLabResults,
  getLabResultById,
  createLabResult,
  updateLabResult,
  deleteLabResult,
  releaseLabResult
};
