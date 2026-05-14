const APPLIED_ADJUSTMENT_STATUSES = new Set(['ISSUED', 'PAID', 'PARTIAL']);
const COUNTED_PAYMENT_STATUSES = new Set(['COMPLETED', 'REFUNDED']);

const toDecimalNumber = (value) => {
  if (value === null || value === undefined || value === '') return 0;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const roundMoney = (value) => Math.round(toDecimalNumber(value) * 100) / 100;

const toMoneyString = (value) => roundMoney(value).toFixed(2);

const computeInvoiceFinancials = (invoiceRecord = {}) => {
  const invoiceTotal = roundMoney(invoiceRecord.total_amount);
  const adjustmentTotal = roundMoney(
    (invoiceRecord.billing_adjustments || []).reduce((sum, adjustment) => {
      if (!adjustment || adjustment.deleted_at) return sum;
      if (!APPLIED_ADJUSTMENT_STATUSES.has(String(adjustment.status || '').toUpperCase())) {
        return sum;
      }
      return sum + toDecimalNumber(adjustment.amount);
    }, 0)
  );

  const grossPaidTotal = roundMoney(
    (invoiceRecord.payments || []).reduce((sum, payment) => {
      if (!payment || payment.deleted_at) return sum;
      if (!COUNTED_PAYMENT_STATUSES.has(String(payment.status || '').toUpperCase())) return sum;
      return sum + toDecimalNumber(payment.amount);
    }, 0)
  );

  const refundedTotal = roundMoney(
    (invoiceRecord.payments || []).reduce((sum, payment) => {
      if (!payment || payment.deleted_at) return sum;
      const paymentRefundTotal = (payment.refunds || []).reduce((refundSum, refund) => {
        if (!refund || refund.deleted_at) return refundSum;
        return refundSum + toDecimalNumber(refund.amount);
      }, 0);
      return sum + paymentRefundTotal;
    }, 0)
  );

  const effectiveTotal = roundMoney(invoiceTotal + adjustmentTotal);
  const netPaidTotal = roundMoney(grossPaidTotal - refundedTotal);
  const balanceDue = roundMoney(effectiveTotal - netPaidTotal);

  return {
    invoice_total: toMoneyString(invoiceTotal),
    adjustment_total: toMoneyString(adjustmentTotal),
    effective_total: toMoneyString(effectiveTotal),
    gross_paid_total: toMoneyString(grossPaidTotal),
    refunded_total: toMoneyString(refundedTotal),
    net_paid_total: toMoneyString(netPaidTotal),
    balance_due: toMoneyString(balanceDue),
  };
};

const deriveInvoiceState = (invoiceRecord = {}, financials = {}) => {
  const status = String(invoiceRecord.status || '').toUpperCase();
  const billingStatus = String(invoiceRecord.billing_status || '').toUpperCase();
  const effectiveTotal = toDecimalNumber(financials.effective_total);
  const netPaidTotal = toDecimalNumber(financials.net_paid_total);
  const balanceDue = toDecimalNumber(financials.balance_due);

  if (status === 'CANCELLED' || billingStatus === 'CANCELLED') {
    return { status: 'CANCELLED', billing_status: 'CANCELLED' };
  }

  if (balanceDue <= 0.009 || effectiveTotal <= 0) {
    return { status: 'PAID', billing_status: 'PAID' };
  }

  if (netPaidTotal > 0) {
    return {
      status: status === 'OVERDUE' ? 'OVERDUE' : 'SENT',
      billing_status: 'PARTIAL',
    };
  }

  if (status === 'DRAFT' || billingStatus === 'DRAFT') {
    return { status: 'DRAFT', billing_status: 'DRAFT' };
  }

  return {
    status: status === 'OVERDUE' ? 'OVERDUE' : 'SENT',
    billing_status: 'ISSUED',
  };
};

const recalculateInvoiceStateTx = async (tx, invoiceId) => {
  const invoiceRecord = await tx.invoice.findFirst({
    where: {
      id: invoiceId,
      deleted_at: null,
    },
    include: {
      payments: {
        where: { deleted_at: null },
        include: {
          refunds: {
            where: { deleted_at: null },
          },
        },
      },
      billing_adjustments: {
        where: { deleted_at: null },
      },
    },
  });

  if (!invoiceRecord) return null;

  const financials = computeInvoiceFinancials(invoiceRecord);
  const nextState = deriveInvoiceState(invoiceRecord, financials);
  const shouldUpdate =
    invoiceRecord.status !== nextState.status ||
    invoiceRecord.billing_status !== nextState.billing_status;

  const invoice = shouldUpdate
    ? await tx.invoice.update({
        where: { id: invoiceRecord.id },
        data: {
          status: nextState.status,
          billing_status: nextState.billing_status,
        },
      })
    : invoiceRecord;

  return {
    invoice,
    financials,
  };
};

module.exports = {
  toDecimalNumber,
  roundMoney,
  toMoneyString,
  computeInvoiceFinancials,
  deriveInvoiceState,
  recalculateInvoiceStateTx,
};
