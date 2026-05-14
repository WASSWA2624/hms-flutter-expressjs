/**
 * Subscription controller
 *
 * @module modules/subscription/controllers
 * @description Controller layer for subscription endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use response helpers for output.
 */

const subscriptionService = require('@services/subscription/subscription.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

/**
 * Get subscription by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscription = async (req, res) => {
  const { id } = req.params;
  const subscription = await subscriptionService.getSubscriptionById(id, req.user);
  return sendSuccess(res, 200, 'messages.subscription.retrieved', subscription);
};

/**
 * List subscriptions with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listSubscriptions = async (req, res) => {
  const { page = 1, limit = 20, sort_by = 'created_at', order = 'desc', ...filters } = req.query;

  const result = await subscriptionService.listSubscriptions(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order,
    req.user
  );

  return sendPaginated(
    res,
    'messages.subscription.list_retrieved',
    result.subscriptions,
    result.pagination
  );
};

/**
 * Create new subscription
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createSubscription = async (req, res) => {
  const subscription = await subscriptionService.createSubscription(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 201, 'messages.subscription.created', subscription);
};

/**
 * Update subscription
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateSubscription = async (req, res) => {
  const { id } = req.params;
  const subscription = await subscriptionService.updateSubscription(
    id,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.subscription.updated', subscription);
};

/**
 * Cancel subscription
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const cancelSubscription = async (req, res) => {
  const { id } = req.params;
  const subscription = await subscriptionService.cancelSubscription(id, req.user, req.ip);
  return sendSuccess(res, 200, 'messages.subscription.cancelled', subscription);
};

/**
 * Reactivate subscription
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const reactivateSubscription = async (req, res) => {
  const { id } = req.params;
  const subscription = await subscriptionService.reactivateSubscription(id, req.user, req.ip);
  return sendSuccess(res, 200, 'messages.subscription.reactivated', subscription);
};

/**
 * Delete subscription (soft delete)
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteSubscription = async (req, res) => {
  const { id } = req.params;
  await subscriptionService.deleteSubscription(id, req.user, req.ip);
  return res.status(204).send();
};

/**
 * Upgrade subscription
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const upgradeSubscription = async (req, res) => {
  const { id } = req.params;
  const subscription = await subscriptionService.upgradeSubscription(id, req.body, req.user, req.ip);
  return sendSuccess(res, 200, 'messages.subscription.upgrade.success', subscription);
};

/**
 * Downgrade subscription
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const downgradeSubscription = async (req, res) => {
  const { id } = req.params;
  const subscription = await subscriptionService.downgradeSubscription(id, req.body, req.user, req.ip);
  return sendSuccess(res, 200, 'messages.subscription.downgrade.success', subscription);
};

/**
 * Renew subscription
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const renewSubscription = async (req, res) => {
  const { id } = req.params;
  const subscription = await subscriptionService.renewSubscription(id, req.body, req.user, req.ip);
  return sendSuccess(res, 200, 'messages.subscription.renew.success', subscription);
};

/**
 * Get proration preview
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscriptionProrationPreview = async (req, res) => {
  const { id } = req.params;
  const preview = await subscriptionService.getSubscriptionProrationPreview(
    id,
    req.query.target_plan_id,
    req.user
  );
  return sendSuccess(res, 200, 'messages.subscription.proration_preview.success', preview);
};

/**
 * Get usage summary
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscriptionUsageSummary = async (req, res) => {
  const { id } = req.params;
  const summary = await subscriptionService.getSubscriptionUsageSummary(id, req.user);
  return sendSuccess(res, 200, 'messages.subscription.usage_summary.success', summary);
};

/**
 * Get fit check
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscriptionFitCheck = async (req, res) => {
  const { id } = req.params;
  const fitCheck = await subscriptionService.getSubscriptionFitCheck(id, req.user);
  return sendSuccess(res, 200, 'messages.subscription.fit_check.success', fitCheck);
};

/**
 * Get upgrade recommendation
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscriptionUpgradeRecommendation = async (req, res) => {
  const { id } = req.params;
  const recommendation = await subscriptionService.getSubscriptionUpgradeRecommendation(id, req.user);
  return sendSuccess(res, 200, 'messages.subscription.upgrade_recommendation.success', recommendation);
};

module.exports = {
  getSubscription,
  listSubscriptions,
  createSubscription,
  updateSubscription,
  cancelSubscription,
  reactivateSubscription,
  deleteSubscription,
  upgradeSubscription,
  downgradeSubscription,
  renewSubscription,
  getSubscriptionProrationPreview,
  getSubscriptionUsageSummary,
  getSubscriptionFitCheck,
  getSubscriptionUpgradeRecommendation
};
