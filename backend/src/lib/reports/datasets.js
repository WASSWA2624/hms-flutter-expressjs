const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { REPORT_DATASET_MAP } = require('@lib/reports/constants');
const { pharmacyRetailMarginUnit } = require('@lib/billing/pharmacy-drug-margins');
const {
  createPharmacyStaffDatasetRunners,
  summarizeStaffSalesPartition,
  pickAttestationUserId,
} = require('@lib/reports/pharmacy-staff-analytics');
const {
  computeInvoiceFinancials,
  toDecimalNumber,
} = require('@lib/billing/financials');

/** Matches billing open_invoices counter in buildBillingFinancialAnalytics. */
const OPEN_PHARMACY_INVOICE_STATUSES = Object.freeze(['DRAFT', 'SENT', 'OVERDUE']);

const resolveBatchExpiryAlertStatus = (expiryDate, expiringWithinDays = 30) => {
  if (!expiryDate) return null;
  const parsed = expiryDate instanceof Date ? expiryDate : new Date(expiryDate);
  if (Number.isNaN(parsed.getTime())) return null;
  const now = new Date();
  if (parsed.getTime() < now.getTime()) return 'EXPIRED';
  const horizon = new Date(now);
  horizon.setDate(horizon.getDate() + Number(expiringWithinDays || 30));
  if (parsed.getTime() <= horizon.getTime()) return 'EXPIRING_SOON';
  return null;
};

/**
 * Exclusive day windows for expiring_windows: (0,30], (30,60], (60,90], (90,180].
 * Expired (≤0) and beyond 180 return null.
 */
const classifyExpiryWindow = (daysToExpiry) => {
  if (daysToExpiry == null || daysToExpiry === '') return null;
  const days = asNumber(daysToExpiry);
  if (!(days > 0)) return null;
  if (days <= 30) return '0-30';
  if (days <= 60) return '30-60';
  if (days <= 90) return '60-90';
  if (days <= 180) return '90-180';
  return null;
};

/** Expiry/loss COGS: buy_unit_price only (no sell fallback). */
const resolveBuyUnitCostOnly = (drug) => {
  const buy = drug?.buy_unit_price;
  if (buy != null && buy !== '') {
    return { unit_cost: asNumber(buy), cost_basis: 'buy_unit_price' };
  }
  return { unit_cost: 0, cost_basis: 'unavailable' };
};

/**
 * Dispense COGS line: buy_unit_price × quantity_dispensed.
 * Returns 0 when buy is unset (documented; not inventing cost).
 */
const computeDispenseCogs = (buyUnitPrice, quantity) => {
  if (buyUnitPrice == null || buyUnitPrice === '') return 0;
  return Math.round(asNumber(buyUnitPrice) * asNumber(quantity) * 100) / 100;
};

const normalizeString = (value) => String(value || '').trim();
const asNumber = (value) => {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (value && typeof value.toString === 'function') {
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
};

const startOfDay = (value = new Date()) => {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date;
};

const endOfDay = (value = new Date()) => {
  const date = new Date(value);
  date.setHours(23, 59, 59, 999);
  return date;
};

const shiftDays = (value, dayOffset) => {
  const date = new Date(value);
  date.setDate(date.getDate() + dayOffset);
  return date;
};

const resolveDateRange = (parameters = {}) => {
  const now = new Date();
  const preset = normalizeString(parameters.date_preset || parameters.datePreset).toLowerCase();
  const fromInput = normalizeString(parameters.from);
  const toInput = normalizeString(parameters.to);
  const wantsCustom = preset === 'custom' || Boolean(fromInput) || Boolean(toInput);

  if (wantsCustom) {
    if (preset === 'custom' && !fromInput && !toInput) {
      return { from: null, to: null, preset: 'custom', invalid: true, reason: 'missing_bounds' };
    }
    const from = fromInput
      ? startOfDay(new Date(fromInput))
      : shiftDays(startOfDay(now), -29);
    const to = toInput ? endOfDay(new Date(toInput)) : endOfDay(now);
    if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
      return { from: null, to: null, preset: 'custom', invalid: true, reason: 'invalid_date' };
    }
    if (from.getTime() > to.getTime()) {
      return { from, to, preset: 'custom', invalid: true, reason: 'from_after_to' };
    }
    return { from, to, preset: 'custom', invalid: false };
  }

  if (preset === 'today' || preset === 'day') {
    return { from: startOfDay(now), to: endOfDay(now), preset: 'day', invalid: false };
  }
  if (preset === 'this_month' || preset === 'month') {
    const from = new Date(now.getFullYear(), now.getMonth(), 1);
    return { from, to: endOfDay(now), preset: 'month', invalid: false };
  }
  if (preset === 'this_year' || preset === 'year') {
    const from = new Date(now.getFullYear(), 0, 1);
    return { from, to: endOfDay(now), preset: 'year', invalid: false };
  }
  if (preset === 'last_7_days') {
    return {
      from: shiftDays(startOfDay(now), -6),
      to: endOfDay(now),
      preset: 'last_7_days',
      invalid: false,
    };
  }
  if (preset === 'last_30_days') {
    return {
      from: shiftDays(startOfDay(now), -29),
      to: endOfDay(now),
      preset: 'last_30_days',
      invalid: false,
    };
  }

  return {
    from: shiftDays(startOfDay(now), -29),
    to: endOfDay(now),
    preset: preset || 'last_30_days',
    invalid: false,
  };
};

const rangeSpanDays = (range) => {
  if (!range?.from || !range?.to) return 0;
  return Math.max(0, (range.to.getTime() - range.from.getTime()) / (24 * 60 * 60 * 1000));
};

const shouldUseMonthlyGranularity = (range) => {
  if (!range || range.invalid) return false;
  if (range.preset === 'year' || range.preset === 'this_year') return true;
  return rangeSpanDays(range) > 45;
};

const periodBucketKey = (dateValue, monthly) => {
  const parsed = dateValue ? new Date(dateValue) : null;
  if (!parsed || Number.isNaN(parsed.getTime())) return null;
  if (monthly) {
    const year = parsed.getUTCFullYear();
    const month = String(parsed.getUTCMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
  }
  return parsed.toISOString().slice(0, 10);
};

const aggregateByPeriod = (rows = [], dateField, keyMap, { monthly = false } = {}) => {
  const index = new Map();

  rows.forEach((row) => {
    const key = periodBucketKey(row?.[dateField], monthly);
    if (!key) return;
    if (!index.has(key)) {
      index.set(key, { date: key });
    }
    const target = index.get(key);
    Object.entries(keyMap).forEach(([field, source]) => {
      if (typeof source === 'function') {
        target[field] = asNumber(target[field]) + asNumber(source(row));
        return;
      }
      target[field] = asNumber(target[field]) + asNumber(row?.[source]);
    });
  });

  return Array.from(index.values()).sort((left, right) => String(left.date).localeCompare(String(right.date)));
};

const APPLIED_ADJUSTMENT_STATUSES = new Set(['ISSUED', 'PAID', 'PARTIAL']);
const COUNTED_PAYMENT_STATUSES = new Set(['COMPLETED', 'REFUNDED']);

const emptyBillingBucket = (date) => ({
  date,
  collections: 0,
  refunds: 0,
  write_offs: 0,
  expenditures: 0,
  profit_proxy: 0,
  net_collections: 0,
  issued_invoices: 0,
  open_invoices: 0,
});

const mergeBillingBuckets = (entries = []) => {
  const index = new Map();
  entries.forEach((entry) => {
    if (!entry?.date) return;
    if (!index.has(entry.date)) {
      index.set(entry.date, emptyBillingBucket(entry.date));
    }
    const target = index.get(entry.date);
    target.collections += asNumber(entry.collections);
    target.refunds += asNumber(entry.refunds);
    target.write_offs += asNumber(entry.write_offs);
    target.issued_invoices += asNumber(entry.issued_invoices);
    target.open_invoices += asNumber(entry.open_invoices);
  });

  return Array.from(index.values())
    .map((entry) => {
      const expenditures = asNumber(entry.refunds) + asNumber(entry.write_offs);
      const collections = asNumber(entry.collections);
      return {
        ...entry,
        expenditures: Math.round(expenditures * 100) / 100,
        net_collections: Math.round((collections - asNumber(entry.refunds)) * 100) / 100,
        // Profit uses gross collections − expenditures so refunds are not double-counted.
        profit_proxy: Math.round((collections - expenditures) * 100) / 100,
        collections: Math.round(collections * 100) / 100,
        refunds: Math.round(asNumber(entry.refunds) * 100) / 100,
        write_offs: Math.round(asNumber(entry.write_offs) * 100) / 100,
      };
    })
    .sort((left, right) => String(left.date).localeCompare(String(right.date)));
};

const summarizeBillingSeries = (rows = []) => {
  const totals = rows.reduce(
    (acc, row) => {
      acc.collections += asNumber(row.collections);
      acc.refunds += asNumber(row.refunds);
      acc.write_offs += asNumber(row.write_offs);
      acc.expenditures += asNumber(row.expenditures);
      acc.profit_proxy += asNumber(row.profit_proxy);
      acc.net_collections += asNumber(row.net_collections);
      acc.issued_invoices += asNumber(row.issued_invoices);
      acc.open_invoices += asNumber(row.open_invoices);
      return acc;
    },
    {
      collections: 0,
      refunds: 0,
      write_offs: 0,
      expenditures: 0,
      profit_proxy: 0,
      net_collections: 0,
      issued_invoices: 0,
      open_invoices: 0,
    }
  );

  return {
    collections: Math.round(totals.collections * 100) / 100,
    refunds: Math.round(totals.refunds * 100) / 100,
    write_offs: Math.round(totals.write_offs * 100) / 100,
    expenditures: Math.round(totals.expenditures * 100) / 100,
    profit_proxy: Math.round(totals.profit_proxy * 100) / 100,
    net_collections: Math.round(totals.net_collections * 100) / 100,
    issued_invoices: totals.issued_invoices,
    open_invoices: totals.open_invoices,
  };
};

/**
 * Facility billing financial analytics for a period.
 * Collections = COMPLETED/REFUNDED payment amounts (gross).
 * Expenditures = refunds + abs(negative applied adjustments).
 * Profit proxy = collections − expenditures.
 */
const buildBillingFinancialAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      invalid: true,
      reason: range.reason || 'invalid_range',
      preset: range.preset,
      from: range.from,
      to: range.to,
      granularity: 'day',
      title: 'Billing collections, expenditures, and profit',
      subtitle: 'Invalid date range',
      columns: [
        'date',
        'collections',
        'expenditures',
        'profit_proxy',
        'refunds',
        'write_offs',
        'net_collections',
        'issued_invoices',
        'open_invoices',
      ],
      rows: [],
      summary: summarizeBillingSeries([]),
      breakdown: { refunds: 0, write_offs: 0 },
    };
  }

  const monthly = shouldUseMonthlyGranularity(range);
  const tenantWhere = buildTenantWhere(scope);

  const [payments, refunds, adjustments, invoices] = await Promise.all([
    prisma.payment.findMany({
      where: {
        ...tenantWhere,
        status: { in: Array.from(COUNTED_PAYMENT_STATUSES) },
        paid_at: { gte: range.from, lte: range.to },
      },
      select: {
        paid_at: true,
        amount: true,
        method: true,
      },
    }),
    prisma.refund.findMany({
      where: {
        deleted_at: null,
        refunded_at: { gte: range.from, lte: range.to },
        payment: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
          ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
        },
      },
      select: {
        refunded_at: true,
        amount: true,
      },
    }),
    prisma.billing_adjustment.findMany({
      where: {
        deleted_at: null,
        adjusted_at: { gte: range.from, lte: range.to },
        status: { in: Array.from(APPLIED_ADJUSTMENT_STATUSES) },
        amount: { lt: 0 },
        invoice: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
          ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
        },
      },
      select: {
        adjusted_at: true,
        amount: true,
      },
    }),
    prisma.invoice.findMany({
      where: {
        ...tenantWhere,
        issued_at: { gte: range.from, lte: range.to },
      },
      select: {
        issued_at: true,
        status: true,
      },
    }),
  ]);

  const paymentBuckets = aggregateByPeriod(
    payments,
    'paid_at',
    { collections: (row) => asNumber(row.amount) },
    { monthly }
  );
  const refundBuckets = aggregateByPeriod(
    refunds,
    'refunded_at',
    { refunds: (row) => asNumber(row.amount) },
    { monthly }
  );
  const writeOffBuckets = aggregateByPeriod(
    adjustments,
    'adjusted_at',
    { write_offs: (row) => Math.abs(asNumber(row.amount)) },
    { monthly }
  );
  const invoiceBuckets = aggregateByPeriod(
    invoices,
    'issued_at',
    {
      issued_invoices: () => 1,
      open_invoices: (row) =>
        ['DRAFT', 'SENT', 'OVERDUE'].includes(String(row.status || '').toUpperCase()) ? 1 : 0,
    },
    { monthly }
  );

  const rows = mergeBillingBuckets([
    ...paymentBuckets,
    ...refundBuckets,
    ...writeOffBuckets,
    ...invoiceBuckets,
  ]);
  const summary = summarizeBillingSeries(rows);

  const methodIndex = new Map();
  payments.forEach((payment) => {
    const method = normalizeString(payment.method) || 'UNKNOWN';
    methodIndex.set(method, asNumber(methodIndex.get(method)) + asNumber(payment.amount));
  });
  const collections_by_method = Array.from(methodIndex.entries())
    .map(([method, amount]) => ({
      method,
      amount: Math.round(asNumber(amount) * 100) / 100,
    }))
    .sort((left, right) => right.amount - left.amount);

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    reason: null,
    preset: range.preset,
    from: range.from,
    to: range.to,
    granularity: monthly ? 'month' : 'day',
    title: 'Billing collections, expenditures, and profit',
    subtitle: `${fromLabel} to ${toLabel} (${monthly ? 'monthly' : 'daily'})`,
    columns: [
      'date',
      'collections',
      'expenditures',
      'profit_proxy',
      'refunds',
      'write_offs',
      'net_collections',
      'issued_invoices',
      'open_invoices',
    ],
    rows,
    summary,
    breakdown: {
      refunds: summary.refunds,
      write_offs: summary.write_offs,
      collections_by_method,
    },
  };
};

const buildTenantWhere = ({ tenant_id, facility_id = null }) => ({
  deleted_at: null,
  tenant_id,
  ...(facility_id ? { facility_id } : {}),
});

const aggregateByDate = (rows = [], dateField, keyMap) => {
  const index = new Map();

  rows.forEach((row) => {
    const dateValue = row?.[dateField];
    const parsed = dateValue ? new Date(dateValue) : null;
    if (!parsed || Number.isNaN(parsed.getTime())) return;
    const key = parsed.toISOString().slice(0, 10);
    if (!index.has(key)) {
      index.set(key, { date: key });
    }
    const target = index.get(key);
    Object.entries(keyMap).forEach(([field, source]) => {
      if (typeof source === 'function') {
        target[field] = asNumber(target[field]) + asNumber(source(row));
        return;
      }
      target[field] = asNumber(target[field]) + asNumber(row?.[source]);
    });
  });

  return Array.from(index.values()).sort((left, right) => String(left.date).localeCompare(String(right.date)));
};

const runPatientRegistrationsDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const rows = await prisma.patient.findMany({
    where: {
      ...buildTenantWhere(scope),
      created_at: { gte: range.from, lte: range.to },
    },
    select: {
      created_at: true,
    },
  });

  const daily = aggregateByDate(rows, 'created_at', {
    registrations: () => 1,
  }).map((entry) => ({
    ...entry,
    facility: scope.facility_label || 'All facilities',
  }));

  return {
    title: 'Patient registrations',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)}`,
    columns: ['date', 'registrations', 'facility'],
    rows: daily,
  };
};

const runAppointmentDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const appointments = await prisma.appointment.findMany({
    where: {
      ...buildTenantWhere(scope),
      scheduled_start: { gte: range.from, lte: range.to },
    },
    select: {
      scheduled_start: true,
      status: true,
    },
  });

  const daily = aggregateByDate(appointments, 'scheduled_start', {
    scheduled: () => 1,
    completed: (row) => (String(row.status || '').toUpperCase() === 'COMPLETED' ? 1 : 0),
    no_show: (row) => (String(row.status || '').toUpperCase() === 'NO_SHOW' ? 1 : 0),
  });

  return {
    title: 'Appointment throughput and no-shows',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)}`,
    columns: ['date', 'scheduled', 'completed', 'no_show'],
    rows: daily,
  };
};

const runBillingDataset = async (scope, parameters = {}) => {
  const analytics = await buildBillingFinancialAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
  };
};

const buildPharmacyPatientScope = (scope = {}) => {
  const where = { deleted_at: null };
  if (scope.tenant_id) where.tenant_id = scope.tenant_id;
  if (scope.facility_id) where.facility_id = scope.facility_id;
  return where;
};

const buildPharmacyOrderScopeWhere = (scope = {}) => ({
  deleted_at: null,
  patient: buildPharmacyPatientScope(scope),
});

const buildDispenseLogScopeWhere = (scope = {}) => ({
  deleted_at: null,
  pharmacy_order_item: {
    deleted_at: null,
    pharmacy_order: {
      deleted_at: null,
      patient: buildPharmacyPatientScope(scope),
    },
  },
});

const resolveOrderSource = (encounterId) => (encounterId ? 'CLINICAL' : 'PHARMACY');

const resolveDispenseUnitPrice = (log) => {
  const drugPrice = asNumber(log?.pharmacy_order_item?.drug?.unit_price);
  if (drugPrice > 0) return drugPrice;

  const snapshot = log?.pharmacy_order_item?.pharmacy_order?.billing_snapshot;
  const lineItems = Array.isArray(snapshot?.line_items) ? snapshot.line_items : [];
  if (!lineItems.length) return drugPrice;

  const drugId = normalizeString(log?.pharmacy_order_item?.drug_id || log?.pharmacy_order_item?.drug?.id);
  const drugName = normalizeString(log?.pharmacy_order_item?.drug?.name);
  const match = lineItems.find((line) => {
    const lineId = normalizeString(line?.id);
    if (drugId && (lineId === drugId || lineId === normalizeString(log?.pharmacy_order_item?.drug?.human_friendly_id))) {
      return true;
    }
    if (drugName && normalizeString(line?.label) === drugName) return true;
    return false;
  });
  return asNumber(match?.unit_price);
};

const emptyThroughputBucket = (date) => ({
  date,
  orders_created: 0,
  dispensed: 0,
  partially_dispensed: 0,
  cancelled: 0,
  returns: 0,
});

const mergeThroughputBuckets = (entries = []) => {
  const index = new Map();
  entries.forEach((entry) => {
    if (!entry?.date) return;
    if (!index.has(entry.date)) {
      index.set(entry.date, emptyThroughputBucket(entry.date));
    }
    const target = index.get(entry.date);
    target.orders_created += asNumber(entry.orders_created);
    target.dispensed += asNumber(entry.dispensed);
    target.partially_dispensed += asNumber(entry.partially_dispensed);
    target.cancelled += asNumber(entry.cancelled);
    target.returns += asNumber(entry.returns);
  });

  return Array.from(index.values()).sort((left, right) =>
    String(left.date).localeCompare(String(right.date))
  );
};

