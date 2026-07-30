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
const {
  normalizeBillingEntity,
  normalizePaymentMode,
  resolveUnitPrices,
  toMoneyString: priceToMoneyString,
  toDecimalNumber: priceToDecimalNumber,
} = require('@lib/billing/price-resolver');
const {
  applyCoverageSplitToLineItems,
  summarizeCoverageShares,
} = require('@lib/billing/coverage-split');
const {
  findActivePreAuthorizationLimit,
  remainingAmount: preAuthRemainingAmount,
  consumePreAuthorizationForBillingTx,
  sumInsurerShareFromItems,
} = require('@lib/billing/pre-authorization-billing');

const SKIPPED_PAYMENT_STATUSES = new Set(['NOT_BILLED', 'NOT_REQUIRED', 'NO_CHARGE']);

const BILLABLE_SOURCE_MODULES = Object.freeze({
  CONSULTATION: 'CONSULTATION',
  LABORATORY: 'LABORATORY',
  RADIOLOGY: 'RADIOLOGY',
  PHARMACY: 'PHARMACY',
  PROCEDURE: 'PROCEDURE',
  THEATRE: 'THEATRE',
  ADMISSION: 'ADMISSION',
  NURSING: 'NURSING',
  WARD_ROUND: 'WARD_ROUND',
  ICU_STAY: 'ICU_STAY',
  CONSUMABLE: 'CONSUMABLE',
  THERAPY: 'THERAPY',
  MORTUARY: 'MORTUARY',
  SERVICE: 'SERVICE',
});

const normalizeBillableSourceModule = (value) => {
  const token = String(value || '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (!token) {
    return null;
  }
  if (BILLABLE_SOURCE_MODULES[token]) {
    return BILLABLE_SOURCE_MODULES[token];
  }
  if (token.includes('LAB')) return BILLABLE_SOURCE_MODULES.LABORATORY;
  if (token.includes('RADIO')) return BILLABLE_SOURCE_MODULES.RADIOLOGY;
  if (token.includes('PHARM')) return BILLABLE_SOURCE_MODULES.PHARMACY;
  if (token.includes('CONSULT')) return BILLABLE_SOURCE_MODULES.CONSULTATION;
  if (token.includes('ADMISS')) return BILLABLE_SOURCE_MODULES.ADMISSION;
  if (token.includes('NURS')) return BILLABLE_SOURCE_MODULES.NURSING;
  if (token.includes('THEAT')) return BILLABLE_SOURCE_MODULES.THEATRE;
  if (token.includes('PROC')) return BILLABLE_SOURCE_MODULES.PROCEDURE;
  if (token.includes('CONSUM')) return BILLABLE_SOURCE_MODULES.CONSUMABLE;
  if (token.includes('THERAP')) return BILLABLE_SOURCE_MODULES.THERAPY;
  if (token.includes('WARD')) return BILLABLE_SOURCE_MODULES.WARD_ROUND;
  if (token.includes('ICU')) return BILLABLE_SOURCE_MODULES.ICU_STAY;
  if (token.includes('MORTUARY')) return BILLABLE_SOURCE_MODULES.MORTUARY;
  return BILLABLE_SOURCE_MODULES.SERVICE;
};

const normalizeChargeKey = (value) => {
  const token = String(value || 'PRIMARY')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '_');
  return token.slice(0, 120) || 'PRIMARY';
};

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

/**
 * True when billing is a non-skipped charge candidate (amount may still be 0
 * until price-engine enrichment fills catalog unit prices).
 */
const isClinicalRequestBillingCandidate = (billing) => {
  if (!billing || typeof billing !== 'object' || Array.isArray(billing)) {
    return false;
  }
  const status = normalizePaymentStatus(billing.payment_status);
  if (!status || SKIPPED_PAYMENT_STATUSES.has(status)) {
    return false;
  }
  return true;
};

const shouldApplyClinicalRequestBilling = (billing) => {
  if (!isClinicalRequestBillingCandidate(billing)) {
    return false;
  }
  const scopedAmount = resolveScopedBillingAmount(billing);
  return toDecimalNumber(scopedAmount) > 0;
};

