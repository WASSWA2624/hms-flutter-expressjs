/**
 * Clinical alert threshold service
 *
 * @module modules/clinical-alert-threshold/services
 * @description Threshold configuration and automatic vital alert evaluation.
 */

const prisma = require('@prisma/client');
const clinicalAlertThresholdRepository = require('@repositories/clinical-alert-threshold/clinical-alert-threshold.repository');
const clinicalAlertService = require('@services/clinical-alert/clinical-alert.service');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');

const AGE_BANDS = Object.freeze({
  NEONATE: 'NEONATE',
  INFANT: 'INFANT',
  CHILD: 'CHILD',
  ADOLESCENT: 'ADOLESCENT',
  ADULT: 'ADULT',
});

const HEART_RATE_BANDS = Object.freeze({
  NEONATE: { normal_min: 100, normal_max: 180, critical_low: 80, critical_high: 200 },
  INFANT: { normal_min: 100, normal_max: 160, critical_low: 80, critical_high: 190 },
  CHILD: { normal_min: 70, normal_max: 130, critical_low: 55, critical_high: 160 },
  ADOLESCENT: { normal_min: 60, normal_max: 110, critical_low: 45, critical_high: 145 },
  ADULT: { normal_min: 60, normal_max: 100, critical_low: 45, critical_high: 140 },
});

const RESPIRATORY_RATE_BANDS = Object.freeze({
  NEONATE: { normal_min: 30, normal_max: 60, critical_low: 20, critical_high: 70 },
  INFANT: { normal_min: 30, normal_max: 53, critical_low: 18, critical_high: 65 },
  CHILD: { normal_min: 20, normal_max: 30, critical_low: 12, critical_high: 45 },
  ADOLESCENT: { normal_min: 12, normal_max: 20, critical_low: 8, critical_high: 30 },
  ADULT: { normal_min: 12, normal_max: 20, critical_low: 8, critical_high: 30 },
});

const BLOOD_PRESSURE_BANDS = Object.freeze({
  NEONATE: {
    SYSTOLIC: { normal_min: 60, normal_max: 90, critical_low: 50, critical_high: 110 },
    DIASTOLIC: { normal_min: 30, normal_max: 60, critical_low: 20, critical_high: 75 },
    MAP: { normal_min: 45, normal_max: 70, critical_low: 35, critical_high: 85 },
  },
  INFANT: {
    SYSTOLIC: { normal_min: 70, normal_max: 100, critical_low: 55, critical_high: 125 },
    DIASTOLIC: { normal_min: 35, normal_max: 65, critical_low: 25, critical_high: 80 },
    MAP: { normal_min: 50, normal_max: 75, critical_low: 40, critical_high: 90 },
  },
  CHILD: {
    SYSTOLIC: { normal_min: 90, normal_max: 110, critical_low: 75, critical_high: 140 },
    DIASTOLIC: { normal_min: 55, normal_max: 75, critical_low: 45, critical_high: 95 },
    MAP: { normal_min: 60, normal_max: 80, critical_low: 45, critical_high: 100 },
  },
  ADOLESCENT: {
    SYSTOLIC: { normal_min: 95, normal_max: 120, critical_low: 80, critical_high: 160 },
    DIASTOLIC: { normal_min: 60, normal_max: 80, critical_low: 50, critical_high: 105 },
    MAP: { normal_min: 65, normal_max: 90, critical_low: 50, critical_high: 110 },
  },
  ADULT: {
    SYSTOLIC: { normal_min: 90, normal_max: 120, critical_low: 80, critical_high: 180 },
    DIASTOLIC: { normal_min: 60, normal_max: 80, critical_low: 50, critical_high: 120 },
    MAP: { normal_min: 70, normal_max: 100, critical_low: 55, critical_high: 130 },
  },
});

const DEFAULT_SINGLE_COMPONENT_BANDS = Object.freeze({
  TEMPERATURE: {
    normal_min: 36,
    normal_max: 37.5,
    critical_low: 35,
    critical_high: 39.5,
  },
  OXYGEN_SATURATION: {
    normal_min: 94,
    normal_max: 100,
    critical_low: 90,
    critical_high: null,
  },
});

