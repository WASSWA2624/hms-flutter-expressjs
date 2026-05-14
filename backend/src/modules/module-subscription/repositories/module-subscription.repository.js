/**
 * Module subscription repository
 *
 * @module modules/module-subscription/repositories
 * @description Data access layer for module subscription operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find module subscription by ID
 *
 * @param {string} id - Module subscription ID
 * @returns {Promise<Object|null>} Module subscription object or null
 */
const findById = async (id) => {
  try {
    return await prisma.module_subscription.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include: {
        module: true,
        subscription: {
          include: {
            plan: true
          }
        }
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many module subscriptions with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of module subscriptions
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.module_subscription.findMany({
      where,
      skip,
      take,
      orderBy,
      include: {
        module: true,
        subscription: {
          include: {
            plan: true
          }
        }
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count module subscriptions with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of module subscriptions
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.module_subscription.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new module subscription
 *
 * @param {Object} data - Module subscription data
 * @returns {Promise<Object>} Created module subscription
 */
const create = async (data) => {
  try {
    return await prisma.module_subscription.create({
      data,
      include: {
        module: true,
        subscription: {
          include: {
            plan: true
          }
        }
      }
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key violation
      throw new HttpError('errors.database.foreign_key', 400);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update module subscription
 *
 * @param {string} id - Module subscription ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated module subscription
 */
const update = async (id, data) => {
  try {
    return await prisma.module_subscription.update({
      where: { id },
      data,
      include: {
        module: true,
        subscription: {
          include: {
            plan: true
          }
        }
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.module_subscription.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key violation
      throw new HttpError('errors.database.foreign_key', 400);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete module subscription
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Module subscription ID
 * @returns {Promise<Object>} Deleted module subscription
 */
const softDelete = async (id) => {
  try {
    return await prisma.module_subscription.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.module_subscription.not_found', 404);
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
