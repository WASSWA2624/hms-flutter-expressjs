/**
 * Facility repository
 *
 * @module modules/facility/repositories
 * @description Data access layer for facility operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

/**
 * Find facility by ID
 *
 * @param {string} id - Facility ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Facility object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.facility.findFirst({
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
 * Find many facilities with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of facilities
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.facility.findMany({
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
 * Count facilities with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of facilities
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.facility.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new facility
 *
 * @param {Object} data - Facility data
 * @returns {Promise<Object>} Created facility
 */
const create = async (data) => {
  try {
    return await prisma.facility.create({
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
      const field = error.meta?.field_name || 'reference';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update facility
 *
 * @param {string} id - Facility ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated facility
 */
const update = async (id, data) => {
  try {
    return await prisma.facility.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.facility.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const field = error.meta?.field_name || 'reference';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete facility
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Facility ID
 * @returns {Promise<Object>} Deleted facility
 */
const softDelete = async (id) => {
  try {
    return await prisma.facility.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.facility.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find facility branches by facility ID
 * Nested endpoint: GET /facilities/:id/branches
 *
 * @param {string} facilityId - Facility ID
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of branches
 */
const findBranches = async (facilityId, skip = 0, take = 20, orderBy = { created_at: 'desc' }) => {
  try {
    return await prisma.branch.findMany({
      where: {
        facility_id: facilityId,
        deleted_at: null
      },
      skip,
      take,
      orderBy
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count facility branches
 *
 * @param {string} facilityId - Facility ID
 * @returns {Promise<number>} Count of branches
 */
const countBranches = async (facilityId) => {
  try {
    return await prisma.branch.count({
      where: {
        facility_id: facilityId,
        deleted_at: null
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete,
  findBranches,
  countBranches
};
