/**
 * Apply request-time billing for clinical orders (lab, radiology, pharmacy).
 *
 * @module lib/billing/clinical-request-billing
 */

const { toDecimalNumber, toMoneyString, roundMoney } = require('@lib/billing/financials');

const SKIPPED_PAYMENT_STATUSES = new Set(['NOT_BILLED', 'NOT_REQUIRED', 'NO_CHARGE']);

const normalizePaymentStatus = (value) =>
  String(value || '')
    .trim()
    .toUpperCase();

const shouldApplyClinicalRequestBilling = (billing) => {
  if (!billing || typeof billing !== 'object' || Array.isArray(billing)) {
    return false;
  }
  const status = normalizePaymentStatus(billing.payment_status);
  if (!status || SKIPPED_PAYMENT_STATUSES.has(status)) {
    return false;
  }
  const scopedAmount = resolveScopedBillingAmount(billing);
  return toDecimalNumber(scopedAmount) > 0;
};

const resolveScopedBillingAmount = (billing = {}) => {
  if (billing.line_amount !== undefined && billing.line_amount !== null && billing.line_amount !== '') {
    return toMoneyString(billing.line_amount);
  }
  if (billing.total_amount !== undefined && billing.total_amount !== null && billing.total_amount !== '') {
    return toMoneyString(billing.total_amount);
  }
  const lineItems = Array.isArray(billing.line_items) ? billing.line_items : [];
  const summed = lineItems.reduce(
    (total, item) => total + toDecimalNumber(item?.line_total ?? item?.unit_price),
    0
  );
  return toMoneyString(summed);
};

const resolveBillingCurrency = (billing = {}, fallback = 'USD') => {
  const currency = String(billing.currency || fallback)
    .trim()
    .toUpperCase();
  return currency || fallback;
};

const buildInvoiceLineItems = (billing = {}, context = {}) => {
  const description = String(context.description || 'Clinical service').trim() || 'Clinical service';
  const scopedAmount = resolveScopedBillingAmount(billing);
  const lineItems = Array.isArray(billing.line_items) ? billing.line_items : [];
  const catalogItemId = context.catalogItemId ? String(context.catalogItemId) : null;

  if (catalogItemId && lineItems.length) {
    const match =
      lineItems.find((entry) => String(entry?.id || '') === catalogItemId) || null;
    if (match) {
      const quantity = Math.max(1, Number(match.quantity) || 1);
      const lineTotal = toMoneyString(billing.line_amount ?? match.line_total ?? match.unit_price ?? scopedAmount);
      const unitPrice = toMoneyString(match.unit_price ?? lineTotal);
      return [
        {
          description: String(match.label || description).trim() || description,
          quantity,
          unit_price: unitPrice,
          total_price: lineTotal,
        },
      ];
    }
  }

  if (lineItems.length) {
    return lineItems.map((entry) => {
      const quantity = Math.max(1, Number(entry.quantity) || 1);
      const unitPrice = toMoneyString(entry.unit_price ?? entry.line_total ?? '0');
      const totalPrice = toMoneyString(entry.line_total ?? entry.unit_price ?? unitPrice);
      return {
        description: String(entry.label || description).trim() || description,
        quantity,
        unit_price: unitPrice,
        total_price: totalPrice,
      };
    });
  }

  return [
    {
      description,
      quantity: 1,
      unit_price: scopedAmount,
      total_price: scopedAmount,
    },
  ];
};

const resolvePaymentStatusAfterApply = (billing, invoice, payment) => {
  const requested = normalizePaymentStatus(billing?.payment_status);
  if (!invoice) {
    return requested || 'NOT_BILLED';
  }
  if (!payment) {
    return requested === 'PAID' || requested === 'PARTIAL' ? 'PENDING' : requested || 'PENDING';
  }

  const invoiceTotal = toDecimalNumber(invoice.total_amount);
  const paidAmount = toDecimalNumber(payment.amount);
  if (paidAmount >= invoiceTotal - 0.009) {
    return 'PAID';
  }
  if (paidAmount > 0) {
    return 'PARTIAL';
  }
  return 'PENDING';
};

const buildBillingSnapshot = (billing, { invoice, payment, paymentStatus }) => ({
  payment_status: paymentStatus,
  currency: resolveBillingCurrency(billing, invoice?.currency || 'USD'),
  total_amount: toMoneyString(invoice?.total_amount ?? resolveScopedBillingAmount(billing)),
  paid_amount: payment ? toMoneyString(payment.amount) : null,
  payment_method: payment?.method || billing?.payment_method || null,
  payment_reference: payment?.transaction_ref || billing?.payment_reference || null,
  invoice_id: invoice?.id || null,
  line_items: Array.isArray(billing?.line_items) ? billing.line_items : [],
  ...(billing?.line_amount !== undefined && billing?.line_amount !== null
    ? { line_amount: toMoneyString(billing.line_amount) }
    : {}),
});

const extractStoredClinicalBilling = (record = {}) => {
  if (record.billing_snapshot && typeof record.billing_snapshot === 'object' && !Array.isArray(record.billing_snapshot)) {
    return record.billing_snapshot;
  }

  const requestDetails =
    record.request_details &&
    typeof record.request_details === 'object' &&
    !Array.isArray(record.request_details)
      ? record.request_details
      : null;
  const nestedBilling = requestDetails?.billing;
  if (nestedBilling && typeof nestedBilling === 'object' && !Array.isArray(nestedBilling)) {
    return nestedBilling;
  }

  return null;
};

