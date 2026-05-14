/**
 * Emergency response repository
 *
 * @module modules/emergency-response/repositories
 * @description Data access layer for emergency response operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  emergency_case: {
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
};

const buildWhere = (filters = {}) => {
  const where = {
    deleted_at: null,
  };

  const {
    search,
    ...rest
  } = filters || {};

  Object.assign(where, rest);

  const normalizedSearch = String(search || '').trim();
  if (!normalizedSearch) return where;

  const searchUpper = normalizedSearch.toUpperCase();
  const searchClauses = [
    { human_friendly_id: { contains: searchUpper } },
    { emergency_case: { human_friendly_id: { contains: searchUpper } } },
    { emergency_case: { patient: { human_friendly_id: { contains: searchUpper } } } },
    { emergency_case: { patient: { first_name: { contains: normalizedSearch } } } },
    { emergency_case: { patient: { last_name: { contains: normalizedSearch } } } },
    { notes: { contains: normalizedSearch } },
  ];

  where.AND = [
    ...(Array.isArray(where.AND) ? where.AND : []),
    { OR: searchClauses },
  ];

  return where;
};

/**
 * Find emergency response by ID
 *
 * @param {string} id - Emergency response ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Emergency response object or null
 */
const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.emergency_response.findFirst({
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
 * Find many emergency responses with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of emergency responses
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  include = DEFAULT_INCLUDE
) => {
  try {
    const where = buildWhere(filters);

    return await prisma.emergency_response.findMany({
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
 * Count emergency responses with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of emergency responses
 */
const count = async (filters = {}) => {
  try {
    const where = buildWhere(filters);

    return await prisma.emergency_response.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new emergency response
 *
 * @param {Object} data - Emergency response data
 * @returns {Promise<Object>} Created emergency response
 */
const create = async (data) => {
  try {
    return await prisma.emergency_response.create({
      data,
      include: DEFAULT_INCLUDE,
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
 * Update emergency response
 *
 * @param {string} id - Emergency response ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated emergency response
 */
const update = async (id, data) => {
  try {
    return await prisma.emergency_response.update({
      where: { id },
      data,
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.emergency_response.not_found', 404);
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
 * Soft delete emergency response
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Emergency response ID
 * @returns {Promise<Object>} Deleted emergency response
 */
const softDelete = async (id) => {
  try {
    return await prisma.emergency_response.update({
      where: { id },
      data: {
        deleted_at: new Date()
      },
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.emergency_response.not_found', 404);
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
