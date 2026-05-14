/**
 * Subscription Plan controller
 *
 * @module modules/subscription-plan/controllers
 * @description Controller layer for subscription plan endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per module-creation.mdc: Use response helpers for output.
 */

const subscriptionPlanService = require('@services/subscription-plan/subscription-plan.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

/**
 * Get subscription plan by ID
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscriptionPlan = async (req, res) => {
  const { id } = req.params;
  const subscriptionPlan = await subscriptionPlanService.getSubscriptionPlanById(id, req.user);
  return sendSuccess(res, 200, 'messages.subscription_plan.retrieved', subscriptionPlan);
};

/**
 * List subscription plans with pagination
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listSubscriptionPlans = async (req, res) => {
  const { page = 1, limit = 20, sort_by = 'created_at', order = 'desc', ...filters } = req.query;

  const result = await subscriptionPlanService.listSubscriptionPlans(
    filters,
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by,
    order,
    req.user
  );

  return sendPaginated(
    res,
    'messages.subscription_plan.list_retrieved',
    result.subscriptionPlans,
    result.pagination
  );
};

/**
 * Create new subscription plan
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createSubscriptionPlan = async (req, res) => {
  const subscriptionPlan = await subscriptionPlanService.createSubscriptionPlan(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 201, 'messages.subscription_plan.created', subscriptionPlan);
};

/**
 * Update subscription plan
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateSubscriptionPlan = async (req, res) => {
  const { id } = req.params;
  const subscriptionPlan = await subscriptionPlanService.updateSubscriptionPlan(
    id,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(res, 200, 'messages.subscription_plan.updated', subscriptionPlan);
};

/**
 * Delete subscription plan (soft delete)
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteSubscriptionPlan = async (req, res) => {
  const { id } = req.params;
  await subscriptionPlanService.deleteSubscriptionPlan(id, req.user, req.ip);
  return res.status(204).send();
};

/**
 * Get plan entitlements
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscriptionPlanEntitlements = async (req, res) => {
  const { id } = req.params;
  const entitlements = await subscriptionPlanService.getPlanEntitlements(id, req.user);
  return sendSuccess(res, 200, 'messages.subscription_plan.entitlements.success', entitlements);
};

/**
 * Get plan add-on eligibility
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getSubscriptionPlanAddOnEligibility = async (req, res) => {
  const { id } = req.params;
  const eligibility = await subscriptionPlanService.getPlanAddOnEligibility(id, req.user);
  return sendSuccess(res, 200, 'messages.subscription_plan.add_on_eligibility.success', eligibility);
};

module.exports = {
  getSubscriptionPlan,
  listSubscriptionPlans,
  createSubscriptionPlan,
  updateSubscriptionPlan,
  deleteSubscriptionPlan,
  getSubscriptionPlanEntitlements,
  getSubscriptionPlanAddOnEligibility
};
