/**
 * Integration log controller
 *
 * @module modules/integration-log/controllers
 * @description HTTP request handlers for integration log endpoints.
 * Per module-creation.mdc: Controllers handle HTTP, call services, return responses.
 * Per module-creation.mdc: All methods must be wrapped with asyncHandler.
 * Note: This is a READ-ONLY module (only GET operations)
 */

const integrationLogService = require('@services/integration-log/integration-log.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

/**
 * Get integration log by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const getIntegrationLog = async (req, res) => {
  const { id } = req.params;
  
  const integrationLog = await integrationLogService.getIntegrationLogById(id);
  
  return sendSuccess(res, 200, 'messages.integration_log.retrieved', integrationLog);
};

/**
 * Get integration logs by integration ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const getIntegrationLogsByIntegrationId = async (req, res) => {
  const { integrationId } = req.params;
  const { page, limit, sort_by, order } = req.query;
  
  const result = await integrationLogService.getIntegrationLogsByIntegrationId(
    integrationId,
    page,
    limit,
    sort_by,
    order
  );
  
  return sendPaginated(
    res,
    'messages.integration_log.list_retrieved',
    result.data,
    result.pagination
  );
};

/**
 * List integration logs with pagination
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const listIntegrationLogs = async (req, res) => {
  const { page, limit, sort_by, order, ...filters } = req.query;
  
  const result = await integrationLogService.listIntegrationLogs(
    filters,
    page,
    limit,
    sort_by,
    order
  );
  
  return sendPaginated(
    res,
    'messages.integration_log.list_retrieved',
    result.data,
    result.pagination
  );
};

/**
 * Replay integration log
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const replayIntegrationLog = async (req, res) => {
  const { id } = req.params;

  const replayedLog = await integrationLogService.replayIntegrationLog(id, req.body, {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  });

  return sendSuccess(res, 200, 'messages.integration_log.replay.success', replayedLog);
};

module.exports = {
  getIntegrationLog,
  getIntegrationLogsByIntegrationId,
  listIntegrationLogs,
  replayIntegrationLog
};