const summarizeThroughputSeries = (rows = []) =>
  rows.reduce(
    (acc, row) => {
      acc.orders_created += asNumber(row.orders_created);
      acc.dispensed += asNumber(row.dispensed);
      acc.partially_dispensed += asNumber(row.partially_dispensed);
      acc.cancelled += asNumber(row.cancelled);
      acc.returns += asNumber(row.returns);
      return acc;
    },
    {
      orders_created: 0,
      dispensed: 0,
      partially_dispensed: 0,
      cancelled: 0,
      returns: 0,
    }
  );

const summarizeConsumptionSeries = (rows = []) => {
  const totals = rows.reduce(
    (acc, row) => {
      acc.quantity_dispensed += asNumber(row.quantity_dispensed);
      acc.amount += asNumber(row.amount);
      return acc;
    },
    { quantity_dispensed: 0, amount: 0 }
  );
  return {
    quantity_dispensed: totals.quantity_dispensed,
    amount: Math.round(totals.amount * 100) / 100,
    drug_count: rows.length,
  };
};

const resolveConsumptionGroupBy = (parameters = {}) => {
  const raw = normalizeString(parameters.group_by || parameters.groupBy || 'drug').toLowerCase();
  if (raw === 'category' || raw === 'facility' || raw === 'patient' || raw === 'drug') {
    return raw;
  }
  return 'drug';
};

const resolveInventoryCategory = (drug) => {
  const maps = Array.isArray(drug?.inventory_maps) ? drug.inventory_maps : [];
  const preferred = maps.find((entry) => entry?.is_default) || maps[0];
  return normalizeString(preferred?.inventory_item?.category) || 'OTHER';
};

const resolvePatientLabel = (patient) => {
  if (!patient) return 'Unknown';
  const hfi = normalizeString(patient.human_friendly_id);
  const name = [normalizeString(patient.first_name), normalizeString(patient.last_name)]
    .filter(Boolean)
    .join(' ');
  if (hfi && name) return `${hfi} · ${name}`;
  return hfi || name || 'Unknown';
};

const resolvePrescriberLabel = (provider) => {
  if (!provider) return null;
  const hfi = normalizeString(provider.human_friendly_id);
  const name = [
    normalizeString(provider.profile?.first_name),
    normalizeString(provider.profile?.last_name),
  ]
    .filter(Boolean)
    .join(' ');
  if (hfi && name) return `${hfi} · ${name}`;
  if (hfi || name) return hfi || name;
  return normalizeString(provider.email) || null;
};

/** Average line items per order: item_count / orders_created (2 dp). */
const computeAverageItemsPerPrescription = (itemCount, orderCount) => {
  const orders = asNumber(orderCount);
  if (orders <= 0) return null;
  return Math.round((asNumber(itemCount) / orders) * 100) / 100;
};

const remainingItemQuantity = (item) => {
  const ordered = asNumber(item?.quantity);
  const dispensed = (Array.isArray(item?.dispense_logs) ? item.dispense_logs : []).reduce(
    (sum, log) => sum + asNumber(log.quantity_dispensed),
    0
  );
  return Math.max(0, ordered - dispensed);
};

const resolveFacilityLabel = (patient) =>
  normalizeString(patient?.facility?.name) ||
  normalizeString(patient?.facility?.human_friendly_id) ||
  'Unknown';

const consumptionColumnsForGroup = (groupBy, { includeProfit = false } = {}) => {
  if (groupBy === 'category') {
    return includeProfit
      ? ['category', 'profit', 'amount']
      : ['category', 'quantity_dispensed', 'amount'];
  }
  if (groupBy === 'facility') {
    return includeProfit
      ? ['facility', 'profit', 'amount']
      : ['facility', 'amount', 'quantity_dispensed'];
  }
  if (groupBy === 'patient') return ['patient', 'amount', 'quantity_dispensed'];
  return ['drug', 'quantity_dispensed', 'amount', 'profit', 'order_source'];
};

const sortConsumptionRows = (rows = []) =>
  [...rows].sort((left, right) => {
    const qtyDiff = asNumber(right.quantity_dispensed) - asNumber(left.quantity_dispensed);
    if (qtyDiff !== 0) return qtyDiff;
    return asNumber(right.amount) - asNumber(left.amount);
  });

/**
 * Pharmacy drug consumption analytics for a period.
 * Amount prefers drug.unit_price × quantity_dispensed; falls back to billing_snapshot line unit_price.
 * Optional group_by: drug (default) | category | facility | patient — same unit/profit math.
 */
const buildPharmacyDrugConsumptionAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const groupBy = resolveConsumptionGroupBy(parameters);
  const includeProfit = Boolean(parameters.include_profit || parameters.includeProfit);
  const columns = consumptionColumnsForGroup(groupBy, { includeProfit });
  const topLimit = Math.max(1, Math.min(100, asNumber(parameters.top_n || parameters.limit) || 25));
  const orderSourceFilter = normalizeString(
    parameters.order_source || parameters.orderSource
  ).toUpperCase();

  if (range.invalid) {
    return {
      invalid: true,
      reason: range.reason || 'invalid_range',
      preset: range.preset,
      from: range.from,
      to: range.to,
      granularity: 'day',
      title: 'Pharmacy drug consumption',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: summarizeConsumptionSeries([]),
      breakdown: { daily_totals: [], source_mix: [] },
    };
  }

  const monthly = shouldUseMonthlyGranularity(range);
  const logs = await prisma.dispense_log.findMany({
    where: {
      ...buildDispenseLogScopeWhere(scope),
      status: 'DISPENSED',
      dispensed_at: { gte: range.from, lte: range.to },
    },
    select: {
      dispensed_at: true,
      quantity_dispensed: true,
      pharmacy_order_item: {
        select: {
          drug_id: true,
          drug: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
              unit_price: true,
              buy_unit_price: true,
              inventory_maps: {
                where: { deleted_at: null },
                select: {
                  is_default: true,
                  inventory_item: {
                    select: {
                      category: true,
                    },
                  },
                },
              },
            },
          },
          pharmacy_order: {
            select: {
              encounter_id: true,
              billing_snapshot: true,
              patient: {
                select: {
                  human_friendly_id: true,
                  first_name: true,
                  last_name: true,
                  facility: {
                    select: {
                      name: true,
                      human_friendly_id: true,
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  });

  const drugIndex = new Map();
  const categoryIndex = new Map();
  const facilityIndex = new Map();
  const patientIndex = new Map();
  const sourceIndex = new Map();
  const dailyRows = [];

  logs.forEach((log) => {
    const qty = asNumber(log.quantity_dispensed);
    if (qty <= 0) return;
    const unitPrice = resolveDispenseUnitPrice(log);
    const amount = Math.round(unitPrice * qty * 100) / 100;
    const buyUnitPrice = log?.pharmacy_order_item?.drug?.buy_unit_price;
    const marginUnit = pharmacyRetailMarginUnit({
      unitPrice,
      buyUnitPrice,
    });
    const profit =
      marginUnit == null ? null : Math.round(marginUnit * qty * 100) / 100;
    // Financial rollups treat null profit as 0; drug rows keep null when buy unset.
    const profitForRollup = profit == null ? 0 : profit;
    const cogs = computeDispenseCogs(buyUnitPrice, qty);
    const drugName =
      normalizeString(log?.pharmacy_order_item?.drug?.name) ||
      normalizeString(log?.pharmacy_order_item?.drug_id) ||
      'Unknown';
    const category = resolveInventoryCategory(log?.pharmacy_order_item?.drug);
    const patient = log?.pharmacy_order_item?.pharmacy_order?.patient;
    const patientLabel = resolvePatientLabel(patient);
    const facilityLabel = resolveFacilityLabel(patient);
    const orderSource = resolveOrderSource(log?.pharmacy_order_item?.pharmacy_order?.encounter_id);
    if (
      orderSourceFilter &&
      (orderSourceFilter === 'PHARMACY' || orderSourceFilter === 'CLINICAL') &&
      orderSource !== orderSourceFilter
    ) {
      return;
    }

    if (!drugIndex.has(drugName)) {
      drugIndex.set(drugName, {
        drug: drugName,
        quantity_dispensed: 0,
        amount: 0,
        profit: null,
        cogs: 0,
        sources: new Map(),
      });
    }
    const drugEntry = drugIndex.get(drugName);
    drugEntry.quantity_dispensed += qty;
    drugEntry.amount = Math.round((drugEntry.amount + amount) * 100) / 100;
    drugEntry.cogs = Math.round((asNumber(drugEntry.cogs) + cogs) * 100) / 100;
    if (profit != null) {
      drugEntry.profit = Math.round((asNumber(drugEntry.profit) + profit) * 100) / 100;
    }
    drugEntry.sources.set(orderSource, asNumber(drugEntry.sources.get(orderSource)) + qty);

    if (!categoryIndex.has(category)) {
      categoryIndex.set(category, {
        category,
        quantity_dispensed: 0,
        amount: 0,
        profit: 0,
        cogs: 0,
      });
    }
    const categoryEntry = categoryIndex.get(category);
    categoryEntry.quantity_dispensed += qty;
    categoryEntry.amount = Math.round((categoryEntry.amount + amount) * 100) / 100;
    categoryEntry.profit = Math.round((asNumber(categoryEntry.profit) + profitForRollup) * 100) / 100;
    categoryEntry.cogs = Math.round((asNumber(categoryEntry.cogs) + cogs) * 100) / 100;

    if (!facilityIndex.has(facilityLabel)) {
      facilityIndex.set(facilityLabel, {
        facility: facilityLabel,
        quantity_dispensed: 0,
        amount: 0,
        profit: 0,
        cogs: 0,
      });
    }
    const facilityEntry = facilityIndex.get(facilityLabel);
    facilityEntry.quantity_dispensed += qty;
    facilityEntry.amount = Math.round((facilityEntry.amount + amount) * 100) / 100;
    facilityEntry.profit = Math.round((asNumber(facilityEntry.profit) + profitForRollup) * 100) / 100;
    facilityEntry.cogs = Math.round((asNumber(facilityEntry.cogs) + cogs) * 100) / 100;

    if (!patientIndex.has(patientLabel)) {
      patientIndex.set(patientLabel, {
        patient: patientLabel,
        quantity_dispensed: 0,
        amount: 0,
      });
    }
    const patientEntry = patientIndex.get(patientLabel);
    patientEntry.quantity_dispensed += qty;
    patientEntry.amount = Math.round((patientEntry.amount + amount) * 100) / 100;

    sourceIndex.set(orderSource, {
      order_source: orderSource,
      quantity_dispensed:
        asNumber(sourceIndex.get(orderSource)?.quantity_dispensed) + qty,
      amount:
        Math.round((asNumber(sourceIndex.get(orderSource)?.amount) + amount) * 100) / 100,
    });

    dailyRows.push({
      dispensed_at: log.dispensed_at,
      quantity_dispensed: qty,
      amount,
      profit: profitForRollup,
      cogs,
    });
  });

  let rows;
  if (groupBy === 'category') {
    rows = sortConsumptionRows(
      Array.from(categoryIndex.values()).map((entry) => {
        const amount = Math.round(entry.amount * 100) / 100;
        if (includeProfit) {
          return {
            category: entry.category,
            profit: Math.round(asNumber(entry.profit) * 100) / 100,
            amount,
          };
        }
        return {
          category: entry.category,
          quantity_dispensed: entry.quantity_dispensed,
          amount,
        };
      })
    );
  } else if (groupBy === 'facility') {
    rows = sortConsumptionRows(
      Array.from(facilityIndex.values()).map((entry) => {
        if (includeProfit) {
          return {
            facility: entry.facility,
            profit: Math.round(asNumber(entry.profit) * 100) / 100,
            amount: Math.round(entry.amount * 100) / 100,
          };
        }
        return {
          facility: entry.facility,
          amount: Math.round(entry.amount * 100) / 100,
          quantity_dispensed: entry.quantity_dispensed,
          profit: entry.profit,
        };
      })
    );
  } else if (groupBy === 'patient') {
    rows = sortConsumptionRows(
      Array.from(patientIndex.values()).map((entry) => ({
        patient: entry.patient,
        amount: Math.round(entry.amount * 100) / 100,
        quantity_dispensed: entry.quantity_dispensed,
      }))
    ).slice(0, topLimit);
  } else {
    rows = sortConsumptionRows(
      Array.from(drugIndex.values()).map((entry) => {
        const sourceEntries = Array.from(entry.sources.entries()).sort(
          (left, right) => right[1] - left[1]
        );
        const orderSource =
          sourceEntries.length === 1
            ? sourceEntries[0][0]
            : sourceEntries.length > 1
              ? 'MIXED'
              : 'UNKNOWN';
        return {
          drug: entry.drug,
          quantity_dispensed: entry.quantity_dispensed,
          amount: Math.round(entry.amount * 100) / 100,
          profit: entry.profit,
          cogs: Math.round(asNumber(entry.cogs) * 100) / 100,
          order_source: orderSource,
        };
      })
    ).slice(0, topLimit);
  }

  const daily_totals = aggregateByPeriod(
    dailyRows,
    'dispensed_at',
    {
      quantity_dispensed: (row) => asNumber(row.quantity_dispensed),
      amount: (row) => asNumber(row.amount),
      profit: (row) => asNumber(row.profit),
      cogs: (row) => asNumber(row.cogs),
    },
    { monthly }
  ).map((entry) => ({
    ...entry,
    amount: Math.round(asNumber(entry.amount) * 100) / 100,
    profit: Math.round(asNumber(entry.profit) * 100) / 100,
    cogs: Math.round(asNumber(entry.cogs) * 100) / 100,
  }));

  const source_mix = Array.from(sourceIndex.values()).sort(
    (left, right) => asNumber(right.quantity_dispensed) - asNumber(left.quantity_dispensed)
  );

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  const sourceLabel = orderSourceFilter
    ? ` · source ${orderSourceFilter}`
    : '';
  const groupLabel =
    groupBy === 'drug' ? `top ${rows.length} by quantity` : `by ${groupBy} (${rows.length})`;

  // Full-period money totals use all dispense events (not the top-N drug slice).
  const periodTotals = dailyRows.reduce(
    (acc, row) => {
      acc.quantity_dispensed += asNumber(row.quantity_dispensed);
      acc.amount += asNumber(row.amount);
      acc.profit += asNumber(row.profit);
      acc.cogs += asNumber(row.cogs);
      return acc;
    },
    { quantity_dispensed: 0, amount: 0, profit: 0, cogs: 0 }
  );
  const profitTotal =
    groupBy === 'drug'
      ? rows.reduce((sum, row) => sum + asNumber(row.profit), 0)
      : Math.round(periodTotals.profit * 100) / 100;

  return {
    invalid: false,
    reason: null,
    preset: range.preset,
    from: range.from,
    to: range.to,
    granularity: monthly ? 'month' : 'day',
    title:
      groupBy === 'category'
        ? includeProfit
          ? 'Pharmacy profit by product/category'
          : 'Pharmacy sales by category'
        : groupBy === 'facility'
          ? includeProfit
            ? 'Pharmacy profit by branch'
            : 'Pharmacy sales by branch'
          : groupBy === 'patient'
            ? 'Pharmacy sales by customer'
            : 'Pharmacy drug consumption',
    subtitle: `${fromLabel} to ${toLabel} (${groupLabel})${sourceLabel}`,
    columns,
    rows,
    summary: {
      ...summarizeConsumptionSeries(rows),
      // Keep drug summary compatible: amount/qty from returned rows (top-N).
      ...(groupBy === 'drug'
        ? {
            profit: profitTotal,
            cogs: Math.round(periodTotals.cogs * 100) / 100,
            source_mix,
          }
        : {
            amount: Math.round(periodTotals.amount * 100) / 100,
            quantity_dispensed: periodTotals.quantity_dispensed,
            drug_count: rows.length,
            profit: Math.round(periodTotals.profit * 100) / 100,
            cogs: Math.round(periodTotals.cogs * 100) / 100,
          }),
      period_amount: Math.round(periodTotals.amount * 100) / 100,
      period_profit: Math.round(periodTotals.profit * 100) / 100,
      period_cogs: Math.round(periodTotals.cogs * 100) / 100,
    },
    breakdown: {
      daily_totals,
      source_mix,
    },
  };
};

/**
 * Pharmacy dispense throughput analytics for a period.
 * Orders bucketed by ordered_at status mix; returns from dispense_log RETURNED updates.
 */
const buildPharmacyDispenseThroughputAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = [
    'date',
    'orders_created',
    'dispensed',
    'partially_dispensed',
    'cancelled',
    'returns',
  ];

  if (range.invalid) {
    return {
      invalid: true,
      reason: range.reason || 'invalid_range',
      preset: range.preset,
      from: range.from,
      to: range.to,
      granularity: 'day',
      title: 'Pharmacy dispense throughput',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: summarizeThroughputSeries([]),
      breakdown: { status_totals: [], voids: [] },
    };
  }

  const monthly = shouldUseMonthlyGranularity(range);
  const [orders, returns] = await Promise.all([
    prisma.pharmacy_order.findMany({
      where: {
        ...buildPharmacyOrderScopeWhere(scope),
        ordered_at: { gte: range.from, lte: range.to },
      },
      select: {
        ordered_at: true,
        status: true,
      },
    }),
    prisma.dispense_log.findMany({
      where: {
        ...buildDispenseLogScopeWhere(scope),
        status: 'RETURNED',
        updated_at: { gte: range.from, lte: range.to },
      },
      select: {
        updated_at: true,
      },
    }),
  ]);

  const orderBuckets = aggregateByPeriod(
    orders,
    'ordered_at',
    {
      orders_created: () => 1,
      dispensed: (row) => (String(row.status || '').toUpperCase() === 'DISPENSED' ? 1 : 0),
      partially_dispensed: (row) =>
        String(row.status || '').toUpperCase() === 'PARTIALLY_DISPENSED' ? 1 : 0,
      cancelled: (row) => (String(row.status || '').toUpperCase() === 'CANCELLED' ? 1 : 0),
    },
    { monthly }
  );
  const returnBuckets = aggregateByPeriod(
    returns,
    'updated_at',
    { returns: () => 1 },
    { monthly }
  );

  const rows = mergeThroughputBuckets([...orderBuckets, ...returnBuckets]);
  const summary = summarizeThroughputSeries(rows);
  const statusIndex = new Map();
  orders.forEach((order) => {
    const status = String(order.status || '').toUpperCase() || 'UNKNOWN';
    statusIndex.set(status, asNumber(statusIndex.get(status)) + 1);
  });
  const status_totals = Array.from(statusIndex.entries())
    .map(([status, orders_created]) => ({ status, orders_created }))
    .sort((left, right) => asNumber(right.orders_created) - asNumber(left.orders_created));
  const voids = [
    { void_type: 'CANCELLED_ORDERS', void_count: summary.cancelled },
    { void_type: 'RETURNED_LOGS', void_count: summary.returns },
  ];
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    reason: null,
    preset: range.preset,
    from: range.from,
    to: range.to,
    granularity: monthly ? 'month' : 'day',
    title: 'Pharmacy dispense throughput',
    subtitle: `${fromLabel} to ${toLabel} (${monthly ? 'monthly' : 'daily'})`,
    columns,
    rows,
    summary,
    breakdown: {
      status_totals,
      voids,
    },
  };
};

const runPharmacyDrugConsumptionDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDrugConsumptionAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const runPharmacyDispenseThroughputDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDispenseThroughputAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const runPharmacySalesByCategoryDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDrugConsumptionAnalytics(scope, {
    ...parameters,
    group_by: 'category',
  });
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const runPharmacySalesByBranchDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDrugConsumptionAnalytics(scope, {
    ...parameters,
    group_by: 'facility',
  });
  const rows = (analytics.rows || []).map((entry) => ({
    facility: entry.facility,
    amount: entry.amount,
    quantity_dispensed: entry.quantity_dispensed,
  }));
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: ['facility', 'amount', 'quantity_dispensed'],
    rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

/**
 * Aggregate inventory stock rows by facility name.
 * Pure helper for unit tests: facility totals must sum to tenant totals.
 */
const aggregateStockByFacility = (stockRows = []) => {
  const index = new Map();
  for (const row of stockRows) {
    const facility = normalizeString(row.facility) || 'Unassigned';
    if (!index.has(facility)) {
      index.set(facility, { facility, quantity: 0, value: 0 });
    }
    const entry = index.get(facility);
    entry.quantity += asNumber(row.quantity);
    entry.value = Math.round((entry.value + asNumber(row.value)) * 100) / 100;
  }
  return Array.from(index.values()).sort(
    (left, right) => asNumber(right.value) - asNumber(left.value)
  );
};

const SHORTAGE_RISK_STATES = Object.freeze(
  new Set(['LOW', 'CRITICAL', 'OUT_OF_STOCK'])
);

/**
 * Count shortage classifiers (LOW/CRITICAL/OUT_OF_STOCK) per facility.
 */
const aggregateShortagesByFacility = (stockRows = []) => {
  const index = new Map();
  for (const row of stockRows) {
    const risk = normalizeString(row.risk_state);
    if (!SHORTAGE_RISK_STATES.has(risk)) continue;
    const facility = normalizeString(row.facility) || 'Unassigned';
    if (!index.has(facility)) {
      index.set(facility, {
        facility,
        shortage_count: 0,
        low_count: 0,
        critical_count: 0,
        out_of_stock_count: 0,
        quantity: 0,
      });
    }
    const entry = index.get(facility);
    entry.shortage_count += 1;
    entry.quantity += asNumber(row.quantity);
    if (risk === 'LOW') entry.low_count += 1;
    if (risk === 'CRITICAL') entry.critical_count += 1;
    if (risk === 'OUT_OF_STOCK') entry.out_of_stock_count += 1;
  }
  return Array.from(index.values()).sort(
    (left, right) => asNumber(right.shortage_count) - asNumber(left.shortage_count)
  );
};

/**
 * Merge sales/profit/stock metrics per facility for comparison charts.
 * Two-facility (or N) rows must sum amount/profit/quantity/value to tenant totals.
 */
const mergeBranchComparisonRows = ({
  salesRows = [],
  stockRows = [],
  shortageRows = [],
  purchaseRows = [],
} = {}) => {
  const index = new Map();
  const ensure = (facility) => {
    const key = normalizeString(facility) || 'Unassigned';
    if (!index.has(key)) {
      index.set(key, {
        facility: key,
        amount: 0,
        profit: null,
        quantity_dispensed: 0,
        quantity: 0,
        value: 0,
        shortage_count: 0,
        request_count: 0,
        order_count: 0,
      });
    }
    return index.get(key);
  };

  for (const row of salesRows) {
    const entry = ensure(row.facility);
    entry.amount = Math.round((entry.amount + asNumber(row.amount)) * 100) / 100;
    entry.quantity_dispensed += asNumber(row.quantity_dispensed);
    if (row.profit != null) {
      entry.profit = Math.round((asNumber(entry.profit) + asNumber(row.profit)) * 100) / 100;
    }
  }
  for (const row of stockRows) {
    const entry = ensure(row.facility);
    entry.quantity += asNumber(row.quantity);
    entry.value = Math.round((entry.value + asNumber(row.value)) * 100) / 100;
  }
  for (const row of shortageRows) {
    const entry = ensure(row.facility);
    entry.shortage_count += asNumber(row.shortage_count);
  }
  for (const row of purchaseRows) {
    const entry = ensure(row.facility);
    entry.request_count += asNumber(row.request_count);
    entry.order_count += asNumber(row.order_count);
  }

  return Array.from(index.values()).sort(
    (left, right) => asNumber(right.amount) - asNumber(left.amount)
  );
};

const loadPurchaseRequestsByFacility = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const where = {
    deleted_at: null,
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  };
  if (!range.invalid && range.from && range.to) {
    where.requested_at = { gte: range.from, lte: range.to };
  }

  const requests = await prisma.purchase_request.findMany({
    where,
    select: {
      id: true,
      facility: { select: { name: true, human_friendly_id: true } },
      purchase_orders: {
        where: { deleted_at: null },
        select: { id: true },
      },
    },
  });

  const index = new Map();
  for (const request of requests) {
    const facility =
      normalizeString(request?.facility?.name) ||
      normalizeString(request?.facility?.human_friendly_id) ||
      scope.facility_label ||
      'Unassigned';
    if (!index.has(facility)) {
      index.set(facility, {
        facility,
        request_count: 0,
        order_count: 0,
      });
    }
    const entry = index.get(facility);
    entry.request_count += 1;
    entry.order_count += Array.isArray(request.purchase_orders)
      ? request.purchase_orders.length
      : 0;
  }

  return Array.from(index.values()).sort(
    (left, right) => asNumber(right.request_count) - asNumber(left.request_count)
  );
};

const runPharmacyProfitByBranchDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDrugConsumptionAnalytics(scope, {
    ...parameters,
    group_by: 'facility',
    include_profit: true,
  });
  const rows = analytics.rows || [];
  const profitTotal = Math.round(
    rows.reduce((sum, row) => sum + asNumber(row.profit), 0) * 100
  ) / 100;
  return {
    title: 'Pharmacy profit by branch',
    subtitle: analytics.subtitle
      ? `${analytics.subtitle} · Ledger: dispense retail margin (null buy → 0 in rollup)`
      : 'Dispense profit by patient facility (branch)',
    columns: ['facility', 'profit', 'amount'],
    rows,
    summary: {
      profit: profitTotal,
      amount: analytics.summary?.period_amount ?? analytics.summary?.amount ?? null,
      facility_count: rows.length,
    },
    breakdown: analytics.breakdown,
  };
};

const runPharmacyStockByBranchDataset = async (scope) => {
  const stockRows = await loadInventoryStockRows(scope);
  const rows = aggregateStockByFacility(stockRows);
  const quantity = rows.reduce((sum, row) => sum + asNumber(row.quantity), 0);
  const value =
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.value), 0) * 100) / 100;
  return {
    title: 'Pharmacy stock by branch',
    subtitle:
      'On-hand quantity and value (qty × buy_unit_price via drug_inventory_map) by facility',
    columns: ['facility', 'quantity', 'value'],
    rows,
    summary: { quantity, value, facility_count: rows.length },
  };
};

const runPharmacyPurchasesByBranchDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Pharmacy purchases by branch',
      subtitle: 'Invalid date range',
      columns: ['facility', 'request_count', 'order_count'],
      rows: [],
      summary: { request_count: 0, order_count: 0, facility_count: 0 },
    };
  }
  const rows = await loadPurchaseRequestsByFacility(scope, parameters);
  const request_count = rows.reduce((sum, row) => sum + asNumber(row.request_count), 0);
  const order_count = rows.reduce((sum, row) => sum + asNumber(row.order_count), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Pharmacy purchases by branch',
    subtitle: `${fromLabel} to ${toLabel} · purchase_request counts by facility (PO line value not modeled)`,
    columns: ['facility', 'request_count', 'order_count'],
    rows,
    summary: { request_count, order_count, facility_count: rows.length },
  };
};

const runPharmacyStockShortagesByBranchDataset = async (scope) => {
  const stockRows = await loadInventoryStockRows(scope);
  const rows = aggregateShortagesByFacility(stockRows);
  return {
    title: 'Pharmacy stock shortages by branch',
    subtitle:
      'LOW / CRITICAL / OUT_OF_STOCK classifiers (same thresholds as inventory_stock_risk) by facility',
    columns: [
      'facility',
      'shortage_count',
      'low_count',
      'critical_count',
      'out_of_stock_count',
      'quantity',
    ],
    rows,
    summary: {
      shortage_count: rows.reduce((sum, row) => sum + asNumber(row.shortage_count), 0),
      facility_count: rows.length,
    },
  };
};

const runPharmacyBestPerformingBranchDataset = async (scope, parameters = {}) => {
  const rankByRaw = normalizeString(
    parameters.rank_by || parameters.rankBy || 'amount'
  ).toLowerCase();
  const rankBy = rankByRaw === 'profit' ? 'profit' : 'amount';
  const analytics = await buildPharmacyDrugConsumptionAnalytics(scope, {
    ...parameters,
    group_by: 'facility',
  });
  const ranked = [...(analytics.rows || [])]
    .map((entry, index) => ({
      rank: index + 1,
      facility: entry.facility,
      amount: entry.amount,
      profit: entry.profit,
      quantity_dispensed: entry.quantity_dispensed,
    }))
    .sort((left, right) => asNumber(right[rankBy]) - asNumber(left[rankBy]))
    .map((entry, index) => ({ ...entry, rank: index + 1 }));

  return {
    title: 'Best-performing branch',
    subtitle: `Ranked by ${rankBy} (facility = branch)`,
    columns: ['rank', 'facility', 'amount', 'profit', 'quantity_dispensed'],
    rows: ranked,
    summary: {
      rank_by: rankBy,
      facility_count: ranked.length,
      top_facility: ranked[0]?.facility || null,
      top_amount: ranked[0]?.amount ?? null,
      top_profit: ranked[0]?.profit ?? null,
    },
  };
};

const runPharmacyBranchComparisonDataset = async (scope, parameters = {}) => {
  const [salesAnalytics, stockRows, purchaseRows] = await Promise.all([
    buildPharmacyDrugConsumptionAnalytics(scope, {
      ...parameters,
      group_by: 'facility',
    }),
    loadInventoryStockRows(scope),
    loadPurchaseRequestsByFacility(scope, parameters),
  ]);
  const stockByFacility = aggregateStockByFacility(stockRows);
  const shortageRows = aggregateShortagesByFacility(stockRows);
  const rows = mergeBranchComparisonRows({
    salesRows: salesAnalytics.rows || [],
    stockRows: stockByFacility,
    shortageRows,
    purchaseRows,
  });
  const amount =
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.amount), 0) * 100) / 100;
  const value =
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.value), 0) * 100) / 100;
  return {
    title: 'Branch comparison',
    subtitle: 'Side-by-side facility metrics (sales, profit, stock, shortages, purchases)',
    columns: [
      'facility',
      'amount',
      'profit',
      'quantity_dispensed',
      'quantity',
      'value',
      'shortage_count',
      'request_count',
      'order_count',
    ],
    rows,
    summary: {
      facility_count: rows.length,
      amount,
      value,
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
    },
  };
};

const runPharmacySalesByCustomerDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDrugConsumptionAnalytics(scope, {
    ...parameters,
    group_by: 'patient',
  });
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const rangeMs = (range) => Math.max(0, range.to.getTime() - range.from.getTime());

const resolveAgeBand = (dateOfBirth, asOf = new Date()) => {
  if (!dateOfBirth) return 'Unknown';
  const dob = dateOfBirth instanceof Date ? dateOfBirth : new Date(dateOfBirth);
  if (Number.isNaN(dob.getTime())) return 'Unknown';
  let age = asOf.getFullYear() - dob.getFullYear();
  const monthDiff = asOf.getMonth() - dob.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && asOf.getDate() < dob.getDate())) {
    age -= 1;
  }
  if (age < 0) return 'Unknown';
  if (age < 18) return 'Under 18';
  if (age < 35) return '18-34';
  if (age < 50) return '35-49';
  if (age < 65) return '50-64';
  return '65+';
};

const loadPharmacyOrderPatientsInRange = async (scope, from, to) => {
  const orders = await prisma.pharmacy_order.findMany({
    where: {
      ...buildPharmacyOrderScopeWhere(scope),
      ordered_at: { gte: from, lte: to },
      patient_id: { not: null },
    },
    select: {
      patient_id: true,
      ordered_at: true,
      patient: {
        select: {
          id: true,
          human_friendly_id: true,
          first_name: true,
          last_name: true,
          gender: true,
          date_of_birth: true,
        },
      },
    },
  });
  return orders;
};

/**
 * Distinct pharmacy customers (patient_id) with an order in range.
 */
const buildPharmacyCustomerCountAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['customer_count'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy number of customers',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { customer_count: 0 },
    };
  }

  const orders = await loadPharmacyOrderPatientsInRange(scope, range.from, range.to);
  const customer_count = new Set(orders.map((row) => row.patient_id).filter(Boolean)).size;
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy number of customers',
    subtitle: `${fromLabel} to ${toLabel} · distinct pharmacy_order.patient_id`,
    columns,
    rows: [{ customer_count }],
    summary: { customer_count },
  };
};

/**
 * New vs returning partition over pharmacy orders (disjoint).
 */
const buildPharmacyCustomersNewVsReturningAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['segment', 'customer_count'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy new vs returning customers',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { customer_count: 0, new_count: 0, returning_count: 0 },
    };
  }

  const inRangeOrders = await loadPharmacyOrderPatientsInRange(scope, range.from, range.to);
  const inRangeIds = [
    ...new Set(inRangeOrders.map((row) => row.patient_id).filter(Boolean)),
  ];

  let priorIds = new Set();
  if (inRangeIds.length > 0) {
    const priorOrders = await prisma.pharmacy_order.findMany({
      where: {
        ...buildPharmacyOrderScopeWhere(scope),
        patient_id: { in: inRangeIds },
        ordered_at: { lt: range.from },
      },
      select: { patient_id: true },
      distinct: ['patient_id'],
    });
    priorIds = new Set(priorOrders.map((row) => row.patient_id).filter(Boolean));
  }

  let new_count = 0;
  let returning_count = 0;
  inRangeIds.forEach((patientId) => {
    if (priorIds.has(patientId)) {
      returning_count += 1;
    } else {
      new_count += 1;
    }
  });

  const rows = [
    { segment: 'new', customer_count: new_count },
    { segment: 'returning', customer_count: returning_count },
  ];
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy new vs returning customers',
    subtitle: `${fromLabel} to ${toLabel} · new = first pharmacy order in range; returning = prior order before from`,
    columns,
    rows,
    summary: {
      customer_count: inRangeIds.length,
      new_count,
      returning_count,
    },
    breakdown: { segments: rows },
  };
};

/**
 * Line-level dispense history for pharmacy customers in period.
 */
const buildPharmacyPatientMedicationHistoryAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['patient', 'drug', 'quantity_dispensed', 'dispensed_at', 'amount'];
  const topLimit = Math.max(1, Math.min(2000, asNumber(parameters.top_n || parameters.limit) || 500));
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy patient medication history',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0, quantity_dispensed: 0, line_count: 0 },
    };
  }

  const logs = await prisma.dispense_log.findMany({
    where: {
      ...buildDispenseLogScopeWhere(scope),
      status: 'DISPENSED',
      dispensed_at: { gte: range.from, lte: range.to },
    },
    select: {
      dispensed_at: true,
      quantity_dispensed: true,
      pharmacy_order_item: {
        select: {
          drug_id: true,
          drug: {
            select: {
              id: true,
              human_friendly_id: true,
              name: true,
              unit_price: true,
            },
          },
          pharmacy_order: {
            select: {
              billing_snapshot: true,
              patient: {
                select: {
                  human_friendly_id: true,
                  first_name: true,
                  last_name: true,
                },
              },
            },
          },
        },
      },
    },
    orderBy: { dispensed_at: 'desc' },
    take: topLimit,
  });

  const rows = [];
  let amountTotal = 0;
  let qtyTotal = 0;
  logs.forEach((log) => {
    const qty = asNumber(log.quantity_dispensed);
    if (qty <= 0) return;
    const unitPrice = resolveDispenseUnitPrice(log);
    const amount = Math.round(unitPrice * qty * 100) / 100;
    amountTotal += amount;
    qtyTotal += qty;
    rows.push({
      patient: resolvePatientLabel(log?.pharmacy_order_item?.pharmacy_order?.patient),
      drug:
        normalizeString(log?.pharmacy_order_item?.drug?.name) ||
        normalizeString(log?.pharmacy_order_item?.drug_id) ||
        'Unknown',
      quantity_dispensed: qty,
      dispensed_at: log.dispensed_at
        ? new Date(log.dispensed_at).toISOString()
        : null,
      amount,
    });
  });

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy patient medication history',
    subtitle: `${fromLabel} to ${toLabel} · up to ${rows.length} dispense lines`,
    columns,
    rows,
    summary: {
      amount: Math.round(amountTotal * 100) / 100,
      quantity_dispensed: qtyTotal,
      line_count: rows.length,
    },
  };
};

const loadOpenPharmacyInvoices = async (scope) => {
  const invoices = await prisma.invoice.findMany({
    where: {
      ...buildPharmacyBillingScopeWhere(scope),
      status: { in: [...OPEN_PHARMACY_INVOICE_STATUSES] },
      patient_id: { not: null },
    },
    select: {
      id: true,
      issued_at: true,
      total_amount: true,
      currency: true,
      status: true,
      patient: {
        select: {
          human_friendly_id: true,
          first_name: true,
          last_name: true,
        },
      },
      payments: {
        where: { deleted_at: null },
        select: {
          amount: true,
          status: true,
          deleted_at: true,
          refunds: {
            where: { deleted_at: null },
            select: { amount: true, deleted_at: true },
          },
        },
      },
      billing_adjustments: {
        where: { deleted_at: null },
        select: { amount: true, status: true, deleted_at: true },
      },
    },
  });

  return invoices
    .map((invoice) => {
      const financials = computeInvoiceFinancials(invoice);
      const balanceDue = Math.max(0, toDecimalNumber(financials.balance_due));
      return {
        invoice,
        balance_due: balanceDue,
        patient: resolvePatientLabel(invoice.patient),
        issued_at: invoice.issued_at
          ? new Date(invoice.issued_at).toISOString()
          : null,
        currency: normalizeString(invoice.currency) || 'UGX',
      };
    })
    .filter((entry) => entry.balance_due > 0.009);
};

/**
 * Open pharmacy invoice balances aggregated per patient (customer credit).
 */
const buildPharmacyCustomerCreditBalanceAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['patient', 'credit_balance'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy customer credit balance',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { credit_balance: 0, customer_count: 0 },
    };
  }

  const openRows = await loadOpenPharmacyInvoices(scope);
  // Credit is a point-in-time ledger; optional issued_at filter keeps aging scoped.
  const filtered = openRows.filter((entry) => {
    if (!entry.invoice?.issued_at) return true;
    const issued = new Date(entry.invoice.issued_at);
    return issued.getTime() >= range.from.getTime() && issued.getTime() <= range.to.getTime();
  });

  const byPatient = new Map();
  filtered.forEach((entry) => {
    const key = entry.patient;
    byPatient.set(key, Math.round((asNumber(byPatient.get(key)) + entry.balance_due) * 100) / 100);
  });

  const rows = Array.from(byPatient.entries())
    .map(([patient, credit_balance]) => ({ patient, credit_balance }))
    .sort((left, right) => right.credit_balance - left.credit_balance);

  const credit_balance =
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.credit_balance), 0) * 100) / 100;
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy customer credit balance',
    subtitle: `${fromLabel} to ${toLabel} · open statuses ${OPEN_PHARMACY_INVOICE_STATUSES.join('|')} · pharmacy invoices`,
    columns,
    rows,
    summary: {
      credit_balance,
      customer_count: rows.length,
    },
  };
};

