/**
 * Message repository
 *
 * @module modules/message/repositories
 * @description Data access layer for message operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find message by ID
 *
 * @param {string} id - Message ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Message object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.message.findFirst({
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
 * Find many messages with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of messages
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.message.findMany({
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
 * Count messages with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of messages
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.message.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new message
 *
 * @param {Object} data - Message data
 * @returns {Promise<Object>} Created message
 */
const create = async (data) => {
  try {
    return await prisma.message.create({
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
 * Update message by ID
 *
 * @param {string} id - Message ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated message
 */
const update = async (id, data) => {
  try {
    return await prisma.message.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.not_found', 404, [{ entity: 'message' }]);
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
 * Soft delete message by ID
 *
 * @param {string} id - Message ID
 * @returns {Promise<Object>} Deleted message
 */
const softDelete = async (id) => {
  try {
    return await prisma.message.update({
      where: { id },
      data: { deleted_at: new Date() }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.not_found', 404, [{ entity: 'message' }]);
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