const resolveScopedBillingAmount = (billing = {}) => {
  if (billing.line_amount !== undefined && billing.line_amount !== null && billing.line_amount !== '') {
    const lineAmount = toDecimalNumber(billing.line_amount);
    if (lineAmount > 0) {
      return toMoneyString(billing.line_amount);
    }
  }
  const lineItems = Array.isArray(billing.line_items) ? billing.line_items : [];
  const summed = lineItems.reduce(
    (total, item) => total + toDecimalNumber(item?.line_total ?? item?.unit_price),
    0
  );
  if (summed > 0) {
    return toMoneyString(summed);
  }
  // Fall back to total only when lines have no priced amounts (ignore 0 totals
  // so pending payloads with priced lines are not blocked).
  if (billing.total_amount !== undefined && billing.total_amount !== null && billing.total_amount !== '') {
    return toMoneyString(billing.total_amount);
  }
  return toMoneyString(0);
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
  const defaultEntity = normalizeBillingEntity(
    billing.billing_entity || context.billingEntity || 'FACILITY'
  );
  const defaultPaymentMode = normalizePaymentMode(
    billing.payment_mode || context.paymentMode || 'SELF_PAY'
  );

  const mapEngineFields = (entry = {}, quantity, unitPrice, totalPrice) => ({
    description: String(entry.label || description).trim() || description,
    quantity,
    unit_price: unitPrice,
    total_price: totalPrice,
    catalog_type: entry.catalog_type || entry.catalogType || context.catalogType || null,
    catalog_item_id: entry.id || entry.catalog_item_id || catalogItemId || null,
    price_book_entry_id: entry.price_book_entry_id || entry.priceBookEntryId || null,
    payment_mode: normalizePaymentMode(entry.payment_mode || defaultPaymentMode),
    coverage_plan_id:
      entry.coverage_plan_id ||
      entry.coveragePlanId ||
      billing.coverage_plan_id ||
      context.coveragePlanId ||
      null,
    insurance_company_id:
      entry.insurance_company_id ||
      entry.insuranceCompanyId ||
      billing.insurance_company_id ||
      context.insuranceCompanyId ||
      null,
    scheme_offer_id: entry.scheme_offer_id || entry.schemeOfferId || null,
    billing_entity: normalizeBillingEntity(
      entry.billing_entity || entry.price_source || defaultEntity
    ),
    price_source:
      entry.price_source ||
      normalizeBillingEntity(entry.billing_entity || defaultEntity),
    patient_share: entry.patient_share != null ? toMoneyString(entry.patient_share) : null,
    insurer_share: entry.insurer_share != null ? toMoneyString(entry.insurer_share) : null,
    copay_amount: entry.copay_amount != null ? toMoneyString(entry.copay_amount) : null,
  });

  if (catalogItemId && lineItems.length) {
    const match =
      lineItems.find((entry) => String(entry?.id || '') === catalogItemId) || null;
    if (match) {
      const quantity = Math.max(1, Number(match.quantity) || 1);
      const lineTotal = toMoneyString(
        billing.line_amount ?? match.line_total ?? match.unit_price ?? scopedAmount
      );
      const unitPrice = toMoneyString(match.unit_price ?? lineTotal);
      return [mapEngineFields(match, quantity, unitPrice, lineTotal)];
    }
  }

  if (lineItems.length) {
    return lineItems.map((entry) => {
      const quantity = Math.max(1, Number(entry.quantity) || 1);
      const unitPrice = toMoneyString(entry.unit_price ?? entry.line_total ?? '0');
      const totalPrice = toMoneyString(entry.line_total ?? entry.unit_price ?? unitPrice);
      return mapEngineFields(entry, quantity, unitPrice, totalPrice);
    });
  }

  return [
    mapEngineFields(
      {
        label: description,
        payment_mode: defaultPaymentMode,
        billing_entity: defaultEntity,
      },
      1,
      scopedAmount,
      scopedAmount
    ),
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
  billing_entity: normalizeBillingEntity(
    billing?.billing_entity || invoice?.billing_entity || 'FACILITY'
  ),
  payment_mode: normalizePaymentMode(billing?.payment_mode || 'SELF_PAY'),
  coverage_plan_id: billing?.coverage_plan_id || null,
  patient_share: billing?.patient_share ?? null,
  insurer_share: billing?.insurer_share ?? null,
  copay_amount: billing?.copay_amount ?? null,
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
  const priceSource = String(entry.price_source || '')
    .trim()
    .toUpperCase();
  const billingEntity = normalizeBillingEntity(
    entry.billing_entity || priceSource || 'FACILITY'
  );
  const paymentMode = normalizePaymentMode(entry.payment_mode || 'SELF_PAY');
  return {
    id: String(entry.id || entry.lab_test_id || entry.lab_panel_id || '').trim(),
    label: String(entry.label || entry.name || 'Clinical service').trim() || 'Clinical service',
    quantity,
    ...(unitPrice ? { unit_price: unitPrice } : {}),
    ...(toDecimalNumber(lineTotal) > 0 ? { line_total: lineTotal } : {}),
    ...(priceSource === 'PHARMACY' || priceSource === 'FACILITY'
      ? { price_source: priceSource }
      : { price_source: billingEntity }),
    billing_entity: billingEntity,
    payment_mode: paymentMode,
    ...(entry.catalog_type || entry.catalogType
      ? { catalog_type: entry.catalog_type || entry.catalogType }
      : {}),
    ...(entry.price_book_entry_id || entry.priceBookEntryId
      ? { price_book_entry_id: entry.price_book_entry_id || entry.priceBookEntryId }
      : {}),
    ...(entry.coverage_plan_id || entry.coveragePlanId
      ? { coverage_plan_id: entry.coverage_plan_id || entry.coveragePlanId }
      : {}),
    ...(entry.insurance_company_id || entry.insuranceCompanyId
      ? {
          insurance_company_id:
            entry.insurance_company_id || entry.insuranceCompanyId,
        }
      : {}),
    ...(entry.scheme_offer_id || entry.schemeOfferId
      ? { scheme_offer_id: entry.scheme_offer_id || entry.schemeOfferId }
      : {}),
    ...(entry.patient_share != null ? { patient_share: toMoneyString(entry.patient_share) } : {}),
    ...(entry.insurer_share != null ? { insurer_share: toMoneyString(entry.insurer_share) } : {}),
    ...(entry.copay_amount != null ? { copay_amount: toMoneyString(entry.copay_amount) } : {}),
  };
};

/**
 * Resolve missing/override line prices via the shared price engine.
 * Keeps client-provided engine refs when present; fills gaps from scheme offers / price book.
 */
const enrichBillingWithPriceEngine = async (billing = {}, options = {}) => {
  const lineItems = Array.isArray(billing.line_items) ? billing.line_items : [];
  const tenantId = options.tenantId;
  if (!tenantId || !lineItems.length) {
    return billing;
  }

  const paymentMode = normalizePaymentMode(
    billing.payment_mode || options.paymentMode || 'SELF_PAY'
  );
  const billingEntity = normalizeBillingEntity(
    billing.billing_entity || options.billingEntity || 'FACILITY'
  );
  const coveragePlanId =
    billing.coverage_plan_id || options.coveragePlanId || null;
  const insuranceCompanyId =
    billing.insurance_company_id || options.insuranceCompanyId || null;

  const resolvable = lineItems.map((item) => ({
    id: item.id || item.catalog_item_id || null,
    catalog_type: item.catalog_type || item.catalogType || options.catalogType,
    catalog_item_id:
      item.catalog_item_id ||
      item.catalogItemId ||
      item.id ||
      options.catalogItemId,
    quantity: Math.max(1, Number(item.quantity) || 1),
    price_source: item.price_source || item.billing_entity || billingEntity,
  }));

  const hasCatalogRefs = resolvable.some(
    (item) => item.catalog_type && item.catalog_item_id
  );
  if (!hasCatalogRefs) {
    return billing;
  }

  let resolved = [];
  try {
    resolved = await resolveUnitPrices({
      tenantId,
      facilityId: options.facilityId || null,
      paymentMode,
      coveragePlanId,
      insuranceCompanyId,
      insurerKey: billing.insurer_key || options.insurerKey || null,
      billingEntity,
      currency: billing.currency || options.currency || null,
      items: resolvable,
    });
  } catch (_error) {
    return billing;
  }

  let enrichedLines = lineItems.map((item, index) => {
    const price = resolved[index] || {};
    const quantity = Math.max(1, Number(item.quantity) || 1);
    const unitPrice =
      price.unitPrice != null
        ? price.unitPrice
        : item.unit_price ?? item.unitPrice ?? null;
    const lineTotal =
      unitPrice != null
        ? priceToMoneyString(priceToDecimalNumber(unitPrice) * quantity)
        : item.line_total ?? null;

    return {
      ...item,
      quantity,
      ...(unitPrice != null ? { unit_price: unitPrice } : {}),
      ...(lineTotal != null ? { line_total: lineTotal } : {}),
      payment_mode: price.paymentMode || paymentMode,
      billing_entity: price.billingEntity || billingEntity,
      price_source: price.priceSource || item.price_source || billingEntity,
      coverage_plan_id: price.coveragePlanId || coveragePlanId || item.coverage_plan_id,
      insurance_company_id:
        price.insuranceCompanyId || insuranceCompanyId || item.insurance_company_id,
      price_book_entry_id: price.priceBookEntryId || item.price_book_entry_id || null,
      scheme_offer_id: price.schemeOfferId || item.scheme_offer_id || null,
      coverage_percentage:
        price.coveragePercentage ?? item.coverage_percentage ?? null,
      copay_type: price.copayType || item.copay_type || null,
      copay_value: price.copayValue ?? item.copay_value ?? null,
      is_excluded: Boolean(price.isExcluded ?? item.is_excluded),
      requires_pre_auth: Boolean(price.requiresPreAuth ?? item.requires_pre_auth),
      catalog_type: resolvable[index]?.catalog_type || item.catalog_type,
      catalog_item_id: resolvable[index]?.catalog_item_id || item.catalog_item_id,
    };
  });

  if (paymentMode === 'INSURANCE') {
    let preAuthRemaining = options.preAuthRemainingAmount;
    if (
      (preAuthRemaining === undefined || preAuthRemaining === null) &&
      (options.patientId || options.encounterId || options.admissionId)
    ) {
      try {
        const prisma = require('@prisma/client');
        const activePreAuth = await findActivePreAuthorizationLimit(prisma, {
          patientId: options.patientId || null,
          encounterId: options.encounterId || null,
          admissionId: options.admissionId || null,
          coveragePlanId,
        });
        preAuthRemaining = preAuthRemainingAmount(activePreAuth);
      } catch (_error) {
        preAuthRemaining = null;
      }
    }

    enrichedLines = applyCoverageSplitToLineItems(enrichedLines, {
      insured: true,
      paymentMode,
      coveragePlanId,
      insuranceCompanyId,
      coveragePercentage:
        billing.coverage_percentage ?? options.coveragePercentage ?? null,
      copayType: billing.copay_type || options.copayType || null,
      copayValue: billing.copay_value ?? options.copayValue ?? null,
      preAuthRemainingAmount: preAuthRemaining,
    });
  }

  const summary = summarizeCoverageShares(enrichedLines);
  // Prefer engine/line totals when the client sent a zero/missing total so
  // pending bill-later payloads without catalog unit prices still post.
  const priorTotal = toDecimalNumber(billing.total_amount);
  return {
    ...billing,
    payment_mode: paymentMode,
    billing_entity: billingEntity,
    coverage_plan_id: coveragePlanId,
    insurance_company_id: insuranceCompanyId,
    line_items: enrichedLines,
    patient_share: summary.patientShare,
    insurer_share: summary.insurerShare,
    copay_amount: summary.copayAmount,
    total_amount:
      priorTotal > 0 ? billing.total_amount : (summary.total ?? billing.total_amount),
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
    orderBy: { ordered_at: 'desc' },
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
    orderBy: { ordered_at: 'desc' },
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
    orderBy: { ordered_at: 'desc' },
    orderSelect: {
      request_details: true,
      encounter_id: true,
      encounter: { select: { id: true, human_friendly_id: true } },
    },
  },
  {
    model: 'ward_round',
    label: 'Ward Round',
    invoiceFilterField: 'billing_snapshot',
    invoiceFilterPath: '$.invoice_id',
    orderBy: { round_at: 'desc' },
    viaAdmission: true,
    orderSelect: {
      billing_snapshot: true,
      admission: {
        select: {
          encounter_id: true,
          encounter: { select: { id: true, human_friendly_id: true } },
        },
      },
    },
  },
  {
    model: 'procedure',
    label: 'Procedure',
    invoiceFilterField: 'billing_snapshot',
    invoiceFilterPath: '$.invoice_id',
    orderBy: { created_at: 'desc' },
    orderSelect: {
      billing_snapshot: true,
      encounter_id: true,
      encounter: { select: { id: true, human_friendly_id: true } },
    },
  },
  {
    model: 'theatre_case',
    label: 'Theatre',
    invoiceFilterField: 'billing_snapshot',
    invoiceFilterPath: '$.invoice_id',
    orderBy: { created_at: 'desc' },
    orderSelect: {
      billing_snapshot: true,
      encounter_id: true,
      encounter: { select: { id: true, human_friendly_id: true } },
    },
  },
  {
    model: 'admission',
    label: 'Admission',
    invoiceFilterField: 'billing_snapshot',
    invoiceFilterPath: '$.invoice_id',
    orderBy: { admitted_at: 'desc' },
    orderSelect: {
      billing_snapshot: true,
      encounter_id: true,
      encounter: { select: { id: true, human_friendly_id: true } },
    },
  },
  {
    model: 'nursing_note',
    label: 'Nursing',
    invoiceFilterField: 'billing_snapshot',
    invoiceFilterPath: '$.invoice_id',
    orderBy: { created_at: 'desc' },
    viaAdmission: true,
    orderSelect: {
      billing_snapshot: true,
      admission: {
        select: {
          encounter_id: true,
          encounter: { select: { id: true, human_friendly_id: true } },
        },
      },
    },
  },
]);

