/**
 * Department repository
 *
 * @module modules/department/repositories
 * @description Data access layer for department operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const {
  softDeleteDepartmentCascade,
  restoreDepartment,
} = require('@lib/facility-structure/cascade-soft-delete');

const buildWhereClause = (filters = {}, { includeDeleted = false } = {}) => {
  const where = { ...filters };
  if (!includeDeleted) {
    where.deleted_at = null;
  }
  return where;
};

const listSchemaTablesWithColumn = async (tx, columnName, { excludeTables = [] } = {}) => {
  const rows = await tx.$queryRaw`
    SELECT DISTINCT TABLE_NAME AS table_name
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND COLUMN_NAME = ${columnName}
  `;

  const excluded = new Set(
    excludeTables.map((name) => String(name || '').trim().toLowerCase()).filter(Boolean)
  );

  return rows
    .map((row) => String(row.table_name || row.TABLE_NAME || '').replace(/`/g, '').trim())
    .filter((tableName) => tableName && !excluded.has(tableName.toLowerCase()));
};

/**
 * Find department by ID
 *
 * @param {string} id - Department ID
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<Object|null>} Department object or null
 */
const findById = async (id, { includeDeleted = false } = {}) => {
  try {
    return await prisma.department.findFirst({
      where: {
        id,
        ...(includeDeleted ? {} : { deleted_at: null }),
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many departments with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<Array>} Array of departments
 */
const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { created_at: 'desc' },
  { includeDeleted = false } = {}
) => {
  try {
    return await prisma.department.findMany({
      where: buildWhereClause(filters, { includeDeleted }),
      skip,
      take,
      orderBy,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count departments with filters
 *
 * @param {Object} filters - Filter criteria
 * @param {Object} [options]
 * @param {boolean} [options.includeDeleted]
 * @returns {Promise<number>} Count of departments
 */
const count = async (filters = {}, { includeDeleted = false } = {}) => {
  try {
    return await prisma.department.count({
      where: buildWhereClause(filters, { includeDeleted }),
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new department
 *
 * @param {Object} data - Department data
 * @returns {Promise<Object>} Created department
 */
const create = async (data) => {
  try {
    return await prisma.department.create({
      data,
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
 * Update department
 *
 * @param {string} id - Department ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated department
 */
const update = async (id, data) => {
  try {
    return await prisma.department.update({
      where: { id },
      data,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.department.not_found', 404);
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
 * Soft delete department and cascade to units.
 *
 * @param {string} id - Department ID
 * @returns {Promise<Object>} Cascade result
 */
const softDelete = async (id) => {
  try {
    return await softDeleteDepartmentCascade(id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2025') {
      throw new HttpError('errors.department.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Restore a soft-deleted department (units remain deleted).
 *
 * @param {string} id - Department ID
 * @returns {Promise<Object>} Restored department
 */
const restore = async (id) => {
  try {
    return await restoreDepartment(id);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2025') {
      throw new HttpError('errors.department.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Permanently delete a soft-deleted department and department-scoped data.
 *
 * @param {string} id - Department ID
 * @returns {Promise<void>}
 */
const permanentDelete = async (id) => {
  try {
    const existing = await prisma.department.findUnique({
      where: { id },
      select: {
        id: true,
        deleted_at: true,
      },
    });

    if (!existing) {
      return;
    }
    if (!existing.deleted_at) {
      throw new HttpError('errors.department.permanent_delete_requires_soft_delete', 400);
    }

    await prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe('SET FOREIGN_KEY_CHECKS = 0');
      try {
        const unitRows = await tx.unit.findMany({
          where: { department_id: id },
          select: { id: true },
        });
        const unitIds = unitRows.map((row) => row.id);

        if (unitIds.length > 0) {
          const unitTables = await listSchemaTablesWithColumn(tx, 'unit_id', {
            excludeTables: ['unit'],
          });
          const placeholders = unitIds.map(() => '?').join(', ');
          for (const tableName of unitTables) {
            await tx.$executeRawUnsafe(
              `DELETE FROM \`${tableName}\` WHERE unit_id IN (${placeholders})`,
              ...unitIds
            );
          }
          await tx.unit.deleteMany({ where: { id: { in: unitIds } } });
        }

        const departmentTables = await listSchemaTablesWithColumn(tx, 'department_id', {
          excludeTables: ['department'],
        });
        for (const tableName of departmentTables) {
          await tx.$executeRawUnsafe(
            `DELETE FROM \`${tableName}\` WHERE department_id = ?`,
            id
          );
        }

        for (const columnName of ['from_department_id', 'to_department_id']) {
          const altTables = await listSchemaTablesWithColumn(tx, columnName);
          for (const tableName of altTables) {
            await tx.$executeRawUnsafe(
              `UPDATE \`${tableName}\` SET \`${columnName}\` = NULL WHERE \`${columnName}\` = ?`,
              id
            );
          }
        }

        await tx.department.delete({ where: { id } });
      } finally {
        await tx.$executeRawUnsafe('SET FOREIGN_KEY_CHECKS = 1');
      }
    }, { timeout: 120000 });
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
  permanentDelete,
};
