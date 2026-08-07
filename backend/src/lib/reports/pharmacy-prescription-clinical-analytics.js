/**
 * Pharmacy prescription & clinical reporting.
 * Dosage/frequency/duration come from pharmacy_order_item columns only.
 * Alert/interaction reports are not invented here — keep those catalog ids unavailable
 * until real alert entities exist.
 */

const prisma = require('@prisma/client');

/**
 * Anti-infective filter: seed catalog codes from ANTI_INFECTIVE_DRUGS
 * (seed-clinical-catalog-pack.js). Amoxicillin AMX500 must remain in this set.
 */
const ANTI_INFECTIVE_DRUG_CODES = Object.freeze([
  'AMX500',
  'AMC625',
  'AZM500',
  'CFX400',
  'CFU500',
  'CRO1G',
  'CIP500',
  'CLX500',
  'DOX100',
  'FLX500',
  'GEN80I',
  'MTZ400',
  'MTZIV',
  'NFT100',
  'CTX960',
  'PNV250',
  'FLU150',
  'ACV400',
  'NYS100',
  'CLTCRM',
]);

/**
 * Controlled-drug set: prefer drug.is_controlled; fall back to Morphine/Tramadol codes.
 */
const CONTROLLED_DRUG_CODES = Object.freeze(['MRF10I', 'TRM50']);

const CONTROLLED_DRUG_SEED_KEYS = Object.freeze([
  'morphine_injection',
  'tramadol_50_capsule',
]);

const asNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const normalizeString = (value) => {
  if (value == null) return '';
  return String(value).trim();
};

const normalizeCode = (value) => normalizeString(value).toUpperCase();

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

/**
 * Plain dosage label from order_item columns — never parse free text into structure.
 * Prefer dosage string; else dose_amount + dose_unit.
 */
const formatDosagePlain = ({ dosage, dose_amount: doseAmount, dose_unit: doseUnit } = {}) => {
  const plain = normalizeString(dosage);
  if (plain) return plain;
  const amount = doseAmount == null || doseAmount === '' ? null : asNumber(doseAmount);
  const unit = normalizeString(doseUnit);
  if (amount == null || !(amount > 0)) return null;
  return unit ? `${amount} ${unit}` : String(amount);
};

/**
 * Convert duration_value + duration_unit to days when unit is recognized.
 * Returns null when unknown (do not invent).
 */
const durationInDays = (value, unit) => {
  if (value == null || value === '') return null;
  const amount = asNumber(value);
  if (!(amount > 0)) return null;
  const key = normalizeString(unit).toLowerCase();
  switch (key) {
    case 'hour':
    case 'hours':
      return Math.round((amount / 24) * 1000) / 1000;
    case 'day':
    case 'days':
      return amount;
    case 'week':
    case 'weeks':
      return amount * 7;
    case 'month':
    case 'months':
      return amount * 30;
    default:
      return null;
  }
};

const formatDurationPlain = (value, unit) => {
  if (value == null || value === '') return null;
  const amount = asNumber(value);
  if (!(amount > 0)) return null;
  const unitLabel = normalizeString(unit);
  return unitLabel ? `${amount} ${unitLabel}` : String(amount);
};

const isAntiInfectiveDrug = (drug = {}) => {
  const code = normalizeCode(drug.code);
  if (code && ANTI_INFECTIVE_DRUG_CODES.includes(code)) return true;
  return false;
};

const isControlledDrug = (drug = {}) => {
  if (drug.is_controlled === true || drug.is_controlled === 1) return true;
  const code = normalizeCode(drug.code);
  if (code && CONTROLLED_DRUG_CODES.includes(code)) return true;
  return false;
};

const providerSelect = {
  human_friendly_id: true,
  email: true,
  profile: {
    select: {
      first_name: true,
      last_name: true,
    },
  },
};

const invalidResult = (title, columns, summary = {}) => ({
  invalid: true,
  title,
  subtitle: 'Invalid date range',
  columns,
  rows: [],
  summary,
});

const buildPharmacyPrescriptionCountAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['orders_created'];
  if (range.invalid) {
    return invalidResult('Prescription count', columns, { orders_created: 0 });
  }

  const orders_created = await prisma.pharmacy_order.count({
    where: {
      ...buildPharmacyOrderScopeWhere(scope),
      ordered_at: { gte: range.from, lte: range.to },
    },
  });

  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Prescription count',
    subtitle: `${fromLabel} to ${toLabel} · pharmacy_order count (aligns with throughput orders_created)`,
    columns,
    rows: [{ orders_created }],
    summary: { orders_created },
  };
};

const buildPharmacyPrescriptionPrescriberAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['prescriber', 'orders_created'];
  if (range.invalid) {
    return invalidResult('Prescriber', columns, {
      orders_created: 0,
      prescriber_count: 0,
    });
  }

  const orders = await prisma.pharmacy_order.findMany({
    where: {
      ...buildPharmacyOrderScopeWhere(scope),
      ordered_at: { gte: range.from, lte: range.to },
      encounter_id: { not: null },
    },
    select: {
      encounter: {
        select: {
          provider: { select: providerSelect },
        },
      },
    },
  });

  const index = new Map();
  orders.forEach((order) => {
    const label = resolvePrescriberLabel(order?.encounter?.provider);
    if (!label) return;
    if (!index.has(label)) {
      index.set(label, { prescriber: label, orders_created: 0 });
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
    title: 'Prescriber',
    subtitle: `${fromLabel} to ${toLabel} · encounter.provider (clinical orders only)`,
    columns,
    rows,
    summary: { orders_created, prescriber_count: rows.length },
  };
};

const buildPharmacyPrescriptionDiagnosisAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['diagnosis', 'orders_created'];
  if (range.invalid) {
    return invalidResult('Diagnosis/indication', columns, {
      orders_created: 0,
      diagnosis_count: 0,
    });
  }

  const orders = await prisma.pharmacy_order.findMany({
    where: {
      ...buildPharmacyOrderScopeWhere(scope),
      ordered_at: { gte: range.from, lte: range.to },
      encounter_id: { not: null },
    },
    select: {
      encounter: {
        select: {
          diagnoses: {
            where: { deleted_at: null },
            select: {
              code: true,
              description: true,
              diagnosis_type: true,
            },
          },
        },
      },
    },
  });

  const index = new Map();
  orders.forEach((order) => {
    const diagnoses = Array.isArray(order?.encounter?.diagnoses)
      ? order.encounter.diagnoses
      : [];
    if (diagnoses.length === 0) return;
    // One order contributes once per distinct diagnosis label on the encounter.
    const seen = new Set();
    diagnoses.forEach((dx) => {
      const description = normalizeString(dx.description);
      const code = normalizeString(dx.code);
      const label = code && description ? `${code} · ${description}` : description || code;
      if (!label || seen.has(label)) return;
      seen.add(label);
      if (!index.has(label)) {
        index.set(label, { diagnosis: label, orders_created: 0 });
      }
      index.get(label).orders_created += 1;
    });
  });

  const rows = Array.from(index.values()).sort(
    (left, right) => asNumber(right.orders_created) - asNumber(left.orders_created)
  );
  const orders_created = rows.reduce((sum, row) => sum + asNumber(row.orders_created), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Diagnosis/indication',
    subtitle: `${fromLabel} to ${toLabel} · encounter diagnosis when encounter_id set`,
    columns,
    rows,
    summary: { orders_created, diagnosis_count: rows.length },
  };
};

const loadOrderItemsInRange = async (scope, range) =>
  prisma.pharmacy_order_item.findMany({
    where: {
      deleted_at: null,
      pharmacy_order: {
        ...buildPharmacyOrderScopeWhere(scope),
        ordered_at: { gte: range.from, lte: range.to },
      },
    },
    select: {
      quantity: true,
      dosage: true,
      dose_amount: true,
      dose_unit: true,
      frequency: true,
      duration_value: true,
      duration_unit: true,
      drug: {
        select: {
          id: true,
          name: true,
          code: true,
        },
      },
    },
  });

const buildPharmacyPrescriptionMedicineAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['drug', 'item_count', 'quantity'];
  if (range.invalid) {
    return invalidResult('Medicine prescribed', columns, {
      item_count: 0,
      quantity: 0,
    });
  }

  const items = await loadOrderItemsInRange(scope, range);
  const index = new Map();
  items.forEach((item) => {
    const label = normalizeString(item?.drug?.name) || normalizeString(item?.drug?.code);
    if (!label) return;
    if (!index.has(label)) {
      index.set(label, { drug: label, item_count: 0, quantity: 0 });
    }
    const row = index.get(label);
    row.item_count += 1;
    row.quantity += asNumber(item.quantity);
  });

  const rows = Array.from(index.values()).sort((left, right) => {
    const qtyDiff = asNumber(right.quantity) - asNumber(left.quantity);
    if (qtyDiff !== 0) return qtyDiff;
    return asNumber(right.item_count) - asNumber(left.item_count);
  });
  const item_count = rows.reduce((sum, row) => sum + asNumber(row.item_count), 0);
  const quantity = rows.reduce((sum, row) => sum + asNumber(row.quantity), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Medicine prescribed',
    subtitle: `${fromLabel} to ${toLabel} · pharmacy_order_item drug.name`,
    columns,
    rows,
    summary: { item_count, quantity },
  };
};

const buildPharmacyPrescriptionDosageAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['dosage', 'item_count'];
  if (range.invalid) {
    return invalidResult('Dosage', columns, { item_count: 0 });
  }

  const items = await loadOrderItemsInRange(scope, range);
  const index = new Map();
  items.forEach((item) => {
    const label = formatDosagePlain(item);
    if (!label) return;
    if (!index.has(label)) {
      index.set(label, { dosage: label, item_count: 0 });
    }
    index.get(label).item_count += 1;
  });

  const rows = Array.from(index.values()).sort(
    (left, right) => asNumber(right.item_count) - asNumber(left.item_count)
  );
  const item_count = rows.reduce((sum, row) => sum + asNumber(row.item_count), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Dosage',
    subtitle: `${fromLabel} to ${toLabel} · dosage or dose_amount+dose_unit plain`,
    columns,
    rows,
    summary: { item_count },
  };
};

const buildPharmacyPrescriptionFrequencyAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['frequency', 'item_count'];
  if (range.invalid) {
    return invalidResult('Frequency', columns, { item_count: 0 });
  }

  const items = await loadOrderItemsInRange(scope, range);
  const index = new Map();
  items.forEach((item) => {
    const label = normalizeString(item.frequency);
    if (!label) return;
    if (!index.has(label)) {
      index.set(label, { frequency: label, item_count: 0 });
    }
    index.get(label).item_count += 1;
  });

  const rows = Array.from(index.values()).sort(
    (left, right) => asNumber(right.item_count) - asNumber(left.item_count)
  );
  const item_count = rows.reduce((sum, row) => sum + asNumber(row.item_count), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Frequency',
    subtitle: `${fromLabel} to ${toLabel} · pharmacy_order_item.frequency plain`,
    columns,
    rows,
    summary: { item_count },
  };
};

const buildPharmacyPrescriptionDurationAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['duration', 'duration_days', 'item_count'];
  if (range.invalid) {
    return invalidResult('Duration', columns, { item_count: 0 });
  }

  const items = await loadOrderItemsInRange(scope, range);
  const index = new Map();
  items.forEach((item) => {
    const label = formatDurationPlain(item.duration_value, item.duration_unit);
    if (!label) return;
    const days = durationInDays(item.duration_value, item.duration_unit);
    if (!index.has(label)) {
      index.set(label, {
        duration: label,
        duration_days: days,
        item_count: 0,
      });
    }
    index.get(label).item_count += 1;
  });

  const rows = Array.from(index.values()).sort(
    (left, right) => asNumber(right.item_count) - asNumber(left.item_count)
  );
  const item_count = rows.reduce((sum, row) => sum + asNumber(row.item_count), 0);
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Duration',
    subtitle: `${fromLabel} to ${toLabel} · duration_value + duration_unit; duration_days when convertible`,
    columns,
    rows,
    summary: { item_count },
  };
};

const loadDispenseQtyByDrugFilter = async (scope, range, predicate) => {
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
          drug: {
            select: {
              name: true,
              code: true,
              is_controlled: true,
            },
          },
        },
      },
    },
  });

  const index = new Map();
  logs.forEach((log) => {
    const drug = log?.pharmacy_order_item?.drug;
    if (!predicate(drug || {})) return;
    const qty = asNumber(log.quantity_dispensed);
    if (!(qty > 0)) return;
    const label = normalizeString(drug?.name) || normalizeString(drug?.code);
    if (!label) return;
    if (!index.has(label)) {
      index.set(label, { drug: label, quantity_dispensed: 0 });
    }
    index.get(label).quantity_dispensed += qty;
  });

  return Array.from(index.values()).sort(
    (left, right) =>
      asNumber(right.quantity_dispensed) - asNumber(left.quantity_dispensed)
  );
};

