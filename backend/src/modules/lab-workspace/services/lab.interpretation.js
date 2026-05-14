const {
  buildLabReferenceRangeRowSummary,
  toOptionalText,
} = require('@services/lab-workspace/lab.configuration');

const toText = (value) => (value == null ? '' : String(value).trim());

const normalizeToken = (value) =>
  toText(value)
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const toNumberOrNull = (value) => {
  const normalized = toText(value);
  if (!normalized) return null;
  const parsed = Number.parseFloat(normalized);
  return Number.isFinite(parsed) ? parsed : null;
};

const ageUnitToDays = (value, unit) => {
  const numericValue = Number.parseInt(String(value || ''), 10);
  if (!Number.isFinite(numericValue)) return null;
  const normalizedUnit = normalizeToken(unit);
  if (normalizedUnit === 'DAY') return numericValue;
  if (normalizedUnit === 'WEEK') return numericValue * 7;
  if (normalizedUnit === 'MONTH') return numericValue * 30;
  if (normalizedUnit === 'YEAR') return numericValue * 365;
  return null;
};

const resolvePatientAgeInDays = (patient = {}, now = new Date()) => {
  const dobValue = patient?.date_of_birth;
  if (!dobValue) return null;
  const parsedDob = dobValue instanceof Date ? dobValue : new Date(dobValue);
  if (Number.isNaN(parsedDob.getTime())) return null;
  const referenceDate = now instanceof Date ? now : new Date(now);
  if (Number.isNaN(referenceDate.getTime())) return null;
  return Math.max(
    0,
    Math.floor((referenceDate.getTime() - parsedDob.getTime()) / (24 * 60 * 60 * 1000))
  );
};

const resolveDefaultUnit = (test = {}) => {
  const defaultOption = Array.isArray(test?.unit_options)
    ? test.unit_options.find((entry) => entry?.is_default)
    : null;
  return (
    toOptionalText(defaultOption?.unit)
    || toOptionalText(test?.unit)
    || null
  );
};

const normalizeAliases = (value) => {
  if (Array.isArray(value)) return value.map((entry) => normalizeToken(entry)).filter(Boolean);
  const normalized = toText(value);
  if (!normalized) return [];
  return normalized
    .split(',')
    .map((entry) => normalizeToken(entry))
    .filter(Boolean);
};

const findQualitativeOption = (test = {}, resultValue, resultText) => {
  const options = Array.isArray(test?.result_options) ? test.result_options : [];
  if (!options.length) return null;

  const candidates = [resultValue, resultText]
    .map((entry) => normalizeToken(entry))
    .filter(Boolean);
  if (!candidates.length) return null;

  for (const option of options) {
    const tokens = new Set([
      normalizeToken(option?.value),
      normalizeToken(option?.label),
      ...normalizeAliases(option?.aliases_json || option?.aliases),
    ]);
    tokens.delete('');
    if (!tokens.size) continue;

    for (const candidate of candidates) {
      for (const token of tokens) {
        if (!token) continue;
        if (candidate === token) return option;
        const paddedCandidate = ` ${candidate} `;
        const paddedToken = ` ${token} `;
        if (paddedCandidate.includes(paddedToken)) return option;
      }
    }
  }

  return null;
};

const findHeuristicTextFlag = (resultValue, resultText) => {
  const candidate = normalizeToken(resultText || resultValue);
  if (!candidate) return null;

  const padded = ` ${candidate} `;
  const containsAny = (terms) =>
    terms.some((term) => padded.includes(` ${normalizeToken(term)} `));

  if (containsAny(['NOT DETECTED', 'NON REACTIVE', 'NEGATIVE', 'ABSENT'])) {
    return {
      status: 'NORMAL',
      result_flag: 'NEGATIVE',
      is_positive: false,
      source: 'HEURISTIC_NEGATIVE',
    };
  }

  if (containsAny(['POSITIVE', 'REACTIVE', 'DETECTED', 'PRESENT'])) {
    return {
      status: 'ABNORMAL',
      result_flag: 'POSITIVE',
      is_positive: true,
      source: 'HEURISTIC_POSITIVE',
    };
  }

  if (containsAny(['TRACE', 'EQUIVOCAL', 'INDETERMINATE'])) {
    return {
      status: 'ABNORMAL',
      result_flag: 'INDETERMINATE',
      is_positive: false,
      source: 'HEURISTIC_INDETERMINATE',
    };
  }

  return null;
};

const matchesReferenceRange = (range = {}, patient = {}, resolvedUnit) => {
  const rangeUnit = toOptionalText(range?.unit);
  if (rangeUnit && resolvedUnit && normalizeToken(rangeUnit) !== normalizeToken(resolvedUnit)) {
    return false;
  }

  const patientGender = normalizeToken(patient?.gender);
  const rangeGender = normalizeToken(range?.gender);
  if (rangeGender && patientGender && rangeGender !== patientGender) {
    return false;
  }
  if (rangeGender && !patientGender) {
    return false;
  }

  const patientAgeDays = resolvePatientAgeInDays(patient);
  const minAgeDays = ageUnitToDays(range?.age_min_value, range?.age_min_unit);
  const maxAgeDays = ageUnitToDays(range?.age_max_value, range?.age_max_unit);
  if (patientAgeDays != null) {
    if (minAgeDays != null && patientAgeDays < minAgeDays) return false;
    if (maxAgeDays != null && patientAgeDays > maxAgeDays) return false;
  } else if (minAgeDays != null || maxAgeDays != null) {
    return false;
  }

  return true;
};