const mapClinicalOrderBillingFields = (record = {}) => {
  const billing = extractStoredClinicalBilling(record);
  if (!billing) {
    return {};
  }

  return {
    payment_status: normalizePaymentStatus(billing.payment_status) || null,
    billing,
  };
};

const mapCatalogUnitPriceFields = (record = {}) => {
  const unitPrice =
    record.unit_price === undefined || record.unit_price === null
      ? null
      : toMoneyString(record.unit_price);
  const currency = record.currency ? String(record.currency).trim().toUpperCase() : null;

  if (!unitPrice || toDecimalNumber(unitPrice) <= 0) {
    return {};
  }

  return {
    unit_price: unitPrice,
    price: unitPrice,
    ...(currency ? { currency } : {}),
  };
};

/**
 * Create invoice (and optional payment) for a clinical order request.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>} Persisted billing snapshot
 */
const applyClinicalRequestBilling = async (tx, options = {}) => {
  const billing = options.billing;
  if (!shouldApplyClinicalRequestBilling(billing)) {
    return null;
  }

  const tenantId = options.tenantId;
  const patientId = options.patientId;
  if (!tenantId || !patientId) {
    return null;
  }

  const invoiceItems = buildInvoiceLineItems(billing, {
    description: options.description,
    catalogItemId: options.catalogItemId,
  });
  const invoiceTotal = roundMoney(
    invoiceItems.reduce((sum, item) => sum + toDecimalNumber(item.total_price), 0)
  );
  if (invoiceTotal <= 0) {
    return null;
  }

  const currency = resolveBillingCurrency(billing, options.currency || 'USD');
  const issuedAt = options.issuedAt instanceof Date ? options.issuedAt : new Date();
  const requestedStatus = normalizePaymentStatus(billing.payment_status);

  const invoice = await tx.invoice.create({
    data: {
      tenant_id: tenantId,
      facility_id: options.facilityId || null,
      patient_id: patientId,
      status: 'SENT',
      billing_status: 'ISSUED',
      total_amount: toMoneyString(invoiceTotal),
      currency,
      issued_at: issuedAt,
      items: {
        create: invoiceItems.map((item) => ({
          description: item.description,
          quantity: item.quantity,
          unit_price: item.unit_price,
          total_price: item.total_price,
        })),
      },
    },
  });

  let payment = null;
  const shouldRecordPayment =
    requestedStatus === 'PAID' ||
    requestedStatus === 'PARTIAL' ||
    toDecimalNumber(billing.paid_amount) > 0;

  if (shouldRecordPayment) {
    const paidAmount = toMoneyString(
      billing.paid_amount ?? (requestedStatus === 'PAID' ? invoiceTotal : billing.paid_amount ?? '0')
    );
    const paymentAmount = toDecimalNumber(paidAmount);
    if (paymentAmount > 0) {
      const paymentStatus = paymentAmount >= invoiceTotal - 0.009 ? 'COMPLETED' : 'COMPLETED';
      payment = await tx.payment.create({
        data: {
          tenant_id: tenantId,
          facility_id: options.facilityId || null,
          patient_id: patientId,
          invoice_id: invoice.id,
          status: paymentStatus,
          method: String(billing.payment_method || 'CASH').trim().toUpperCase(),
          amount: toMoneyString(paymentAmount),
          paid_at: issuedAt,
          transaction_ref: billing.payment_reference || null,
        },
      });

      await tx.invoice.update({
        where: { id: invoice.id },
        data: {
          status: paymentAmount >= invoiceTotal - 0.009 ? 'PAID' : 'SENT',
          billing_status: paymentAmount >= invoiceTotal - 0.009 ? 'PAID' : 'PARTIAL',
        },
      });
    }
  }

  const paymentStatus = resolvePaymentStatusAfterApply(billing, invoice, payment);
  return buildBillingSnapshot(billing, { invoice, payment, paymentStatus });
};

const persistLabOrderBilling = async (tx, { orderId, billing, ...context }) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, ...context });
  if (!snapshot) {
    return null;
  }
  await tx.lab_order.update({
    where: { id: orderId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

const persistPharmacyOrderBilling = async (tx, { orderId, billing, ...context }) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, ...context });
  if (!snapshot) {
    return null;
  }
  await tx.pharmacy_order.update({
    where: { id: orderId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

const persistRadiologyOrderBilling = async (tx, { orderId, requestDetails = {}, billing, ...context }) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, ...context });
  if (!snapshot) {
    return requestDetails;
  }
  const nextDetails = {
    ...requestDetails,
    billing: snapshot,
  };
  await tx.radiology_order.update({
    where: { id: orderId },
    data: { request_details: nextDetails },
  });
  return nextDetails;
};

module.exports = {
  shouldApplyClinicalRequestBilling,
  applyClinicalRequestBilling,
  persistLabOrderBilling,
  persistPharmacyOrderBilling,
  persistRadiologyOrderBilling,
  buildBillingSnapshot,
  extractStoredClinicalBilling,
  mapClinicalOrderBillingFields,
  mapCatalogUnitPriceFields,
  resolveScopedBillingAmount,
};