/**
 * Open pharmacy invoices aged (outstanding payments).
 */
const buildPharmacyCustomerOutstandingAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['patient', 'amount', 'issued_at'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy outstanding payments',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0, invoice_count: 0 },
    };
  }

  const openRows = await loadOpenPharmacyInvoices(scope);
  const rows = openRows
    .filter((entry) => {
      if (!entry.invoice?.issued_at) return true;
      const issued = new Date(entry.invoice.issued_at);
      return issued.getTime() >= range.from.getTime() && issued.getTime() <= range.to.getTime();
    })
    .map((entry) => ({
      patient: entry.patient,
      amount: Math.round(entry.balance_due * 100) / 100,
      issued_at: entry.issued_at,
    }))
    .sort((left, right) => String(left.issued_at || '').localeCompare(String(right.issued_at || '')));

  const amount =
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.amount), 0) * 100) / 100;
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy outstanding payments',
    subtitle: `${fromLabel} to ${toLabel} · open pharmacy invoices with balance_due > 0`,
    columns,
    rows,
    summary: {
      amount,
      invoice_count: rows.length,
    },
  };
};

/**
 * Aggregate gender / age-band counts for pharmacy customers in range (no PHI rows).
 */
const buildPharmacyCustomerDemographicsAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['dimension', 'bucket', 'customer_count'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy customer demographics',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { customer_count: 0 },
    };
  }

  const orders = await loadPharmacyOrderPatientsInRange(scope, range.from, range.to);
  const patientIndex = new Map();
  orders.forEach((order) => {
    if (!order.patient_id || !order.patient) return;
    if (!patientIndex.has(order.patient_id)) {
      patientIndex.set(order.patient_id, order.patient);
    }
  });

  const genderIndex = new Map();
  const ageIndex = new Map();
  patientIndex.forEach((patient) => {
    const gender = normalizeString(patient.gender).toUpperCase() || 'UNKNOWN';
    genderIndex.set(gender, asNumber(genderIndex.get(gender)) + 1);
    const ageBand = resolveAgeBand(patient.date_of_birth, range.to);
    ageIndex.set(ageBand, asNumber(ageIndex.get(ageBand)) + 1);
  });

  const rows = [
    ...Array.from(genderIndex.entries()).map(([bucket, customer_count]) => ({
      dimension: 'gender',
      bucket,
      customer_count,
    })),
    ...Array.from(ageIndex.entries()).map(([bucket, customer_count]) => ({
      dimension: 'age_band',
      bucket,
      customer_count,
    })),
  ].sort((left, right) => {
    const dim = String(left.dimension).localeCompare(String(right.dimension));
    if (dim !== 0) return dim;
    return asNumber(right.customer_count) - asNumber(left.customer_count);
  });

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy customer demographics',
    subtitle: `${fromLabel} to ${toLabel} · gender and age_band aggregates only`,
    columns,
    rows,
    summary: { customer_count: patientIndex.size },
  };
};

/**
 * Retention = prior-window purchasers who also purchase in current window.
 * Prior window is equal length immediately before `from`.
 */
const buildPharmacyCustomerRetentionAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['segment', 'customer_count', 'retention_rate'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy customer retention',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { retention_rate: null, customer_count: 0 },
    };
  }

  const durationMs = rangeMs(range);
  const priorTo = new Date(range.from.getTime() - 1);
  const priorFrom = new Date(range.from.getTime() - durationMs);

  const [priorOrders, currentOrders] = await Promise.all([
    loadPharmacyOrderPatientsInRange(scope, priorFrom, priorTo),
    loadPharmacyOrderPatientsInRange(scope, range.from, range.to),
  ]);

  const priorIds = new Set(priorOrders.map((row) => row.patient_id).filter(Boolean));
  const currentIds = new Set(currentOrders.map((row) => row.patient_id).filter(Boolean));
  let retained = 0;
  priorIds.forEach((id) => {
    if (currentIds.has(id)) retained += 1;
  });

  const prior_count = priorIds.size;
  const current_count = currentIds.size;
  const retention_rate =
    prior_count > 0 ? Math.round((retained / prior_count) * 10000) / 10000 : null;

  const rows = [
    { segment: 'prior_purchasers', customer_count: prior_count, retention_rate: null },
    { segment: 'retained', customer_count: retained, retention_rate },
    { segment: 'current_purchasers', customer_count: current_count, retention_rate: null },
  ];

  const priorFromLabel = priorFrom.toISOString().slice(0, 10);
  const priorToLabel = priorTo.toISOString().slice(0, 10);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy customer retention',
    subtitle: `Prior ${priorFromLabel}–${priorToLabel} (equal length) → current ${fromLabel}–${toLabel}`,
    columns,
    rows,
    summary: {
      retention_rate,
      customer_count: retained,
      prior_count,
      current_count,
    },
  };
};

const runPharmacyCustomerCountDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyCustomerCountAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyCustomersNewVsReturningDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyCustomersNewVsReturningAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const runPharmacyPatientMedicationHistoryDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyPatientMedicationHistoryAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyCustomerCreditBalanceDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyCustomerCreditBalanceAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyCustomerOutstandingDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyCustomerOutstandingAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyCustomerDemographicsDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyCustomerDemographicsAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyCustomerRetentionDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyCustomerRetentionAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const buildPharmacyBillingScopeWhere = (scope = {}) => ({
  deleted_at: null,
  billing_entity: 'PHARMACY',
  tenant_id: scope.tenant_id,
  ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
});

const sumPeriodAmount = (dailyTotals = []) =>
  Math.round(
    dailyTotals.reduce((sum, row) => sum + asNumber(row.amount), 0) * 100
  ) / 100;

/**
 * Pharmacy-scoped payment method totals (payment.method, billing_entity=PHARMACY).
 */
const buildPharmacySalesPaymentMethodAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['method', 'amount'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy sales by payment method',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0 },
    };
  }

  const payments = await prisma.payment.findMany({
    where: {
      ...buildPharmacyBillingScopeWhere(scope),
      status: { in: Array.from(COUNTED_PAYMENT_STATUSES) },
      paid_at: { gte: range.from, lte: range.to },
    },
    select: {
      method: true,
      amount: true,
    },
  });

  const methodIndex = new Map();
  payments.forEach((payment) => {
    const method = normalizeString(payment.method) || 'UNKNOWN';
    methodIndex.set(method, asNumber(methodIndex.get(method)) + asNumber(payment.amount));
  });

  const rows = Array.from(methodIndex.entries())
    .map(([method, amount]) => ({
      method,
      amount: Math.round(asNumber(amount) * 100) / 100,
    }))
    .sort((left, right) => right.amount - left.amount);

  const amount = Math.round(rows.reduce((sum, row) => sum + asNumber(row.amount), 0) * 100) / 100;
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy sales by payment method',
    subtitle: `${fromLabel} to ${toLabel} (pharmacy-scoped payments)`,
    columns,
    rows,
    summary: { amount },
  };
};

/**
 * Pharmacy-scoped discounts: applied negative billing_adjustment on pharmacy invoices.
 */
const buildPharmacySalesDiscountsAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['date', 'amount', 'reason'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy discounts',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0 },
    };
  }

  const adjustments = await prisma.billing_adjustment.findMany({
    where: {
      deleted_at: null,
      adjusted_at: { gte: range.from, lte: range.to },
      status: { in: Array.from(APPLIED_ADJUSTMENT_STATUSES) },
      amount: { lt: 0 },
      invoice: buildPharmacyBillingScopeWhere(scope),
    },
    select: {
      adjusted_at: true,
      amount: true,
      reason: true,
    },
    orderBy: { adjusted_at: 'asc' },
  });

  const rows = adjustments.map((entry) => ({
    date: entry.adjusted_at ? new Date(entry.adjusted_at).toISOString().slice(0, 10) : null,
    amount: Math.round(Math.abs(asNumber(entry.amount)) * 100) / 100,
    reason: normalizeString(entry.reason) || null,
  }));
  const amount = Math.round(rows.reduce((sum, row) => sum + asNumber(row.amount), 0) * 100) / 100;
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy discounts',
    subtitle: `${fromLabel} to ${toLabel} (negative applied adjustments)`,
    columns,
    rows,
    summary: { amount },
  };
};

/**
 * Pharmacy refund money + dispense return counts (not conflated).
 */
const buildPharmacySalesRefundsAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['date', 'amount', 'returns'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy refunds and returns',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0, returns: 0 },
    };
  }

  const monthly = shouldUseMonthlyGranularity(range);
  const [refunds, returns] = await Promise.all([
    prisma.refund.findMany({
      where: {
        deleted_at: null,
        refunded_at: { gte: range.from, lte: range.to },
        payment: buildPharmacyBillingScopeWhere(scope),
      },
      select: {
        refunded_at: true,
        amount: true,
      },
    }),
    prisma.dispense_log.findMany({
      where: {
        ...buildDispenseLogScopeWhere(scope),
        status: 'RETURNED',
        updated_at: { gte: range.from, lte: range.to },
      },
      select: {
        updated_at: true,
      },
    }),
  ]);

  const refundBuckets = aggregateByPeriod(
    refunds,
    'refunded_at',
    { amount: (row) => asNumber(row.amount) },
    { monthly }
  );
  const returnBuckets = aggregateByPeriod(
    returns,
    'updated_at',
    { returns: () => 1 },
    { monthly }
  );

  const index = new Map();
  [...refundBuckets, ...returnBuckets].forEach((entry) => {
    if (!entry?.date) return;
    if (!index.has(entry.date)) {
      index.set(entry.date, { date: entry.date, amount: 0, returns: 0 });
    }
    const target = index.get(entry.date);
    target.amount = Math.round((asNumber(target.amount) + asNumber(entry.amount)) * 100) / 100;
    target.returns += asNumber(entry.returns);
  });

  const rows = Array.from(index.values()).sort((left, right) =>
    String(left.date).localeCompare(String(right.date))
  );
  const summary = rows.reduce(
    (acc, row) => {
      acc.amount += asNumber(row.amount);
      acc.returns += asNumber(row.returns);
      return acc;
    },
    { amount: 0, returns: 0 }
  );
  summary.amount = Math.round(summary.amount * 100) / 100;

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy refunds and returns',
    subtitle: `${fromLabel} to ${toLabel} (refund $ vs return count)`,
    columns,
    rows,
    summary,
  };
};

/**
 * Net revenue = gross dispense revenue − pharmacy refunds − pharmacy discounts.
 */
const buildPharmacySalesNetRevenueAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['metric', 'amount'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy net revenue',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { amount: 0, gross_revenue: 0, refunds: 0, discounts: 0, net_revenue: 0 },
    };
  }

  const [consumption, refunds, discounts] = await Promise.all([
    buildPharmacyDrugConsumptionAnalytics(scope, parameters),
    buildPharmacySalesRefundsAnalytics(scope, parameters),
    buildPharmacySalesDiscountsAnalytics(scope, parameters),
  ]);

  const gross_revenue = sumPeriodAmount(consumption?.breakdown?.daily_totals || []);
  const refundAmount = asNumber(refunds?.summary?.amount);
  const discountAmount = asNumber(discounts?.summary?.amount);
  const net_revenue = Math.round((gross_revenue - refundAmount - discountAmount) * 100) / 100;

  const rows = [
    { metric: 'gross_revenue', amount: gross_revenue },
    { metric: 'refunds', amount: refundAmount },
    { metric: 'discounts', amount: discountAmount },
    { metric: 'net_revenue', amount: net_revenue },
  ];

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy net revenue',
    subtitle: `${fromLabel} to ${toLabel} · Net = gross − refunds − discounts`,
    columns,
    rows,
    summary: {
      amount: net_revenue,
      gross_revenue,
      refunds: refundAmount,
      discounts: discountAmount,
      net_revenue,
    },
  };
};

/**
 * Average transaction value = period gross dispense amount / orders_created.
 */
const buildPharmacySalesAvgTransactionAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['average_transaction_value', 'orders_created', 'amount'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy average transaction value',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { average_transaction_value: null, orders_created: 0, amount: 0 },
    };
  }

  const [consumption, throughput] = await Promise.all([
    buildPharmacyDrugConsumptionAnalytics(scope, parameters),
    buildPharmacyDispenseThroughputAnalytics(scope, parameters),
  ]);

  const amount = sumPeriodAmount(consumption?.breakdown?.daily_totals || []);
  const orders_created = asNumber(throughput?.summary?.orders_created);
  const average_transaction_value =
    orders_created > 0 ? Math.round((amount / orders_created) * 100) / 100 : null;

  const rows = [
    {
      average_transaction_value,
      orders_created,
      amount,
    },
  ];

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy average transaction value',
    subtitle: `${fromLabel} to ${toLabel} · amount / orders_created`,
    columns,
    rows,
    summary: {
      average_transaction_value,
      orders_created,
      amount,
    },
  };
};

const runPharmacySalesPaymentMethodDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacySalesPaymentMethodAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacySalesDiscountsDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacySalesDiscountsAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacySalesRefundsDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacySalesRefundsAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacySalesNetRevenueDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacySalesNetRevenueAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacySalesAvgTransactionDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacySalesAvgTransactionAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

/**
 * Pharmacy-scoped billing financials (billing_entity=PHARMACY).
 * Same formulas as buildBillingFinancialAnalytics; never mix with dispense profit_proxy labeling.
 */
const buildPharmacyBillingFinancialAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = [
    'date',
    'collections',
    'expenditures',
    'profit_proxy',
    'refunds',
    'write_offs',
    'net_collections',
    'issued_invoices',
    'open_invoices',
  ];
  if (range.invalid) {
    return {
      invalid: true,
      reason: range.reason || 'invalid_range',
      title: 'Pharmacy billing collections and cash',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: summarizeBillingSeries([]),
      breakdown: { refunds: 0, write_offs: 0 },
    };
  }

  const monthly = shouldUseMonthlyGranularity(range);
  const billingWhere = buildPharmacyBillingScopeWhere(scope);

  const [payments, refunds, adjustments, invoices] = await Promise.all([
    prisma.payment.findMany({
      where: {
        ...billingWhere,
        status: { in: Array.from(COUNTED_PAYMENT_STATUSES) },
        paid_at: { gte: range.from, lte: range.to },
      },
      select: {
        paid_at: true,
        amount: true,
        method: true,
      },
    }),
    prisma.refund.findMany({
      where: {
        deleted_at: null,
        refunded_at: { gte: range.from, lte: range.to },
        payment: billingWhere,
      },
      select: {
        refunded_at: true,
        amount: true,
      },
    }),
    prisma.billing_adjustment.findMany({
      where: {
        deleted_at: null,
        adjusted_at: { gte: range.from, lte: range.to },
        status: { in: Array.from(APPLIED_ADJUSTMENT_STATUSES) },
        amount: { lt: 0 },
        invoice: billingWhere,
      },
      select: {
        adjusted_at: true,
        amount: true,
      },
    }),
    prisma.invoice.findMany({
      where: {
        ...billingWhere,
        issued_at: { gte: range.from, lte: range.to },
      },
      select: {
        issued_at: true,
        status: true,
      },
    }),
  ]);

  const paymentBuckets = aggregateByPeriod(
    payments,
    'paid_at',
    { collections: (row) => asNumber(row.amount) },
    { monthly }
  );
  const refundBuckets = aggregateByPeriod(
    refunds,
    'refunded_at',
    { refunds: (row) => asNumber(row.amount) },
    { monthly }
  );
  const writeOffBuckets = aggregateByPeriod(
    adjustments,
    'adjusted_at',
    { write_offs: (row) => Math.abs(asNumber(row.amount)) },
    { monthly }
  );
  const invoiceBuckets = aggregateByPeriod(
    invoices,
    'issued_at',
    {
      issued_invoices: () => 1,
      open_invoices: (row) =>
        OPEN_PHARMACY_INVOICE_STATUSES.includes(String(row.status || '').toUpperCase())
          ? 1
          : 0,
    },
    { monthly }
  );

  const rows = mergeBillingBuckets([
    ...paymentBuckets,
    ...refundBuckets,
    ...writeOffBuckets,
    ...invoiceBuckets,
  ]);
  const summary = summarizeBillingSeries(rows);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    reason: null,
    preset: range.preset,
    from: range.from,
    to: range.to,
    granularity: monthly ? 'month' : 'day',
    title: 'Pharmacy billing collections and cash',
    subtitle: `${fromLabel} to ${toLabel} · Ledger: pharmacy-scoped billing (not dispense margin)`,
    columns,
    rows,
    summary,
    breakdown: {
      refunds: summary.refunds,
      write_offs: summary.write_offs,
    },
  };
};

/**
 * Revenue chart: dispense retail amount series (consumption ledger).
 */
const buildPharmacyFinancialRevenueAnalytics = async (scope, parameters = {}) => {
  const consumption = await buildPharmacyDrugConsumptionAnalytics(scope, parameters);
  const daily = consumption?.breakdown?.daily_totals || [];
  const rows = daily.map((entry) => ({
    date: entry.date,
    amount: asNumber(entry.amount),
  }));
  const amount =
    asNumber(consumption?.summary?.period_amount) ||
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.amount), 0) * 100) / 100;

  return {
    invalid: Boolean(consumption?.invalid),
    title: 'Pharmacy revenue',
    subtitle: consumption?.invalid
      ? 'Invalid date range'
      : `${consumption.subtitle} · Ledger: dispense retail amount (consumption)`,
    columns: ['date', 'amount'],
    rows,
    summary: { amount },
    breakdown: consumption?.breakdown || null,
  };
};

/**
 * COGS = Σ buy_unit_price × quantity_dispensed (0 when buy unset).
 */
const buildPharmacyFinancialCogsAnalytics = async (scope, parameters = {}) => {
  const consumption = await buildPharmacyDrugConsumptionAnalytics(scope, parameters);
  const daily = consumption?.breakdown?.daily_totals || [];
  const rows = daily.map((entry) => ({
    date: entry.date,
    cogs: asNumber(entry.cogs),
  }));
  const cogs =
    asNumber(consumption?.summary?.period_cogs) ||
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.cogs), 0) * 100) / 100;

  return {
    invalid: Boolean(consumption?.invalid),
    title: 'Pharmacy cost of goods sold',
    subtitle: consumption?.invalid
      ? 'Invalid date range'
      : `${consumption.subtitle} · Ledger: Σ buy_unit_price × qty (unset buy → 0)`,
    columns: ['date', 'cogs'],
    rows,
    summary: { cogs, amount: cogs },
    breakdown: consumption?.breakdown || null,
  };
};

/**
 * Gross profit = consumption retail margin (null buy treated as 0 in rollup).
 */
const buildPharmacyFinancialGrossProfitAnalytics = async (scope, parameters = {}) => {
  const consumption = await buildPharmacyDrugConsumptionAnalytics(scope, parameters);
  const daily = consumption?.breakdown?.daily_totals || [];
  const rows = daily.map((entry) => ({
    date: entry.date,
    profit: asNumber(entry.profit),
    amount: asNumber(entry.amount),
  }));
  const profit =
    asNumber(consumption?.summary?.period_profit) ||
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.profit), 0) * 100) / 100;
  const amount =
    asNumber(consumption?.summary?.period_amount) ||
    Math.round(rows.reduce((sum, row) => sum + asNumber(row.amount), 0) * 100) / 100;

  return {
    invalid: Boolean(consumption?.invalid),
    title: 'Pharmacy gross profit',
    subtitle: consumption?.invalid
      ? 'Invalid date range'
      : `${consumption.subtitle} · Ledger: dispense retail margin (null buy → 0; not billing profit_proxy)`,
    columns: ['date', 'profit', 'amount'],
    rows,
    summary: { profit, amount },
    breakdown: consumption?.breakdown || null,
  };
};

