/**
 * Conversation repository
 *
 * @module modules/conversation/repositories
 * @description Data access layer for conversation operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find conversation by ID
 *
 * @param {string} id - Conversation ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Conversation object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.conversation.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many conversations with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of conversations
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.conversation.findMany({
      where,
      skip,
      take,
      orderBy,
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count conversations with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of conversations
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.conversation.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new conversation
 *
 * @param {Object} data - Conversation data
 * @returns {Promise<Object>} Created conversation
 */
const create = async (data) => {
  try {
    return await prisma.conversation.create({
      data
    });
  } catch (error) {
    // Handle Prisma errors
    if (error.code === 'P2002') {
      throw new HttpError('errors.database.unique', 409, [{ field: error.meta?.target }]);
    }
    if (error.code === 'P2003') {
      throw new HttpError('errors.database.foreign_key', 400, [{ field: error.meta?.field_name }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update conversation by ID
 *
 * @param {string} id - Conversation ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated conversation
 */
const update = async (id, data) => {
  try {
    return await prisma.conversation.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.not_found', 404, [{ entity: 'conversation' }]);
    }
    if (error.code === 'P2002') {
      throw new HttpError('errors.database.unique', 409, [{ field: error.meta?.target }]);
    }
    if (error.code === 'P2003') {
      throw new HttpError('errors.database.foreign_key', 400, [{ field: error.meta?.field_name }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete conversation by ID
 *
 * @param {string} id - Conversation ID
 * @returns {Promise<Object>} Deleted conversation
 */
const softDelete = async (id) => {
  try {
    return await prisma.conversation.update({
      where: { id },
      data: { deleted_at: new Date() }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.not_found', 404, [{ entity: 'conversation' }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
};
