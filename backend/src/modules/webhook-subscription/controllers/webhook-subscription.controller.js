/**
 * Webhook subscription controller
 *
 * @module modules/webhook-subscription/controllers
 * @description HTTP request handlers for webhook subscription endpoints.
 * Per module-creation.mdc: Controllers handle HTTP, call services, return responses.
 * Per module-creation.mdc: All methods must be wrapped with asyncHandler.
 */

const webhookSubscriptionService = require('@services/webhook-subscription/webhook-subscription.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

/**
 * Get webhook subscription by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const getWebhookSubscription = async (req, res) => {
  const { id } = req.params;
  
  const webhookSubscription = await webhookSubscriptionService.getWebhookSubscriptionById(id);
  
  return sendSuccess(res, 200, 'messages.webhook_subscription.retrieved', webhookSubscription);
};

/**
 * List webhook subscriptions with pagination
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const listWebhookSubscriptions = async (req, res) => {
  const { page, limit, sort_by, order, ...filters } = req.query;
  
  const result = await webhookSubscriptionService.listWebhookSubscriptions(
    filters,
    page,
    limit,
    sort_by,
    order
  );
  
  return sendPaginated(
    res,
    'messages.webhook_subscription.list_retrieved',
    result.data,
    result.pagination
  );
};

/**
 * Create new webhook subscription
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const createWebhookSubscription = async (req, res) => {
  const data = req.body;
  
  // Audit context from authenticated user
  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id || data.tenant_id,
    ip_address: req.ip
  };
  
  const webhookSubscription = await webhookSubscriptionService.createWebhookSubscription(data, auditContext);
  
  return sendSuccess(res, 201, 'messages.webhook_subscription.created', webhookSubscription);
};

/**
 * Update webhook subscription
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const updateWebhookSubscription = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  
  // Audit context from authenticated user
  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  };
  
  const webhookSubscription = await webhookSubscriptionService.updateWebhookSubscription(id, data, auditContext);
  
  return sendSuccess(res, 200, 'messages.webhook_subscription.updated', webhookSubscription);
};

/**
 * Delete webhook subscription (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const deleteWebhookSubscription = async (req, res) => {
  const { id } = req.params;
  
  // Audit context from authenticated user
  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  };
  
  await webhookSubscriptionService.deleteWebhookSubscription(id, auditContext);
  
  // Per response-format.mdc: DELETE returns 204 with no body
  return res.status(204).send();
};

/**
 * Replay webhook subscription
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const replayWebhookSubscription = async (req, res) => {
  const { id } = req.params;

  const auditContext = {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  };

  const result = await webhookSubscriptionService.replayWebhookSubscription(id, req.body, auditContext);

  return sendSuccess(res, 200, 'messages.webhook_subscription.replay.success', result);
};

module.exports = {
  getWebhookSubscription,
  listWebhookSubscriptions,
  createWebhookSubscription,
  updateWebhookSubscription,
  deleteWebhookSubscription,
  replayWebhookSubscription
};
