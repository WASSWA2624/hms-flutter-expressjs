/**
 * Message service
 *
 * @module modules/message/services
 * @description Business logic layer for message operations.
 * Per module-creation.mdc: Only import/use its own repository, call createAuditLog for mutations.
 * Per prisma.mdc: Use $transaction() for multi-step mutations.
 */

const messageRepository = require('@repositories/message/message.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * Get message by ID
 *
 * @param {string} id - Message ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object>} Message object
 * @throws {HttpError} If message not found
 */
const getMessageById = async (id, include = {}) => {
  const message = await messageRepository.findById(id, include);
  
  if (!message) {
    throw new HttpError('errors.message.not_found', 404, [{ entity: 'message', id }]);
  }
  
  return message;
};

/**
 * List messages with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @param {Object} include - Relations to include
 * @returns {Promise<Object>} Paginated messages
 */
const listMessages = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc', include = {}) => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  // Build search filter
  const where = { ...filters };
  if (filters.search) {
    where.OR = [
      { content: { contains: filters.search, mode: 'insensitive' } }
    ];
    delete where.search;
  }

  const [messages, total] = await Promise.all([
    messageRepository.findMany(where, skip, limit, orderBy, include),
    messageRepository.count(where)
  ]);

  return {
    messages,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit)
  };
};

/**
 * Create new message
 *
 * @param {Object} data - Message data
 * @param {Object} user - Authenticated user
 * @returns {Promise<Object>} Created message
 */
const createMessage = async (data, user) => {
  const message = await messageRepository.create(data);

  // Audit log
  try {
    await createAuditLog({
      user_id: user?.id,
      action: 'CREATE',
      entity: 'message',
      entity_id: message.id,
      new_values: message,
      ip_address: user?.ip,
      user_agent: user?.user_agent
    });
  } catch {
    // Audit failures are intentionally ignored to keep write paths non-blocking.
  }

  return message;
};

/**
 * Update message
 *
 * @param {string} id - Message ID
 * @param {Object} data - Update data
 * @param {Object} user - Authenticated user
 * @returns {Promise<Object>} Updated message
 */
const updateMessage = async (id, data, user) => {
  // Get existing message
  const existingMessage = await getMessageById(id);
  
  // Update message
  const updatedMessage = await messageRepository.update(id, data);

  // Audit log
  try {
    await createAuditLog({
      user_id: user?.id,
      action: 'UPDATE',
      entity: 'message',
      entity_id: id,
      old_values: existingMessage,
      new_values: updatedMessage,
      ip_address: user?.ip,
      user_agent: user?.user_agent
    });
  } catch {
    // Audit failures are intentionally ignored to keep write paths non-blocking.
  }

  return updatedMessage;
};

/**
 * Delete message (soft delete)
 *
 * @param {string} id - Message ID
 * @param {Object} user - Authenticated user
 * @returns {Promise<Object>} Deleted message
 */
const deleteMessage = async (id, user) => {
  // Get existing message
  const existingMessage = await getMessageById(id);
  
  // Soft delete
  const deletedMessage = await messageRepository.softDelete(id);

  // Audit log
  try {
    await createAuditLog({
      user_id: user?.id,
      action: 'DELETE',
      entity: 'message',
      entity_id: id,
      old_values: existingMessage,
      ip_address: user?.ip,
      user_agent: user?.user_agent
    });
  } catch {
    // Audit failures are intentionally ignored to keep write paths non-blocking.
  }

  return deletedMessage;
};

module.exports = {
  getMessageById,
  listMessages,
  createMessage,
  updateMessage,
  deleteMessage
};

