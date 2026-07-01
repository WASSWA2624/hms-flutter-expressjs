/**
 * Payroll compensation calculation helpers.
 *
 * Quantity sources:
 * - PER_HOUR: shift assignment durations in period
 * - PER_DAY: eligible workdays (availability slots + shift days minus approved leave)
 * - PER_MONTH: calendar proration over pay period; capped by eligible workdays when pay_frequency is not MONTHLY
 * - PER_CONSULTATION: completed OPD encounters attributed to staff provider user
 * - PER_PROCEDURE: completed procedures on staff encounters in period
 */

const daysBetweenInclusive = (start, end) => {
  const startDate = new Date(start);
  const endDate = new Date(end);
  if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) return 0;
  const startUtc = Date.UTC(startDate.getUTCFullYear(), startDate.getUTCMonth(), startDate.getUTCDate());
  const endUtc = Date.UTC(endDate.getUTCFullYear(), endDate.getUTCMonth(), endDate.getUTCDate());
  return Math.max(0, Math.floor((endUtc - startUtc) / 86400000) + 1);
};

const overlapDaysInclusive = (leftStart, leftEnd, rightStart, rightEnd) => {
  const start = new Date(Math.max(new Date(leftStart).getTime(), new Date(rightStart).getTime()));
  const end = new Date(Math.min(new Date(leftEnd).getTime(), new Date(rightEnd || leftEnd).getTime()));
  return daysBetweenInclusive(start, end);
};

const normalizeMoney = (value) => Number((Number(value || 0) || 0).toFixed(2));

const startOfDayKey = (value) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().slice(0, 10);
};

