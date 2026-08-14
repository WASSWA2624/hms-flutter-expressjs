/**
 * Document number sequence repository
 *
 * @module modules/accounts-workspace/repositories
 * @description Data access for document numbering policies, plus read-only
 * access to the `human_id_counter` rows those policies configure. Every read
 * filters soft-deleted rows (`deleted_at: null`).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DOCUMENT_SEQUENCE_INCLUDE = {
  facility: { select: { id: true, human_friendly_id: true, name: true } },
};

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2002') {
      throw new HttpError('errors.accounts.document_sequence.duplicate', 409, [
        { field: error.meta?.target?.[0] || 'sequence_code' },
      ]);
    }
    if (error.code === 'P2003') {
      throw new HttpError('errors.database.foreign_key_field', 400, [
        { field: error.meta?.field_name || 'field' },
      ]);
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.accounts.document_sequence.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findFirst = async (where = {}, include = DOCUMENT_SEQUENCE_INCLUDE) =>
  withDbErrorHandling(() =>
    prisma.document_number_sequence.findFirst({
      where: { deleted_at: null, ...where },
      include,
    })
  );

const findMany = async (
  where = {},
  skip = 0,
  take = 20,
  orderBy = [{ document_type: 'asc' }, { sequence_code: 'asc' }],
  include = DOCUMENT_SEQUENCE_INCLUDE
) =>
  withDbErrorHandling(() =>
    prisma.document_number_sequence.findMany({
      where: { deleted_at: null, ...where },
      skip,
      take,
      orderBy,
      include,
    })
  );

const count = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.document_number_sequence.count({ where: { deleted_at: null, ...where } })
  );

/** Status tallies for the workspace summary and tab badge. */
const groupByStatus = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.document_number_sequence.groupBy({
      by: ['status'],
      where: { deleted_at: null, ...where },
      _count: { _all: true },
    })
  );

const create = async (data) =>
  withDbErrorHandling(() => prisma.document_number_sequence.create({ data }));

/**
 * Update guarded by the optimistic version the caller read.
 *
 * Returns `null` when no row matched so the service can distinguish a stale
 * version (409) from a missing record (404).
 */
const updateWithVersion = async (id, expectedVersion, data) =>
  withDbErrorHandling(async () => {
    const result = await prisma.document_number_sequence.updateMany({
      where: { id, deleted_at: null, version: expectedVersion },
      data: { ...data, version: { increment: 1 } },
    });
    if (result.count === 0) return null;
    return prisma.document_number_sequence.findFirst({
      where: { id },
      include: DOCUMENT_SEQUENCE_INCLUDE,
    });
  });

/**
 * Live counters for the given `human_id_counter` coordinates.
 *
 * Read-only on purpose: `src/prisma/client.js` is the only writer, so the tab
 * reports the number that will actually be issued instead of a second copy of
 * it. Returns the raw rows; the service maps them onto sequences.
 */
const findCounters = async (keys = []) => {
  if (!keys.length) return [];
  return withDbErrorHandling(() =>
    prisma.human_id_counter.findMany({
      where: {
        deleted_at: null,
        OR: keys.map(({ model_name, prefix, scope_key }) => ({
          model_name,
          prefix,
          scope_key,
        })),
      },
      select: {
        model_name: true,
        prefix: true,
        scope_key: true,
        last_value: true,
        updated_at: true,
      },
    })
  );
};

const runInTransaction = async (handler) =>
  withDbErrorHandling(() => prisma.$transaction(handler));

module.exports = {
  DOCUMENT_SEQUENCE_INCLUDE,
  findFirst,
  findMany,
  count,
  groupByStatus,
  create,
  updateWithVersion,
  findCounters,
  runInTransaction,
};
