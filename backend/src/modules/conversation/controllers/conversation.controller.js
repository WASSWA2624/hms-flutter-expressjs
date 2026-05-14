/**
 * Conversation controller
 *
 * @module modules/conversation/controllers
 * @description Request handlers for conversation endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler, use response helpers.
 */

const conversationService = require('@services/conversation/conversation.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * Get conversation by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const getConversation = async (req, res) => {
  const { id } = req.params;
  const conversation = await conversationService.getConversationById(id);
  
  return sendSuccess(res, 200, 'messages.conversation.retrieved', conversation);
};

/**
 * List conversations with pagination
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const listConversations = async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    tenant_id,
    created_by_user_id,
    subject,
    search
  } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (created_by_user_id) filters.created_by_user_id = created_by_user_id;
  if (subject) filters.subject = { contains: subject, mode: 'insensitive' };
  if (search) filters.search = search;

  const result = await conversationService.listConversations(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order
  );

  return sendPaginated(res, 'messages.conversation.list', result.conversations, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1
  });
};

/**
 * Create new conversation
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const createConversation = async (req, res) => {
  const data = req.body;
  const user = {
    id: req.user?.id,
    ip: req.ip,
    user_agent: req.get('user-agent')
  };
  
  const conversation = await conversationService.createConversation(data, user);
  
  return sendSuccess(res, 201, 'messages.conversation.created', conversation);
};

/**
 * Update conversation
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const updateConversation = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const user = {
    id: req.user?.id,
    ip: req.ip,
    user_agent: req.get('user-agent')
  };
  
  const conversation = await conversationService.updateConversation(id, data, user);
  
  return sendSuccess(res, 200, 'messages.conversation.updated', conversation);
};

/**
 * Delete conversation (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const deleteConversation = async (req, res) => {
  const { id } = req.params;
  const user = {
    id: req.user?.id,
    ip: req.ip,
    user_agent: req.get('user-agent')
  };
  
  await conversationService.deleteConversation(id, user);
  
  // Per response-format.mdc: DELETE returns 204 with no body
  return res.status(204).send();
};

module.exports = {
  getConversation,
  listConversations,
  createConversation,
  updateConversation,
  deleteConversation
};
