/**
 * Triage assessment repository
 *
 * @module modules/triage-assessment/repositories
 * @description Data access layer for triage assessment operations.
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

const SEARCHABLE_TRIAGE_LEVELS = new Set([
  'LEVEL_1',
  'LEVEL_2',
  'LEVEL_3',
  'LEVEL_4',
  'LEVEL_5',
]);
const SEARCHABLE_TRIAGE_LEVEL_ALIAS_MAP = Object.freeze({
  LEVEL_1: 'LEVEL_1',
  LEVEL_2: 'LEVEL_2',
  LEVEL_3: 'LEVEL_3',
  LEVEL_4: 'LEVEL_4',
  LEVEL_5: 'LEVEL_5',
  IMMEDIATE: 'LEVEL_1',
  URGENT: 'LEVEL_2',
  LESS_URGENT: 'LEVEL_3',
  NON_URGENT: 'LEVEL_4',
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
    { emergency_case: { human_friendly_id: { contains: searchUpper } } },
    { emergency_case: { patient: { human_friendly_id: { contains: searchUpper } } } },
    { emergency_case: { patient: { first_name: { contains: normalizedSearch } } } },
    { emergency_case: { patient: { last_name: { contains: normalizedSearch } } } },
    { notes: { contains: normalizedSearch } },
  ];

  const mappedTriageLevel = SEARCHABLE_TRIAGE_LEVEL_ALIAS_MAP[searchUpper];
  if (mappedTriageLevel && SEARCHABLE_TRIAGE_LEVELS.has(mappedTriageLevel)) {
    searchClauses.push({ triage_level: mappedTriageLevel });
  }

  where.AND = [
    ...(Array.isArray(where.AND) ? where.AND : []),
    { OR: searchClauses },
  ];

  return where;
};

/**
 * Find triage assessment by ID
 *
 * @param {string} id - Triage assessment ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Triage assessment object or null
 */
const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.triage_assessment.findFirst({
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
 * Find many triage assessments with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of triage assessments
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

    return await prisma.triage_assessment.findMany({
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
 * Count triage assessments with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of triage assessments
 */
const count = async (filters = {}) => {
  try {
    const where = buildWhere(filters);

    return await prisma.triage_assessment.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new triage assessment
 *
 * @param {Object} data - Triage assessment data
 * @returns {Promise<Object>} Created triage assessment
 */
const create = async (data) => {
  try {
    return await prisma.triage_assessment.create({
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
 * Update triage assessment
 *
 * @param {string} id - Triage assessment ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated triage assessment
 */
const update = async (id, data) => {
  try {
    return await prisma.triage_assessment.update({
      where: { id },
      data,
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.triage_assessment.not_found', 404);
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
 * Soft delete triage assessment
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Triage assessment ID
 * @returns {Promise<Object>} Deleted triage assessment
 */
const softDelete = async (id) => {
  try {
    return await prisma.triage_assessment.update({
      where: { id },
      data: {
        deleted_at: new Date()
      },
      include: DEFAULT_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.triage_assessment.not_found', 404);
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