/**
 * Net profit = gross_profit − pharmacy refunds − pharmacy write_offs.
 */
const buildPharmacyFinancialNetProfitAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['metric', 'amount'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Pharmacy net profit',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: {
        amount: 0,
        gross_profit: 0,
        refunds: 0,
        write_offs: 0,
        net_profit: 0,
      },
    };
  }

  const [gross, billing] = await Promise.all([
    buildPharmacyFinancialGrossProfitAnalytics(scope, parameters),
    buildPharmacyBillingFinancialAnalytics(scope, parameters),
  ]);

  const gross_profit = asNumber(gross?.summary?.profit);
  const refunds = asNumber(billing?.summary?.refunds);
  const write_offs = asNumber(billing?.summary?.write_offs);
  const net_profit = Math.round((gross_profit - refunds - write_offs) * 100) / 100;

  const rows = [
    { metric: 'gross_profit', amount: gross_profit },
    { metric: 'refunds', amount: refunds },
    { metric: 'write_offs', amount: write_offs },
    { metric: 'net_profit', amount: net_profit },
  ];
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Pharmacy net profit',
    subtitle: `${fromLabel} to ${toLabel} · Net = gross_profit − refunds − write_offs (dispense margin − pharmacy billing)`,
    columns,
    rows,
    summary: {
      amount: net_profit,
      gross_profit,
      refunds,
      write_offs,
      net_profit,
    },
  };
};

/**
 * Operating expenses from pharmacy billing expenditures (refunds + write_offs).
 */
const buildPharmacyFinancialOperatingExpensesAnalytics = async (scope, parameters = {}) => {
  const billing = await buildPharmacyBillingFinancialAnalytics(scope, parameters);
  const rows = (billing.rows || []).map((entry) => ({
    date: entry.date,
    expenditures: asNumber(entry.expenditures),
  }));
  const expenditures = asNumber(billing?.summary?.expenditures);

  return {
    invalid: Boolean(billing?.invalid),
    title: 'Pharmacy operating expenses',
    subtitle: billing?.invalid
      ? 'Invalid date range'
      : `${billing.subtitle} · expenditures = refunds + write_offs (billing runner; not general OpEx)`,
    columns: ['date', 'expenditures'],
    rows,
    summary: { expenditures, amount: expenditures },
  };
};

/**
 * Customer receivables: open pharmacy invoice balance_due totals.
 */
const buildPharmacyFinancialReceivablesAnalytics = async (scope, parameters = {}) => {
  const outstanding = await buildPharmacyCustomerOutstandingAnalytics(scope, parameters);
  return {
    ...outstanding,
    title: 'Pharmacy customer receivables',
    subtitle: outstanding.invalid
      ? outstanding.subtitle
      : `${outstanding.subtitle} · Ledger: open pharmacy invoice balance_due`,
  };
};

/**
 * Cash flow / daily cash: pharmacy-scoped billing net_collections series.
 */
const buildPharmacyFinancialCashFlowAnalytics = async (scope, parameters = {}) => {
  const billing = await buildPharmacyBillingFinancialAnalytics(scope, parameters);
  const rows = (billing.rows || []).map((entry) => ({
    date: entry.date,
    collections: asNumber(entry.collections),
    refunds: asNumber(entry.refunds),
    net_collections: asNumber(entry.net_collections),
  }));

  return {
    invalid: Boolean(billing?.invalid),
    title: 'Pharmacy cash flow',
    subtitle: billing?.invalid
      ? 'Invalid date range'
      : `${billing.subtitle} · series: net_collections (= collections − refunds − write_offs path)`,
    columns: ['date', 'collections', 'refunds', 'net_collections'],
    rows,
    summary: {
      collections: asNumber(billing?.summary?.collections),
      refunds: asNumber(billing?.summary?.refunds),
      net_collections: asNumber(billing?.summary?.net_collections),
      amount: asNumber(billing?.summary?.net_collections),
    },
  };
};

const buildPharmacyFinancialProfitByCategoryAnalytics = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDrugConsumptionAnalytics(scope, {
    ...parameters,
    group_by: 'category',
    include_profit: true,
  });
  return {
    invalid: Boolean(analytics?.invalid),
    title: analytics.title || 'Pharmacy profit by product/category',
    subtitle: analytics.invalid
      ? 'Invalid date range'
      : `${analytics.subtitle} · Ledger: dispense retail margin by inventory_item.category`,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: {
      profit: asNumber(analytics?.summary?.period_profit ?? analytics?.summary?.profit),
      amount: asNumber(analytics?.summary?.period_amount ?? analytics?.summary?.amount),
    },
    breakdown: analytics.breakdown,
  };
};

const buildPharmacyFinancialProfitByPeriodAnalytics = async (scope, parameters = {}) => {
  const gross = await buildPharmacyFinancialGrossProfitAnalytics(scope, parameters);
  return {
    ...gross,
    title: 'Pharmacy profit by period',
    subtitle: gross.invalid
      ? 'Invalid date range'
      : String(gross.subtitle || '').replace(
          'Pharmacy gross profit',
          'Profit by period'
        ),
  };
};

const runPharmacyFinancialRevenueDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialRevenueAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const runPharmacyFinancialCogsDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialCogsAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const runPharmacyFinancialGrossProfitDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialGrossProfitAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const runPharmacyFinancialNetProfitDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialNetProfitAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyFinancialOperatingExpensesDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialOperatingExpensesAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyFinancialReceivablesDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialReceivablesAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyFinancialCashFlowDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialCashFlowAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyFinancialProfitByCategoryDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialProfitByCategoryAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

const runPharmacyFinancialProfitByPeriodDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyFinancialProfitByPeriodAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
  };
};

/**
 * Pack qty dispensed grouped by encounter.provider (clinical orders only).
 * Walk-in / unlinked orders are omitted — do not invent a prescriber.
 */
const buildPharmacyDispensingByPrescriberAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['prescriber', 'quantity_dispensed'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Medicines dispensed by prescriber',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { quantity_dispensed: 0, prescriber_count: 0 },
    };
  }

  const logs = await prisma.dispense_log.findMany({
    where: {
      ...buildDispenseLogScopeWhere(scope),
      status: 'DISPENSED',
      dispensed_at: { gte: range.from, lte: range.to },
    },
    select: {
      quantity_dispensed: true,
      pharmacy_order_item: {
        select: {
          pharmacy_order: {
            select: {
              encounter: {
                select: {
                  provider: {
                    select: {
                      human_friendly_id: true,
                      email: true,
                      profile: {
                        select: {
                          first_name: true,
                          last_name: true,
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  });

  const index = new Map();
  logs.forEach((log) => {
    const qty = asNumber(log.quantity_dispensed);
    if (qty <= 0) return;
    const label = resolvePrescriberLabel(
      log?.pharmacy_order_item?.pharmacy_order?.encounter?.provider
    );
    if (!label) return;
    if (!index.has(label)) {
      index.set(label, { prescriber: label, quantity_dispensed: 0 });
    }
    index.get(label).quantity_dispensed += qty;
  });

  const rows = Array.from(index.values()).sort(
    (left, right) => asNumber(right.quantity_dispensed) - asNumber(left.quantity_dispensed)
  );
  const quantity_dispensed = rows.reduce(
    (sum, row) => sum + asNumber(row.quantity_dispensed),
    0
  );
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Medicines dispensed by prescriber',
    subtitle: `${fromLabel} to ${toLabel} · pack qty via encounter.provider (linked clinical orders only)`,
    columns,
    rows,
    summary: {
      quantity_dispensed,
      prescriber_count: rows.length,
    },
  };
};

/**
 * PARTIALLY_DISPENSED orders with remaining pack qty (ordered − DISPENSED logs).
 */
const buildPharmacyDispensingPartialAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['status', 'orders_created', 'remaining_quantity'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Partial dispensing',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { orders_created: 0, remaining_quantity: 0 },
    };
  }

  const orders = await prisma.pharmacy_order.findMany({
    where: {
      ...buildPharmacyOrderScopeWhere(scope),
      status: 'PARTIALLY_DISPENSED',
      ordered_at: { gte: range.from, lte: range.to },
    },
    select: {
      items: {
        where: { deleted_at: null },
        select: {
          quantity: true,
          dispense_logs: {
            where: { deleted_at: null, status: 'DISPENSED' },
            select: { quantity_dispensed: true },
          },
        },
      },
    },
  });

  const remaining_quantity = orders.reduce(
    (sum, order) =>
      sum +
      (Array.isArray(order.items) ? order.items : []).reduce(
        (itemSum, item) => itemSum + remainingItemQuantity(item),
        0
      ),
    0
  );
  const orders_created = orders.length;
  const rows = [
    {
      status: 'PARTIALLY_DISPENSED',
      orders_created,
      remaining_quantity,
    },
  ];
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Partial dispensing',
    subtitle: `${fromLabel} to ${toLabel} · remaining = ordered qty − DISPENSED pack qty`,
    columns,
    rows,
    summary: { orders_created, remaining_quantity },
  };
};

/**
 * Prescription frequency = pharmacy_order count per patient in range.
 */
const buildPharmacyDispensingFrequencyAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['patient', 'orders_created'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Prescription frequency',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: { orders_created: 0, patient_count: 0 },
    };
  }

  const orders = await prisma.pharmacy_order.findMany({
    where: {
      ...buildPharmacyOrderScopeWhere(scope),
      ordered_at: { gte: range.from, lte: range.to },
    },
    select: {
      patient: {
        select: {
          human_friendly_id: true,
          first_name: true,
          last_name: true,
        },
      },
    },
  });

  const index = new Map();
  orders.forEach((order) => {
    const label = resolvePatientLabel(order.patient);
    if (!index.has(label)) {
      index.set(label, { patient: label, orders_created: 0 });
    }
    index.get(label).orders_created += 1;
  });

  const rows = Array.from(index.values()).sort(
    (left, right) => asNumber(right.orders_created) - asNumber(left.orders_created)
  );
  const orders_created = rows.reduce((sum, row) => sum + asNumber(row.orders_created), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Prescription frequency',
    subtitle: `${fromLabel} to ${toLabel} · orders per patient`,
    columns,
    rows,
    summary: {
      orders_created,
      patient_count: rows.length,
    },
  };
};

/**
 * Average items per prescription = pharmacy_order_item count / pharmacy_order count.
 */
const buildPharmacyDispensingAvgItemsAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['average_items_per_prescription', 'item_count', 'orders_created'];
  if (range.invalid) {
    return {
      invalid: true,
      title: 'Average items per prescription',
      subtitle: 'Invalid date range',
      columns,
      rows: [],
      summary: {
        average_items_per_prescription: null,
        item_count: 0,
        orders_created: 0,
      },
    };
  }

  const orderWhere = {
    ...buildPharmacyOrderScopeWhere(scope),
    ordered_at: { gte: range.from, lte: range.to },
  };
  const [orders_created, item_count] = await Promise.all([
    prisma.pharmacy_order.count({ where: orderWhere }),
    prisma.pharmacy_order_item.count({
      where: {
        deleted_at: null,
        pharmacy_order: orderWhere,
      },
    }),
  ]);
  const average_items_per_prescription = computeAverageItemsPerPrescription(
    item_count,
    orders_created
  );
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Average items per prescription',
    subtitle: `${fromLabel} to ${toLabel} · item_count / orders_created`,
    columns,
    rows: [
      {
        average_items_per_prescription,
        item_count,
        orders_created,
      },
    ],
    summary: {
      average_items_per_prescription,
      item_count,
      orders_created,
    },
  };
};

const runPharmacyDispensingByPrescriberDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDispensingByPrescriberAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyDispensingPartialDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDispensingPartialAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyDispensingFrequencyDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDispensingFrequencyAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const runPharmacyDispensingAvgItemsDataset = async (scope, parameters = {}) => {
  const analytics = await buildPharmacyDispensingAvgItemsAnalytics(scope, parameters);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const claimBucket = (submittedAt) => {
  const diffDays = Math.floor((Date.now() - new Date(submittedAt).getTime()) / (24 * 60 * 60 * 1000));
  if (diffDays <= 7) return '0-7 days';
  if (diffDays <= 14) return '8-14 days';
  if (diffDays <= 30) return '15-30 days';
  return '31+ days';
};

const runInsuranceClaimsDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const claims = await prisma.insurance_claim.findMany({
    where: {
      deleted_at: null,
      submitted_at: { gte: range.from, lte: range.to },
      invoice: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
    },
    select: {
      submitted_at: true,
      status: true,
    },
  });

  const index = new Map();
  claims.forEach((claim) => {
    const bucket = claimBucket(claim.submitted_at);
    const key = `${bucket}:${claim.status}`;
    if (!index.has(key)) {
      index.set(key, { bucket, status: claim.status, claims: 0 });
    }
    index.get(key).claims += 1;
  });

  return {
    title: 'Insurance claims aging',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)}`,
    columns: ['bucket', 'status', 'claims'],
    rows: Array.from(index.values()),
  };
};

/**
 * Stock risk classifier (do not diverge from pharmacy reporting index rule 3).
 * qty≤0 OUT_OF_STOCK; qty≤floor(reorder/2) CRITICAL; qty≤reorder LOW;
 * qty≥reorder×3 OVERSTOCK; else OK.
 */
const classifyStockRisk = (quantity, reorderLevel) => {
  const qty = asNumber(quantity);
  const reorder = asNumber(reorderLevel);
  if (qty <= 0) return 'OUT_OF_STOCK';
  if (reorder > 0 && qty <= Math.max(1, Math.floor(reorder / 2))) return 'CRITICAL';
  if (reorder > 0 && qty <= reorder) return 'LOW';
  if (reorder > 0 && qty >= reorder * 3) return 'OVERSTOCK';
  return 'OK';
};

/**
 * Unit cost for stock value: prefer drug.buy_unit_price via drug_inventory_map,
 * fallback drug.unit_price. Returns { unit_cost, cost_basis }.
 */
const resolveInventoryUnitCost = (drugMaps = []) => {
  const maps = Array.isArray(drugMaps) ? drugMaps : [];
  const ordered = [...maps].sort((left, right) => {
    if (Boolean(right?.is_default) !== Boolean(left?.is_default)) {
      return right?.is_default ? 1 : -1;
    }
    return 0;
  });
  for (const map of ordered) {
    const buy = map?.drug?.buy_unit_price;
    if (buy != null && buy !== '') {
      return { unit_cost: asNumber(buy), cost_basis: 'buy_unit_price' };
    }
  }
  for (const map of ordered) {
    const sell = map?.drug?.unit_price;
    if (sell != null && sell !== '') {
      return { unit_cost: asNumber(sell), cost_basis: 'unit_price' };
    }
  }
  return { unit_cost: 0, cost_basis: 'unavailable' };
};

const computeStockValue = (quantity, unitCost) =>
  Math.round(asNumber(quantity) * asNumber(unitCost) * 100) / 100;

/**
 * Signed on-hand delta for a stock_movement row.
 * INBOUND +, OUTBOUND -, TRANSFER - (leaving facility), ADJUSTMENT uses signed qty
 * or reason when quantity is always positive.
 */
const movementSignedDelta = (movement = {}) => {
  const qty = asNumber(movement.quantity);
  const type = normalizeString(movement.movement_type).toUpperCase();
  const reason = normalizeString(movement.reason).toUpperCase();
  if (type === 'INBOUND') return qty;
  if (type === 'OUTBOUND' || type === 'TRANSFER') return -Math.abs(qty);
  if (type === 'ADJUSTMENT') {
    if (qty < 0) return qty;
    if (reason === 'DAMAGE' || reason === 'EXPIRY' || reason === 'DISPENSE') {
      return -Math.abs(qty);
    }
    if (reason === 'PURCHASE' || reason === 'RETURN') return Math.abs(qty);
    return qty;
  }
  return 0;
};

/**
 * Velocity classes for fast/slow/dead stock reports (period OUTBOUND+DISPENSE vs on-hand).
 * FAST: issued >= on_hand when on_hand > 0 (turnover ≥ 1), or issued ≥ 10 when on_hand is 0
 * SLOW: 0 < issued < on_hand × 0.25 (turnover < 0.25)
 * DEAD: issued === 0 && on_hand > 0
 * else MEDIUM (not shown in fast/slow/dead dialogs)
 */
const classifyStockVelocity = (issuedQty, onHandQty) => {
  const issued = asNumber(issuedQty);
  const onHand = asNumber(onHandQty);
  if (issued <= 0 && onHand > 0) return 'DEAD';
  if (onHand > 0 && issued >= onHand) return 'FAST';
  if (onHand <= 0 && issued >= 10) return 'FAST';
  if (issued > 0 && onHand > 0 && issued < onHand * 0.25) return 'SLOW';
  if (issued > 0) return 'MEDIUM';
  return 'DEAD';
};

const buildInventoryStockScopeWhere = (scope = {}) => ({
  deleted_at: null,
  inventory_item: {
    deleted_at: null,
    tenant_id: scope.tenant_id,
  },
  ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
});

const inventoryItemCostSelect = {
  name: true,
  unit: true,
  drug_maps: {
    where: { deleted_at: null },
    select: {
      is_default: true,
      drug: {
        select: {
          name: true,
          buy_unit_price: true,
          unit_price: true,
          currency: true,
        },
      },
    },
  },
};

const loadInventoryStockRows = async (scope) => {
  const stocks = await prisma.inventory_stock.findMany({
    where: buildInventoryStockScopeWhere(scope),
    select: {
      id: true,
      inventory_item_id: true,
      quantity: true,
      reorder_level: true,
      facility: { select: { name: true } },
      inventory_item: { select: inventoryItemCostSelect },
    },
  });

  return stocks.map((entry) => {
    const quantity = asNumber(entry.quantity);
    const reorderLevel = asNumber(entry.reorder_level);
    const cost = resolveInventoryUnitCost(entry?.inventory_item?.drug_maps);
    const value = computeStockValue(quantity, cost.unit_cost);
    return {
      inventory_item_id: entry.inventory_item_id,
      facility: entry?.facility?.name || scope.facility_label || 'Unassigned',
      inventory_item: entry?.inventory_item?.name || 'Unknown',
      unit: normalizeString(entry?.inventory_item?.unit) || null,
      quantity,
      reorder_level: reorderLevel,
      reorder_quantity: Math.max(0, reorderLevel - quantity),
      risk_state: classifyStockRisk(quantity, reorderLevel),
      unit_cost: cost.unit_cost,
      cost_basis: cost.cost_basis,
      value,
      expiry_date: null,
      expiry_alert_status: null,
      days_to_expiry: null,
      batch_number: null,
    };
  });
};

const loadInventoryExpiryRows = async (scope) => {
  const batchWhere = {
    deleted_at: null,
    quantity: { gt: 0 },
    expiry_date: { not: null },
    drug: {
      deleted_at: null,
      tenant_id: scope.tenant_id,
    },
  };
  if (scope.facility_id) {
    batchWhere.OR = [
      { storage_room: { facility_id: scope.facility_id, deleted_at: null } },
      { storage_room_id: null },
    ];
  }

  const batches = await prisma.drug_batch.findMany({
    where: batchWhere,
    select: {
      batch_number: true,
      quantity: true,
      expiry_date: true,
      expiry_alert_lead_days: true,
      drug: {
        select: {
          name: true,
          buy_unit_price: true,
          supplier_id: true,
          supplier: { select: { name: true } },
          inventory_maps: {
            where: { deleted_at: null },
            select: {
              is_default: true,
              inventory_item: { select: { category: true } },
            },
          },
        },
      },
      storage_room: { select: { facility: { select: { name: true } } } },
    },
  });

  const now = Date.now();
  const expiryRows = [];
  for (const batch of batches) {
    const leadDays =
      batch.expiry_alert_lead_days != null
        ? Number(batch.expiry_alert_lead_days)
        : 30;
    const status = resolveBatchExpiryAlertStatus(batch.expiry_date, leadDays);
    if (!status) {
      continue;
    }
    const expiryMs = new Date(batch.expiry_date).getTime();
    const daysToExpiry = Number.isFinite(expiryMs)
      ? Math.ceil((expiryMs - now) / (24 * 60 * 60 * 1000))
      : null;
    // Expiry/loss value is always at buy cost (COGS), never sell.
    const cost = resolveBuyUnitCostOnly(batch.drug);
    const quantity = asNumber(batch.quantity);
    const defaultMap = resolveDefaultInventoryMap(batch?.drug?.inventory_maps);
    expiryRows.push({
      facility:
        batch?.storage_room?.facility?.name ||
        scope.facility_label ||
        'Unassigned',
      inventory_item: normalizeString(batch?.drug?.name) || 'Unknown',
      drug: normalizeString(batch?.drug?.name) || 'Unknown',
      category: normalizeString(defaultMap?.inventory_item?.category) || null,
      supplier_id: normalizeString(batch?.drug?.supplier_id) || null,
      supplier: normalizeString(batch?.drug?.supplier?.name) || null,
      quantity,
      reorder_level: null,
      reorder_quantity: null,
      risk_state: status,
      unit_cost: cost.unit_cost,
      cost_basis: cost.cost_basis,
      value: computeStockValue(quantity, cost.unit_cost),
      expiry_date: batch.expiry_date
        ? new Date(batch.expiry_date).toISOString().slice(0, 10)
        : null,
      expiry_alert_status: status,
      days_to_expiry: daysToExpiry,
      expiry_window: classifyExpiryWindow(daysToExpiry),
      batch_number: normalizeString(batch.batch_number) || null,
    });
  }
  return expiryRows;
};

const runInventoryDataset = async (scope) => {
  const [stockRows, expiryRows] = await Promise.all([
    loadInventoryStockRows(scope),
    loadInventoryExpiryRows(scope),
  ]);

  const rows = [...stockRows, ...expiryRows].sort((left, right) => {
    const rank = (state) => {
      if (state === 'EXPIRED' || state === 'CRITICAL' || state === 'OUT_OF_STOCK') return 0;
      if (state === 'EXPIRING_SOON' || state === 'LOW') return 1;
      if (state === 'OVERSTOCK') return 2;
      return 3;
    };
    const byRisk = rank(left.risk_state) - rank(right.risk_state);
    if (byRisk !== 0) return byRisk;
    return asNumber(left.days_to_expiry ?? 9999) - asNumber(right.days_to_expiry ?? 9999);
  });

  const valueTotal = Math.round(
    stockRows.reduce((sum, row) => sum + asNumber(row.value), 0) * 100
  ) / 100;

  const expiredValue = Math.round(
    expiryRows
      .filter((row) => row.risk_state === 'EXPIRED')
      .reduce((sum, row) => sum + asNumber(row.value), 0) * 100
  ) / 100;

  return {
    title: 'Inventory stock risk',
    subtitle:
      'On-hand stock levels plus low-stock, overstock, near-expiry, and expired batch pressure. Expiry batch value at buy cost.',
    columns: [
      'facility',
      'inventory_item',
      'quantity',
      'reorder_level',
      'risk_state',
      'expiry_date',
      'expiry_alert_status',
      'days_to_expiry',
      'expiry_window',
      'batch_number',
      'value',
      'category',
      'supplier',
      'supplier_id',
      'drug',
    ],
    rows,
    summary: {
      low_stock: stockRows.filter((row) => row.risk_state === 'LOW').length,
      critical_stock: stockRows.filter((row) => row.risk_state === 'CRITICAL').length,
      out_of_stock: stockRows.filter((row) => row.risk_state === 'OUT_OF_STOCK').length,
      overstock: stockRows.filter((row) => row.risk_state === 'OVERSTOCK').length,
      ok_stock: stockRows.filter((row) => row.risk_state === 'OK').length,
      expiring_soon: expiryRows.filter((row) => row.risk_state === 'EXPIRING_SOON').length,
      expired: expiryRows.filter((row) => row.risk_state === 'EXPIRED').length,
      total_stock_rows: stockRows.length,
      total_risk_rows: rows.length,
      value: valueTotal,
      expired_value: expiredValue,
    },
  };
};

const runInventoryStockValueDataset = async (scope) => {
  const stockRows = await loadInventoryStockRows(scope);
  const rows = stockRows
    .map((row) => ({
      facility: row.facility,
      inventory_item: row.inventory_item,
      quantity: row.quantity,
      unit_cost: row.unit_cost,
      value: row.value,
      cost_basis: row.cost_basis,
      risk_state: row.risk_state,
    }))
    .sort((left, right) => asNumber(right.value) - asNumber(left.value));
  const value = Math.round(rows.reduce((sum, row) => sum + asNumber(row.value), 0) * 100) / 100;
  const basisCounts = rows.reduce((acc, row) => {
    const key = row.cost_basis || 'unavailable';
    acc[key] = asNumber(acc[key]) + 1;
    return acc;
  }, {});
  const primaryBasis =
    Object.entries(basisCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || 'buy_unit_price';

  return {
    title: 'Inventory stock value',
    subtitle: `On-hand quantity × unit cost (prefer buy_unit_price via drug_inventory_map; fallback unit_price). Dominant basis: ${primaryBasis}`,
    columns: ['facility', 'inventory_item', 'quantity', 'unit_cost', 'value', 'cost_basis', 'risk_state'],
    rows,
    summary: { value, quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0) },
  };
};

const buildInventoryMovementWhere = (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const where = {
    deleted_at: null,
    inventory_item: {
      deleted_at: null,
      tenant_id: scope.tenant_id,
    },
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  };
  if (!range.invalid && range.from && range.to) {
    where.occurred_at = { gte: range.from, lte: range.to };
  }
  return { where, range };
};

const mapStockMovementRow = (entry, scope) => ({
  occurred_at: entry.occurred_at
    ? new Date(entry.occurred_at).toISOString()
    : null,
  movement_type: normalizeString(entry.movement_type) || null,
  reason: normalizeString(entry.reason) || null,
  quantity: asNumber(entry.quantity),
  facility: entry?.facility?.name || scope.facility_label || 'Unassigned',
  inventory_item: entry?.inventory_item?.name || 'Unknown',
  inventory_item_id: entry.inventory_item_id,
});

const loadStockMovements = async (scope, parameters = {}, extraWhere = {}) => {
  const { where, range } = buildInventoryMovementWhere(scope, parameters);
  if (range.invalid) {
    return { invalid: true, range, rows: [] };
  }
  const movements = await prisma.stock_movement.findMany({
    where: { ...where, ...extraWhere },
    select: {
      inventory_item_id: true,
      movement_type: true,
      reason: true,
      quantity: true,
      occurred_at: true,
      facility: { select: { name: true } },
      inventory_item: { select: { name: true } },
    },
    orderBy: [{ occurred_at: 'asc' }, { created_at: 'asc' }],
  });
  return {
    invalid: false,
    range,
    rows: movements.map((entry) => mapStockMovementRow(entry, scope)),
  };
};

const runInventoryStockMovementHistoryDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockMovements(scope, parameters);
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Stock movement history',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (chronological stock_movement)`,
    columns: ['occurred_at', 'movement_type', 'reason', 'quantity', 'facility', 'inventory_item'],
    rows: loaded.rows,
    summary: {
      quantity: loaded.rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      movement_count: loaded.rows.length,
    },
  };
};

const runInventoryStockReceivedDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockMovements(scope, parameters, {
    movement_type: 'INBOUND',
    reason: 'PURCHASE',
  });
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Stock received',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (INBOUND + PURCHASE)`,
    columns: ['occurred_at', 'inventory_item', 'quantity', 'facility'],
    rows: loaded.rows.map((row) => ({
      occurred_at: row.occurred_at,
      inventory_item: row.inventory_item,
      quantity: row.quantity,
      facility: row.facility,
    })),
    summary: {
      quantity: loaded.rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
    },
  };
};

const runInventoryStockIssuedDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockMovements(scope, parameters, {
    movement_type: 'OUTBOUND',
    reason: 'DISPENSE',
  });
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Stock issued / dispensed',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (OUTBOUND + DISPENSE)`,
    columns: ['occurred_at', 'inventory_item', 'quantity', 'facility'],
    rows: loaded.rows.map((row) => ({
      occurred_at: row.occurred_at,
      inventory_item: row.inventory_item,
      quantity: row.quantity,
      facility: row.facility,
    })),
    summary: {
      quantity: loaded.rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
    },
  };
};

const loadStockAdjustments = async (scope, parameters = {}, extraWhere = {}) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return { invalid: true, range, rows: [] };
  }
  const adjustments = await prisma.stock_adjustment.findMany({
    where: {
      deleted_at: null,
      adjusted_at: { gte: range.from, lte: range.to },
      inventory_item: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
      },
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      ...extraWhere,
    },
    select: {
      inventory_item_id: true,
      quantity: true,
      reason: true,
      adjusted_at: true,
      facility: { select: { name: true } },
      inventory_item: {
        select: inventoryItemCostSelect,
      },
    },
    orderBy: [{ adjusted_at: 'asc' }, { created_at: 'asc' }],
  });

  const rows = adjustments.map((entry) => {
    const quantity = asNumber(entry.quantity);
    // Loss/write-off value at buy cost (COGS); no sell fallback.
    const maps = entry?.inventory_item?.drug_maps || [];
    let unitCost = 0;
    let costBasis = 'unavailable';
    const ordered = [...maps].sort((left, right) => {
      if (Boolean(right?.is_default) !== Boolean(left?.is_default)) {
        return right?.is_default ? 1 : -1;
      }
      return 0;
    });
    for (const map of ordered) {
      const buy = map?.drug?.buy_unit_price;
      if (buy != null && buy !== '') {
        unitCost = asNumber(buy);
        costBasis = 'buy_unit_price';
        break;
      }
    }
    return {
      adjusted_at: entry.adjusted_at
        ? new Date(entry.adjusted_at).toISOString()
        : null,
      inventory_item: entry?.inventory_item?.name || 'Unknown',
      facility: entry?.facility?.name || scope.facility_label || 'Unassigned',
      quantity,
      reason: normalizeString(entry.reason) || null,
      value: computeStockValue(Math.abs(quantity), unitCost),
      cost_basis: costBasis,
    };
  });
  return { invalid: false, range, rows };
};

const runInventoryStockAdjustmentsDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockAdjustments(scope, parameters);
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Stock adjustments',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (stock_adjustment; no actor user_id on schema)`,
    columns: ['adjusted_at', 'inventory_item', 'quantity', 'reason', 'facility'],
    rows: loaded.rows.map((row) => ({
      adjusted_at: row.adjusted_at,
      inventory_item: row.inventory_item,
      quantity: row.quantity,
      reason: row.reason,
      facility: row.facility,
    })),
    summary: {
      quantity: loaded.rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      adjustment_count: loaded.rows.length,
    },
  };
};

const runInventoryDamagedStockDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockAdjustments(scope, parameters, { reason: 'DAMAGE' });
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Damaged stock',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (stock_adjustment reason=DAMAGE at buy cost)`,
    columns: ['adjusted_at', 'inventory_item', 'quantity', 'value', 'facility'],
    rows: loaded.rows.map((row) => ({
      adjusted_at: row.adjusted_at,
      inventory_item: row.inventory_item,
      quantity: row.quantity,
      value: row.value,
      facility: row.facility,
    })),
    summary: {
      quantity: loaded.rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      value: Math.round(
        loaded.rows.reduce((sum, row) => sum + asNumber(row.value), 0) * 100
      ) / 100,
    },
  };
};

/**
 * Lost/missing stock: StockReason has no LOSS enum — map reason=OTHER only.
 * Do not relabel DAMAGE (see damaged_stock).
 */
const runInventoryLostStockDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockAdjustments(scope, parameters, { reason: 'OTHER' });
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Lost / missing stock',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (reason=OTHER as loss proxy — schema has no LOSS; DAMAGE excluded)`,
    columns: ['adjusted_at', 'inventory_item', 'quantity', 'reason', 'value', 'facility'],
    rows: loaded.rows.map((row) => ({
      adjusted_at: row.adjusted_at,
      inventory_item: row.inventory_item,
      quantity: row.quantity,
      reason: row.reason,
      value: row.value,
      facility: row.facility,
    })),
    summary: {
      quantity: loaded.rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      value: Math.round(
        loaded.rows.reduce((sum, row) => sum + asNumber(row.value), 0) * 100
      ) / 100,
    },
  };
};

/**
 * Stock write-offs: stock_adjustment reason EXPIRY or DAMAGE; value at buy cost.
 */
const runInventoryStockWriteOffsDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockAdjustments(scope, parameters, {
    reason: { in: ['DAMAGE', 'EXPIRY'] },
  });
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  const rows = loaded.rows.map((row) => ({
    adjusted_at: row.adjusted_at,
    inventory_item: row.inventory_item,
    reason: row.reason,
    quantity: row.quantity,
    value: row.value,
    amount: row.value,
    facility: row.facility,
  }));
  const value = Math.round(rows.reduce((sum, row) => sum + asNumber(row.value), 0) * 100) / 100;
  return {
    title: 'Stock write-offs',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (EXPIRY|DAMAGE write-offs at buy cost)`,
    columns: [
      'adjusted_at',
      'inventory_item',
      'reason',
      'quantity',
      'value',
      'amount',
      'facility',
    ],
    rows,
    summary: {
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      value,
      amount: value,
      write_off_count: rows.length,
    },
  };
};

/**
 * Reasons for adjustments: group stock_adjustment by reason with counts/qty/value.
 */
const runInventoryAdjustmentReasonsDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockAdjustments(scope, parameters);
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  const byReason = new Map();
  for (const row of loaded.rows) {
    const reason = normalizeString(row.reason) || 'UNKNOWN';
    const current = byReason.get(reason) || {
      reason,
      adjustment_count: 0,
      quantity: 0,
      value: 0,
    };
    current.adjustment_count += 1;
    current.quantity += asNumber(row.quantity);
    current.value += asNumber(row.value);
    byReason.set(reason, current);
  }
  const rows = [...byReason.values()]
    .map((entry) => ({
      ...entry,
      value: Math.round(asNumber(entry.value) * 100) / 100,
    }))
    .sort((left, right) => right.adjustment_count - left.adjustment_count);

  return {
    title: 'Adjustment reasons',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (grouped by stock_adjustment.reason)`,
    columns: ['reason', 'adjustment_count', 'quantity', 'value'],
    rows,
    summary: {
      adjustment_count: loaded.rows.length,
      reason_count: rows.length,
      value: Math.round(rows.reduce((sum, row) => sum + asNumber(row.value), 0) * 100) / 100,
    },
  };
};

const runInventoryReorderDataset = async (scope) => {
  const stockRows = await loadInventoryStockRows(scope);
  const rows = stockRows
    .map((row) => ({
      facility: row.facility,
      inventory_item: row.inventory_item,
      quantity: row.quantity,
      reorder_level: row.reorder_level,
      reorder_quantity: row.reorder_quantity,
      risk_state: row.risk_state,
    }))
    .sort((left, right) => asNumber(right.reorder_quantity) - asNumber(left.reorder_quantity));

  return {
    title: 'Inventory reorder levels',
    subtitle: 'reorder_quantity = max(0, reorder_level − quantity); no separate reorder field on schema',
    columns: [
      'facility',
      'inventory_item',
      'quantity',
      'reorder_level',
      'reorder_quantity',
      'risk_state',
    ],
    rows,
    summary: {
      reorder_quantity: rows.reduce((sum, row) => sum + asNumber(row.reorder_quantity), 0),
      items_below_reorder: rows.filter((row) => asNumber(row.reorder_quantity) > 0).length,
    },
  };
};

const runInventoryOpeningClosingDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Opening and closing stock',
      subtitle: 'Invalid date range',
      columns: ['inventory_item', 'facility', 'opening_quantity', 'closing_quantity'],
      rows: [],
      summary: {},
    };
  }

  const [stockRows, movements, adjustments] = await Promise.all([
    loadInventoryStockRows(scope),
    prisma.stock_movement.findMany({
      where: {
        deleted_at: null,
        occurred_at: { gte: range.from, lte: range.to },
        inventory_item: { deleted_at: null, tenant_id: scope.tenant_id },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        movement_type: true,
        reason: true,
        quantity: true,
      },
    }),
    prisma.stock_adjustment.findMany({
      where: {
        deleted_at: null,
        adjusted_at: { gte: range.from, lte: range.to },
        inventory_item: { deleted_at: null, tenant_id: scope.tenant_id },
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      },
      select: {
        inventory_item_id: true,
        quantity: true,
      },
    }),
  ]);

  const netByItem = new Map();
  movements.forEach((movement) => {
    const key = movement.inventory_item_id;
    netByItem.set(key, asNumber(netByItem.get(key)) + movementSignedDelta(movement));
  });
  adjustments.forEach((adjustment) => {
    const key = adjustment.inventory_item_id;
    netByItem.set(key, asNumber(netByItem.get(key)) + asNumber(adjustment.quantity));
  });

  const rows = stockRows.map((row) => {
    const net = asNumber(netByItem.get(row.inventory_item_id));
    const closing_quantity = row.quantity;
    const opening_quantity = closing_quantity - net;
    return {
      inventory_item: row.inventory_item,
      facility: row.facility,
      unit: row.unit,
      opening_quantity,
      closing_quantity,
    };
  });

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Opening and closing stock',
    subtitle: `${fromLabel} to ${toLabel} (closing = current on-hand; opening = closing − period net movements/adjustments)`,
    columns: ['inventory_item', 'facility', 'opening_quantity', 'closing_quantity', 'unit'],
    rows,
    summary: {
      opening_quantity: rows.reduce((sum, row) => sum + asNumber(row.opening_quantity), 0),
      closing_quantity: rows.reduce((sum, row) => sum + asNumber(row.closing_quantity), 0),
    },
  };
};

const runInventoryStockTurnoverDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Stock turnover',
      subtitle: 'Invalid date range',
      columns: ['inventory_item', 'stock_turnover', 'days_of_stock', 'issued_quantity'],
      rows: [],
      summary: {},
    };
  }

  const [openingClosing, issued] = await Promise.all([
    runInventoryOpeningClosingDataset(scope, parameters),
    loadStockMovements(scope, parameters, {
      movement_type: 'OUTBOUND',
      reason: 'DISPENSE',
    }),
  ]);

  const issuedByItem = new Map();
  issued.rows.forEach((row) => {
    const key = row.inventory_item;
    issuedByItem.set(key, asNumber(issuedByItem.get(key)) + asNumber(row.quantity));
  });

  const periodDays = Math.max(
    1,
    Math.ceil((range.to.getTime() - range.from.getTime()) / (24 * 60 * 60 * 1000)) + 1
  );

  const rows = openingClosing.rows.map((row) => {
    const issuedQty = asNumber(issuedByItem.get(row.inventory_item));
    const avgOnHand =
      (asNumber(row.opening_quantity) + asNumber(row.closing_quantity)) / 2;
    const stock_turnover =
      avgOnHand > 0 ? Math.round((issuedQty / avgOnHand) * 1000) / 1000 : null;
    const days_of_stock =
      stock_turnover && stock_turnover > 0
        ? Math.round((periodDays / stock_turnover) * 10) / 10
        : null;
    return {
      inventory_item: row.inventory_item,
      facility: row.facility,
      issued_quantity: issuedQty,
      opening_quantity: row.opening_quantity,
      closing_quantity: row.closing_quantity,
      stock_turnover,
      days_of_stock,
    };
  });

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);
  return {
    title: 'Stock turnover',
    subtitle: `${fromLabel} to ${toLabel} — stock_turnover = issued(OUTBOUND+DISPENSE) / avg((opening+closing)/2); days_of_stock = period_days / turnover`,
    columns: [
      'inventory_item',
      'facility',
      'issued_quantity',
      'stock_turnover',
      'days_of_stock',
    ],
    rows,
    summary: {
      period_days: periodDays,
      issued_quantity: rows.reduce((sum, row) => sum + asNumber(row.issued_quantity), 0),
    },
    breakdown: {
      series: rows
        .filter((row) => row.stock_turnover != null)
        .map((row) => ({
          label: row.inventory_item,
          stock_turnover: row.stock_turnover,
          days_of_stock: row.days_of_stock,
        })),
    },
  };
};

const runInventoryStockVelocityDataset = async (scope, parameters = {}) => {
  const [stockRows, issued] = await Promise.all([
    loadInventoryStockRows(scope),
    loadStockMovements(scope, parameters, {
      movement_type: 'OUTBOUND',
      reason: 'DISPENSE',
    }),
  ]);

  const issuedByItem = new Map();
  issued.rows.forEach((row) => {
    const key = row.inventory_item_id || row.inventory_item;
    issuedByItem.set(key, asNumber(issuedByItem.get(key)) + asNumber(row.quantity));
  });

  const rows = stockRows
    .map((row) => {
      const issued_quantity = asNumber(
        issuedByItem.get(row.inventory_item_id) ?? issuedByItem.get(row.inventory_item)
      );
      const velocity_class = classifyStockVelocity(issued_quantity, row.quantity);
      return {
        facility: row.facility,
        inventory_item: row.inventory_item,
        quantity: row.quantity,
        issued_quantity,
        velocity_class,
      };
    })
    .sort((left, right) => asNumber(right.issued_quantity) - asNumber(left.issued_quantity));

  const fromLabel = issued.range?.from ? issued.range.from.toISOString().slice(0, 10) : '';
  const toLabel = issued.range?.to ? issued.range.to.toISOString().slice(0, 10) : '';

  return {
    title: 'Stock velocity (fast / slow / dead)',
    subtitle: issued.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} — FAST: issued≥on-hand; SLOW: 0<issued<on-hand×0.25; DEAD: issued=0 & on-hand>0 (OUTBOUND+DISPENSE)`,
    columns: ['facility', 'inventory_item', 'quantity', 'issued_quantity', 'velocity_class'],
    rows,
    summary: {
      fast: rows.filter((row) => row.velocity_class === 'FAST').length,
      slow: rows.filter((row) => row.velocity_class === 'SLOW').length,
      dead: rows.filter((row) => row.velocity_class === 'DEAD').length,
      medium: rows.filter((row) => row.velocity_class === 'MEDIUM').length,
    },
  };
};

const runHrDataset = async (scope) => {
  const [staffProfiles, pendingLeaves, unassignedShifts] = await Promise.all([
    prisma.staff_profile.count({
      where: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
      },
    }),
    prisma.staff_leave.count({
      where: {
        deleted_at: null,
        status: 'REQUESTED',
        staff_profile: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
        },
      },
    }),
    prisma.shift.count({
      where: {
        ...buildTenantWhere(scope),
        assignments: { none: { deleted_at: null } },
      },
    }),
  ]);

  return {
    title: 'HR staffing and leave coverage',
    subtitle: 'Current staffing posture',
    columns: ['metric', 'value', 'facility'],
    rows: [
      { metric: 'active_staff_profiles', value: staffProfiles, facility: scope.facility_label || 'All facilities' },
      { metric: 'pending_leave_requests', value: pendingLeaves, facility: scope.facility_label || 'All facilities' },
      { metric: 'unassigned_shifts', value: unassignedShifts, facility: scope.facility_label || 'All facilities' },
    ],
  };
};

const runBiomedicalDataset = async (scope) => {
  const [openIncidents, activeDowntime, criticalDowntime] = await Promise.all([
    prisma.equipment_incident_report.count({
      where: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
        status: { in: ['OPEN', 'IN_PROGRESS', 'REPORTED'] },
      },
    }),
    prisma.equipment_downtime_log.count({
      where: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
        ended_at: null,
      },
    }),
    prisma.equipment_downtime_log.count({
      where: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
        ended_at: null,
        is_clinically_critical: true,
      },
    }),
  ]);

  return {
    title: 'Biomedical incidents and downtime',
    subtitle: 'Current incidents and downtime pressure',
    columns: ['metric', 'value', 'facility'],
    rows: [
      { metric: 'open_incidents', value: openIncidents, facility: scope.facility_label || 'All facilities' },
      { metric: 'active_downtime', value: activeDowntime, facility: scope.facility_label || 'All facilities' },
      { metric: 'critical_downtime', value: criticalDowntime, facility: scope.facility_label || 'All facilities' },
    ],
  };
};

const runCommunicationsDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const deliveries = await prisma.notification_delivery.findMany({
    where: {
      deleted_at: null,
      created_at: { gte: range.from, lte: range.to },
      notification: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
      },
    },
    select: {
      channel: true,
      status: true,
    },
  });

  const index = new Map();
  deliveries.forEach((delivery) => {
    const key = `${delivery.channel}:${delivery.status || 'UNKNOWN'}`;
    if (!index.has(key)) {
      index.set(key, {
        channel: delivery.channel,
        status: delivery.status || 'UNKNOWN',
        deliveries: 0,
      });
    }
    index.get(key).deliveries += 1;
  });

  return {
    title: 'Communications delivery performance',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)}`,
    columns: ['channel', 'status', 'deliveries'],
    rows: Array.from(index.values()),
  };
};

const emptyToNull = (value) => {
  const trimmed = normalizeString(value);
  return trimmed || null;
};

const toIsoDate = (value) => {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString().slice(0, 10);
};

/**
 * Catalog unit margin percent: profit_per_unit / unit_price when sell > 0.
 * Null when buy unset (pharmacyRetailMarginUnit null) or unit_price ≤ 0.
 */
const computeCatalogProfitMargin = (unitPrice, buyUnitPrice) => {
  const marginUnit = pharmacyRetailMarginUnit({ unitPrice, buyUnitPrice });
  if (marginUnit == null) return null;
  const sell = asNumber(unitPrice);
  if (!(sell > 0)) return null;
  return Math.round((marginUnit / sell) * 10000) / 100;
};

const resolveDefaultInventoryMap = (maps = []) => {
  if (!Array.isArray(maps) || maps.length === 0) return null;
  return maps.find((entry) => entry?.is_default) || maps[0] || null;
};

const buildPharmacyMedicinesCatalogRow = ({
  drug,
  batch = null,
  offering = null,
  rowKind = 'drug',
} = {}) => {
  const defaultMap = resolveDefaultInventoryMap(drug?.inventory_maps);
  const inventoryItem = defaultMap?.inventory_item || null;
  const catalogSell =
    offering?.unit_price != null ? offering.unit_price : drug?.unit_price;
  const buy = drug?.buy_unit_price;
  const currency =
    emptyToNull(offering?.currency) ||
    emptyToNull(drug?.currency) ||
    'UGX';
  const form = emptyToNull(drug?.form);
  const storageRoom = emptyToNull(batch?.storage_room?.name);
  const storageShelf =
    emptyToNull(batch?.storage_shelf?.label) ||
    emptyToNull(batch?.storage_shelf?.shelf_code);
  const storageParts = [storageRoom, storageShelf].filter(Boolean);
  const expiryDate = batch?.expiry_date || null;
  const now = Date.now();
  const expiryMs = expiryDate ? new Date(expiryDate).getTime() : NaN;
  const daysToExpiry = Number.isFinite(expiryMs)
    ? Math.ceil((expiryMs - now) / (24 * 60 * 60 * 1000))
    : null;
  const profitPerUnit = pharmacyRetailMarginUnit({
    unitPrice: catalogSell,
    buyUnitPrice: buy,
  });

  return {
    row_kind: rowKind,
    drug_id: emptyToNull(drug?.id),
    name: emptyToNull(drug?.name) || 'Unknown',
    code: emptyToNull(drug?.code),
    human_friendly_id: emptyToNull(drug?.human_friendly_id),
    generic_name: emptyToNull(drug?.generic_name),
    brand_name: emptyToNull(drug?.brand_name),
    category: emptyToNull(inventoryItem?.category),
    strength: emptyToNull(drug?.strength),
    form,
    dosage_form: form,
    unit: emptyToNull(inventoryItem?.unit),
    batch_number: emptyToNull(batch?.batch_number),
    quantity: batch ? asNumber(batch.quantity) : null,
    manufactured_at: toIsoDate(batch?.manufactured_at),
    expiry_date: toIsoDate(expiryDate),
    days_to_expiry: daysToExpiry,
    selling_price:
      catalogSell == null || catalogSell === '' ? null : asNumber(catalogSell),
    unit_price:
      catalogSell == null || catalogSell === '' ? null : asNumber(catalogSell),
    purchase_price: buy == null || buy === '' ? null : asNumber(buy),
    buy_unit_price: buy == null || buy === '' ? null : asNumber(buy),
    profit_per_unit: profitPerUnit,
    profit_margin: computeCatalogProfitMargin(catalogSell, buy),
    currency,
    storage_room: storageRoom,
    storage_shelf: storageShelf,
    storage_requirements: storageParts.length ? storageParts.join(' / ') : null,
  };
};

const runPharmacyMedicinesCatalogDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const toLabel = range?.to ? range.to.toISOString().slice(0, 10) : '';

  const offeringWhere = {
    deleted_at: null,
    is_active: true,
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  };

  const batchWhere = {
    deleted_at: null,
  };
  if (scope.facility_id) {
    batchWhere.OR = [
      { storage_room: { facility_id: scope.facility_id, deleted_at: null } },
      { storage_room_id: null },
    ];
  }

  const [drugs, offerings] = await Promise.all([
    prisma.drug.findMany({
      where: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
      },
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        brand_name: true,
        generic_name: true,
        code: true,
        form: true,
        strength: true,
        buy_unit_price: true,
        unit_price: true,
        currency: true,
        inventory_maps: {
          where: { deleted_at: null },
          select: {
            is_default: true,
            inventory_item: {
              select: {
                category: true,
                unit: true,
              },
            },
          },
        },
        batches: {
          where: batchWhere,
          select: {
            batch_number: true,
            manufactured_at: true,
            expiry_date: true,
            quantity: true,
            storage_room: { select: { name: true } },
            storage_shelf: { select: { label: true, shelf_code: true } },
          },
          orderBy: [{ expiry_date: 'asc' }, { batch_number: 'asc' }],
        },
      },
      orderBy: [{ name: 'asc' }, { code: 'asc' }],
    }),
    prisma.facility_pharmacy_offering.findMany({
      where: offeringWhere,
      select: {
        drug_id: true,
        unit_price: true,
        currency: true,
      },
    }),
  ]);

  const offeringByDrug = new Map();
  offerings.forEach((entry) => {
    if (!offeringByDrug.has(entry.drug_id)) {
      offeringByDrug.set(entry.drug_id, entry);
    }
  });

  const rows = [];
  drugs.forEach((drug) => {
    const offering = offeringByDrug.get(drug.id) || null;
    rows.push(
      buildPharmacyMedicinesCatalogRow({
        drug,
        batch: null,
        offering,
        rowKind: 'drug',
      })
    );
    (drug.batches || []).forEach((batch) => {
      rows.push(
        buildPharmacyMedicinesCatalogRow({
          drug,
          batch,
          offering,
          rowKind: 'batch',
        })
      );
    });
  });

  return {
    title: 'Pharmacy medicines catalog',
    subtitle: toLabel
      ? `Catalog as of ${toLabel}`
      : 'Drug and batch catalog attributes',
    columns: [
      'row_kind',
      'drug_id',
      'name',
      'code',
      'human_friendly_id',
      'generic_name',
      'brand_name',
      'category',
      'strength',
      'form',
      'dosage_form',
      'unit',
      'batch_number',
      'quantity',
      'manufactured_at',
      'expiry_date',
      'days_to_expiry',
      'selling_price',
      'unit_price',
      'purchase_price',
      'buy_unit_price',
      'profit_per_unit',
      'profit_margin',
      'currency',
      'storage_room',
      'storage_shelf',
      'storage_requirements',
    ],
    rows,
    summary: {
      drug_count: drugs.length,
      batch_count: rows.filter((row) => row.row_kind === 'batch').length,
    },
  };
};

/**
 * Non-negative whole days between PO ordered_at and goods_receipt.received_at.
 */
const computeDeliveryDays = (orderedAt, receivedAt) => {
  if (!orderedAt || !receivedAt) return null;
  const ordered = orderedAt instanceof Date ? orderedAt : new Date(orderedAt);
  const received = receivedAt instanceof Date ? receivedAt : new Date(receivedAt);
  if (Number.isNaN(ordered.getTime()) || Number.isNaN(received.getTime())) return null;
  const diffMs = received.getTime() - ordered.getTime();
  return Math.max(0, Math.round(diffMs / (24 * 60 * 60 * 1000)));
};

const buildPurchaseOrderScopeWhere = (scope = {}, range = null) => {
  const where = {
    deleted_at: null,
    OR: [
      { supplier: { deleted_at: null, tenant_id: scope.tenant_id } },
      {
        supplier_id: null,
        purchase_request: { deleted_at: null, tenant_id: scope.tenant_id },
      },
    ],
  };
  if (scope.facility_id) {
    where.purchase_request = {
      deleted_at: null,
      tenant_id: scope.tenant_id,
      facility_id: scope.facility_id,
    };
    delete where.OR;
  }
  if (range && !range.invalid && range.from && range.to) {
    where.ordered_at = { gte: range.from, lte: range.to };
  }
  return where;
};

const loadPurchaseOrderRows = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return { invalid: true, range, rows: [] };
  }

  const orders = await prisma.purchase_order.findMany({
    where: buildPurchaseOrderScopeWhere(scope, range),
    select: {
      id: true,
      human_friendly_id: true,
      status: true,
      ordered_at: true,
      supplier_id: true,
      supplier: { select: { id: true, name: true } },
      goods_receipts: {
        where: { deleted_at: null },
        select: { received_at: true, status: true },
        orderBy: [{ received_at: 'asc' }],
        take: 1,
      },
    },
    orderBy: [{ ordered_at: 'asc' }, { created_at: 'asc' }],
  });

  const rows = orders.map((entry) => {
    const receipt = entry.goods_receipts?.[0] || null;
    const orderedAt = entry.ordered_at ? new Date(entry.ordered_at).toISOString() : null;
    const receivedAt = receipt?.received_at
      ? new Date(receipt.received_at).toISOString()
      : null;
    const deliveryDays = computeDeliveryDays(entry.ordered_at, receipt?.received_at);
    return {
      id: entry.id,
      human_friendly_id: entry.human_friendly_id || null,
      status: normalizeString(entry.status) || null,
      ordered_at: orderedAt,
      received_at: receivedAt,
      delivery_days: deliveryDays,
      supplier_id: entry.supplier_id || entry.supplier?.id || null,
      supplier: entry.supplier?.name || 'Unassigned',
      receipt_status: receipt ? normalizeString(receipt.status) || null : null,
    };
  });

  return { invalid: false, range, rows };
};

const runPharmacyPurchaseOrdersDataset = async (scope, parameters = {}) => {
  const loaded = await loadPurchaseOrderRows(scope, parameters);
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';

  const bySupplier = new Map();
  loaded.rows.forEach((row) => {
    const key = row.supplier_id || row.supplier || 'unassigned';
    if (!bySupplier.has(key)) {
      bySupplier.set(key, {
        supplier: row.supplier,
        supplier_id: row.supplier_id,
        po_count: 0,
        receipt_count: 0,
        delivery_days_sum: 0,
        delivery_days_n: 0,
      });
    }
    const bucket = bySupplier.get(key);
    bucket.po_count += 1;
    if (row.received_at) bucket.receipt_count += 1;
    if (row.delivery_days != null) {
      bucket.delivery_days_sum += asNumber(row.delivery_days);
      bucket.delivery_days_n += 1;
    }
  });

  const supplierPerformance = Array.from(bySupplier.values()).map((bucket) => {
    const avg =
      bucket.delivery_days_n > 0
        ? Math.round((bucket.delivery_days_sum / bucket.delivery_days_n) * 100) / 100
        : null;
    return {
      supplier: bucket.supplier,
      supplier_id: bucket.supplier_id,
      po_count: bucket.po_count,
      receipt_count: bucket.receipt_count,
      delivery_days: avg,
      // Qty fulfillment needs PO/goods-receipt line items (schema gap).
      fulfillment_rate: null,
    };
  });

  return {
    title: 'Pharmacy purchase orders',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (PO headers; delivery_days from goods_receipt)`,
    columns: [
      'ordered_at',
      'status',
      'supplier',
      'human_friendly_id',
      'received_at',
      'delivery_days',
      'id',
      'receipt_status',
    ],
    rows: loaded.rows,
    summary: {
      po_count: loaded.rows.length,
      receipt_count: loaded.rows.filter((row) => row.received_at).length,
    },
    breakdown: {
      by_supplier: supplierPerformance,
    },
  };
};

const inventoryItemPurchaseSelect = {
  name: true,
  unit: true,
  drug_maps: {
    where: { deleted_at: null },
    select: {
      is_default: true,
      drug: {
        select: {
          name: true,
          buy_unit_price: true,
          unit_price: true,
          currency: true,
          supplier_id: true,
          supplier: { select: { id: true, name: true } },
        },
      },
    },
  },
};

const resolvePreferredDrugFromMaps = (drugMaps = []) => {
  const maps = Array.isArray(drugMaps) ? drugMaps : [];
  const ordered = [...maps].sort((left, right) => {
    if (Boolean(right?.is_default) !== Boolean(left?.is_default)) {
      return right?.is_default ? 1 : -1;
    }
    return 0;
  });
  return ordered.find((map) => map?.drug)?.drug || null;
};

const loadPurchaseInboundValueRows = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return { invalid: true, range, rows: [] };
  }

  const where = {
    deleted_at: null,
    movement_type: 'INBOUND',
    reason: 'PURCHASE',
    inventory_item: {
      deleted_at: null,
      tenant_id: scope.tenant_id,
    },
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
  };
  if (range.from && range.to) {
    where.occurred_at = { gte: range.from, lte: range.to };
  }

  const movements = await prisma.stock_movement.findMany({
    where,
    select: {
      inventory_item_id: true,
      quantity: true,
      occurred_at: true,
      facility: { select: { name: true } },
      inventory_item: { select: inventoryItemPurchaseSelect },
    },
    orderBy: [{ occurred_at: 'asc' }, { created_at: 'asc' }],
  });

  const rows = movements.map((entry) => {
    const quantity = asNumber(entry.quantity);
    const drug = resolvePreferredDrugFromMaps(entry?.inventory_item?.drug_maps);
    const cost = resolveInventoryUnitCost(entry?.inventory_item?.drug_maps);
    const amount =
      cost.cost_basis === 'buy_unit_price'
        ? computeStockValue(quantity, cost.unit_cost)
        : cost.cost_basis === 'unavailable'
          ? null
          : computeStockValue(quantity, cost.unit_cost);
    return {
      occurred_at: entry.occurred_at ? new Date(entry.occurred_at).toISOString() : null,
      inventory_item: entry?.inventory_item?.name || 'Unknown',
      inventory_item_id: entry.inventory_item_id,
      drug: drug?.name || null,
      supplier_id: drug?.supplier_id || drug?.supplier?.id || null,
      supplier: drug?.supplier?.name || 'Unassigned',
      facility: entry?.facility?.name || scope.facility_label || 'Unassigned',
      quantity,
      amount,
      unit_cost: cost.unit_cost,
      cost_basis:
        cost.cost_basis === 'buy_unit_price'
          ? 'stock inbound × buy_unit_price'
          : cost.cost_basis,
      currency: normalizeString(drug?.currency) || null,
    };
  });

  return { invalid: false, range, rows };
};

const runPharmacyPurchaseInboundValueDataset = async (scope, parameters = {}) => {
  const loaded = await loadPurchaseInboundValueRows(scope, parameters);
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  const amount = loaded.rows.reduce((sum, row) => sum + asNumber(row.amount), 0);
  const quantity = loaded.rows.reduce((sum, row) => sum + asNumber(row.quantity), 0);

  return {
    title: 'Pharmacy purchase value',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (stock inbound × buy_unit_price)`,
    columns: [
      'occurred_at',
      'supplier',
      'inventory_item',
      'drug',
      'quantity',
      'amount',
      'currency',
      'cost_basis',
      'facility',
    ],
    rows: loaded.rows,
    summary: {
      amount: Math.round(amount * 100) / 100,
      quantity,
      movement_count: loaded.rows.length,
    },
  };
};

