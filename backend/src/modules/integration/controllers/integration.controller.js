/**
 * Integration controller
 *
 * @module modules/integration/controllers
 * @description HTTP request handlers for integration endpoints.
 * Per module-creation.mdc: Controllers handle HTTP, call services, return responses.
 * Per module-creation.mdc: All methods must be wrapped with asyncHandler.
 */

const integrationService = require('@services/integration/integration.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

/**
 * Get integration by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const getIntegration = async (req, res) => {
  const { id } = req.params;
  
  const integration = await integrationService.getIntegrationById(id);
  
  return sendSuccess(res, 200, 'messages.integration.retrieved', integration);
};

/**
 * List integrations with pagination
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const listIntegrations = async (req, res) => {
  const { page, limit, sort_by, order, ...filters } = req.query;
  
  const result = await integrationService.listIntegrations(
    filters,
    page,
    limit,
    sort_by,
    order
  );
  
  return sendPaginated(
    res,
    'messages.integration.list_retrieved',
    result.data,
    result.pagination
  );
};

/**
 * Create new integration
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const createIntegration = async (req, res) => {
  const data = req.body;
  
  // Audit context from authenticated user
  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id || data.tenant_id,
    ip_address: req.ip
  };
  
  const integration = await integrationService.createIntegration(data, auditContext);
  
  return sendSuccess(res, 201, 'messages.integration.created', integration);
};

/**
 * Update integration
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const updateIntegration = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  
  // Audit context from authenticated user
  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  };
  
  const integration = await integrationService.updateIntegration(id, data, auditContext);
  
  return sendSuccess(res, 200, 'messages.integration.updated', integration);
};

/**
 * Delete integration (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const deleteIntegration = async (req, res) => {
  const { id } = req.params;
  
  // Audit context from authenticated user
  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  };
  
  await integrationService.deleteIntegration(id, auditContext);
  
  // Per response-format.mdc: DELETE returns 204 with no body
  return res.status(204).send();
};

/**
 * Test integration connection
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const testIntegrationConnection = async (req, res) => {
  const { id } = req.params;

  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  };

  const result = await integrationService.testIntegrationConnection(id, req.body, auditContext);

  return sendSuccess(res, 200, 'messages.integration.test_connection.success', result);
};

/**
 * Trigger integration sync
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const syncIntegrationNow = async (req, res) => {
  const { id } = req.params;

  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  };

  const result = await integrationService.syncIntegrationNow(id, req.body, auditContext);

  return sendSuccess(res, 200, 'messages.integration.sync_now.success', result);
};

module.exports = {
  getIntegration,
  listIntegrations,
  createIntegration,
  updateIntegration,
  deleteIntegration,
  testIntegrationConnection,
  syncIntegrationNow
};