const buildClinicalInvoiceIdFilter = (source, invoiceId) => ({
  [source.invoiceFilterField]: {
    path: source.invoiceFilterPath,
    equals: invoiceId,
  },
});

const buildClinicalEncounterIdFilter = (source, encounterIds) => {
  if (source.viaAdmission) {
    return {
      admission: {
        is: {
          deleted_at: null,
          encounter_id: { in: encounterIds },
        },
      },
    };
  }
  return { encounter_id: { in: encounterIds } };
};

const resolveSourceOrderBy = (source) => source.orderBy || { created_at: 'desc' };

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
  if (normalized.includes('consult')) {
    return 'Consultation';
  }
  if (normalized.includes('admiss')) {
    return 'Admission';
  }
  if (normalized.includes('nurs')) {
    return 'Nursing';
  }
  if (normalized.includes('theat')) {
    return 'Theatre';
  }
  if (normalized.includes('proc')) {
    return 'Procedure';
  }
  if (normalized.includes('consum')) {
    return 'Consumable';
  }
  if (normalized.includes('ward')) {
    return 'Ward Round';
  }
  return token.charAt(0).toUpperCase() + token.slice(1);
};

const resolveOrderEncounterContext = (order = {}) => {
  const nested = order.admission?.encounter || order.encounter || null;
  return {
    encounter_id:
      order.encounter_id || order.admission?.encounter_id || nested?.id || null,
    encounter_display_id: nested?.human_friendly_id || null,
  };
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
    let orders = [];
    try {
      orders = await prisma[source.model].findMany({
        where: {
          deleted_at: null,
          OR: uniqueIds.map((invoiceId) => buildClinicalInvoiceIdFilter(source, invoiceId)),
        },
        select: source.orderSelect,
      });
    } catch (_error) {
      continue;
    }

    for (const order of orders) {
      const snapshot = extractStoredClinicalBilling(order);
      const invoiceId = extractInvoiceIdFromSnapshot(snapshot);
      if (!invoiceId) {
        continue;
      }
      const encounterContext = resolveOrderEncounterContext(order);
      const existing = contexts.get(invoiceId) || {
        encounter_id: null,
        encounter_display_id: null,
        source_modules: new Set(),
      };
      existing.source_modules.add(source.label);
      if (!existing.encounter_id) {
        existing.encounter_id =
          encounterContext.encounter_id || snapshot?.encounter_id || null;
        existing.encounter_display_id =
          encounterContext.encounter_display_id ||
          snapshot?.encounter_display_id ||
          encounterContext.encounter_id ||
          null;
      }
      contexts.set(invoiceId, existing);
    }
  }

  if (prisma?.billable_charge_event?.findMany) {
    try {
      const events = await prisma.billable_charge_event.findMany({
        where: {
          deleted_at: null,
          status: 'POSTED',
          invoice_id: { in: uniqueIds },
        },
        select: {
          invoice_id: true,
          source_module: true,
          encounter_id: true,
          encounter: { select: { id: true, human_friendly_id: true } },
        },
      });
      for (const event of events) {
        const invoiceId = event.invoice_id ? String(event.invoice_id) : null;
        if (!invoiceId) {
          continue;
        }
        const existing = contexts.get(invoiceId) || {
          encounter_id: null,
          encounter_display_id: null,
          source_modules: new Set(),
        };
        const label = normalizeSourceModuleLabel(event.source_module);
        if (label) {
          existing.source_modules.add(label);
        }
        if (!existing.encounter_id) {
          existing.encounter_id = event.encounter_id || event.encounter?.id || null;
          existing.encounter_display_id = event.encounter?.human_friendly_id || null;
        }
        contexts.set(invoiceId, existing);
      }
    } catch (_error) {
      // Table may not exist until migration is applied.
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
      let orders = [];
      try {
        orders = await prisma[source.model].findMany({
          where: {
            deleted_at: null,
            ...buildClinicalEncounterIdFilter(source, encounterIds),
          },
          select: source.orderSelect,
          take: 500,
        });
      } catch (_error) {
        continue;
      }
      for (const order of orders) {
        const snapshot = extractStoredClinicalBilling(order);
        const invoiceId = extractInvoiceIdFromSnapshot(snapshot);
        if (invoiceId) {
          invoiceIds.add(invoiceId);
        }
      }
    }

    if (prisma?.billable_charge_event?.findMany) {
      try {
        const events = await prisma.billable_charge_event.findMany({
          where: {
            deleted_at: null,
            status: 'POSTED',
            encounter_id: { in: encounterIds },
            invoice_id: { not: null },
          },
          select: { invoice_id: true },
          take: 500,
        });
        for (const event of events) {
          if (event.invoice_id) {
            invoiceIds.add(String(event.invoice_id));
          }
        }
      } catch (_error) {
        // Table may not exist until migration is applied.
      }
    }

    return [...invoiceIds];
  }

  for (const source of CLINICAL_INVOICE_SOURCES) {
    if (!prisma?.[source.model]?.findMany) {
      continue;
    }
    let orders = [];
    try {
      orders = await prisma[source.model].findMany({
        where: { deleted_at: null },
        select: source.orderSelect,
        take: 500,
        orderBy: resolveSourceOrderBy(source),
      });
    } catch (_error) {
      continue;
    }
    for (const order of orders) {
      const snapshot = extractStoredClinicalBilling(order);
      const invoiceId = extractInvoiceIdFromSnapshot(snapshot);
      if (!invoiceId) {
        continue;
      }
      const encounterContext = resolveOrderEncounterContext(order);
      const encounterDisplayId = String(
        encounterContext.encounter_display_id ||
          snapshot?.encounter_display_id ||
          ''
      ).toUpperCase();
      if (encounterDisplayId.includes(upper)) {
        invoiceIds.add(invoiceId);
      }
    }
  }

  if (prisma?.billable_charge_event?.findMany) {
    try {
      const events = await prisma.billable_charge_event.findMany({
        where: {
          deleted_at: null,
          status: 'POSTED',
          invoice_id: { not: null },
        },
        select: {
          invoice_id: true,
          encounter: { select: { human_friendly_id: true } },
        },
        take: 500,
        orderBy: { posted_at: 'desc' },
      });
      for (const event of events) {
        const encounterDisplayId = String(
          event.encounter?.human_friendly_id || ''
        ).toUpperCase();
        if (encounterDisplayId.includes(upper) && event.invoice_id) {
          invoiceIds.add(String(event.invoice_id));
        }
      }
    } catch (_error) {
      // Table may not exist until migration is applied.
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
    await reverseBillableChargeEventsForInvoice(tx, invoiceId);
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
  await reverseBillableChargeEventsForInvoice(tx, invoiceId);
  return true;
};

/**
 * Mark posted billable_charge_event rows as REVERSED and free the idempotency key.
 */
const reverseBillableChargeEventsForInvoice = async (tx, invoiceId) => {
  if (!invoiceId || !tx?.billable_charge_event?.findMany) {
    return;
  }
  const events = await tx.billable_charge_event.findMany({
    where: {
      invoice_id: invoiceId,
      status: 'POSTED',
      deleted_at: null,
    },
  });
  const now = new Date();
  for (const event of events) {
    await tx.billable_charge_event.update({
      where: { id: event.id },
      data: {
        status: 'REVERSED',
        reversed_at: now,
        deleted_at: now,
        charge_key: `REV:${event.charge_key}:${event.id}`.slice(0, 120),
      },
    });
  }
};

/**
 * Look up an existing posted charge for the same source identity (retry / reprocess).
 */
const findPostedBillableChargeEvent = async (
  tx,
  { tenantId, sourceModule, sourceId, chargeKey }
) => {
  if (!tx?.billable_charge_event?.findFirst || !tenantId || !sourceModule || !sourceId) {
    return null;
  }
  return tx.billable_charge_event.findFirst({
    where: {
      tenant_id: tenantId,
      source_module: sourceModule,
      source_id: sourceId,
      charge_key: chargeKey,
      status: 'POSTED',
      deleted_at: null,
    },
  });
};

/**
 * Upsert the idempotent billable charge event after a successful invoice post.
 */
const upsertBillableChargeEvent = async (
  tx,
  {
    tenantId,
    facilityId = null,
    patientId = null,
    encounterId = null,
    sourceModule,
    sourceId,
    chargeKey = 'PRIMARY',
    invoiceId = null,
    catalogType = null,
    catalogItemId = null,
    actorUserId = null,
    unitPriceSnapshot = null,
    totalAmountSnapshot = null,
    currency = null,
    existingEventId = null,
  } = {}
) => {
  if (!tx?.billable_charge_event || !tenantId || !sourceModule || !sourceId) {
    return null;
  }

  const data = {
    tenant_id: tenantId,
    facility_id: facilityId || null,
    patient_id: patientId || null,
    encounter_id: encounterId || null,
    source_module: sourceModule,
    source_id: String(sourceId),
    charge_key: normalizeChargeKey(chargeKey),
    invoice_id: invoiceId || null,
    catalog_type: catalogType || null,
    catalog_item_id: catalogItemId || null,
    actor_user_id: actorUserId || null,
    unit_price_snapshot: unitPriceSnapshot != null ? toMoneyString(unitPriceSnapshot) : null,
    total_amount_snapshot:
      totalAmountSnapshot != null ? toMoneyString(totalAmountSnapshot) : null,
    currency: currency || null,
    status: 'POSTED',
    posted_at: new Date(),
    reversed_at: null,
    deleted_at: null,
  };

  if (existingEventId) {
    return tx.billable_charge_event.update({
      where: { id: existingEventId },
      data,
    });
  }

  try {
    return await tx.billable_charge_event.create({ data });
  } catch (error) {
    // Unique collision under concurrent retry: load and update the winner.
    if (error?.code === 'P2002') {
      const existing = await findPostedBillableChargeEvent(tx, {
        tenantId,
        sourceModule,
        sourceId,
        chargeKey: data.charge_key,
      });
      if (existing) {
        return tx.billable_charge_event.update({
          where: { id: existing.id },
          data,
        });
      }
    }
    throw error;
  }
};

/**
 * Rebuild a billing snapshot from an already-posted invoice (idempotent retry path).
 */
const buildSnapshotFromExistingInvoice = async (
  tx,
  { invoiceId, billing, encounterId, encounterDisplayId }
) => {
  const invoice = await tx.invoice.findFirst({
    where: { id: invoiceId, deleted_at: null },
    include: {
      payments: { where: { deleted_at: null }, orderBy: { created_at: 'desc' } },
    },
  });
  if (!invoice) {
    return null;
  }
  const payment =
    (invoice.payments || []).find((entry) =>
      COMPLETED_PAYMENT_STATUSES.has(String(entry.status || '').toUpperCase())
    ) ||
    invoice.payments?.[0] ||
    null;
  const paymentStatus = resolvePaymentStatusAfterApply(billing, invoice, payment);
  return buildBillingSnapshot(billing || {}, {
    invoice,
    payment,
    paymentStatus,
    encounterId,
    encounterDisplayId,
  });
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
  { invoiceId, billing, invoiceTotal, tenantId, patientId, facilityId, issuedAt, billingEntity }
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
      billing_entity: normalizeBillingEntity(
        billingEntity || billing.billing_entity || 'FACILITY'
      ),
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
 * Pass `sourceModule` + `sourceId` (+ optional `chargeKey`) so retries and realtime
 * reprocessing reuse the same billable_charge_event / invoice instead of posting again.
 *
 * @param {import('@prisma/client').Prisma.TransactionClient} tx
 * @param {Object} options
 * @returns {Promise<Object|null>} Persisted billing snapshot (null when nothing is billed)
 */
const applyClinicalRequestBilling = async (tx, options = {}) => {
  let billing = options.billing;
  let existingInvoiceId = extractInvoiceIdFromSnapshot(options.existingSnapshot);
  const sourceModule = normalizeBillableSourceModule(options.sourceModule);
  const sourceId = options.sourceId ? String(options.sourceId).trim() : null;
  const chargeKey = normalizeChargeKey(options.chargeKey || 'PRIMARY');
  const allowRepeat = Boolean(options.allowRepeat);

  const postedEvent = await findPostedBillableChargeEvent(tx, {
    tenantId: options.tenantId,
    sourceModule,
    sourceId,
    chargeKey,
  });

  // Idempotent retry: same source already posted and caller is not mutating lines.
  // Callers that pass existingSnapshot (order edits) continue into the mutable path.
  if (
    postedEvent?.invoice_id &&
    !options.existingSnapshot &&
    options.mutableUpdate !== true
  ) {
    const reused = await buildSnapshotFromExistingInvoice(tx, {
      invoiceId: postedEvent.invoice_id,
      billing,
      encounterId: options.encounterId || postedEvent.encounter_id,
      encounterDisplayId: options.encounterDisplayId,
    });
    if (reused) {
      return reused;
    }
  }

  // Consultation (and other non-repeatable charges): refuse a second distinct post.
  if (
    postedEvent?.invoice_id &&
    existingInvoiceId &&
    existingInvoiceId !== postedEvent.invoice_id &&
    !allowRepeat &&
    sourceModule === BILLABLE_SOURCE_MODULES.CONSULTATION
  ) {
    const reused = await buildSnapshotFromExistingInvoice(tx, {
      invoiceId: postedEvent.invoice_id,
      billing,
      encounterId: options.encounterId || postedEvent.encounter_id,
      encounterDisplayId: options.encounterDisplayId,
    });
    if (reused) {
      return reused;
    }
  }

  if (!existingInvoiceId && postedEvent?.invoice_id) {
    existingInvoiceId = postedEvent.invoice_id;
  }

  const tenantId = options.tenantId;
  const patientId = options.patientId;

  // Skip only explicit not-billable statuses before enrichment. Zero-amount
  // PENDING payloads (common when Review billing is skipped) must still reach
  // the price engine so radiology/pharmacy/procedure charges are not leaked.
  if (!isClinicalRequestBillingCandidate(billing)) {
    if (existingInvoiceId) {
      await cancelInvoiceIfReversible(tx, existingInvoiceId);
    }
    return null;
  }

  if (!tenantId || !patientId) {
    return null;
  }

  billing = await enrichBillingWithPriceEngine(billing, {
    tenantId,
    facilityId: options.facilityId,
    paymentMode: options.paymentMode,
    billingEntity: options.billingEntity,
    coveragePlanId: options.coveragePlanId,
    insuranceCompanyId: options.insuranceCompanyId,
    insurerKey: options.insurerKey,
    coveragePercentage: options.coveragePercentage,
    copayType: options.copayType,
    copayValue: options.copayValue,
    catalogType: options.catalogType,
    catalogItemId: options.catalogItemId,
    currency: options.currency,
    patientId,
    encounterId: options.encounterId || null,
    admissionId: options.admissionId || null,
  });

  if (!shouldApplyClinicalRequestBilling(billing)) {
    if (existingInvoiceId) {
      await cancelInvoiceIfReversible(tx, existingInvoiceId);
    }
    return null;
  }

  const billingEntity = normalizeBillingEntity(
    options.billingEntity || billing.billing_entity || 'FACILITY'
  );
  const paymentMode = normalizePaymentMode(
    options.paymentMode || billing.payment_mode || 'SELF_PAY'
  );

  let previousInsurerShare = 0;
  if (existingInvoiceId && paymentMode === 'INSURANCE') {
    const priorInvoice = await tx.invoice.findFirst({
      where: { id: existingInvoiceId, deleted_at: null },
      include: { items: { where: { deleted_at: null } } },
    });
    previousInsurerShare = sumInsurerShareFromItems(priorInvoice?.items);
  }

  let enrichedBilling = {
    ...billing,
    billing_entity: billingEntity,
    payment_mode: paymentMode,
  };

  // Re-apply coverage split with live pre-auth remaining so invoice lines are capped.
  if (
    paymentMode === 'INSURANCE' &&
    Array.isArray(billing.line_items) &&
    billing.line_items.length
  ) {
    let preAuthRemaining = options.preAuthRemainingAmount;
    if (preAuthRemaining === undefined || preAuthRemaining === null) {
      const activePreAuth = await findActivePreAuthorizationLimit(tx, {
        patientId,
        encounterId: options.encounterId || null,
        admissionId: options.admissionId || null,
        coveragePlanId: billing.coverage_plan_id || options.coveragePlanId,
      });
      preAuthRemaining = preAuthRemainingAmount(activePreAuth);
    }

    const splitLines = applyCoverageSplitToLineItems(billing.line_items, {
      insured: true,
      paymentMode,
      coveragePlanId: billing.coverage_plan_id || options.coveragePlanId,
      insuranceCompanyId:
        billing.insurance_company_id || options.insuranceCompanyId,
      coveragePercentage:
        billing.coverage_percentage ?? options.coveragePercentage,
      copayType: billing.copay_type || options.copayType,
      copayValue: billing.copay_value ?? options.copayValue,
      preAuthRemainingAmount: preAuthRemaining,
    });
    const summary = summarizeCoverageShares(splitLines);
    enrichedBilling = {
      ...enrichedBilling,
      line_items: splitLines,
      patient_share: summary.patientShare,
      insurer_share: summary.insurerShare,
      copay_amount: summary.copayAmount,
    };
  }

  const invoiceItems = buildInvoiceLineItems(enrichedBilling, {
    description: options.description,
    catalogItemId: options.catalogItemId,
    catalogType: options.catalogType || enrichedBilling.catalog_type,
    billingEntity,
    paymentMode,
    coveragePlanId: options.coveragePlanId || enrichedBilling.coverage_plan_id,
    insuranceCompanyId:
      options.insuranceCompanyId || enrichedBilling.insurance_company_id,
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

  const currency = resolveBillingCurrency(enrichedBilling, options.currency || 'USD');
  const issuedAt = options.issuedAt instanceof Date ? options.issuedAt : new Date();
  const itemCreateData = invoiceItems.map((item) => ({
    description: item.description,
    quantity: item.quantity,
    unit_price: item.unit_price,
    total_price: item.total_price,
    catalog_type: item.catalog_type || null,
    catalog_item_id: item.catalog_item_id || null,
    price_book_entry_id: item.price_book_entry_id || null,
    payment_mode: item.payment_mode || paymentMode,
    coverage_plan_id: item.coverage_plan_id || null,
    insurance_company_id: item.insurance_company_id || null,
    scheme_offer_id: item.scheme_offer_id || null,
    billing_entity: item.billing_entity || billingEntity,
    price_source: item.price_source || billingEntity,
    patient_share: item.patient_share,
    insurer_share: item.insurer_share,
    copay_amount: item.copay_amount,
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
          billing_entity: billingEntity,
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
        billing_entity: billingEntity,
        total_amount: toMoneyString(invoiceTotal),
        currency,
        issued_at: issuedAt,
        items: { create: itemCreateData },
      },
    });
  }

  const payment = await recordRequestPayment(tx, {
    invoiceId: invoice.id,
    billing: enrichedBilling,
    invoiceTotal,
    tenantId,
    patientId,
    facilityId: options.facilityId,
    issuedAt,
    billingEntity,
  });

  // Recalculate invoice status from authoritative payment/adjustment data.
  const recalculated = await recalculateInvoiceStateTx(tx, invoice.id);
  invoice = recalculated?.invoice || invoice;

  const paymentStatus = resolvePaymentStatusAfterApply(enrichedBilling, invoice, payment);
  const snapshot = buildBillingSnapshot(enrichedBilling, {
    invoice,
    payment,
    paymentStatus,
    encounterId: options.encounterId,
    encounterDisplayId: options.encounterDisplayId,
  });

  const primaryLine = invoiceItems[0] || {};
  await upsertBillableChargeEvent(tx, {
    tenantId,
    facilityId: options.facilityId || null,
    patientId,
    encounterId: options.encounterId || null,
    sourceModule,
    sourceId,
    chargeKey,
    invoiceId: invoice.id,
    catalogType: primaryLine.catalog_type || options.catalogType || null,
    catalogItemId: primaryLine.catalog_item_id || options.catalogItemId || null,
    actorUserId: options.actorUserId || null,
    unitPriceSnapshot: primaryLine.unit_price || null,
    totalAmountSnapshot: invoice.total_amount,
    currency,
    existingEventId: postedEvent?.id || null,
  });

  // Pre-auth consume: first post uses full insurer share; mutable updates adjust by delta.
  // Idempotent retries that reused an existing invoice return earlier and skip this path.
  if (paymentMode === 'INSURANCE') {
    const nextInsurerShare = toDecimalNumber(
      enrichedBilling.insurer_share ?? sumInsurerShareFromItems(invoiceItems)
    );
    await consumePreAuthorizationForBillingTx(tx, {
      patientId,
      encounterId: options.encounterId || null,
      admissionId: options.admissionId || null,
      coveragePlanId: enrichedBilling.coverage_plan_id || options.coveragePlanId,
      insurerShare: nextInsurerShare,
      previousInsurerShare,
    });
  }

  return snapshot;
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
    sourceModule: BILLABLE_SOURCE_MODULES.LABORATORY,
    sourceId: orderId,
    mutableUpdate: Boolean(existingSnapshot),
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

/**
 * Build pending billing from a radiology order request (server-side fallback).
 *
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const buildRadiologyOrderBillingFromRequest = async ({
  radiologyTestId,
  tenantId,
  facilityId = null,
  description = 'Radiology order',
}) => {
  const { resolveUnitPrice } = require('@lib/billing/price-resolver');
  const catalogItemId = String(radiologyTestId || '').trim();
  if (!catalogItemId || !tenantId) {
    return null;
  }
  const test = await resolveCatalogRecord({
    identifier: catalogItemId,
    model: 'radiology_procedure',
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
    return null;
  }
  const pricing = await resolveUnitPrice({
    catalogType: 'RADIOLOGY_TEST',
    catalogItemId: test.id,
    tenantId,
    facilityId,
  });
  const unitPrice =
    pricing?.unitPrice ??
    (test.unit_price != null ? toMoneyString(test.unit_price) : null);
  if (unitPrice == null || toDecimalNumber(unitPrice) <= 0) {
    return null;
  }
  const currency = resolveBillingCurrency(
    { currency: pricing?.currency || test.currency },
    'USD'
  );
  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: test.human_friendly_id || test.id,
        label: test.name || description,
        quantity: 1,
        unit_price: unitPrice,
        line_total: unitPrice,
        catalog_type: 'RADIOLOGY_TEST',
      },
    ],
    currency,
  });
};

/**
 * Build pending billing from pharmacy order items (server-side fallback).
 *
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const buildPharmacyOrderBillingFromRequest = async ({
  items = [],
  tenantId,
  facilityId = null,
}) => {
  const { resolveUnitPrice } = require('@lib/billing/price-resolver');
  if (!tenantId || !Array.isArray(items) || items.length === 0) {
    return null;
  }
  const lineItems = [];
  let currency = 'USD';
  for (const item of items) {
    const drugId = String(item?.drug_id || item?.id || '').trim();
    if (!drugId) {
      continue;
    }
    const quantity = Math.max(1, Number(item?.quantity) || 1);
    const drug = await resolveCatalogRecord({
      identifier: drugId,
      model: 'drug',
      tenantId,
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        unit_price: true,
        currency: true,
      },
    });
    if (!drug) {
      continue;
    }
    const pricing = await resolveUnitPrice({
      catalogType: 'DRUG',
      catalogItemId: drug.id,
      tenantId,
      facilityId,
      billingEntity: 'FACILITY',
    });
    const unitPrice =
      pricing?.unitPrice ??
      (drug.unit_price != null ? toMoneyString(drug.unit_price) : null);
    if (unitPrice == null || toDecimalNumber(unitPrice) <= 0) {
      continue;
    }
    if (pricing?.currency || drug.currency) {
      currency = resolveBillingCurrency(
        { currency: pricing?.currency || drug.currency },
        currency
      );
    }
    const lineTotal = toMoneyString(toDecimalNumber(unitPrice) * quantity);
    lineItems.push({
      id: drug.human_friendly_id || drug.id,
      label: drug.name || item?.drug_name || 'Pharmacy item',
      quantity,
      unit_price: unitPrice,
      line_total: lineTotal,
      catalog_type: 'DRUG',
      price_source: pricing?.priceSource || 'FACILITY',
    });
  }
  return buildPendingClinicalRequestBilling({ lineItems, currency });
};

/**
 * Build pending billing for a procedure when client omitted billing payload.
 *
 * @param {Object} options
 * @returns {Promise<Object|null>}
 */
const buildProcedureBillingFromRequest = async ({
  catalogItemId = null,
  code = null,
  description = 'Procedure',
  unitPrice = null,
  currency = 'USD',
  tenantId,
  facilityId = null,
}) => {
  const { resolveUnitPrice } = require('@lib/billing/price-resolver');
  const lineId = String(catalogItemId || code || description || '').trim();
  if (!lineId) {
    return null;
  }
  let resolvedPrice = unitPrice != null ? toMoneyString(unitPrice) : null;
  let resolvedCurrency = currency;
  if (
    (resolvedPrice == null || toDecimalNumber(resolvedPrice) <= 0) &&
    catalogItemId &&
    tenantId
  ) {
    const pricing = await resolveUnitPrice({
      catalogType: 'SERVICE',
      catalogItemId: String(catalogItemId).trim(),
      tenantId,
      facilityId,
      billingEntity: 'FACILITY',
    });
    if (pricing?.unitPrice != null && toDecimalNumber(pricing.unitPrice) > 0) {
      resolvedPrice = pricing.unitPrice;
      resolvedCurrency = pricing.currency || resolvedCurrency;
    }
  }
  if (resolvedPrice == null || toDecimalNumber(resolvedPrice) <= 0) {
    return null;
  }
  return buildPendingClinicalRequestBilling({
    lineItems: [
      {
        id: lineId,
        label: description || lineId,
        quantity: 1,
        unit_price: resolvedPrice,
        line_total: resolvedPrice,
        catalog_type: 'SERVICE',
      },
    ],
    currency: resolveBillingCurrency({ currency: resolvedCurrency }, 'USD'),
  });
};

const persistPharmacyOrderBilling = async (
  tx,
  { orderId, billing, existingSnapshot, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.PHARMACY,
    sourceId: orderId,
    mutableUpdate: Boolean(existingSnapshot),
    ...context,
  });
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
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.RADIOLOGY,
    sourceId: orderId,
    mutableUpdate: Boolean(existingSnapshot),
    ...context,
  });
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
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.WARD_ROUND,
    sourceId: wardRoundId,
    mutableUpdate: Boolean(existingSnapshot),
    ...context,
  });
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
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.PROCEDURE,
    sourceId: procedureId,
    mutableUpdate: Boolean(existingSnapshot),
    ...context,
  });
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
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.THEATRE,
    sourceId: theatreCaseId,
    mutableUpdate: Boolean(existingSnapshot),
    ...context,
  });
  await tx.theatre_case.update({
    where: { id: theatreCaseId },
    data: { billing_snapshot: snapshot },
  });
  return snapshot;
};

