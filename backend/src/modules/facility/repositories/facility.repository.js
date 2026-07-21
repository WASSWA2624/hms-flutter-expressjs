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

const normalizeFacilityName = (value) =>
  String(value || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, ' ');

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
) => {
  try {
    return await prisma.branch.findMany({
      where: {
        facility_id: facilityId,
        deleted_at: null,
      },
      skip,
      take,
      orderBy,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  findByTenantAndName,
  count,
  create,
  update,
  softDelete,
  restore,
  permanentDelete,
  normalizeFacilityName,
};
