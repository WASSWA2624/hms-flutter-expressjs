const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error?.code === 'P2025') {
      throw new HttpError('errors.resource.not_found', 404);
    }
    if (error?.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error?.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const withTransaction = async (callback) =>
  withDbErrorHandling(() => prisma.$transaction((tx) => callback(tx)));

const findInvoiceById = async (id, include = {}) =>
  withDbErrorHandling(() =>
    prisma.invoice.findFirst({
      where: {
        id,
        deleted_at: null,
      },
      include,
    })
  );

const findPaymentById = async (id, include = {}) =>
  withDbErrorHandling(() =>
    prisma.payment.findFirst({
      where: {
        id,
        deleted_at: null,
      },
      include,
    })
  );

const findApprovalById = async (id, include = {}) =>
  withDbErrorHandling(() =>
    prisma.billing_approval.findFirst({
      where: {
        id,
        deleted_at: null,
      },
      include,
    })
  );

const findUserById = async (id, select = { id: true, email: true, phone: true }) =>
  withDbErrorHandling(() =>
    prisma.user.findFirst({
      where: {
        id,
        deleted_at: null,
      },
      select,
    })
  );

const findPatientById = async (id, include = {}) =>
  withDbErrorHandling(() =>
    prisma.patient.findFirst({
      where: {
        id,
        deleted_at: null,
      },
      include,
    })
  );

const countInvoices = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.invoice.count({
      where: {
        deleted_at: null,
        ...where,
      },
    })
  );

const countClaims = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.insurance_claim.count({
      where: {
        deleted_at: null,
        ...where,
      },
    })
  );

const countApprovals = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.billing_approval.count({
      where: {
        deleted_at: null,
        ...where,
      },
    })
  );

const countPayments = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.payment.count({
      where: {
        deleted_at: null,
        ...where,
      },
    })
  );

const countRefunds = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.refund.count({
      where: {
        deleted_at: null,
        ...where,
      },
    })
  );

const findManyInvoices = async (where = {}, skip = 0, take = 20, orderBy = { issued_at: 'desc' }, include = {}) =>
  withDbErrorHandling(() =>
    prisma.invoice.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include,
    })
  );

const findManyPayments = async (where = {}, skip = 0, take = 20, orderBy = { paid_at: 'desc' }, include = {}) =>
  withDbErrorHandling(() =>
    prisma.payment.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include,
    })
  );

const findManyRefunds = async (where = {}, skip = 0, take = 20, orderBy = { refunded_at: 'desc' }, include = {}) =>
  withDbErrorHandling(() =>
    prisma.refund.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include,
    })
  );

const findManyClaims = async (where = {}, skip = 0, take = 20, orderBy = { submitted_at: 'desc' }, include = {}) =>
  withDbErrorHandling(() =>
    prisma.insurance_claim.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include,
    })
  );

const findManyPreAuthorizations = async (
  where = {},
  skip = 0,
  take = 20,
  orderBy = { requested_at: 'desc' },
  include = {}
) =>
  withDbErrorHandling(() =>
    prisma.pre_authorization.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include,
    })
  );

const findManyAdjustments = async (
  where = {},
  skip = 0,
  take = 20,
  orderBy = { adjusted_at: 'desc' },
  include = {}
) =>
  withDbErrorHandling(() =>
    prisma.billing_adjustment.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include,
    })
  );

const findManyApprovals = async (where = {}, skip = 0, take = 20, orderBy = { requested_at: 'desc' }, include = {}) =>
  withDbErrorHandling(() =>
    prisma.billing_approval.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include,
    })
  );

const aggregatePayments = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.payment.aggregate({
      where: {
        deleted_at: null,
        ...where,
      },
      _sum: {
        amount: true,
      },
    })
  );

const aggregateRefunds = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.refund.aggregate({
      where: {
        deleted_at: null,
        ...where,
      },
      _sum: {
        amount: true,
      },
    })
  );

const createApproval = async (data) =>
  withDbErrorHandling(() =>
    prisma.billing_approval.create({
      data,
    })
  );

const updateApproval = async (id, data) =>
  withDbErrorHandling(() =>
    prisma.billing_approval.update({
      where: { id },
      data,
    })
  );

const createRefund = async (data) =>
  withDbErrorHandling(() =>
    prisma.refund.create({
      data,
    })
  );

const createAdjustment = async (data) =>
  withDbErrorHandling(() =>
    prisma.billing_adjustment.create({
      data,
    })
  );

const updateInvoice = async (id, data) =>
  withDbErrorHandling(() =>
    prisma.invoice.update({
      where: { id },
      data,
    })
  );

const updatePayment = async (id, data) =>
  withDbErrorHandling(() =>
    prisma.payment.update({
      where: { id },
      data,
    })
  );

module.exports = {
  withTransaction,
  findInvoiceById,
  findPaymentById,
  findApprovalById,
  findUserById,
  findPatientById,
  countInvoices,
  countClaims,
  countApprovals,
  countPayments,
  countRefunds,
  findManyInvoices,
  findManyPayments,
  findManyRefunds,
  findManyClaims,
  findManyPreAuthorizations,
  findManyAdjustments,
  findManyApprovals,
  aggregatePayments,
  aggregateRefunds,
  createApproval,
  updateApproval,
  createRefund,
  createAdjustment,
  updateInvoice,
  updatePayment,
};
