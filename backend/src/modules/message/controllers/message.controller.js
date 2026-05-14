/**
 * Message controller
 *
 * @module modules/message/controllers
 * @description Request handlers for message endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler, use response helpers.
 */

const messageService = require('@services/message/message.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * Get message by ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const getMessage = async (req, res) => {
  const { id } = req.params;
  const message = await messageService.getMessageById(id);
  
  return sendSuccess(res, 200, 'messages.message.retrieved', message);
};

/**
 * List messages with pagination
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const listMessages = async (req, res) => {
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
    conversation_id,
    sender_user_id,
    sender_patient_id,
    search
  } = req.query;

  const filters = {};
  if (conversation_id) filters.conversation_id = conversation_id;
  if (sender_user_id) filters.sender_user_id = sender_user_id;
  if (sender_patient_id) filters.sender_patient_id = sender_patient_id;
  if (search) filters.search = search;

  const result = await messageService.listMessages(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order
  );

  return sendPaginated(res, 'messages.message.list', result.messages, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1
  });
};

/**
 * Get messages by conversation ID
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const getMessagesByConversation = async (req, res) => {
  const { conversationId } = req.params;
  const {
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc'
  } = req.query;

  const filters = { conversation_id: conversationId };

  const result = await messageService.listMessages(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order
  );

  return sendPaginated(res, 'messages.message.list', result.messages, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages: result.totalPages,
    hasNextPage: result.page < result.totalPages,
    hasPreviousPage: result.page > 1
  });
};

/**
 * Create new message
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const createMessage = async (req, res) => {
  const data = req.body;
  const user = {
    id: req.user?.id,
    ip: req.ip,
    user_agent: req.get('user-agent')
  };
  
  const message = await messageService.createMessage(data, user);
  
  return sendSuccess(res, 201, 'messages.message.created', message);
};

/**
 * Update message
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const updateMessage = async (req, res) => {
  const { id } = req.params;
  const data = req.body;
  const user = {
    id: req.user?.id,
    ip: req.ip,
    user_agent: req.get('user-agent')
  };
  
  const message = await messageService.updateMessage(id, data, user);
  
  return sendSuccess(res, 200, 'messages.message.updated', message);
};

/**
 * Delete message (soft delete)
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const deleteMessage = async (req, res) => {
  const { id } = req.params;
  const user = {
    id: req.user?.id,
    ip: req.ip,
    user_agent: req.get('user-agent')
  };
  
  await messageService.deleteMessage(id, user);
  
  // Per response-format.mdc: DELETE returns 204 with no body
  return res.status(204).send();
};

module.exports = {
  getMessage,
  listMessages,
  getMessagesByConversation,
  createMessage,
  updateMessage,
  deleteMessage
};
