/**
 * Post-op note repository
 *
 * @module modules/post-op-note/repositories
 * @description Data access layer for Post-op note operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const BASE_INCLUDE = {
  theatre_case: {
    select: {
      id: true,
      human_friendly_id: true,
      encounter: {
        select: {
          id: true,
          human_friendly_id: true,
          patient: {
            select: {
              id: true,
              human_friendly_id: true,
              first_name: true,
              last_name: true,
            },
          },
        },
      },
    },
  },
};

/**
 * Find Post-op note by ID
 *
 * @param {string} id - Post-op note ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Post-op note object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.post_op_note.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include: {
        ...BASE_INCLUDE,
        ...include,
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many Post-op notes with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of Post-op notes
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.post_op_note.findMany({
      where,
      skip,
      take,
      orderBy,
      include: {
        ...BASE_INCLUDE,
        ...include,
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count Post-op notes with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of Post-op notes
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.post_op_note.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new Post-op note
 *
 * @param {Object} data - Post-op note data
 * @returns {Promise<Object>} Created Post-op note
 */
const create = async (data) => {
  try {
    return await prisma.post_op_note.create({
      data
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update Post-op note
 *
 * @param {string} id - Post-op note ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated Post-op note
 */
const update = async (id, data) => {
  try {
    return await prisma.post_op_note.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.post_op_note.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete Post-op note
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Post-op note ID
 * @returns {Promise<Object>} Deleted Post-op note
 */
const softDelete = async (id) => {
  try {
    return await prisma.post_op_note.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.post_op_note.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  BASE_INCLUDE,
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
};
