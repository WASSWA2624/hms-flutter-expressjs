/**
 * Payment Methods repository
 *
 * @module modules/accounts-workspace/repositories
 * @description Data access for payment method configuration. Standard CRUD
 * only; every read filters soft-deleted rows (`deleted_at: null`).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const ACCOUNT_SELECT = {
  select: { id: true, human_friendly_id: true, code: true, name: true },
};

const PAYMENT_METHOD_INCLUDE = {
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  settlement_account: ACCOUNT_SELECT,
  clearing_account: ACCOUNT_SELECT,
};

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2002') {
      throw new HttpError('errors.accounts.payment_method.duplicate', 409, [
        { field: error.meta?.target?.[0] || 'method_code' },
      ]);
    }
    if (error.code === 'P2003') {
      throw new HttpError('errors.database.foreign_key_field', 400, [
        { field: error.meta?.field_name || 'field' },
      ]);
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.accounts.payment_method.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findFirst = async (where = {}, include = PAYMENT_METHOD_INCLUDE) =>
  withDbErrorHandling(() =>
    prisma.payment_method.findFirst({
      where: { deleted_at: null, ...where },
      include,
    })
  );

const findMany = async (
  where = {},
  skip = 0,
  take = 20,
  orderBy = [{ effective_from: 'desc' }, { method_code: 'desc' }],
  include = PAYMENT_METHOD_INCLUDE
) =>
  withDbErrorHandling(() =>
    prisma.payment_method.findMany({
      where: { deleted_at: null, ...where },
      skip,
      take,
      orderBy,
      include,
    })
  );

const count = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.payment_method.count({ where: { deleted_at: null, ...where } })
  );

/** Status tallies for the workspace summary and tab badge. */
const groupByStatus = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.payment_method.groupBy({
      by: ['status'],
      where: { deleted_at: null, ...where },
      _count: { _all: true },
    })
  );

const create = async (data) =>
  withDbErrorHandling(() => prisma.payment_method.create({ data }));

/**
 * Update guarded by the optimistic version the caller read.
 *
 * Returns `null` when no row matched so the service can distinguish a stale
 * version (409) from a missing record (404).
 */
const updateWithVersion = async (id, expectedVersion, data) =>
  withDbErrorHandling(async () => {
    const result = await prisma.payment_method.updateMany({
      where: { id, deleted_at: null, version: expectedVersion },
      data: { ...data, version: { increment: 1 } },
    });
    if (result.count === 0) return null;
    return prisma.payment_method.findFirst({
      where: { id },
      include: PAYMENT_METHOD_INCLUDE,
    });
  });

/**
 * Recorded payments that already used this tender in this scope.
 *
 * Archiving a method that history references would strand posted receipts
 * behind a soft delete, so the service refuses it.
 */
const countRecordedPayments = async ({ tenantId, facilityId, methodType }) =>
  withDbErrorHandling(() =>
    prisma.payment.count({
      where: {
        deleted_at: null,
        tenant_id: tenantId,
        ...(facilityId ? { facility_id: facilityId } : {}),
        method: methodType,
      },
    })
  );

const runInTransaction = async (handler) =>
  withDbErrorHandling(() => prisma.$transaction(handler));

module.exports = {
  PAYMENT_METHOD_INCLUDE,
  findFirst,
  findMany,
  count,
  groupByStatus,
  create,
  updateWithVersion,
  countRecordedPayments,
  runInTransaction,
};
