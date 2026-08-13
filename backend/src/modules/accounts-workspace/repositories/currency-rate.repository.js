/**
 * Currency rate repository
 *
 * @module modules/accounts-workspace/repositories
 * @description Data access for currencies & exchange rates. Standard CRUD only;
 * every read filters soft-deleted rows (`deleted_at: null`).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const CURRENCY_RATE_INCLUDE = {
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  updated_user: {
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
      throw new HttpError('errors.accounts.currency_rate.duplicate', 409, [
        { field: error.meta?.target?.[0] || 'currency_code' },
      ]);
    }
    if (error.code === 'P2003') {
      throw new HttpError('errors.database.foreign_key_field', 400, [
        { field: error.meta?.field_name || 'field' },
      ]);
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.accounts.currency_rate.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findFirst = async (where = {}, include = CURRENCY_RATE_INCLUDE) =>
  withDbErrorHandling(() =>
    prisma.accounts_currency_rate.findFirst({
      where: { deleted_at: null, ...where },
      include,
    })
  );

const findMany = async (
  where = {},
  skip = 0,
  take = 20,
  orderBy = [{ effective_date: 'desc' }, { currency_code: 'desc' }],
  include = CURRENCY_RATE_INCLUDE
) =>
  withDbErrorHandling(() =>
    prisma.accounts_currency_rate.findMany({
      where: { deleted_at: null, ...where },
      skip,
      take,
      orderBy,
      include,
    })
  );

const count = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.accounts_currency_rate.count({ where: { deleted_at: null, ...where } })
  );

/** Status tallies for the workspace summary and tab badge. */
const groupByStatus = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.accounts_currency_rate.groupBy({
      by: ['status'],
      where: { deleted_at: null, ...where },
      _count: { _all: true },
    })
  );

const create = async (data) =>
  withDbErrorHandling(() => prisma.accounts_currency_rate.create({ data }));

/**
 * Update guarded by the optimistic version the caller read.
 *
 * Returns `null` when no row matched so the service can distinguish a stale
 * version (409) from a missing record (404).
 */
const updateWithVersion = async (id, expectedVersion, data) =>
  withDbErrorHandling(async () => {
    const result = await prisma.accounts_currency_rate.updateMany({
      where: { id, deleted_at: null, version: expectedVersion },
      data: { ...data, version: { increment: 1 } },
    });
    if (result.count === 0) return null;
    return prisma.accounts_currency_rate.findFirst({
      where: { id },
      include: CURRENCY_RATE_INCLUDE,
    });
  });

/** Clears the base-currency flag on every other row in the same scope. */
const clearBaseCurrencyFlag = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.accounts_currency_rate.updateMany({
      where: { deleted_at: null, is_base_currency: true, ...where },
      data: { is_base_currency: false },
    })
  );

const runInTransaction = async (handler) =>
  withDbErrorHandling(() => prisma.$transaction(handler));

module.exports = {
  CURRENCY_RATE_INCLUDE,
  findFirst,
  findMany,
  count,
  groupByStatus,
  create,
  updateWithVersion,
  clearBaseCurrencyFlag,
  runInTransaction,
};