const runPharmacyPurchasesBySupplierDataset = async (scope, parameters = {}) => {
  const [orders, inbound] = await Promise.all([
    loadPurchaseOrderRows(scope, parameters),
    loadPurchaseInboundValueRows(scope, parameters),
  ]);
  const fromLabel = orders.range?.from ? orders.range.from.toISOString().slice(0, 10) : '';
  const toLabel = orders.range?.to ? orders.range.to.toISOString().slice(0, 10) : '';

  const index = new Map();
  const ensure = (supplierId, supplierName) => {
    const key = supplierId || supplierName || 'unassigned';
    if (!index.has(key)) {
      index.set(key, {
        supplier_id: supplierId || null,
        supplier: supplierName || 'Unassigned',
        po_count: 0,
        quantity: 0,
        amount: 0,
        inbound_count: 0,
        currency: null,
      });
    }
    return index.get(key);
  };

  orders.rows.forEach((row) => {
    ensure(row.supplier_id, row.supplier).po_count += 1;
  });
  inbound.rows.forEach((row) => {
    const bucket = ensure(row.supplier_id, row.supplier);
    bucket.quantity += asNumber(row.quantity);
    bucket.amount += asNumber(row.amount);
    bucket.inbound_count += 1;
    if (!bucket.currency && row.currency) bucket.currency = row.currency;
  });

  const rows = Array.from(index.values())
    .map((bucket) => ({
      ...bucket,
      amount: Math.round(asNumber(bucket.amount) * 100) / 100,
    }))
    .sort((left, right) => {
      if (asNumber(right.po_count) !== asNumber(left.po_count)) {
        return asNumber(right.po_count) - asNumber(left.po_count);
      }
      return asNumber(right.amount) - asNumber(left.amount);
    });

  return {
    title: 'Purchases by supplier',
    subtitle:
      orders.invalid || inbound.invalid
        ? 'Invalid date range'
        : `${fromLabel} to ${toLabel} (PO count + inbound × buy_unit_price)`,
    columns: ['supplier', 'po_count', 'quantity', 'amount', 'inbound_count', 'currency'],
    rows,
    summary: {
      supplier_count: rows.length,
      po_count: rows.reduce((sum, row) => sum + asNumber(row.po_count), 0),
      amount: Math.round(rows.reduce((sum, row) => sum + asNumber(row.amount), 0) * 100) / 100,
      quantity: rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
    },
  };
};

const runPharmacySupplierPricingDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const toLabel = range?.to ? range.to.toISOString().slice(0, 10) : '';

  const drugs = await prisma.drug.findMany({
    where: {
      deleted_at: null,
      tenant_id: scope.tenant_id,
      supplier_id: { not: null },
    },
    select: {
      id: true,
      name: true,
      code: true,
      buy_unit_price: true,
      currency: true,
      supplier: { select: { id: true, name: true } },
    },
    orderBy: [{ name: 'asc' }, { code: 'asc' }],
  });

  const rows = drugs.map((drug) => ({
    supplier_id: drug.supplier?.id || null,
    supplier: drug.supplier?.name || 'Unassigned',
    drug: drug.name,
    drug_id: drug.id,
    code: drug.code || null,
    buy_unit_price:
      drug.buy_unit_price == null || drug.buy_unit_price === ''
        ? null
        : asNumber(drug.buy_unit_price),
    currency: normalizeString(drug.currency) || null,
  }));

  return {
    title: 'Supplier pricing',
    subtitle: toLabel
      ? `Current buy_unit_price by supplier as of ${toLabel}`
      : 'Current drug.buy_unit_price by supplier',
    columns: ['supplier', 'drug', 'buy_unit_price', 'currency', 'code'],
    rows,
    summary: {
      drug_count: rows.length,
      supplier_count: new Set(rows.map((row) => row.supplier_id).filter(Boolean)).size,
    },
  };
};

const runPharmacyPurchaseReturnsDataset = async (scope, parameters = {}) => {
  const loaded = await loadStockMovements(scope, parameters, {
    movement_type: 'OUTBOUND',
    reason: 'RETURN',
  });
  const fromLabel = loaded.range?.from ? loaded.range.from.toISOString().slice(0, 10) : '';
  const toLabel = loaded.range?.to ? loaded.range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Purchase returns',
    subtitle: loaded.invalid
      ? 'Invalid date range'
      : `${fromLabel} to ${toLabel} (OUTBOUND + RETURN)`,
    columns: ['occurred_at', 'inventory_item', 'quantity', 'facility', 'reason'],
    rows: loaded.rows.map((row) => ({
      occurred_at: row.occurred_at,
      inventory_item: row.inventory_item,
      quantity: row.quantity,
      facility: row.facility,
      reason: row.reason,
    })),
    summary: {
      quantity: loaded.rows.reduce((sum, row) => sum + asNumber(row.quantity), 0),
      movement_count: loaded.rows.length,
    },
  };
};

const extractPriceChangeFields = (diffJson) => {
  if (!diffJson || typeof diffJson !== 'object' || Array.isArray(diffJson)) return [];
  const fields = [];
  const candidates = ['buy_unit_price', 'unit_price', 'transfer_unit_price'];
  for (const field of candidates) {
    const entry = diffJson[field];
    if (entry == null) continue;
    if (typeof entry === 'object' && !Array.isArray(entry)) {
      const fromValue = entry.from ?? entry.old ?? entry.before ?? null;
      const toValue = entry.to ?? entry.new ?? entry.after ?? null;
      if (fromValue != null || toValue != null) {
        fields.push({ field, from_value: fromValue, to_value: toValue });
      }
      continue;
    }
    fields.push({ field, from_value: null, to_value: entry });
  }
  return fields;
};

const runPharmacyDrugPriceChangesDataset = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  if (range.invalid) {
    return {
      title: 'Drug price changes',
      subtitle: 'Invalid date range',
      columns: ['changed_at', 'drug', 'field', 'from_value', 'to_value', 'currency'],
      rows: [],
      summary: { change_count: 0 },
    };
  }

  const where = {
    deleted_at: null,
    tenant_id: scope.tenant_id,
    entity: 'drug',
    action: 'UPDATE',
  };
  if (range.from && range.to) {
    where.created_at = { gte: range.from, lte: range.to };
  }

  const logs = await prisma.audit_log.findMany({
    where,
    select: {
      entity_id: true,
      diff_json: true,
      created_at: true,
    },
    orderBy: [{ created_at: 'asc' }],
  });

  const drugIds = [...new Set(logs.map((entry) => entry.entity_id).filter(Boolean))];
  const drugs = drugIds.length
    ? await prisma.drug.findMany({
        where: {
          deleted_at: null,
          tenant_id: scope.tenant_id,
          id: { in: drugIds },
        },
        select: { id: true, name: true, currency: true },
      })
    : [];
  const drugById = new Map(drugs.map((drug) => [drug.id, drug]));

  const rows = [];
  logs.forEach((log) => {
    const changes = extractPriceChangeFields(log.diff_json);
    if (changes.length === 0) return;
    const drug = drugById.get(log.entity_id);
    changes.forEach((change) => {
      rows.push({
        changed_at: log.created_at ? new Date(log.created_at).toISOString() : null,
        drug: drug?.name || log.entity_id,
        drug_id: log.entity_id,
        field: change.field,
        from_value:
          change.from_value == null || change.from_value === ''
            ? null
            : asNumber(change.from_value),
        to_value:
          change.to_value == null || change.to_value === ''
            ? null
            : asNumber(change.to_value),
        currency: normalizeString(drug?.currency) || null,
      });
    });
  });

  const fromLabel = range.from ? range.from.toISOString().slice(0, 10) : '';
  const toLabel = range.to ? range.to.toISOString().slice(0, 10) : '';
  return {
    title: 'Drug price changes',
    subtitle: `${fromLabel} to ${toLabel} (audit_log buy/unit price diffs)`,
    columns: ['changed_at', 'drug', 'field', 'from_value', 'to_value', 'currency'],
    rows,
    summary: { change_count: rows.length },
  };
};

const DATASET_RUNNERS = Object.freeze({
  patient_registrations: runPatientRegistrationsDataset,
  appointment_throughput_no_shows: runAppointmentDataset,
  billing_collections_open_balances: runBillingDataset,
  insurance_claims_aging: runInsuranceClaimsDataset,
  pharmacy_drug_consumption: runPharmacyDrugConsumptionDataset,
  pharmacy_dispense_throughput: runPharmacyDispenseThroughputDataset,
  pharmacy_sales_by_category: runPharmacySalesByCategoryDataset,
  pharmacy_sales_by_branch: runPharmacySalesByBranchDataset,
  pharmacy_profit_by_branch: runPharmacyProfitByBranchDataset,
  pharmacy_stock_by_branch: runPharmacyStockByBranchDataset,
  pharmacy_purchases_by_branch: runPharmacyPurchasesByBranchDataset,
  pharmacy_stock_shortages_by_branch: runPharmacyStockShortagesByBranchDataset,
  pharmacy_best_performing_branch: runPharmacyBestPerformingBranchDataset,
  pharmacy_branch_comparison: runPharmacyBranchComparisonDataset,
  pharmacy_sales_by_customer: runPharmacySalesByCustomerDataset,
  pharmacy_sales_payment_methods: runPharmacySalesPaymentMethodDataset,
  pharmacy_sales_discounts: runPharmacySalesDiscountsDataset,
  pharmacy_sales_refunds: runPharmacySalesRefundsDataset,
  pharmacy_sales_net_revenue: runPharmacySalesNetRevenueDataset,
  pharmacy_sales_avg_transaction: runPharmacySalesAvgTransactionDataset,
  ...createPharmacyStaffDatasetRunners(resolveDateRange),
  pharmacy_financial_revenue: runPharmacyFinancialRevenueDataset,
  pharmacy_financial_cogs: runPharmacyFinancialCogsDataset,
  pharmacy_financial_gross_profit: runPharmacyFinancialGrossProfitDataset,
  pharmacy_financial_net_profit: runPharmacyFinancialNetProfitDataset,
  pharmacy_financial_operating_expenses: runPharmacyFinancialOperatingExpensesDataset,
  pharmacy_financial_receivables: runPharmacyFinancialReceivablesDataset,
  pharmacy_financial_cash_flow: runPharmacyFinancialCashFlowDataset,
  pharmacy_financial_profit_by_category: runPharmacyFinancialProfitByCategoryDataset,
  pharmacy_financial_profit_by_period: runPharmacyFinancialProfitByPeriodDataset,
  pharmacy_customer_count: runPharmacyCustomerCountDataset,
  pharmacy_customers_new_vs_returning: runPharmacyCustomersNewVsReturningDataset,
  pharmacy_patient_medication_history: runPharmacyPatientMedicationHistoryDataset,
  pharmacy_customer_credit_balance: runPharmacyCustomerCreditBalanceDataset,
  pharmacy_customer_outstanding: runPharmacyCustomerOutstandingDataset,
  pharmacy_customer_demographics: runPharmacyCustomerDemographicsDataset,
  pharmacy_customer_retention: runPharmacyCustomerRetentionDataset,
  pharmacy_dispensing_by_prescriber: runPharmacyDispensingByPrescriberDataset,
  pharmacy_dispensing_partial: runPharmacyDispensingPartialDataset,
  pharmacy_dispensing_frequency: runPharmacyDispensingFrequencyDataset,
  pharmacy_dispensing_avg_items: runPharmacyDispensingAvgItemsDataset,
  pharmacy_medicines_catalog: runPharmacyMedicinesCatalogDataset,
  pharmacy_purchase_orders: runPharmacyPurchaseOrdersDataset,
  pharmacy_purchase_inbound_value: runPharmacyPurchaseInboundValueDataset,
  pharmacy_purchases_by_supplier: runPharmacyPurchasesBySupplierDataset,
  pharmacy_supplier_pricing: runPharmacySupplierPricingDataset,
  pharmacy_purchase_returns: runPharmacyPurchaseReturnsDataset,
  pharmacy_drug_price_changes: runPharmacyDrugPriceChangesDataset,
  inventory_stock_risk: runInventoryDataset,
  inventory_stock_value: runInventoryStockValueDataset,
  inventory_opening_closing: runInventoryOpeningClosingDataset,
  inventory_stock_received: runInventoryStockReceivedDataset,
  inventory_stock_issued: runInventoryStockIssuedDataset,
  inventory_stock_adjustments: runInventoryStockAdjustmentsDataset,
  inventory_damaged_stock: runInventoryDamagedStockDataset,
  inventory_lost_stock: runInventoryLostStockDataset,
  inventory_stock_write_offs: runInventoryStockWriteOffsDataset,
  inventory_adjustment_reasons: runInventoryAdjustmentReasonsDataset,
  inventory_reorder: runInventoryReorderDataset,
  inventory_stock_turnover: runInventoryStockTurnoverDataset,
  inventory_stock_velocity: runInventoryStockVelocityDataset,
  inventory_stock_movement_history: runInventoryStockMovementHistoryDataset,
  hr_staffing_leave_coverage: runHrDataset,
  biomedical_incidents_downtime: runBiomedicalDataset,
  communications_delivery_performance: runCommunicationsDataset,
});

const pickColumns = (rows = [], requested = [], defaults = []) => {
  const normalizedRequested = (Array.isArray(requested) ? requested : [])
    .map((entry) => normalizeString(entry))
    .filter(Boolean);

  if (normalizedRequested.length > 0) return normalizedRequested;
  if (Array.isArray(defaults) && defaults.length > 0) return defaults;

  const firstRow = rows.find((entry) => entry && typeof entry === 'object') || {};
  return Object.keys(firstRow);
};

const executeReportDataset = async ({ dataset_key, scope, definition_json = {}, parameters = {} }) => {
  const dataset = REPORT_DATASET_MAP[dataset_key];
  const runner = DATASET_RUNNERS[dataset_key];

  if (!dataset || typeof runner !== 'function') {
    throw new HttpError('errors.report_definition.invalid_dataset', 400, [{ field: 'dataset_key' }]);
  }

  const result = await runner(scope, parameters, definition_json);
  const columns = pickColumns(result.rows, definition_json.columns, dataset.default_columns);
  const filteredRows = (Array.isArray(result.rows) ? result.rows : []).map((row) =>
    columns.reduce((acc, key) => {
      acc[key] = row?.[key] ?? null;
      return acc;
    }, {})
  );

  return {
    dataset,
    title: result.title || dataset.label,
    subtitle: result.subtitle || dataset.description,
    columns,
    rows: filteredRows,
    summary: result.summary || null,
    breakdown: result.breakdown || null,
  };
};

module.exports = {
  aggregateShortagesByFacility,
  aggregateStockByFacility,
  buildBillingFinancialAnalytics,
  buildPharmacyBillingFinancialAnalytics,
  buildPharmacyCustomerCountAnalytics,
  buildPharmacyCustomerCreditBalanceAnalytics,
  buildPharmacyCustomerDemographicsAnalytics,
  buildPharmacyCustomerOutstandingAnalytics,
  buildPharmacyCustomerRetentionAnalytics,
  buildPharmacyCustomersNewVsReturningAnalytics,
  buildPharmacyDispenseThroughputAnalytics,
  buildPharmacyDispensingAvgItemsAnalytics,
  buildPharmacyDispensingByPrescriberAnalytics,
  buildPharmacyDispensingFrequencyAnalytics,
  buildPharmacyDispensingPartialAnalytics,
  buildPharmacyDrugConsumptionAnalytics,
  buildPharmacyFinancialCashFlowAnalytics,
  buildPharmacyFinancialCogsAnalytics,
  buildPharmacyFinancialGrossProfitAnalytics,
  buildPharmacyFinancialNetProfitAnalytics,
  buildPharmacyFinancialOperatingExpensesAnalytics,
  buildPharmacyFinancialProfitByCategoryAnalytics,
  buildPharmacyFinancialProfitByPeriodAnalytics,
  buildPharmacyFinancialReceivablesAnalytics,
  buildPharmacyFinancialRevenueAnalytics,
  buildPharmacyMedicinesCatalogRow,
  buildPharmacyPatientMedicationHistoryAnalytics,
  buildPharmacySalesAvgTransactionAnalytics,
  buildPharmacySalesDiscountsAnalytics,
  buildPharmacySalesNetRevenueAnalytics,
  buildPharmacySalesPaymentMethodAnalytics,
  buildPharmacySalesRefundsAnalytics,
  classifyExpiryWindow,
  classifyStockRisk,
  classifyStockVelocity,
  computeAverageItemsPerPrescription,
  computeCatalogProfitMargin,
  computeDeliveryDays,
  computeDispenseCogs,
  computeStockValue,
  executeReportDataset,
  extractPriceChangeFields,
  mergeBranchComparisonRows,
  movementSignedDelta,
  OPEN_PHARMACY_INVOICE_STATUSES,
  remainingItemQuantity,
  resolveAgeBand,
  resolveBuyUnitCostOnly,
  resolveDateRange,
  resolveInventoryUnitCost,
  shouldUseMonthlyGranularity,
  summarizeBillingSeries,
  summarizeConsumptionSeries,
  summarizeStaffSalesPartition,
  summarizeThroughputSeries,
  pickAttestationUserId,
};
