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

/**
 * Pharmacy drug consumption analytics for a period.
 * Amount prefers drug.unit_price × quantity_dispensed; falls back to billing_snapshot line unit_price.
 */
const buildPharmacyDrugConsumptionAnalytics = async (scope, parameters = {}) => {
  const range = resolveDateRange(parameters);
  const columns = ['drug', 'quantity_dispensed', 'amount', 'profit', 'order_source'];
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
            },
          },
          pharmacy_order: {
            select: {
              encounter_id: true,
              billing_snapshot: true,
            },
          },
        },
      },
    },
  });

  const drugIndex = new Map();
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

  const rows = Array.from(drugIndex.values())
    .map((entry) => {
      const sourceEntries = Array.from(entry.sources.entries()).sort(
        (left, right) => right[1] - left[1]
      );
      const orderSource =
        sourceEntries.length === 1 ? sourceEntries[0][0] : sourceEntries.length > 1 ? 'MIXED' : 'UNKNOWN';
      return {
        drug: entry.drug,
        quantity_dispensed: entry.quantity_dispensed,
        amount: Math.round(entry.amount * 100) / 100,
        profit: entry.profit,
        order_source: orderSource,
      };
    })
    .sort((left, right) => {
      const qtyDiff = asNumber(right.quantity_dispensed) - asNumber(left.quantity_dispensed);
      if (qtyDiff !== 0) return qtyDiff;
      return asNumber(right.amount) - asNumber(left.amount);
    })
    .slice(0, topLimit);

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

  return {
    invalid: false,
    reason: null,
    preset: range.preset,
    from: range.from,
    to: range.to,
    granularity: monthly ? 'month' : 'day',
    title: 'Pharmacy drug consumption',
    subtitle: `${fromLabel} to ${toLabel} (top ${rows.length} by quantity)${sourceLabel}`,
    columns,
    rows,
    summary: {
      ...summarizeConsumptionSeries(rows),
      profit: rows.reduce((sum, row) => sum + asNumber(row.profit), 0),
      source_mix,
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

const runInventoryDataset = async (scope) => {
  const stocks = await prisma.inventory_stock.findMany({
    where: {
      deleted_at: null,
      inventory_item: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
      },
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    },
    select: {
      quantity: true,
      reorder_level: true,
      facility: { select: { name: true } },
      inventory_item: { select: { name: true } },
    },
  });

  const stockRows = stocks
    .filter((entry) => asNumber(entry.reorder_level) > 0 && asNumber(entry.quantity) <= asNumber(entry.reorder_level))
    .map((entry) => ({
      facility: entry?.facility?.name || scope.facility_label || 'Unassigned',
      inventory_item: entry?.inventory_item?.name || 'Unknown',
      quantity: asNumber(entry.quantity),
      reorder_level: asNumber(entry.reorder_level),
      risk_state:
        asNumber(entry.quantity) <= Math.max(1, Math.floor(asNumber(entry.reorder_level) / 2))
          ? 'CRITICAL'
          : 'LOW',
      expiry_date: null,
      expiry_alert_status: null,
      days_to_expiry: null,
      batch_number: null,
    }));

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
      drug: { select: { name: true } },
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
    expiryRows.push({
      facility:
        batch?.storage_room?.facility?.name ||
        scope.facility_label ||
        'Unassigned',
      inventory_item: normalizeString(batch?.drug?.name) || 'Unknown',
      quantity: asNumber(batch.quantity),
      reorder_level: null,
      risk_state: status,
      expiry_date: batch.expiry_date
        ? new Date(batch.expiry_date).toISOString().slice(0, 10)
        : null,
      expiry_alert_status: status,
      days_to_expiry: daysToExpiry,
      batch_number: normalizeString(batch.batch_number) || null,
    });
  }

  const rows = [...stockRows, ...expiryRows].sort((left, right) => {
    const rank = (state) => {
      if (state === 'EXPIRED' || state === 'CRITICAL') return 0;
      if (state === 'EXPIRING_SOON' || state === 'LOW') return 1;
      return 2;
    };
    const byRisk = rank(left.risk_state) - rank(right.risk_state);
    if (byRisk !== 0) return byRisk;
    return asNumber(left.days_to_expiry ?? 9999) - asNumber(right.days_to_expiry ?? 9999);
  });

  return {
    title: 'Inventory stock risk',
    subtitle: 'Low-stock, critical-stock, near-expiry, and expired batch pressure',
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
    ],
    rows,
    summary: {
      low_stock: stockRows.filter((row) => row.risk_state === 'LOW').length,
      critical_stock: stockRows.filter((row) => row.risk_state === 'CRITICAL').length,
      expiring_soon: expiryRows.filter((row) => row.risk_state === 'EXPIRING_SOON').length,
      expired: expiryRows.filter((row) => row.risk_state === 'EXPIRED').length,
      total_risk_rows: rows.length,
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
  inventory_stock_risk: runInventoryDataset,
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
  executeReportDataset,
  resolveDateRange,
  shouldUseMonthlyGranularity,
  summarizeBillingSeries,
  summarizeConsumptionSeries,
  summarizeThroughputSeries,
};
