/**
 * Posting Rule controller
 *
 * @module modules/accounts-workspace/controllers
 * @description Request/response layer for Posting Rules. Business rules, scope,
 * and audit live in the service.
 */

const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const postingRuleService = require('@services/accounts-workspace/posting-rule.service');

const listPostingRules = asyncHandler(async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by: sortBy,
    order,
    ...filters
  } = req.query;

  const result = await postingRuleService.listPostingRules(
    filters,
    Number(page),
    Number(limit),
    req.user,
    sortBy,
    order
  );

  return sendPaginated(
    res,
    'messages.accounts.posting_rule.list.success',
    result.items,
    result.pagination
  );
});

const getPostingRule = asyncHandler(async (req, res) => {
  const data = await postingRuleService.getPostingRule(
    req.params.postingRuleIdentifier,
    req.query,
    req.user
  );
  return sendSuccess(res, 200, 'messages.accounts.posting_rule.get.success', data);
});

const createPostingRule = asyncHandler(async (req, res) => {
  const data = await postingRuleService.createPostingRule(
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    201,
    'messages.accounts.posting_rule.create.success',
    data
  );
});

const updatePostingRule = asyncHandler(async (req, res) => {
  const data = await postingRuleService.updatePostingRule(
    req.params.postingRuleIdentifier,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.posting_rule.update.success',
    data
  );
});

const applyPostingRuleAction = asyncHandler(async (req, res) => {
  const data = await postingRuleService.applyPostingRuleAction(
    req.params.postingRuleIdentifier,
    req.params.action,
    req.body,
    req.user,
    req.ip
  );
  return sendSuccess(
    res,
    200,
    'messages.accounts.posting_rule.action.success',
    data
  );
});

module.exports = {
  listPostingRules,
  getPostingRule,
  createPostingRule,
  updatePostingRule,
  applyPostingRuleAction,
};
