/**
 * Audit log repository
 *
 * @module modules/audit-log/repositories
 * @description Data access layer for audit log operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 * Note: This is a READ-ONLY module - no create/update/delete operations exposed via API
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find audit log by ID
 *
 * @param {string} id - Audit log ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Audit log object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.audit_log.findFirst({
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
 * Find many audit logs with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of audit logs
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.audit_log.findMany({
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
 * Count audit logs with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of audit logs
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.audit_log.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count
};