/**
 * Build a catalogue-driven consultation billing payload from fee defaults.
 * Prefer price-book CONSULTATION entries when catalog refs are present.
 */
const buildConsultationBillingPayload = ({
  consultationFee,
  currency = 'USD',
  paymentStatus = 'PENDING',
  catalogItemId = null,
  label = 'Consultation fee',
  payNow = null,
  paymentMode = 'SELF_PAY',
  billingEntity = 'FACILITY',
} = {}) => {
  const amount = toMoneyString(consultationFee);
  if (toDecimalNumber(amount) <= 0) {
    return null;
  }

  const lineItem = {
    id: catalogItemId || 'consultation',
    label,
    quantity: 1,
    unit_price: amount,
    line_total: amount,
    catalog_type: 'CONSULTATION',
    ...(catalogItemId ? { catalog_item_id: catalogItemId } : {}),
    billing_entity: billingEntity,
    payment_mode: paymentMode,
  };

  const billing = {
    payment_status: paymentStatus,
    currency: resolveBillingCurrency({ currency }, 'USD'),
    total_amount: amount,
    line_amount: amount,
    billing_entity: billingEntity,
    payment_mode: paymentMode,
    line_items: [lineItem],
  };

  if (payNow) {
    const paidStatus = String(payNow.status || 'COMPLETED').toUpperCase();
    if (paidStatus === 'COMPLETED' || paidStatus === 'PAID') {
      billing.payment_status = 'PAID';
      billing.paid_amount = toMoneyString(payNow.amount ?? amount);
      billing.payment_method = payNow.method || 'CASH';
      billing.payment_reference = payNow.transaction_ref || null;
    }
  }

  return billing;
};

