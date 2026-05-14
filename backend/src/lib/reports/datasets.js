const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { REPORT_DATASET_MAP } = require('@lib/reports/constants');

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

  if (fromInput || toInput) {
    return {
      from: fromInput ? startOfDay(new Date(fromInput)) : shiftDays(startOfDay(now), -29),
      to: toInput ? endOfDay(new Date(toInput)) : endOfDay(now),
    };
  }

  if (preset === 'today') {
    return { from: startOfDay(now), to: endOfDay(now) };
  }
  if (preset === 'this_month') {
    const from = new Date(now.getFullYear(), now.getMonth(), 1);
    return { from, to: endOfDay(now) };
  }

  return {
    from: shiftDays(startOfDay(now), -29),
    to: endOfDay(now),
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
  const range = resolveDateRange(parameters);
  const [payments, invoices] = await Promise.all([
    prisma.payment.findMany({
      where: {
        ...buildTenantWhere(scope),
        paid_at: { gte: range.from, lte: range.to },
      },
      select: {
        paid_at: true,
        amount: true,
      },
    }),
    prisma.invoice.findMany({
      where: {
        ...buildTenantWhere(scope),
        issued_at: { gte: range.from, lte: range.to },
      },
      select: {
        issued_at: true,
        status: true,
      },
    }),
  ]);

  const paymentsByDate = aggregateByDate(payments, 'paid_at', {
    collections: (row) => asNumber(row.amount),
  });
  const invoicesByDate = aggregateByDate(invoices, 'issued_at', {
    issued_invoices: () => 1,
    open_invoices: (row) =>
      ['DRAFT', 'SENT', 'OVERDUE'].includes(String(row.status || '').toUpperCase()) ? 1 : 0,
  });

  const index = new Map();
  [...paymentsByDate, ...invoicesByDate].forEach((entry) => {
    if (!index.has(entry.date)) {
      index.set(entry.date, { date: entry.date, collections: 0, issued_invoices: 0, open_invoices: 0 });
    }
    const target = index.get(entry.date);
    target.collections += asNumber(entry.collections);
    target.issued_invoices += asNumber(entry.issued_invoices);
    target.open_invoices += asNumber(entry.open_invoices);
  });

  return {
    title: 'Billing collections and open balances',
    subtitle: `${range.from.toISOString().slice(0, 10)} to ${range.to.toISOString().slice(0, 10)}`,
    columns: ['date', 'collections', 'issued_invoices', 'open_invoices'],
    rows: Array.from(index.values()).sort((left, right) => left.date.localeCompare(right.date)),
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

  const rows = stocks
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
    }));

  return {
    title: 'Inventory stock risk',
    subtitle: 'Current low-stock and critical-stock pressure',
    columns: ['facility', 'inventory_item', 'quantity', 'reorder_level', 'risk_state'],
    rows,
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
  };
};

module.exports = {
  executeReportDataset,
  resolveDateRange,
};
