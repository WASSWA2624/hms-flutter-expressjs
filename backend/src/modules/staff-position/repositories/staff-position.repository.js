/**
 * Staff position repository
 *
 * @module modules/staff-position/repositories
 * @description Data access layer for staff position operations.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const buildWhereClause = (filters = {}, { includeDeleted = false } = {}) => {
  const where = { ...filters };
  if (!includeDeleted) {
    where.deleted_at = null;
  }
  return where;
};

/**
 * Find staff position by ID
 */
const findById = async (id, { includeDeleted = false } = {}) => {
  try {
    return await prisma.staff_position.findFirst({
      where: {
        id,
        ...(includeDeleted ? {} : { deleted_at: null })
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many staff positions with pagination
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  { includeDeleted = false } = {}
) => {
  try {
    return await prisma.staff_position.findMany({
      where: buildWhereClause(filters, { includeDeleted }),
      skip,
      take,
      orderBy
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count staff positions with filters
 */
const count = async (filters = {}, { includeDeleted = false } = {}) => {
  try {
    return await prisma.staff_position.count({
      where: buildWhereClause(filters, { includeDeleted })
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new staff position
 */
const create = async (data) => {
  try {
    return await prisma.staff_position.create({
      data
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
 * Update staff position
 */
const update = async (id, data) => {
  try {
    return await prisma.staff_position.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.staff_position.not_found', 404);
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
 * Soft delete staff position
 */
const softDelete = async (id) => {
  try {
    return await prisma.staff_position.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.staff_position.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Restore a soft-deleted staff position
 */
const restore = async (id) => {
  try {
    const existing = await prisma.staff_position.findFirst({
      where: { id }
    });
    if (!existing) {
      throw new HttpError('errors.staff_position.not_found', 404);
    }
    if (!existing.deleted_at) {
      return existing;
    }
    return await prisma.staff_position.update({
      where: { id },
      data: { deleted_at: null }
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2025') {
      throw new HttpError('errors.staff_position.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Permanently delete a soft-deleted staff position
 */
const permanentDelete = async (id) => {
  try {
    const existing = await prisma.staff_position.findUnique({
      where: { id },
      select: { id: true, deleted_at: true }
    });
    if (!existing) {
      return;
    }
    if (!existing.deleted_at) {
      throw new HttpError(
        'errors.staff_position.permanent_delete_requires_soft_delete',
        400
      );
    }
    await prisma.staff_position.delete({ where: { id } });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2025') {
      return;
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