const persistConsultationBilling = async (
  tx,
  { encounterId, billing, existingSnapshot, ...context }
) => {
  return applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.CONSULTATION,
    sourceId: encounterId,
    encounterId,
    chargeKey: 'PRIMARY',
    catalogType: 'CONSULTATION',
    description: context.description || 'Consultation fee',
    mutableUpdate: Boolean(existingSnapshot),
    ...context,
  });
};

const persistAdmissionBilling = async (
  tx,
  { admissionId, billing, existingSnapshot, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.ADMISSION,
    sourceId: admissionId,
    catalogType: context.catalogType || 'SERVICE',
    description: context.description || 'Admission fee',
    mutableUpdate: Boolean(existingSnapshot),
    ...context,
  });
  if (tx?.admission?.update) {
    await tx.admission.update({
      where: { id: admissionId },
      data: { billing_snapshot: snapshot },
    });
  }
  return snapshot;
};

const persistNursingServiceBilling = async (
  tx,
  { nursingNoteId, billing, existingSnapshot, ...context }
) => {
  const snapshot = await applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.NURSING,
    sourceId: nursingNoteId,
    catalogType: context.catalogType || 'SERVICE',
    description: context.description || 'Nursing service',
    mutableUpdate: Boolean(existingSnapshot),
    allowRepeat: true,
    ...context,
  });
  if (tx?.nursing_note?.update) {
    await tx.nursing_note.update({
      where: { id: nursingNoteId },
      data: { billing_snapshot: snapshot },
    });
  }
  return snapshot;
};

