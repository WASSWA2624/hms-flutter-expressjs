/**
 * Emergency case repository
 *
 * @module modules/emergency-case/repositories
 * @description Data access layer for emergency case operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
    },
  },
};

const SEARCHABLE_SEVERITIES = new Set(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']);
const SEARCHABLE_STATUSES = new Set(['OPEN', 'CLOSED', 'CANCELLED']);
const SEARCHABLE_STATUS_ALIAS_MAP = Object.freeze({
  OPEN: 'OPEN',
  CLOSED: 'CLOSED',
  CANCELLED: 'CANCELLED',
  PENDING: 'OPEN',
  IN_PROGRESS: 'OPEN',
  COMPLETED: 'CLOSED',
});

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
    { patient: { human_friendly_id: { contains: searchUpper } } },
    { patient: { first_name: { contains: normalizedSearch } } },
    { patient: { last_name: { contains: normalizedSearch } } },
    { tenant: { human_friendly_id: { contains: searchUpper } } },
    { tenant: { name: { contains: normalizedSearch } } },
    { facility: { human_friendly_id: { contains: searchUpper } } },
    { facility: { name: { contains: normalizedSearch } } },
  ];

  if (SEARCHABLE_SEVERITIES.has(searchUpper)) {
    searchClauses.push({ severity: searchUpper });
  }

  const mappedStatus = SEARCHABLE_STATUS_ALIAS_MAP[searchUpper];
  if (mappedStatus && SEARCHABLE_STATUSES.has(mappedStatus)) {
    searchClauses.push({ status: mappedStatus });
  }

  where.AND = [
    ...(Array.isArray(where.AND) ? where.AND : []),
    { OR: searchClauses },
  ];

  return where;
};

/**
 * Find emergency case by ID
 *
 * @param {string} id - Emergency case ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Emergency case object or null
 */
const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.emergency_case.findFirst({
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
 * Find many emergency cases with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of emergency cases
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

    return await prisma.emergency_case.findMany({
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
 * Count emergency cases with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of emergency cases
 */
const count = async (filters = {}) => {
  try {
    const where = buildWhere(filters);

    return await prisma.emergency_case.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new emergency case
 *
 * @param {Object} data - Emergency case data
 * @returns {Promise<Object>} Created emergency case
 */
const create = async (data) => {
  try {
    return await prisma.emergency_case.create({
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
 * Update emergency case
 *
 * @param {string} id - Emergency case ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated emergency case
 */
const update = async (id, data) => {
  try {
    return await prisma.emergency_case.update({
      where: { id },
      data,
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.emergency_case.not_found', 404);
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
 * Soft delete emergency case
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Emergency case ID
 * @returns {Promise<Object>} Deleted emergency case
 */
const softDelete = async (id) => {
  try {
    return await prisma.emergency_case.update({
      where: { id },
      data: {
        deleted_at: new Date()
      },
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.emergency_case.not_found', 404);
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
