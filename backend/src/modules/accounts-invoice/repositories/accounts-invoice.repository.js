/**
 * Accounts Invoice repository — facility outflow invoices.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const withDb = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    if (error.code === 'P2025') {
      throw new HttpError('errors.accounts_invoice.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findById = async (id, include = {}) =>
  withDb(() =>
    prisma.accounts_invoice.findFirst({
      where: { id, deleted_at: null },
      include,
    })
  );

const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { invoice_date: 'desc' },
  include = {}
) =>
  withDb(() =>
    prisma.accounts_invoice.findMany({
      where: { deleted_at: null, ...filters },
      skip,
      take,
      orderBy,
      include,
    })
  );

const count = async (filters = {}) =>
  withDb(() =>
    prisma.accounts_invoice.count({
      where: { deleted_at: null, ...filters },
    })
  );

const create = async (data) =>
  withDb(() => prisma.accounts_invoice.create({ data }));

const update = async (id, data) =>
  withDb(() => prisma.accounts_invoice.update({ where: { id }, data }));

const deleteItemsForInvoice = async (accountsInvoiceId) =>
  withDb(() =>
    prisma.accounts_invoice_item.updateMany({
      where: { accounts_invoice_id: accountsInvoiceId, deleted_at: null },
      data: { deleted_at: new Date() },
    })
  );

const createItems = async (items) =>
  withDb(() =>
    prisma.accounts_invoice_item.createMany({
      data: items,
    })
  );

module.exports = {
  findById,
  findMany,
  count,
  create,
  update,
  deleteItemsForInvoice,
  createItems,
};