const enumerateDayKeys = (periodStart, periodEnd) => {
  const keys = [];
  const cursor = new Date(periodStart);
  const end = new Date(periodEnd);
  if (Number.isNaN(cursor.getTime()) || Number.isNaN(end.getTime())) return keys;

  cursor.setUTCHours(0, 0, 0, 0);
  end.setUTCHours(0, 0, 0, 0);
  while (cursor.getTime() <= end.getTime()) {
    keys.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return keys;
};

const isDayOnLeave = (dayKey, leaves = []) =>
  leaves.some((leave) => {
    const leaveStart = startOfDayKey(leave.start_date);
    const leaveEnd = startOfDayKey(leave.end_date);
    if (!leaveStart || !leaveEnd) return false;
    return dayKey >= leaveStart && dayKey <= leaveEnd;
  });

/**
 * Eligible workday = calendar day in period with availability or assigned shift, excluding approved leave.
 */
const computeEligibleWorkdays = ({
  periodStart,
  periodEnd,
  availabilityRecords = [],
  assignments = [],
  leaves = [],
}) => {
  const eligibleKeys = new Set();
  const periodKeys = enumerateDayKeys(periodStart, periodEnd);

  for (const assignment of assignments) {
    const dayKey = startOfDayKey(assignment?.shift?.start_time);
    if (dayKey && periodKeys.includes(dayKey) && !isDayOnLeave(dayKey, leaves)) {
      eligibleKeys.add(dayKey);
    }
  }

  for (const dayKey of periodKeys) {
    if (isDayOnLeave(dayKey, leaves)) continue;
    const dayOfWeek = new Date(`${dayKey}T00:00:00.000Z`).getUTCDay();
    const hasAvailability = availabilityRecords.some((record) => {
      if (String(record.preference || 'AVAILABLE').toUpperCase() === 'UNAVAILABLE') return false;
      const fromKey = startOfDayKey(record.effective_from);
      const toKey = record.effective_to ? startOfDayKey(record.effective_to) : '9999-12-31';
      if (!fromKey || dayKey < fromKey || dayKey > toKey) return false;
      return Number(record.day_of_week) === dayOfWeek;
    });
    if (hasAvailability) {
      eligibleKeys.add(dayKey);
    }
  }

  return {
    eligibleDays: eligibleKeys.size,
    eligibleDayKeys: [...eligibleKeys].sort(),
  };
};

const buildComponentResult = ({
  compensation,
  payType,
  rate,
  currency,
  quantity,
  unit,
  formula,
  sourceRefs = {},
  extra = {},
}) => {
  const amount = normalizeMoney(rate * quantity);
  return {
    amount,
    currency,
    calculation: {
      compensation_id: compensation?.id || compensation?.human_friendly_id || null,
      pay_type: payType,
      rate: normalizeMoney(rate),
      currency,
      quantity: normalizeMoney(quantity),
      unit,
      formula,
      amount,
      source_refs: sourceRefs,
      ...extra,
    },
    warning: quantity === 0 ? 'zero_quantity' : null,
  };
};

const calculateCompensationAmount = ({
  compensation,
  totalHours = 0,
  periodStart,
  periodEnd,
  eligibleWorkdays = { eligibleDays: 0, eligibleDayKeys: [] },
  consultationCount = 0,
  procedureCount = 0,
}) => {
  const payType = String(compensation?.pay_type || '').trim().toUpperCase();
  const rate = Number(compensation?.rate || 0) || 0;
  const currency = String(compensation?.currency || 'USD').trim().toUpperCase() || 'USD';
  const metadata = compensation?.metadata_json && typeof compensation.metadata_json === 'object'
    ? compensation.metadata_json
    : {};

  if (payType === 'PER_HOUR') {
    return buildComponentResult({
      compensation,
      payType,
      rate,
      currency,
      quantity: totalHours,
      unit: 'hours',
      formula: 'rate * hours',
      sourceRefs: { shift_hours: normalizeMoney(totalHours) },
    });
  }

  if (payType === 'PER_DAY') {
    const { eligibleDays, eligibleDayKeys } = eligibleWorkdays;
    return buildComponentResult({
      compensation,
      payType,
      rate,
      currency,
      quantity: eligibleDays,
      unit: 'days',
      formula: 'rate * eligible_days',
      sourceRefs: {
        eligible_days: eligibleDays,
        eligible_day_keys: eligibleDayKeys,
      },
    });
  }

  if (payType === 'PER_MONTH') {
    const periodDays = daysBetweenInclusive(periodStart, periodEnd) || 1;
    let eligibleDays = overlapDaysInclusive(
      compensation.effective_from || periodStart,
      compensation.effective_to || periodEnd,
      periodStart,
      periodEnd
    );
    const payFrequency = String(metadata.pay_frequency || 'MONTHLY').toUpperCase();
    if (payFrequency !== 'MONTHLY') {
      eligibleDays = Math.min(eligibleDays, eligibleWorkdays.eligibleDays || 0);
    }
    const quantity = eligibleDays / periodDays;
    return buildComponentResult({
      compensation,
      payType,
      rate,
      currency,
      quantity,
      unit: 'period_fraction',
      formula: 'rate * eligible_days / period_days',
      sourceRefs: {
        period_days: periodDays,
        eligible_days: eligibleDays,
        pay_frequency: payFrequency,
      },
      extra: { period_days: periodDays, eligible_days: eligibleDays },
    });
  }

  if (payType === 'PER_CONSULTATION') {
    const count = Number(consultationCount || 0) || 0;
    return buildComponentResult({
      compensation,
      payType,
      rate,
      currency,
      quantity: count,
      unit: 'consultations',
      formula: 'rate * consultation_count',
      sourceRefs: { consultation_count: count, source: 'encounter_opd_closed' },
    });
  }

  if (payType === 'PER_PROCEDURE') {
    const count = Number(procedureCount || 0) || 0;
    return buildComponentResult({
      compensation,
      payType,
      rate,
      currency,
      quantity: count,
      unit: 'procedures',
      formula: 'rate * procedure_count',
      sourceRefs: { procedure_count: count, source: 'procedure_performed_at' },
    });
  }

  return buildComponentResult({
    compensation,
    payType,
    rate,
    currency,
    quantity: 0,
    unit: 'unknown',
    formula: 'unsupported_pay_type',
  });
};

const sumCompensationAmounts = (calculations = []) => {
  const currency = calculations.find((item) => item.currency)?.currency || 'USD';
  const sameCurrency = calculations.filter((item) => item.currency === currency);
  const mixedCurrency = calculations.some((item) => item.currency && item.currency !== currency);
  const amount = normalizeMoney(sameCurrency.reduce((sum, item) => sum + Number(item.amount || 0), 0));
  const warnings = calculations
    .filter((item) => item.warning)
    .map((item) => ({
      pay_type: item.calculation?.pay_type,
      warning: item.warning,
    }));

  return { amount, currency, warnings, mixedCurrency };
};

module.exports = {
  daysBetweenInclusive,
  overlapDaysInclusive,
  normalizeMoney,
  enumerateDayKeys,
  computeEligibleWorkdays,
  calculateCompensationAmount,
  sumCompensationAmounts,
};