const toNumber = (value) => {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value?.toNumber === 'function') {
    const parsed = value.toNumber();
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value?.toString === 'function') {
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

const cleanText = (value) => String(value || '').trim().toUpperCase();

const resolveAgeBand = (patient = null) => {
  const dateValue =
    patient?.date_of_birth ||
    patient?.dob ||
    patient?.birth_date ||
    patient?.dateOfBirth ||
    patient?.birthDate ||
    null;
  if (!dateValue) return AGE_BANDS.ADULT;

  const parsed = new Date(dateValue);
  if (Number.isNaN(parsed.getTime())) return AGE_BANDS.ADULT;

  const now = new Date();
  const dayMs = 24 * 60 * 60 * 1000;
  const ageDays = Math.max(0, Math.floor((now.getTime() - parsed.getTime()) / dayMs));

  let ageMonths = (now.getFullYear() - parsed.getFullYear()) * 12 + (now.getMonth() - parsed.getMonth());
  if (now.getDate() < parsed.getDate()) ageMonths -= 1;
  ageMonths = Math.max(0, ageMonths);

  let ageYears = now.getFullYear() - parsed.getFullYear();
  const monthDelta = now.getMonth() - parsed.getMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getDate() < parsed.getDate())) {
    ageYears -= 1;
  }
  ageYears = Math.max(0, ageYears);

  if (ageDays <= 28) return AGE_BANDS.NEONATE;
  if (ageMonths < 12) return AGE_BANDS.INFANT;
  if (ageYears < 13) return AGE_BANDS.CHILD;
  if (ageYears < 18) return AGE_BANDS.ADOLESCENT;
  return AGE_BANDS.ADULT;
};

const buildThresholdKey = (vitalType, component, ageBand) =>
  `${cleanText(vitalType)}::${cleanText(component)}::${cleanText(ageBand)}`;

const normalizeThresholdRow = (row, source = 'TENANT') => ({
  id: row.id || null,
  tenant_id: row.tenant_id || null,
  facility_id: row.facility_id || null,
  vital_type: cleanText(row.vital_type),
  component: cleanText(row.component),
  age_band: cleanText(row.age_band),
  normal_min: toNumber(row.normal_min),
  normal_max: toNumber(row.normal_max),
  critical_low: toNumber(row.critical_low),
  critical_high: toNumber(row.critical_high),
  is_active: row.is_active !== false,
  source,
});

const buildSeedThresholdRows = () => {
  const rows = [];

  for (const [ageBand, limits] of Object.entries(HEART_RATE_BANDS)) {
    rows.push({
      vital_type: 'HEART_RATE',
      component: 'VALUE',
      age_band: ageBand,
      ...limits,
      source: 'GLOBAL',
    });
  }

  for (const [ageBand, limits] of Object.entries(RESPIRATORY_RATE_BANDS)) {
    rows.push({
      vital_type: 'RESPIRATORY_RATE',
      component: 'VALUE',
      age_band: ageBand,
      ...limits,
      source: 'GLOBAL',
    });
  }

  for (const [ageBand, components] of Object.entries(BLOOD_PRESSURE_BANDS)) {
    for (const [component, limits] of Object.entries(components)) {
      rows.push({
        vital_type: 'BLOOD_PRESSURE',
        component,
        age_band: ageBand,
        ...limits,
        source: 'GLOBAL',
      });
    }
  }

  for (const ageBand of Object.values(AGE_BANDS)) {
    rows.push({
      vital_type: 'TEMPERATURE',
      component: 'VALUE',
      age_band: ageBand,
      ...DEFAULT_SINGLE_COMPONENT_BANDS.TEMPERATURE,
      source: 'GLOBAL',
    });
    rows.push({
      vital_type: 'OXYGEN_SATURATION',
      component: 'VALUE',
      age_band: ageBand,
      ...DEFAULT_SINGLE_COMPONENT_BANDS.OXYGEN_SATURATION,
      source: 'GLOBAL',
    });
  }

  return rows.map((row) => normalizeThresholdRow(row, 'GLOBAL'));
};

const GLOBAL_DEFAULT_THRESHOLDS = buildSeedThresholdRows();