const rankReferenceRange = (range = {}, resolvedUnit) => {
  const unitSpecified = Boolean(toOptionalText(range?.unit));
  const genderSpecified = Boolean(toOptionalText(range?.gender));
  const minSpecified = range?.age_min_value != null;
  const maxSpecified = range?.age_max_value != null;
  const exactUnitMatch =
    unitSpecified
    && resolvedUnit
    && normalizeToken(range?.unit) === normalizeToken(resolvedUnit);

  return (
    (exactUnitMatch ? 8 : unitSpecified ? 6 : 3)
    + (genderSpecified ? 2 : 1)
    + (minSpecified ? 1 : 0)
    + (maxSpecified ? 1 : 0)
  );
};

const selectReferenceRange = (test = {}, patient = {}, resolvedUnit) => {
  const ranges = Array.isArray(test?.reference_ranges) ? test.reference_ranges : [];
  const candidates = ranges.filter((range) => matchesReferenceRange(range, patient, resolvedUnit));
  if (!candidates.length) return null;

  return candidates.sort((left, right) => {
    const scoreDelta = rankReferenceRange(right, resolvedUnit) - rankReferenceRange(left, resolvedUnit);
    if (scoreDelta !== 0) return scoreDelta;
    return Number(left?.sort_order || 0) - Number(right?.sort_order || 0);
  })[0];
};

const evaluateNumericRange = (range = {}, numericValue) => {
  const criticalMin = toNumberOrNull(range?.critical_min_value);
  const criticalMax = toNumberOrNull(range?.critical_max_value);
  const normalMin = toNumberOrNull(range?.normal_min_value);
  const normalMax = toNumberOrNull(range?.normal_max_value);

  if (criticalMin != null && numericValue < criticalMin) {
    return { status: 'CRITICAL', result_flag: 'CRITICAL_LOW', is_positive: false };
  }
  if (criticalMax != null && numericValue > criticalMax) {
    return { status: 'CRITICAL', result_flag: 'CRITICAL_HIGH', is_positive: false };
  }
  if (normalMin != null && numericValue < normalMin) {
    return { status: 'ABNORMAL', result_flag: 'LOW', is_positive: false };
  }
  if (normalMax != null && numericValue > normalMax) {
    return { status: 'ABNORMAL', result_flag: 'HIGH', is_positive: false };
  }
  if (
    normalMin != null
    || normalMax != null
    || criticalMin != null
    || criticalMax != null
  ) {
    return { status: 'NORMAL', result_flag: null, is_positive: false };
  }
  return null;
};

const evaluateLabResult = ({
  test = {},
  patient = {},
  resultValue = null,
  resultText = null,
  resultUnit = null,
  fallbackStatus = 'PENDING',
} = {}) => {
  const resolvedUnit = toOptionalText(resultUnit) || resolveDefaultUnit(test);
  const qualitativeOption = findQualitativeOption(test, resultValue, resultText);
  if (qualitativeOption) {
    return {
      status: toText(qualitativeOption.status).toUpperCase() || 'ABNORMAL',
      result_flag: toOptionalText(qualitativeOption.result_flag) || normalizeToken(qualitativeOption.value),
      is_positive: Boolean(qualitativeOption.is_positive),
      result_unit: resolvedUnit,
      reference_range_label: null,
      reference_range_summary: null,
      source: 'QUALITATIVE_OPTION',
    };
  }

  const numericValue = toNumberOrNull(resultValue);
  if (numericValue != null) {
    const matchedRange = selectReferenceRange(test, patient, resolvedUnit);
    const numericEvaluation = matchedRange
      ? evaluateNumericRange(matchedRange, numericValue)
      : null;
    if (numericEvaluation) {
      return {
        ...numericEvaluation,
        result_unit: resolvedUnit,
        reference_range_label: toOptionalText(matchedRange?.label),
        reference_range_summary: buildLabReferenceRangeRowSummary(matchedRange) || null,
        source: 'NUMERIC_RANGE',
      };
    }
  }

  const heuristicFlag = findHeuristicTextFlag(resultValue, resultText);
  if (heuristicFlag) {
    return {
      ...heuristicFlag,
      result_unit: resolvedUnit,
      reference_range_label: null,
      reference_range_summary: null,
    };
  }

  return {
    status: toText(fallbackStatus).toUpperCase() || 'PENDING',
    result_flag: null,
    is_positive: false,
    result_unit: resolvedUnit,
    reference_range_label: null,
    reference_range_summary: null,
    source: 'FALLBACK',
  };
};

module.exports = {
  evaluateLabResult,
  findHeuristicTextFlag,
  findQualitativeOption,
  resolveDefaultUnit,
  resolvePatientAgeInDays,
  selectReferenceRange,
};
