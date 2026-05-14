/**
 * Dispense Log controller
 *
 * @module modules/dispense-log/controllers
 * @description Controllers for dispense log endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use response helpers for consistent output.
 */

const dispenseLogService = require('@services/dispense-log/dispense-log.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List dispense logs
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const listDispenseLogs = async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    ...filters
  } = req.query;

  const result = await dispenseLogService.listDispenseLogs(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order
  );

  return sendPaginated(
    res,
    'messages.dispense_log.list.success',
    result.items,
    result.pagination
  );
};

/**
 * Get dispense log by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const getDispenseLogById = async (req, res) => {
  const { id } = req.params;

  const dispenseLog = await dispenseLogService.getDispenseLogById(id);

  if (!dispenseLog) {
    throw new HttpError('errors.dispense_log.not_found', 404);
  }

  return sendSuccess(res, 200, 'messages.dispense_log.get.success', dispenseLog);
};

/**
 * Create dispense log
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const createDispenseLog = async (req, res) => {
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const dispenseLog = await dispenseLogService.createDispenseLog(data, auditContext);

  return sendSuccess(res, 201, 'messages.dispense_log.create.success', dispenseLog);
};

/**
 * Update dispense log
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const updateDispenseLog = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  const dispenseLog = await dispenseLogService.updateDispenseLog(id, data, auditContext);

  return sendSuccess(res, 200, 'messages.dispense_log.update.success', dispenseLog);
};

/**
 * Delete dispense log (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */
const deleteDispenseLog = async (req, res) => {
  const { id } = req.params;
  const auditContext = {
    user_id: req.user?.id,
    ip: req.ip
  };

  await dispenseLogService.deleteDispenseLog(id, auditContext);

  return res.status(204).send();
};

module.exports = {
  listDispenseLogs,
  getDispenseLogById,
  createDispenseLog,
  updateDispenseLog,
  deleteDispenseLog
};