const resolveEffectiveThresholds = async ({ tenant_id, facility_id = null, vital_type = null }) => {
  const dbRows = await clinicalAlertThresholdRepository.findMany({
    tenant_id,
    is_active: true,
    ...(vital_type ? { vital_type: cleanText(vital_type) } : {}),
    OR: facility_id ? [{ facility_id: facility_id || null }, { facility_id: null }] : [{ facility_id: null }],
  });

  const thresholdMap = new Map();
  GLOBAL_DEFAULT_THRESHOLDS
    .filter((row) => (vital_type ? cleanText(row.vital_type) === cleanText(vital_type) : true))
    .forEach((row) => {
      thresholdMap.set(buildThresholdKey(row.vital_type, row.component, row.age_band), row);
    });

  dbRows
    .filter((row) => row.facility_id == null)
    .forEach((row) => {
      const normalized = normalizeThresholdRow(row, 'TENANT');
      thresholdMap.set(
        buildThresholdKey(normalized.vital_type, normalized.component, normalized.age_band),
        normalized
      );
    });

  dbRows
    .filter((row) => facility_id && row.facility_id === facility_id)
    .forEach((row) => {
      const normalized = normalizeThresholdRow(row, 'FACILITY');
      thresholdMap.set(
        buildThresholdKey(normalized.vital_type, normalized.component, normalized.age_band),
        normalized
      );
    });

  return Array.from(thresholdMap.values()).sort((a, b) => {
    if (a.vital_type !== b.vital_type) return a.vital_type.localeCompare(b.vital_type);
    if (a.component !== b.component) return a.component.localeCompare(b.component);
    return a.age_band.localeCompare(b.age_band);
  });
};

const listClinicalAlertThresholds = async (filters = {}, context = {}) => {
  const tenantId = filters.tenant_id || context.tenant_id || null;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const facilityId =
    filters.facility_id !== undefined
      ? filters.facility_id || null
      : context.facility_id || null;

  const thresholds = await resolveEffectiveThresholds({
    tenant_id: tenantId,
    facility_id: facilityId,
    vital_type: filters.vital_type || null,
  });

  return {
    tenant_id: tenantId,
    facility_id: facilityId,
    thresholds,
  };
};

const updateClinicalAlertThresholds = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id || null;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const facilityId = payload.facility_id || null;
  const rules = Array.isArray(payload.rules) ? payload.rules : [];
  if (rules.length === 0) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'rules' }]);
  }

  const now = new Date();
  const rowsToCreate = rules.map((rule) => ({
    tenant_id: tenantId,
    facility_id: facilityId,
    vital_type: cleanText(rule.vital_type),
    component: cleanText(rule.component || 'VALUE'),
    age_band: cleanText(rule.age_band || AGE_BANDS.ADULT),
    normal_min: toNumber(rule.normal_min),
    normal_max: toNumber(rule.normal_max),
    critical_low: toNumber(rule.critical_low),
    critical_high: toNumber(rule.critical_high),
    is_active: rule.is_active !== false,
    created_at: now,
    updated_at: now,
  }));

  await prisma.$transaction(async (tx) => {
    await tx.clinical_vital_alert_threshold.updateMany({
      where: {
        deleted_at: null,
        tenant_id: tenantId,
        facility_id: facilityId,
      },
      data: {
        is_active: false,
        deleted_at: now,
      },
    });

    await tx.clinical_vital_alert_threshold.createMany({
      data: rowsToCreate,
    });
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'clinical_vital_alert_threshold',
    entity_id: `${tenantId}:${facilityId || 'TENANT_DEFAULT'}`,
    diff: {
      after: {
        tenant_id: tenantId,
        facility_id: facilityId,
        rule_count: rowsToCreate.length,
      },
    },
    ip_address: context.ip_address,
  }).catch(() => {});

  return listClinicalAlertThresholds({ tenant_id: tenantId, facility_id: facilityId }, context);
};

const parseBloodPressureValue = (value) => {
  const match = String(value || '')
    .trim()
    .match(/^(\d{2,3}(?:\.\d{1,2})?)\s*\/\s*(\d{2,3}(?:\.\d{1,2})?)$/);
  if (!match) return null;
  return {
    systolic: toNumber(match[1]),
    diastolic: toNumber(match[2]),
  };
};

