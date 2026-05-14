/**
 * Integration log repository
 *
 * @module modules/integration-log/repositories
 * @description Data access layer for integration log operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 * Note: This is a READ-ONLY module (no create/update/delete operations)
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find integration log by ID
 *
 * @param {string} id - Integration log ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Integration log object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.integration_log.findFirst({
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
 * Find many integration logs with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of integration logs
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { logged_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.integration_log.findMany({
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
 * Count integration logs with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of integration logs
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.integration_log.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create integration log entry
 *
 * @param {Object} data - Integration log data
 * @returns {Promise<Object>} Created integration log
 */
const create = async (data) => {
  try {
    return await prisma.integration_log.create({
      data
    });
  } catch (error) {
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create
};
