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

const buildBillingSnapshot = (billing, { invoice, payment, paymentStatus, encounterId, encounterDisplayId }) => ({
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
  ...(encounterId ? { encounter_id: String(encounterId) } : {}),
  ...(encounterDisplayId ? { encounter_display_id: String(encounterDisplayId) } : {}),
});

const normalizeBillingLineItem = (entry = {}) => {
  const quantity = Math.max(1, Number(entry.quantity) || 1);
  const unitPrice = entry.unit_price != null ? toMoneyString(entry.unit_price) : null;
  const lineTotal = toMoneyString(
    entry.line_total ?? (unitPrice ? toDecimalNumber(unitPrice) * quantity : 0)
  );
  return {
    id: String(entry.id || entry.lab_test_id || entry.lab_panel_id || '').trim(),
    label: String(entry.label || entry.name || 'Clinical service').trim() || 'Clinical service',
    quantity,
    ...(unitPrice ? { unit_price: unitPrice } : {}),
    ...(toDecimalNumber(lineTotal) > 0 ? { line_total: lineTotal } : {}),
  };
};

/**
 * Build a pending billing payload for the billing office (no point-of-care payment).
 *
 * @param {Object} options
 * @param {Array<Object>} [options.lineItems]
 * @param {string} [options.currency]
 * @returns {Object|null}
 */
const buildPendingClinicalRequestBilling = ({ lineItems = [], currency = 'USD' } = {}) => {
  const normalizedItems = (Array.isArray(lineItems) ? lineItems : [])
    .map(normalizeBillingLineItem)
    .filter((entry) => entry.id || entry.label);
  const total = roundMoney(
    normalizedItems.reduce(
      (sum, item) => sum + toDecimalNumber(item.line_total ?? item.unit_price ?? 0),
      0
    )
  );
  if (total <= 0) {
    return null;
  }
  return {
    payment_status: 'PENDING',
    currency: resolveBillingCurrency({ currency }),
    line_items: normalizedItems,
    total_amount: toMoneyString(total),
  };
};

/**
 * Strip pay-now fields and force pending clearance for billing-office payment.
 *
 * @param {Object|null|undefined} billing
 * @returns {Object|null}
 */
const normalizeBillingOfficeClinicalBilling = (billing) => {
  if (!billing || typeof billing !== 'object' || Array.isArray(billing)) {
    return null;
  }
  return buildPendingClinicalRequestBilling({
    lineItems: billing.line_items,
    currency: billing.currency,
  });
};

const resolveInvoicePaymentStatus = (invoice = {}) => {
  const billingStatus = normalizePaymentStatus(invoice.billing_status);
  if (billingStatus === 'PAID') {
    return 'PAID';
  }
  if (billingStatus === 'PARTIAL') {
    return 'PARTIAL';
  }
  const completedPayments = (invoice.payments || []).filter(
    (payment) =>
      payment &&
      !payment.deleted_at &&
      COMPLETED_PAYMENT_STATUSES.has(String(payment.status || '').toUpperCase())
  );
  const paidAmount = completedPayments.reduce(
    (sum, payment) => sum + toDecimalNumber(payment.amount),
    0
  );
  const invoiceTotal = toDecimalNumber(invoice.total_amount);
  if (paidAmount >= invoiceTotal - 0.009 && invoiceTotal > 0) {
    return 'PAID';
  }
  if (paidAmount > 0) {
    return 'PARTIAL';
  }
  return 'PENDING';
};