/**
 * Catalogue-driven consumable / generic SERVICE charge with no parent clinical table.
 * `sourceId` must be a stable unique identifier for the usage event.
 */
const persistConsumableBilling = async (
  tx,
  { consumableUsageId, billing, existingSnapshot, ...context }
) => {
  return applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.CONSUMABLE,
    sourceId: consumableUsageId,
    catalogType: context.catalogType || 'SERVICE',
    description: context.description || 'Consumable',
    mutableUpdate: Boolean(existingSnapshot),
    allowRepeat: Boolean(context.allowRepeat),
    chargeKey: context.chargeKey || 'PRIMARY',
    ...context,
  });
};

/**
 * ICU stay start charge (critical-care package / bed-day). Idempotent on
 * `ICU_STAY` + stay id + charge key via billable charge events — no parallel
 * cash ledger in the ICU module.
 */
const persistIcuStayBilling = async (
  tx,
  { icuStayId, billing, existingSnapshot, ...context }
) => {
  return applyClinicalRequestBilling(tx, {
    billing,
    existingSnapshot,
    sourceModule: BILLABLE_SOURCE_MODULES.ICU_STAY,
    sourceId: icuStayId,
    catalogType: context.catalogType || 'SERVICE',
    description: context.description || 'ICU critical-care package',
    mutableUpdate: Boolean(existingSnapshot),
    chargeKey: context.chargeKey || 'ICU_STAY_START',
    ...context,
  });
};

module.exports = {
  BILLABLE_SOURCE_MODULES,
  isClinicalRequestBillingCandidate,
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
  persistConsultationBilling,
  persistAdmissionBilling,
  persistNursingServiceBilling,
  persistConsumableBilling,
  persistIcuStayBilling,
  buildConsultationBillingPayload,
  buildBillingSnapshot,
  buildPendingClinicalRequestBilling,
  enrichBillingWithPriceEngine,
  normalizeBillingOfficeClinicalBilling,
  buildLabOrderBillingFromRequest,
  buildRadiologyOrderBillingFromRequest,
  buildPharmacyOrderBillingFromRequest,
  buildProcedureBillingFromRequest,
  resolveClinicalInvoiceContexts,
  resolveInvoiceIdsForEncounterToken,
  resolveInvoiceIdsForSourceModule,
  syncClinicalOrderBillingSnapshotsFromInvoiceTx,
  resolveInvoicePaymentStatus,
  extractStoredClinicalBilling,
  mapClinicalOrderBillingFields,
  mapCatalogUnitPriceFields,
  resolveScopedBillingAmount,
  findPostedBillableChargeEvent,
  upsertBillableChargeEvent,
};