const buildPharmacyPrescriptionAntibioticUsageAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['drug', 'quantity_dispensed'];
  if (range.invalid) {
    return invalidResult('Antibiotic usage', columns, {
      quantity_dispensed: 0,
      drug_count: 0,
    });
  }

  const rows = await loadDispenseQtyByDrugFilter(scope, range, isAntiInfectiveDrug);
  const quantity_dispensed = rows.reduce(
    (sum, row) => sum + asNumber(row.quantity_dispensed),
    0
  );
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Antibiotic usage',
    subtitle: `${fromLabel} to ${toLabel} · anti-infective codes ${ANTI_INFECTIVE_DRUG_CODES.join(',')}`,
    columns,
    rows,
    summary: { quantity_dispensed, drug_count: rows.length },
  };
};

const buildPharmacyPrescriptionControlledDispensingAnalytics = async (
  scope,
  parameters = {},
  resolveDateRange
) => {
  const range = resolveDateRange(parameters);
  const columns = ['drug', 'quantity_dispensed'];
  if (range.invalid) {
    return invalidResult('Controlled-drug dispensing', columns, {
      quantity_dispensed: 0,
      drug_count: 0,
    });
  }

  const rows = await loadDispenseQtyByDrugFilter(scope, range, isControlledDrug);
  const quantity_dispensed = rows.reduce(
    (sum, row) => sum + asNumber(row.quantity_dispensed),
    0
  );
  const fromLabel = range.from.toISOString().slice(0, 10);
  const toLabel = range.to.toISOString().slice(0, 10);

  return {
    invalid: false,
    title: 'Controlled-drug dispensing',
    subtitle: `${fromLabel} to ${toLabel} · drug.is_controlled (fallback codes ${CONTROLLED_DRUG_CODES.join(',')})`,
    columns,
    rows,
    summary: { quantity_dispensed, drug_count: rows.length },
  };
};

const wrapRunner = (builder, resolveDateRange) => async (scope, parameters = {}) => {
  const analytics = await builder(scope, parameters, resolveDateRange);
  return {
    title: analytics.title,
    subtitle: analytics.subtitle,
    columns: analytics.columns,
    rows: analytics.rows,
    summary: analytics.summary,
  };
};

const createPharmacyPrescriptionClinicalDatasetRunners = (resolveDateRange) =>
  Object.freeze({
    pharmacy_prescription_count: wrapRunner(
      buildPharmacyPrescriptionCountAnalytics,
      resolveDateRange
    ),
    pharmacy_prescription_prescriber: wrapRunner(
      buildPharmacyPrescriptionPrescriberAnalytics,
      resolveDateRange
    ),
    pharmacy_prescription_diagnosis: wrapRunner(
      buildPharmacyPrescriptionDiagnosisAnalytics,
      resolveDateRange
    ),
    pharmacy_prescription_medicine: wrapRunner(
      buildPharmacyPrescriptionMedicineAnalytics,
      resolveDateRange
    ),
    pharmacy_prescription_dosage: wrapRunner(
      buildPharmacyPrescriptionDosageAnalytics,
      resolveDateRange
    ),
    pharmacy_prescription_frequency: wrapRunner(
      buildPharmacyPrescriptionFrequencyAnalytics,
      resolveDateRange
    ),
    pharmacy_prescription_duration: wrapRunner(
      buildPharmacyPrescriptionDurationAnalytics,
      resolveDateRange
    ),
    pharmacy_prescription_antibiotic_usage: wrapRunner(
      buildPharmacyPrescriptionAntibioticUsageAnalytics,
      resolveDateRange
    ),
    pharmacy_prescription_controlled_dispensing: wrapRunner(
      buildPharmacyPrescriptionControlledDispensingAnalytics,
      resolveDateRange
    ),
  });

module.exports = {
  ANTI_INFECTIVE_DRUG_CODES,
  CONTROLLED_DRUG_CODES,
  CONTROLLED_DRUG_SEED_KEYS,
  createPharmacyPrescriptionClinicalDatasetRunners,
  durationInDays,
  formatDosagePlain,
  formatDurationPlain,
  isAntiInfectiveDrug,
  isControlledDrug,
  buildPharmacyPrescriptionCountAnalytics,
  buildPharmacyPrescriptionPrescriberAnalytics,
  buildPharmacyPrescriptionDiagnosisAnalytics,
  buildPharmacyPrescriptionMedicineAnalytics,
  buildPharmacyPrescriptionDosageAnalytics,
  buildPharmacyPrescriptionFrequencyAnalytics,
  buildPharmacyPrescriptionDurationAnalytics,
  buildPharmacyPrescriptionAntibioticUsageAnalytics,
  buildPharmacyPrescriptionControlledDispensingAnalytics,
};
