/**
 * Apply request-time billing for clinical orders (lab, radiology, pharmacy).
 *
 * @module lib/billing/clinical-request-billing
 */

const {
  toDecimalNumber,
  toMoneyString,
  roundMoney,
  recalculateInvoiceStateTx,
} = require('@lib/billing/financials');

const SKIPPED_PAYMENT_STATUSES = new Set(['NOT_BILLED', 'NOT_REQUIRED', 'NO_CHARGE']);

const VALID_PAYMENT_METHODS = new Set([
  'CASH',
  'CREDIT_CARD',
  'DEBIT_CARD',
  'PREPAID_CARD',
  'GIFT_CARD',
  'VOUCHER',
  'BANK_CHECK',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'INSURANCE',
  'OTHER',
]);

const PAYMENT_METHOD_ALIASES = new Map([
  ['CARD', 'CREDIT_CARD'],
  ['CREDIT', 'CREDIT_CARD'],
  ['DEBIT', 'DEBIT_CARD'],
  ['CHEQUE', 'BANK_CHECK'],
  ['CHECK', 'BANK_CHECK'],
  ['MOMO', 'MOBILE_MONEY'],
  ['MOBILE', 'MOBILE_MONEY'],
  ['TRANSFER', 'BANK_TRANSFER'],
  ['BANK', 'BANK_TRANSFER'],
]);

const COMPLETED_PAYMENT_STATUSES = new Set(['COMPLETED', 'REFUNDED']);

/**
 * Normalize an arbitrary payment-method string to a valid PaymentMethodType enum value.
 *
 * @param {unknown} value
 * @returns {string}
 */
const normalizePaymentMethod = (value) => {
  const normalized = String(value || 'CASH')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (VALID_PAYMENT_METHODS.has(normalized)) {
    return normalized;
  }
  if (PAYMENT_METHOD_ALIASES.has(normalized)) {
    return PAYMENT_METHOD_ALIASES.get(normalized);
  }
  return 'OTHER';
};

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

const extractInvoiceIdFromSnapshot = (snapshot) => {
  if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) {
    return null;
  }
  const invoiceId = snapshot.invoice_id;
  return invoiceId ? String(invoiceId) : null;
};

const invoiceHasCompletedPayment = (invoiceRecord) =>
  (invoiceRecord?.payments || []).some(
    (payment) =>
      payment &&
      !payment.deleted_at &&
      COMPLETED_PAYMENT_STATUSES.has(String(payment.status || '').toUpperCase())
  );

/**
 * Cancel (void) an invoice previously generated from a clinical request, provided it
 * has no settled payments. Invoices with completed payments are left untouched so the
 * billing workspace can drive a refund/adjustment instead.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {string} invoiceId
 * @returns {Promise<boolean>} true when the invoice was cancelled (or already cancelled)
 */
const cancelInvoiceIfReversible = async (tx, invoiceId) => {
  if (!invoiceId) {
    return false;
  }
  const invoice = await tx.invoice.findFirst({
    where: { id: invoiceId, deleted_at: null },
    include: { payments: { where: { deleted_at: null } } },
  });
  if (!invoice) {
    return false;
  }
  if (invoiceHasCompletedPayment(invoice)) {
    return false;
  }
  if (String(invoice.status || '').toUpperCase() === 'CANCELLED') {
    return true;
  }
  await tx.invoice_item.updateMany({
    where: { invoice_id: invoice.id, deleted_at: null },
    data: { deleted_at: new Date() },
  });
  await tx.payment.updateMany({
    where: { invoice_id: invoice.id, deleted_at: null, status: 'PENDING' },
    data: { status: 'FAILED' },
  });
  await tx.invoice.update({
    where: { id: invoice.id },
    data: { status: 'CANCELLED', billing_status: 'CANCELLED' },
  });
  return true;
};

/**
 * Reverse the billing previously applied for a clinical order (used on delete/cancel).
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @param {Object|null} options.existingSnapshot - Stored billing snapshot
 * @returns {Promise<boolean>} true when an invoice was reversed
 */
const reverseClinicalRequestBilling = async (tx, { existingSnapshot } = {}) => {
  const invoiceId = extractInvoiceIdFromSnapshot(existingSnapshot);
  if (!invoiceId) {
    return false;
  }
  return cancelInvoiceIfReversible(tx, invoiceId);
};

const recordRequestPayment = async (
  tx,
  { invoiceId, billing, invoiceTotal, tenantId, patientId, facilityId, issuedAt }
) => {
  const requestedStatus = normalizePaymentStatus(billing.payment_status);
  const shouldRecordPayment =
    requestedStatus === 'PAID' ||
    requestedStatus === 'PARTIAL' ||
    toDecimalNumber(billing.paid_amount) > 0;
  if (!shouldRecordPayment) {
    return null;
  }

  const paidAmount = toMoneyString(
    billing.paid_amount ?? (requestedStatus === 'PAID' ? invoiceTotal : '0')
  );
  const paymentAmount = toDecimalNumber(paidAmount);
  if (paymentAmount <= 0) {
    return null;
  }

  return tx.payment.create({
    data: {
      tenant_id: tenantId,
      facility_id: facilityId || null,
      patient_id: patientId,
      invoice_id: invoiceId,
      status: 'COMPLETED',
      method: normalizePaymentMethod(billing.payment_method),
      amount: toMoneyString(paymentAmount),
      paid_at: issuedAt,
      transaction_ref: billing.payment_reference || null,
    },
  });
};

