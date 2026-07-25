/**
 * Radiology procedure repository
 *
 * @module modules/radiology-procedure/repositories
 * @description Data access layer for radiology procedure operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null) unless includeDeleted.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const TENANT_NAME_INCLUDE = Object.freeze({
  tenant: {
    select: {
      id: true,
      name: true
    }
  }
});

const buildWhereClause = (filters = {}, { includeDeleted = false } = {}) => {
  const where = { ...filters };
  if (!includeDeleted) {
    where.deleted_at = null;
  }
  return where;
};

const resolveIncludeOptions = (includeOrOptions = {}, defaultInclude = TENANT_NAME_INCLUDE) => {
  if (
    includeOrOptions
    && typeof includeOrOptions === 'object'
    && ('includeDeleted' in includeOrOptions || 'include' in includeOrOptions)
  ) {
    return {
      includeDeleted: Boolean(includeOrOptions.includeDeleted),
      include: includeOrOptions.include === undefined
        ? defaultInclude
        : includeOrOptions.include
    };
  }

  return {
    includeDeleted: false,
    include: includeOrOptions && Object.keys(includeOrOptions).length > 0
      ? includeOrOptions
      : defaultInclude
  };
};

/**
 * Find radiology procedure by ID
 *
 * @param {string} id - Radiology procedure ID
 * @param {Object} [includeOrOptions] - Prisma include, or { includeDeleted, include }
 * @returns {Promise<Object|null>} Radiology procedure object or null
 */
const findById = async (id, includeOrOptions = {}) => {
  try {
    const { includeDeleted, include } = resolveIncludeOptions(includeOrOptions, {});
    return await prisma.radiology_procedure.findFirst({
      where: {
        id,
        ...(includeDeleted ? {} : { deleted_at: null })
      },
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many radiology procedures with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} [includeOrOptions] - Prisma include, or { includeDeleted, include }
 * @returns {Promise<Array>} Array of radiology procedures
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  includeOrOptions = {}
) => {
  try {
    const { includeDeleted, include } = resolveIncludeOptions(includeOrOptions, {});
    const where = buildWhereClause(filters, { includeDeleted });

    return await prisma.radiology_procedure.findMany({
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
 * Count radiology procedures with filters
 *
 * @param {Object} filters - Filter criteria
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted=false]
 * @returns {Promise<number>} Count of radiology procedures
 */
const count = async (filters = {}, options = {}) => {
  try {
    const includeDeleted = Boolean(options.includeDeleted);
    const where = buildWhereClause(filters, { includeDeleted });

    return await prisma.radiology_procedure.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new radiology procedure
 *
 * @param {Object} data - Radiology procedure data
 * @returns {Promise<Object>} Created radiology procedure
 */
const create = async (data) => {
  try {
    return await prisma.radiology_procedure.create({
      data,
      include: TENANT_NAME_INCLUDE
    });
  } catch (error) {
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update radiology procedure
 *
 * @param {string} id - Radiology procedure ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated radiology procedure
 */
const update = async (id, data) => {
  try {
    return await prisma.radiology_procedure.update({
      where: { id },
      data,
      include: TENANT_NAME_INCLUDE
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete radiology procedure
 *
 * @param {string} id - Radiology procedure ID
 * @returns {Promise<Object>} Soft-deleted radiology procedure
 */
const softDelete = async (id) => {
  try {
    return await prisma.radiology_procedure.update({
      where: { id },
      data: {
        deleted_at: new Date()
      },
      include: TENANT_NAME_INCLUDE
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Restore a soft-deleted radiology procedure
 *
 * @param {string} id - Radiology procedure ID
 * @returns {Promise<Object>} Restored radiology procedure
 */
const restore = async (id) => {
  try {
    const existing = await prisma.radiology_procedure.findUnique({
      where: { id },
      select: {
        id: true,
        deleted_at: true
      }
    });

    if (!existing || !existing.deleted_at) {
      throw Object.assign(new Error('Record not found'), { code: 'P2025' });
    }

    return await prisma.radiology_procedure.update({
      where: { id },
      data: { deleted_at: null },
      include: TENANT_NAME_INCLUDE
    });
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.radiology_test.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Permanently delete a soft-deleted radiology procedure and related offerings.
 *
 * @param {string} id - Radiology procedure ID
 * @returns {Promise<void>}
 */
const permanentDelete = async (id) => {
  try {
    const existing = await prisma.radiology_procedure.findUnique({
      where: { id },
      select: {
        id: true,
        deleted_at: true
      }
    });

    if (!existing) {
      return;
    }
    if (!existing.deleted_at) {
      throw new HttpError('errors.radiology_test.permanent_delete_requires_soft_delete', 400);
    }

    await prisma.$transaction(async (tx) => {
      await tx.facility_radiology_procedure_offering.deleteMany({
        where: { radiology_procedure_id: id }
      });
      await tx.radiology_order.updateMany({
        where: { radiology_procedure_id: id },
        data: { radiology_procedure_id: null }
      });
      await tx.radiology_procedure.delete({ where: { id } });
    });
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
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
  softDelete,
  restore,
  permanentDelete
};
