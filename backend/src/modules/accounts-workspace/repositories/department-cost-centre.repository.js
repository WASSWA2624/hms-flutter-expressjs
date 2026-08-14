/**
 * Departments & Cost Centres repository
 *
 * @module modules/accounts-workspace/repositories
 * @description Data access for the finance projection of `department`. The
 * record is owned by `modules/department`; this repository reads and updates
 * the same rows rather than a parallel table. Every read filters soft-deleted
 * rows (`deleted_at: null`).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const USER_SELECT = {
  select: {
    id: true,
    human_friendly_id: true,
    profile: { select: { first_name: true, last_name: true } },
  },
};

const ACCOUNT_SELECT = {
  select: { id: true, human_friendly_id: true, code: true, name: true },
};

const DEPARTMENT_INCLUDE = {
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  parent: {
    select: { id: true, human_friendly_id: true, name: true, code: true },
  },
  manager: USER_SELECT,
  budget_owner: USER_SELECT,
  default_revenue_account: ACCOUNT_SELECT,
  default_expense_account: ACCOUNT_SELECT,
};

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2002') {
      throw new HttpError('errors.accounts.department.duplicate', 409, [
        { field: error.meta?.target?.[0] || 'department_code' },
      ]);
    }
    if (error.code === 'P2003') {
      throw new HttpError('errors.database.foreign_key_field', 400, [
        { field: error.meta?.field_name || 'field' },
      ]);
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.accounts.department.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findFirst = async (where = {}, include = DEPARTMENT_INCLUDE) =>
  withDbErrorHandling(() =>
    prisma.department.findFirst({
      where: { deleted_at: null, ...where },
      include,
    })
  );

const findMany = async (
  where = {},
  skip = 0,
  take = 20,
  orderBy = [{ effective_from: 'desc' }, { code: 'desc' }],
  include = DEPARTMENT_INCLUDE
) =>
  withDbErrorHandling(() =>
    prisma.department.findMany({
      where: { deleted_at: null, ...where },
      skip,
      take,
      orderBy,
      include,
    })
  );

const count = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.department.count({ where: { deleted_at: null, ...where } })
  );

/** Status tallies for the workspace summary and tab badge. */
const groupByStatus = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.department.groupBy({
      by: ['status'],
      where: { deleted_at: null, ...where },
      _count: { _all: true },
    })
  );

const create = async (data) =>
  withDbErrorHandling(() => prisma.department.create({ data }));

/**
 * Update guarded by the optimistic version the caller read.
 *
 * Returns `null` when no row matched so the service can distinguish a stale
 * version (409) from a missing record (404).
 */
const updateWithVersion = async (id, expectedVersion, data) =>
  withDbErrorHandling(async () => {
    const result = await prisma.department.updateMany({
      where: { id, deleted_at: null, version: expectedVersion },
      data: { ...data, version: { increment: 1 } },
    });
    if (result.count === 0) return null;
    return prisma.department.findFirst({
      where: { id },
      include: DEPARTMENT_INCLUDE,
    });
  });

/**
 * Rows that would break if this department were archived.
 *
 * Archive is blocked while active children or staffed units still point here,
 * so a soft archive can never strand live organizational structure.
 */
const countBlockingReferences = async (id) =>
  withDbErrorHandling(async () => {
    const [children, units, wards] = await Promise.all([
      prisma.department.count({
        where: { parent_id: id, deleted_at: null, status: { not: 'ARCHIVED' } },
      }),
      prisma.unit.count({ where: { department_id: id, deleted_at: null } }),
      prisma.ward.count({ where: { department_id: id, deleted_at: null } }),
    ]);
    return { children, units, wards, total: children + units + wards };
  });

const runInTransaction = async (handler) =>
  withDbErrorHandling(() => prisma.$transaction(handler));

module.exports = {
  DEPARTMENT_INCLUDE,
  findFirst,
  findMany,
  count,
  groupByStatus,
  create,
  updateWithVersion,
  countBlockingReferences,
  runInTransaction,
};