/**
 * Create or update the invoice (and optional payment) for a clinical order request.
 *
 * When `existingSnapshot` references a still-mutable invoice (no completed payments),
 * the invoice is updated in place so editing an order keeps a single dynamic invoice.
 * When billing is no longer chargeable, any prior invoice is reversed.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>} Persisted billing snapshot (null when nothing is billed)
 */
const applyClinicalRequestBilling = async (tx, options = {}) => {
  const billing = options.billing;
  const existingInvoiceId = extractInvoiceIdFromSnapshot(options.existingSnapshot);

  if (!shouldApplyClinicalRequestBilling(billing)) {
    if (existingInvoiceId) {
      await cancelInvoiceIfReversible(tx, existingInvoiceId);
    }
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
    if (existingInvoiceId) {
      await cancelInvoiceIfReversible(tx, existingInvoiceId);
    }
    return null;
  }

  const currency = resolveBillingCurrency(billing, options.currency || 'USD');
  const issuedAt = options.issuedAt instanceof Date ? options.issuedAt : new Date();
  const itemCreateData = invoiceItems.map((item) => ({
    description: item.description,
    quantity: item.quantity,
    unit_price: item.unit_price,
    total_price: item.total_price,
  }));

  // Attempt in-place update of the existing invoice when it is still mutable.
  let invoice = null;
  if (existingInvoiceId) {
    const candidate = await tx.invoice.findFirst({
      where: { id: existingInvoiceId, deleted_at: null },
      include: { payments: { where: { deleted_at: null } } },
    });
    if (candidate && !invoiceHasCompletedPayment(candidate)) {
      await tx.invoice_item.updateMany({
        where: { invoice_id: candidate.id, deleted_at: null },
        data: { deleted_at: new Date() },
      });
      invoice = await tx.invoice.update({
        where: { id: candidate.id },
        data: {
          tenant_id: tenantId,
          facility_id: options.facilityId || null,
          patient_id: patientId,
          status: 'SENT',
          billing_status: 'ISSUED',
          total_amount: toMoneyString(invoiceTotal),
          currency,
          issued_at: issuedAt,
          items: { create: itemCreateData },
        },
      });
    }
  }

  if (!invoice) {
    // The prior invoice (if any) is paid or missing; cancel reversible leftovers and
    // create a fresh invoice so the order points at a clean, accurate charge.
    if (existingInvoiceId) {
      await cancelInvoiceIfReversible(tx, existingInvoiceId);
    }
    invoice = await tx.invoice.create({
      data: {
        tenant_id: tenantId,
        facility_id: options.facilityId || null,
        patient_id: patientId,
        status: 'SENT',
        billing_status: 'ISSUED',
        total_amount: toMoneyString(invoiceTotal),
        currency,
        issued_at: issuedAt,
        items: { create: itemCreateData },
      },
    });
  }

  const payment = await recordRequestPayment(tx, {
    invoiceId: invoice.id,
    billing,
    invoiceTotal,
    tenantId,
    patientId,
    facilityId: options.facilityId,
    issuedAt,
  });

  // Recalculate invoice status from authoritative payment/adjustment data.
  const recalculated = await recalculateInvoiceStateTx(tx, invoice.id);
  invoice = recalculated?.invoice || invoice;

  const paymentStatus = resolvePaymentStatusAfterApply(billing, invoice, payment);
  return buildBillingSnapshot(billing, { invoice, payment, paymentStatus });
};

const syncClinicalRequestBilling = applyClinicalRequestBilling;

const persistLabOrderBilling = async (tx, { orderId, billing, existingSnapshot, ...context }) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, existingSnapshot, ...context });
  await tx.lab_order.update({
    where: { id: orderId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

const persistPharmacyOrderBilling = async (
  tx,
  { orderId, billing, existingSnapshot, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, existingSnapshot, ...context });
  await tx.pharmacy_order.update({
    where: { id: orderId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

const persistRadiologyOrderBilling = async (
  tx,
  { orderId, requestDetails = {}, billing, existingSnapshot, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, existingSnapshot, ...context });
  const nextDetails = { ...requestDetails };
  if (snapshot) {
    nextDetails.billing = snapshot;
  } else {
    delete nextDetails.billing;
  }
  await tx.radiology_order.update({
    where: { id: orderId },
    data: { request_details: nextDetails },
  });
  return nextDetails;
};

const persistWardRoundBilling = async (
  tx,
  { wardRoundId, billing, existingSnapshot, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, existingSnapshot, ...context });
  await tx.ward_round.update({
    where: { id: wardRoundId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

const persistProcedureBilling = async (
  tx,
  { procedureId, billing, existingSnapshot, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, existingSnapshot, ...context });
  await tx.procedure.update({
    where: { id: procedureId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

const persistTheatreCaseBilling = async (
  tx,
  { theatreCaseId, billing, existingSnapshot, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, { billing, existingSnapshot, ...context });
  await tx.theatre_case.update({
    where: { id: theatreCaseId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

module.exports = {
  shouldApplyClinicalRequestBilling,
  applyClinicalRequestBilling,
  syncClinicalRequestBilling,
  reverseClinicalRequestBilling,
  cancelInvoiceIfReversible,
  normalizePaymentMethod,
  persistLabOrderBilling,
  persistPharmacyOrderBilling,
  persistRadiologyOrderBilling,
  persistWardRoundBilling,
  persistProcedureBilling,
  persistTheatreCaseBilling,
  buildBillingSnapshot,
  extractStoredClinicalBilling,
  mapClinicalOrderBillingFields,
  mapCatalogUnitPriceFields,
  resolveScopedBillingAmount,
};
