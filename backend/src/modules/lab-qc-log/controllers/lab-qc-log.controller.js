/**
 * Lab QC log controller
 */

const labQcLogService = require('@services/lab-qc-log/lab-qc-log.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listLabQcLogs = asyncHandler(async (req, res) => {
  const {
    lab_test_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = { lab_test_id, search };
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await labQcLogService.listLabQcLogs(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.lab_qc_log.list.success', result.labQcLogs, result.pagination);
});

const getLabQcLogById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labQcLog = await labQcLogService.getLabQcLogById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_qc_log.get.success', labQcLog);
});

const createLabQcLog = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labQcLog = await labQcLogService.createLabQcLog(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.lab_qc_log.create.success', labQcLog);
});

const updateLabQcLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const labQcLog = await labQcLogService.updateLabQcLog(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.lab_qc_log.update.success', labQcLog);
});

const deleteLabQcLog = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await labQcLogService.deleteLabQcLog(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listLabQcLogs,
  getLabQcLogById,
  createLabQcLog,
  updateLabQcLog,
  deleteLabQcLog
};