const extractMeasuredComponents = (vitalSign = {}) => {
  const vitalType = cleanText(vitalSign.vital_type);
  if (!vitalType) return [];

  if (vitalType === 'BLOOD_PRESSURE') {
    const parsedLegacy = parseBloodPressureValue(vitalSign.value);
    const systolic = toNumber(vitalSign.systolic_value) ?? parsedLegacy?.systolic ?? null;
    const diastolic = toNumber(vitalSign.diastolic_value) ?? parsedLegacy?.diastolic ?? null;
    const mapValue = toNumber(vitalSign.map_value);

    const rows = [];
    if (systolic != null) rows.push({ vital_type: vitalType, component: 'SYSTOLIC', numeric_value: systolic });
    if (diastolic != null) rows.push({ vital_type: vitalType, component: 'DIASTOLIC', numeric_value: diastolic });
    if (mapValue != null) rows.push({ vital_type: vitalType, component: 'MAP', numeric_value: mapValue });
    return rows;
  }

  const numericValue = toNumber(vitalSign.value);
  if (numericValue == null) return [];
  return [{ vital_type: vitalType, component: 'VALUE', numeric_value: numericValue }];
};

const evaluateAgainstThreshold = (numericValue, threshold) => {
  const criticalLow = toNumber(threshold.critical_low);
  const criticalHigh = toNumber(threshold.critical_high);
  const normalMin = toNumber(threshold.normal_min);
  const normalMax = toNumber(threshold.normal_max);

  if (criticalLow != null && numericValue < criticalLow) return { state: 'CRITICAL_LOW' };
  if (criticalHigh != null && numericValue > criticalHigh) return { state: 'CRITICAL_HIGH' };
  if (normalMin != null && numericValue < normalMin) return { state: 'LOW' };
  if (normalMax != null && numericValue > normalMax) return { state: 'HIGH' };
  return { state: 'NORMAL' };
};

const severityForState = (state) => {
  if (state === 'CRITICAL_LOW' || state === 'CRITICAL_HIGH') return 'CRITICAL';
  if (state === 'LOW' || state === 'HIGH') return 'HIGH';
  return null;
};

const evaluateVitalAndCreateAlerts = async (payload = {}, context = {}) => {
  if (!isFeatureEnabled('clinical_alert_auto_rules')) {
    return [];
  }

  const encounter = payload.encounter || null;
  const vitalSign = payload.vitalSign || null;
  if (!encounter?.id || !encounter?.tenant_id || !vitalSign?.id) {
    return [];
  }

  const measurements = extractMeasuredComponents(vitalSign);
  if (measurements.length === 0) return [];

  const ageBand = resolveAgeBand(payload.patient || encounter?.patient || null);
  const effectiveThresholds = await resolveEffectiveThresholds({
    tenant_id: encounter.tenant_id,
    facility_id: encounter.facility_id || null,
    vital_type: measurements[0].vital_type,
  });

  const alerts = [];
  for (const measurement of measurements) {
    const threshold =
      effectiveThresholds.find(
        (rule) =>
          cleanText(rule.vital_type) === measurement.vital_type &&
          cleanText(rule.component) === cleanText(measurement.component) &&
          cleanText(rule.age_band) === ageBand
      ) ||
      effectiveThresholds.find(
        (rule) =>
          cleanText(rule.vital_type) === measurement.vital_type &&
          cleanText(rule.component) === cleanText(measurement.component) &&
          cleanText(rule.age_band) === AGE_BANDS.ADULT
      );

    if (!threshold) continue;

    const evaluation = evaluateAgainstThreshold(measurement.numeric_value, threshold);
    const severity = severityForState(evaluation.state);
    if (!severity) continue;

    const componentLabel = measurement.component === 'VALUE' ? '' : `${measurement.component} `;
    const message = `${measurement.vital_type} ${componentLabel}value ${measurement.numeric_value} is ${evaluation.state.toLowerCase().replace('_', ' ')}`.trim();

    const alert = await clinicalAlertService.createAutoVitalClinicalAlert(
      {
        encounter_id: encounter.id,
        severity,
        message,
        vital_sign_id: vitalSign.id,
      },
      context.user_id,
      context.ip_address
    );
    alerts.push(alert);
  }

  return alerts;
};

module.exports = {
  listClinicalAlertThresholds,
  updateClinicalAlertThresholds,
  evaluateVitalAndCreateAlerts,
  resolveEffectiveThresholds,
};

