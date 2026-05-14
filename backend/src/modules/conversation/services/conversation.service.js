/**
 * Conversation service
 *
 * @module modules/conversation/services
 * @description Business logic layer for conversation operations.
 * Per module-creation.mdc: Only import/use its own repository, call createAuditLog for mutations.
 * Per prisma.mdc: Use $transaction() for multi-step mutations.
 */

const conversationRepository = require('@repositories/conversation/conversation.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * Get conversation by ID
 *
 * @param {string} id - Conversation ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object>} Conversation object
 * @throws {HttpError} If conversation not found
 */
const getConversationById = async (id, include = {}) => {
  const conversation = await conversationRepository.findById(id, include);
  
  if (!conversation) {
    throw new HttpError('errors.conversation.not_found', 404, [{ entity: 'conversation', id }]);
  }
  
  return conversation;
};

/**
 * List conversations with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @param {Object} include - Relations to include
 * @returns {Promise<Object>} Paginated conversations
 */
const listConversations = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc', include = {}) => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  // Build search filter
  const where = { ...filters };
  if (filters.search) {
    where.OR = [
      { subject: { contains: filters.search, mode: 'insensitive' } }
    ];
    delete where.search;
  }

  const [conversations, total] = await Promise.all([
    conversationRepository.findMany(where, skip, limit, orderBy, include),
    conversationRepository.count(where)
  ]);

  return {
    conversations,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit)
  };
};

/**
 * Create new conversation
 *
 * @param {Object} data - Conversation data
 * @param {Object} user - Authenticated user
 * @returns {Promise<Object>} Created conversation
 */
const createConversation = async (data, user) => {
  const conversation = await conversationRepository.create(data);

  // Audit log
  try {
    await createAuditLog({
      user_id: user?.id,
      action: 'CREATE',
      entity: 'conversation',
      entity_id: conversation.id,
      new_values: conversation,
      ip_address: user?.ip,
      user_agent: user?.user_agent
    });
  } catch {
    // Audit failures are intentionally ignored to keep write paths non-blocking.
  }

  return conversation;
};

/**
 * Update conversation
 *
 * @param {string} id - Conversation ID
 * @param {Object} data - Update data
 * @param {Object} user - Authenticated user
 * @returns {Promise<Object>} Updated conversation
 */
const updateConversation = async (id, data, user) => {
  // Get existing conversation
  const existingConversation = await getConversationById(id);
  
  // Update conversation
  const updatedConversation = await conversationRepository.update(id, data);

  // Audit log
  try {
    await createAuditLog({
      user_id: user?.id,
      action: 'UPDATE',
      entity: 'conversation',
      entity_id: id,
      old_values: existingConversation,
      new_values: updatedConversation,
      ip_address: user?.ip,
      user_agent: user?.user_agent
    });
  } catch {
    // Audit failures are intentionally ignored to keep write paths non-blocking.
  }

  return updatedConversation;
};

/**
 * Delete conversation (soft delete)
 *
 * @param {string} id - Conversation ID
 * @param {Object} user - Authenticated user
 * @returns {Promise<Object>} Deleted conversation
 */
const deleteConversation = async (id, user) => {
  // Get existing conversation
  const existingConversation = await getConversationById(id);
  
  // Soft delete
  const deletedConversation = await conversationRepository.softDelete(id);

  // Audit log
  try {
    await createAuditLog({
      user_id: user?.id,
      action: 'DELETE',
      entity: 'conversation',
      entity_id: id,
      old_values: existingConversation,
      ip_address: user?.ip,
      user_agent: user?.user_agent
    });
  } catch {
    // Audit failures are intentionally ignored to keep write paths non-blocking.
  }

  return deletedConversation;
};

module.exports = {
  getConversationById,
  listConversations,
  createConversation,
  updateConversation,
  deleteConversation
};