const mergeSnapshotPaymentStatus = (snapshot, invoice, paymentStatus) => {
  if (!snapshot || typeof snapshot !== 'object') {
    return null;
  }
  const completedPayments = (invoice?.payments || []).filter(
    (payment) =>
      payment &&
      !payment.deleted_at &&
      COMPLETED_PAYMENT_STATUSES.has(String(payment.status || '').toUpperCase())
  );
  const paidAmount = completedPayments.reduce(
    (sum, payment) => sum + toDecimalNumber(payment.amount),
    0
  );
  const latestPayment = completedPayments.sort(
    (left, right) =>
      (toDate(right.paid_at)?.getTime() || 0) - (toDate(left.paid_at)?.getTime() || 0)
  )[0];
  return {
    ...snapshot,
    payment_status: paymentStatus,
    total_amount: toMoneyString(invoice?.total_amount ?? snapshot.total_amount),
    paid_amount: paidAmount > 0 ? toMoneyString(paidAmount) : null,
    payment_method: latestPayment?.method || snapshot.payment_method || null,
    payment_reference: latestPayment?.transaction_ref || snapshot.payment_reference || null,
    invoice_id: invoice?.id || snapshot.invoice_id || null,
  };
};

const toDate = (value) => {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

/**
 * Resolve encounter context for invoices linked to clinical orders.
 *
 * @param {string[]} invoiceIds
 * @returns {Promise<Map<string, { encounter_id: string|null, encounter_display_id: string|null }>>}
 */
const resolveClinicalInvoiceContexts = async (invoiceIds = []) => {
  const contexts = await findClinicalOrdersForInvoices(invoiceIds);
  const resolved = new Map();
  for (const [invoiceId, context] of contexts.entries()) {
    const modules = [...context.source_modules];
    resolved.set(invoiceId, {
      encounter_id: context.encounter_id || null,
      encounter_display_id: context.encounter_display_id || null,
      source_modules: modules,
      source_module: modules[0] || null,
    });
  }
  return resolved;
};

const CLINICAL_INVOICE_SOURCES = Object.freeze([
  {
    model: 'lab_order',
    label: 'Laboratory',
    invoiceFilterField: 'billing_snapshot',
    invoiceFilterPath: '$.invoice_id',
    orderSelect: {
      billing_snapshot: true,
      encounter_id: true,
      encounter: { select: { id: true, human_friendly_id: true } },
    },
  },
  {
    model: 'pharmacy_order',
    label: 'Pharmacy',
    invoiceFilterField: 'billing_snapshot',
    invoiceFilterPath: '$.invoice_id',
    orderSelect: {
      billing_snapshot: true,
      encounter_id: true,
      encounter: { select: { id: true, human_friendly_id: true } },
    },
  },
  {
    model: 'radiology_order',
    label: 'Radiology',
    invoiceFilterField: 'request_details',
    invoiceFilterPath: '$.billing.invoice_id',
    orderSelect: {
      request_details: true,
      encounter_id: true,
      encounter: { select: { id: true, human_friendly_id: true } },
    },
  },
]);

const buildClinicalInvoiceIdFilter = (source, invoiceId) => ({
  [source.invoiceFilterField]: {
    path: source.invoiceFilterPath,
    equals: invoiceId,
  },
});

const normalizeSourceModuleLabel = (value) => {
  const token = String(value || '').trim();
  if (!token) {
    return null;
  }
  const normalized = token.toLowerCase();
  if (normalized.includes('lab')) {
    return 'Laboratory';
  }
  if (normalized.includes('radio')) {
    return 'Radiology';
  }
  if (normalized.includes('pharm')) {
    return 'Pharmacy';
  }
  return token.charAt(0).toUpperCase() + token.slice(1);
};

const findClinicalOrdersForInvoices = async (invoiceIds = []) => {
  const prisma = require('@prisma/client');
  const uniqueIds = [...new Set((invoiceIds || []).map((id) => String(id || '').trim()).filter(Boolean))];
  const contexts = new Map();
  if (!uniqueIds.length) {
    return contexts;
  }

  for (const source of CLINICAL_INVOICE_SOURCES) {
    if (!prisma?.[source.model]?.findMany) {
      continue;
    }
    const orders = await prisma[source.model].findMany({
      where: {
        deleted_at: null,
        OR: uniqueIds.map((invoiceId) => buildClinicalInvoiceIdFilter(source, invoiceId)),
      },
      select: source.orderSelect,
    });

    for (const order of orders) {
      const snapshot = extractStoredClinicalBilling(order);
      const invoiceId = extractInvoiceIdFromSnapshot(snapshot);
      if (!invoiceId) {
        continue;
      }
      const existing = contexts.get(invoiceId) || {
        encounter_id: null,
        encounter_display_id: null,
        source_modules: new Set(),
      };
      existing.source_modules.add(source.label);
      if (!existing.encounter_id) {
        existing.encounter_id = order.encounter_id || snapshot?.encounter_id || null;
        existing.encounter_display_id =
          order.encounter?.human_friendly_id ||
          snapshot?.encounter_display_id ||
          order.encounter_id ||
          null;
      }
      contexts.set(invoiceId, existing);
    }
  }

  return contexts;
};

const resolveInvoiceIdsForEncounterToken = async (scope, token) => {
  const prisma = require('@prisma/client');
  const normalized = String(token || '').trim();
  if (!normalized) {
    return [];
  }
  const invoiceIds = new Set();
  const upper = normalized.toUpperCase();
  const encounterWhere = {
    deleted_at: null,
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    OR: [{ human_friendly_id: { contains: upper } }, { id: normalized }],
  };
  const encounters = prisma?.encounter?.findMany
    ? await prisma.encounter.findMany({
        where: encounterWhere,
        select: { id: true, human_friendly_id: true },
        take: 50,
      })
    : [];
  const encounterIds = encounters.map((entry) => entry.id).filter(Boolean);

  if (encounterIds.length) {
    for (const source of CLINICAL_INVOICE_SOURCES) {
      if (!prisma?.[source.model]?.findMany) {
        continue;
      }
      const orders = await prisma[source.model].findMany({
        where: {
          deleted_at: null,
          encounter_id: { in: encounterIds },
        },
        select: source.orderSelect,
        take: 500,
      });
      for (const order of orders) {
        const snapshot = extractStoredClinicalBilling(order);
        const invoiceId = extractInvoiceIdFromSnapshot(snapshot);
        if (invoiceId) {
          invoiceIds.add(invoiceId);
        }
      }
    }
    return [...invoiceIds];
  }

  for (const source of CLINICAL_INVOICE_SOURCES) {
    if (!prisma?.[source.model]?.findMany) {
      continue;
    }
    const orders = await prisma[source.model].findMany({
      where: { deleted_at: null },
      select: source.orderSelect,
      take: 500,
      orderBy: { ordered_at: 'desc' },
    });
    for (const order of orders) {
      const snapshot = extractStoredClinicalBilling(order);
      const invoiceId = extractInvoiceIdFromSnapshot(snapshot);
      if (!invoiceId) {
        continue;
      }
      const encounterDisplayId = String(
        order.encounter?.human_friendly_id || snapshot?.encounter_display_id || ''
      ).toUpperCase();
      if (encounterDisplayId.includes(upper)) {
        invoiceIds.add(invoiceId);
      }
    }
  }

  return [...invoiceIds];
};

const resolveInvoiceIdsForSourceModule = async (scope, sourceModule) => {
  const prisma = require('@prisma/client');
  const label = normalizeSourceModuleLabel(sourceModule);
  if (!label) {
    return [];
  }
  const source = CLINICAL_INVOICE_SOURCES.find(
    (entry) => entry.label.toLowerCase() === label.toLowerCase()
  );
  if (!source || !prisma?.[source.model]?.findMany) {
    return [];
  }
  const orders = await prisma[source.model].findMany({
    where: { deleted_at: null },
    select: source.orderSelect,
    take: 1000,
  });
  const invoiceIds = new Set();
  for (const order of orders) {
    const snapshot = extractStoredClinicalBilling(order);
    const invoiceId = extractInvoiceIdFromSnapshot(snapshot);
    if (invoiceId) {
      invoiceIds.add(invoiceId);
    }
  }
  return [...invoiceIds];
};

/**
 * Sync stored clinical-order billing snapshots after invoice payment changes.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {string} invoiceId
 * @returns {Promise<{ labOrderIds: string[] }>}
 */
const syncClinicalOrderBillingSnapshotsFromInvoiceTx = async (tx, invoiceId) => {
  const normalizedInvoiceId = String(invoiceId || '').trim();
  if (!normalizedInvoiceId) {
    return { labOrderIds: [] };
  }

  const invoice = await tx.invoice.findFirst({
    where: { id: normalizedInvoiceId, deleted_at: null },
    include: { payments: { where: { deleted_at: null } } },
  });
  if (!invoice) {
    return { labOrderIds: [] };
  }

  const paymentStatus = resolveInvoicePaymentStatus(invoice);
  const labOrders = await tx.lab_order.findMany({
    where: {
      deleted_at: null,
      billing_snapshot: { path: '$.invoice_id', equals: normalizedInvoiceId },
    },
    select: { id: true, billing_snapshot: true },
  });

  const labOrderIds = [];
  for (const order of labOrders) {
    const snapshot = extractStoredClinicalBilling(order);
    if (!snapshot) {
      continue;
    }
    const nextSnapshot = mergeSnapshotPaymentStatus(snapshot, invoice, paymentStatus);
    await tx.lab_order.update({
      where: { id: order.id },
      data: { billing_snapshot: nextSnapshot },
    });
    labOrderIds.push(order.id);
  }

  const pharmacyOrders = await tx.pharmacy_order.findMany({
    where: {
      deleted_at: null,
      billing_snapshot: { path: '$.invoice_id', equals: normalizedInvoiceId },
    },
    select: { id: true, billing_snapshot: true },
  });
  for (const order of pharmacyOrders) {
    const snapshot = extractStoredClinicalBilling(order);
    if (!snapshot) {
      continue;
    }
    const nextSnapshot = mergeSnapshotPaymentStatus(snapshot, invoice, paymentStatus);
    await tx.pharmacy_order.update({
      where: { id: order.id },
      data: { billing_snapshot: nextSnapshot },
    });
  }

  return { labOrderIds };
};

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
  return buildBillingSnapshot(billing, {
    invoice,
    payment,
    paymentStatus,
    encounterId: options.encounterId,
    encounterDisplayId: options.encounterDisplayId,
  });
};

