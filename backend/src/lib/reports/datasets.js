const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { REPORT_DATASET_MAP } = require('@lib/reports/constants');
const { pharmacyRetailMarginUnit } = require('@lib/billing/pharmacy-drug-margins');

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

const resolveFacilityLabel = (patient) =>
  normalizeString(patient?.facility?.name) ||
  normalizeString(patient?.facility?.human_friendly_id) ||
  'Unknown';

const consumptionColumnsForGroup = (groupBy) => {
  if (groupBy === 'category') return ['category', 'quantity_dispensed', 'amount'];
  if (groupBy === 'facility') return ['facility', 'amount', 'quantity_dispensed'];
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
  const columns = consumptionColumnsForGroup(groupBy);
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
        sources: new Map(),
      });
    }
    const drugEntry = drugIndex.get(drugName);
    drugEntry.quantity_dispensed += qty;
    drugEntry.amount = Math.round((drugEntry.amount + amount) * 100) / 100;
    if (profit != null) {
      drugEntry.profit = Math.round((asNumber(drugEntry.profit) + profit) * 100) / 100;
    }
    drugEntry.sources.set(orderSource, asNumber(drugEntry.sources.get(orderSource)) + qty);

    if (!categoryIndex.has(category)) {
      categoryIndex.set(category, { category, quantity_dispensed: 0, amount: 0 });
    }
    const categoryEntry = categoryIndex.get(category);
    categoryEntry.quantity_dispensed += qty;
    categoryEntry.amount = Math.round((categoryEntry.amount + amount) * 100) / 100;

    if (!facilityIndex.has(facilityLabel)) {
      facilityIndex.set(facilityLabel, {
        facility: facilityLabel,
        quantity_dispensed: 0,
        amount: 0,
      });
    }
    const facilityEntry = facilityIndex.get(facilityLabel);
    facilityEntry.quantity_dispensed += qty;
    facilityEntry.amount = Math.round((facilityEntry.amount + amount) * 100) / 100;

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
    });
  });

  let rows;
  if (groupBy === 'category') {
    rows = sortConsumptionRows(
      Array.from(categoryIndex.values()).map((entry) => ({
        category: entry.category,
        quantity_dispensed: entry.quantity_dispensed,
        amount: Math.round(entry.amount * 100) / 100,
      }))
    );
  } else if (groupBy === 'facility') {
    rows = sortConsumptionRows(
      Array.from(facilityIndex.values()).map((entry) => ({
        facility: entry.facility,
        amount: Math.round(entry.amount * 100) / 100,
        quantity_dispensed: entry.quantity_dispensed,
      }))
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
    },
    { monthly }
  ).map((entry) => ({
    ...entry,
    amount: Math.round(asNumber(entry.amount) * 100) / 100,
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
      return acc;
    },
    { quantity_dispensed: 0, amount: 0 }
  );
  const profitTotal =
    groupBy === 'drug'
      ? rows.reduce((sum, row) => sum + asNumber(row.profit), 0)
      : null;

  return {
    invalid: false,
    reason: null,
    preset: range.preset,
    from: range.from,
    to: range.to,
    granularity: monthly ? 'month' : 'day',
    title:
      groupBy === 'category'
        ? 'Pharmacy sales by category'
        : groupBy === 'facility'
          ? 'Pharmacy sales by branch'
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
            source_mix,
          }
        : {
            amount: Math.round(periodTotals.amount * 100) / 100,
            quantity_dispensed: periodTotals.quantity_dispensed,
            drug_count: rows.length,
          }),
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
    summary: summarizeThroughputSeries(rows),
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
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
    breakdown: analytics.breakdown,
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
          unit_price: true,
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
    const cost = resolveInventoryUnitCost([
      { is_default: true, drug: batch.drug },
    ]);
    const quantity = asNumber(batch.quantity);
    expiryRows.push({
      facility:
        batch?.storage_room?.facility?.name ||
        scope.facility_label ||
        'Unassigned',
      inventory_item: normalizeString(batch?.drug?.name) || 'Unknown',
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

  return {
    title: 'Inventory stock risk',
    subtitle:
      'On-hand stock levels plus low-stock, overstock, near-expiry, and expired batch pressure',
    columns: [
      'facility',
      'inventory_item',
      'quantity',
      'reorder_level',
      'risk_state',
      'expiry_date',
      'expiry_alert_status',
      'days_to_expiry',
      'batch_number',
      'value',
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
    const cost = resolveInventoryUnitCost(entry?.inventory_item?.drug_maps);
    return {
      adjusted_at: entry.adjusted_at
        ? new Date(entry.adjusted_at).toISOString()
        : null,
      inventory_item: entry?.inventory_item?.name || 'Unknown',
      facility: entry?.facility?.name || scope.facility_label || 'Unassigned',
      quantity,
      reason: normalizeString(entry.reason) || null,
      value: computeStockValue(Math.abs(quantity), cost.unit_cost),
      cost_basis: cost.cost_basis,
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
      : `${fromLabel} to ${toLabel} (stock_adjustment reason=DAMAGE)`,
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
      : `${fromLabel} to ${toLabel} (stock_adjustment reason=OTHER as loss proxy; DAMAGE excluded)`,
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

const DATASET_RUNNERS = Object.freeze({
  patient_registrations: runPatientRegistrationsDataset,
  appointment_throughput_no_shows: runAppointmentDataset,
  billing_collections_open_balances: runBillingDataset,
  insurance_claims_aging: runInsuranceClaimsDataset,
  pharmacy_drug_consumption: runPharmacyDrugConsumptionDataset,
  pharmacy_dispense_throughput: runPharmacyDispenseThroughputDataset,
  pharmacy_sales_by_category: runPharmacySalesByCategoryDataset,
  pharmacy_sales_by_branch: runPharmacySalesByBranchDataset,
  pharmacy_sales_by_customer: runPharmacySalesByCustomerDataset,
  pharmacy_sales_payment_methods: runPharmacySalesPaymentMethodDataset,
  pharmacy_sales_discounts: runPharmacySalesDiscountsDataset,
  pharmacy_sales_refunds: runPharmacySalesRefundsDataset,
  pharmacy_sales_net_revenue: runPharmacySalesNetRevenueDataset,
  pharmacy_sales_avg_transaction: runPharmacySalesAvgTransactionDataset,
  inventory_stock_risk: runInventoryDataset,
  inventory_stock_value: runInventoryStockValueDataset,
  inventory_opening_closing: runInventoryOpeningClosingDataset,
  inventory_stock_received: runInventoryStockReceivedDataset,
  inventory_stock_issued: runInventoryStockIssuedDataset,
  inventory_stock_adjustments: runInventoryStockAdjustmentsDataset,
  inventory_damaged_stock: runInventoryDamagedStockDataset,
  inventory_lost_stock: runInventoryLostStockDataset,
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
  buildBillingFinancialAnalytics,
  buildPharmacyDispenseThroughputAnalytics,
  buildPharmacyDrugConsumptionAnalytics,
  buildPharmacySalesAvgTransactionAnalytics,
  buildPharmacySalesDiscountsAnalytics,
  buildPharmacySalesNetRevenueAnalytics,
  buildPharmacySalesPaymentMethodAnalytics,
  buildPharmacySalesRefundsAnalytics,
  classifyStockRisk,
  classifyStockVelocity,
  computeStockValue,
  executeReportDataset,
  movementSignedDelta,
  resolveDateRange,
  resolveInventoryUnitCost,
  shouldUseMonthlyGranularity,
  summarizeBillingSeries,
  summarizeConsumptionSeries,
  summarizeThroughputSeries,
};
