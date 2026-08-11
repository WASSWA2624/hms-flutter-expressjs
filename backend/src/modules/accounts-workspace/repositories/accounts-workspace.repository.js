const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const withDbErrorHandling = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const findInvoiceRowsForLedgers = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.invoice.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      select: {
        id: true,
        patient_id: true,
        total_amount: true,
        currency: true,
        updated_at: true,
        created_at: true,
        patient: {
          select: {
            id: true,
            first_name: true,
            last_name: true,
            human_friendly_id: true,
            display_id: true,
          },
        },
      },
      take: 5000,
      orderBy: { updated_at: 'desc' },
    })
  );

const findPaymentRowsForLedgers = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.payment.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      select: {
        id: true,
        patient_id: true,
        amount: true,
        status: true,
        updated_at: true,
        created_at: true,
      },
      take: 5000,
      orderBy: { updated_at: 'desc' },
    })
  );

const findRefundRowsForLedgers = async (where = {}) =>
  withDbErrorHandling(() =>
    prisma.refund.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      select: {
        id: true,
        amount: true,
        updated_at: true,
        created_at: true,
        payment: {
          select: {
            patient_id: true,
          },
        },
      },
      take: 5000,
      orderBy: { updated_at: 'desc' },
    })
  );

module.exports = {
  findInvoiceRowsForLedgers,
  findPaymentRowsForLedgers,
  findRefundRowsForLedgers,
};