const syncClinicalRequestBilling = applyClinicalRequestBilling;

const persistLabOrderBilling = async (
  tx,
  { orderId, billing, existingSnapshot, encounterId, encounterDisplayId, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    encounterId,
    encounterDisplayId,
    ...context,
  });
  await tx.lab_order.update({
    where: { id: orderId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

const resolveCatalogRecord = async ({ identifier, model, tenantId, select }) => {
  const prisma = require('@prisma/client');
  const token = String(identifier || '').trim();
  if (!token || !prisma?.[model]?.findFirst) {
    return null;
  }
  return prisma[model].findFirst({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      OR: [{ id: token }, { human_friendly_id: token }],
    },
    select,
  });
};

const resolveLabTestPricing = async ({ labTestId, tenantId, facilityId }) => {
  const prisma = require('@prisma/client');
  if (facilityId && prisma?.facility_lab_test_offering?.findFirst) {
    const offering = await prisma.facility_lab_test_offering.findFirst({
      where: {
        deleted_at: null,
        is_active: true,
        facility_id: facilityId,
        lab_test_id: labTestId,
      },
      select: { unit_price: true, currency: true },
    });
    if (offering?.unit_price != null && toDecimalNumber(offering.unit_price) > 0) {
      return {
        unitPrice: toMoneyString(offering.unit_price),
        currency: offering.currency || null,
      };
    }
  }
  const test = await prisma.lab_test.findFirst({
    where: { id: labTestId, deleted_at: null, tenant_id: tenantId },
    select: { unit_price: true, currency: true },
  });
  if (test?.unit_price != null && toDecimalNumber(test.unit_price) > 0) {
    return {
      unitPrice: toMoneyString(test.unit_price),
      currency: test.currency || null,
    };
  }
  return null;
};

const resolveLabPanelPricing = async ({ labPanelId, tenantId, facilityId }) => {
  const prisma = require('@prisma/client');
  if (facilityId && prisma?.facility_lab_panel_offering?.findFirst) {
    const offering = await prisma.facility_lab_panel_offering.findFirst({
      where: {
        deleted_at: null,
        is_active: true,
        facility_id: facilityId,
        lab_panel_id: labPanelId,
      },
      select: { unit_price: true, currency: true },
    });
    if (offering?.unit_price != null && toDecimalNumber(offering.unit_price) > 0) {
      return {
        unitPrice: toMoneyString(offering.unit_price),
        currency: offering.currency || null,
      };
    }
  }
  const panel = await prisma.lab_panel.findFirst({
    where: { id: labPanelId, deleted_at: null, tenant_id: tenantId },
    select: { unit_price: true, currency: true },
  });
  if (panel?.unit_price != null && toDecimalNumber(panel.unit_price) > 0) {
    return {
      unitPrice: toMoneyString(panel.unit_price),
      currency: panel.currency || null,
    };
  }
  return null;
};

/**
 * Build pending billing from lab order request selections (server-side fallback).
 *
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const buildLabOrderBillingFromRequest = async ({
  requestedTests = [],
  requestedPanels = [],
  tenantId,
  facilityId = null,
}) => {
  const lineItems = [];
  let currency = 'USD';

  for (const request of requestedTests) {
    const requestedId = String(request?.lab_test_id || '').trim();
    if (!requestedId) {
      continue;
    }
    const test = await resolveCatalogRecord({
      identifier: requestedId,
      model: 'lab_test',
      tenantId,
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        unit_price: true,
        currency: true,
      },
    });
    if (!test) {
      continue;
    }
    const pricing = await resolveLabTestPricing({
      labTestId: test.id,
      tenantId,
      facilityId,
    });
    const unitPrice = pricing?.unitPrice ?? (test.unit_price != null ? toMoneyString(test.unit_price) : null);
    if (pricing?.currency) {
      currency = resolveBillingCurrency({ currency: pricing.currency }, currency);
    } else if (test.currency) {
      currency = resolveBillingCurrency({ currency: test.currency }, currency);
    }
    lineItems.push({
      id: test.human_friendly_id || test.id,
      label: test.name,
      quantity: 1,
      unit_price: unitPrice,
      line_total: unitPrice,
    });
  }

  for (const request of requestedPanels) {
    const requestedId = String(request?.lab_panel_id || '').trim();
    if (!requestedId || requestedId.startsWith('STD_LAB_PANEL:')) {
      continue;
    }
    const panel = await resolveCatalogRecord({
      identifier: requestedId,
      model: 'lab_panel',
      tenantId,
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        unit_price: true,
        currency: true,
      },
    });
    if (!panel) {
      continue;
    }
    const pricing = await resolveLabPanelPricing({
      labPanelId: panel.id,
      tenantId,
      facilityId,
    });
    const unitPrice = pricing?.unitPrice ?? (panel.unit_price != null ? toMoneyString(panel.unit_price) : null);
    if (pricing?.currency) {
      currency = resolveBillingCurrency({ currency: pricing.currency }, currency);
    } else if (panel.currency) {
      currency = resolveBillingCurrency({ currency: panel.currency }, currency);
    }
    lineItems.push({
      id: panel.human_friendly_id || panel.id,
      label: panel.name,
      quantity: 1,
      unit_price: unitPrice,
      line_total: unitPrice,
    });
  }

  return buildPendingClinicalRequestBilling({ lineItems, currency });
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
  buildPendingClinicalRequestBilling,
  normalizeBillingOfficeClinicalBilling,
  buildLabOrderBillingFromRequest,
  resolveClinicalInvoiceContexts,
  resolveInvoiceIdsForEncounterToken,
  resolveInvoiceIdsForSourceModule,
  syncClinicalOrderBillingSnapshotsFromInvoiceTx,
  resolveInvoicePaymentStatus,
  extractStoredClinicalBilling,
  mapClinicalOrderBillingFields,
  mapCatalogUnitPriceFields,
  resolveScopedBillingAmount,
};
