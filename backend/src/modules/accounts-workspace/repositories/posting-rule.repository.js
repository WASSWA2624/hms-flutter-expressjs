/**
 * Posting Rule repository
 *
 * @module modules/accounts-workspace/repositories
 * @description Data access for posting rules. Standard CRUD only; every read
 * filters soft-deleted rows (`deleted_at: null`).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const POSTING_RULE_INCLUDE = {
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  reopened_user: {
    select: {
      id: true,
      human_friendly_id: true,
      profile: { select: { first_name: true, last_name: true } },
    },
  },
};

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2002') {
      throw new HttpError('errors.accounts.posting_rule.duplicate', 409, [
        { field: error.meta?.target?.[0] || 'rule_code' },
      ]);
    }
    if (error.code === 'P2003') {
      throw new HttpError('errors.database.foreign_key_field', 400, [
        { field: error.meta?.field_name || 'field' },
      ]);
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.accounts.posting_rule.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findFirst = async (where = {}, include = POSTING_RULE_INCLUDE) =>
  withDbErrorHandling(() =>
    prisma.posting_rule.findFirst({
      where: { deleted_at: null, ...where },
      include,
    })
  );

const findMany = async (
  where = {},
  skip = 0,
  take = 20,
  orderBy = [{ priority: 'desc' }, { rule_code: 'desc' }],
  include = POSTING_RULE_INCLUDE
) =>
  withDbErrorHandling(() =>
    prisma.posting_rule.findMany({
      where: { deleted_at: null, ...where },
      skip,
      take,
      orderBy,
      include,
    })
  );

const count = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.posting_rule.count({ where: { deleted_at: null, ...where } })
  );

/** Status tallies for the workspace summary and tab badge. */
const groupByStatus = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.posting_rule.groupBy({
      by: ['status'],
      where: { deleted_at: null, ...where },
      _count: { _all: true },
    })
  );

const create = async (data) =>
  withDbErrorHandling(() => prisma.posting_rule.create({ data }));

/**
 * Update guarded by the optimistic version the caller read.
 *
 * Returns `null` when no row matched so the service can distinguish a stale
 * version (409) from a missing record (404).
 */
const updateWithVersion = async (id, expectedVersion, data) =>
  withDbErrorHandling(async () => {
    const result = await prisma.posting_rule.updateMany({
      where: { id, deleted_at: null, version: expectedVersion },
      data: { ...data, version: { increment: 1 } },
    });
    if (result.count === 0) return null;
    return prisma.posting_rule.findFirst({
      where: { id },
      include: POSTING_RULE_INCLUDE,
    });
  });

const runInTransaction = async (handler) =>
  withDbErrorHandling(() => prisma.$transaction(handler));

module.exports = {
  POSTING_RULE_INCLUDE,
  findFirst,
  findMany,
  count,
  groupByStatus,
  create,
  updateWithVersion,
  runInTransaction,
};
