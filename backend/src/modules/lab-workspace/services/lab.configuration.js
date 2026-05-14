const toText = (value) => (value == null ? '' : String(value).trim());

const toOptionalText = (value) => {
  const normalized = toText(value);
  return normalized || null;
};

const toIntegerOrNull = (value) => {
  const normalized = toText(value);
  if (!normalized) return null;
  const parsed = Number.parseInt(normalized, 10);
  return Number.isNaN(parsed) ? null : parsed;
};

const toDecimalOrNull = (value) => {
  const normalized = toText(value);
  if (!normalized) return null;
  const parsed = Number.parseFloat(normalized);
  if (Number.isNaN(parsed)) return null;
  return parsed.toFixed(4);
};

const normalizeGenderValue = (value) => {
  const normalized = toText(value).toUpperCase();
  return normalized || null;
};

const normalizeAgeUnitValue = (value) => {
  const normalized = toText(value).toUpperCase();
  return normalized || null;
};

const buildAgeSummary = (value, unit) => {
  if (value == null || value === '') return '';
  const normalizedUnit = toText(unit).toLowerCase();
  if (!normalizedUnit) return String(value);
  return `${value} ${normalizedUnit}${Number(value) === 1 ? '' : 's'}`;
};

const buildNumericRangeSummary = (minimum, maximum) => {
  const minText = toText(minimum);
  const maxText = toText(maximum);
  if (minText && maxText) return `${minText} - ${maxText}`;
  if (minText) return `>= ${minText}`;
  if (maxText) return `<= ${maxText}`;
  return '';
};

const buildLabReferenceRangeRowSummary = (entry = {}) => {
  const ageMin = buildAgeSummary(entry.age_min_value, entry.age_min_unit);
  const ageMax = buildAgeSummary(entry.age_max_value, entry.age_max_unit);
  const unit = toText(entry.unit);
  const ageSummary =
    ageMin && ageMax
      ? `${ageMin} to ${ageMax}`
      : ageMin
        ? `${ageMin}+`
        : ageMax
          ? `up to ${ageMax}`
          : '';
  const normalSummary = buildNumericRangeSummary(
    entry.normal_min_value,
    entry.normal_max_value
  );
  const textSummary = toText(entry.reference_text);
  const fragments = [
    toText(entry.label),
    unit ? `Unit ${unit}` : '',
    toText(entry.gender),
    ageSummary,
    textSummary || normalSummary,
  ].filter(Boolean);
  return fragments.join(' | ');
};

const buildLabReferenceRangeSummary = (fallbackText, ranges = []) => {
  const fallback = toOptionalText(fallbackText);
  if (fallback) return fallback;
  const summaries = Array.isArray(ranges)
    ? ranges.map((entry) => buildLabReferenceRangeRowSummary(entry)).filter(Boolean)
    : [];
  if (!summaries.length) return null;
  return summaries.slice(0, 2).join('; ');
};

const normalizeLabReferenceRanges = (value = []) => {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry, index) => {
      if (!entry || typeof entry !== 'object') return null;
      return {
        label: toOptionalText(entry.label),
        unit: toOptionalText(entry.unit),
        gender: normalizeGenderValue(entry.gender),
        age_min_value: toIntegerOrNull(entry.age_min_value),
        age_min_unit: normalizeAgeUnitValue(entry.age_min_unit),
        age_max_value: toIntegerOrNull(entry.age_max_value),
        age_max_unit: normalizeAgeUnitValue(entry.age_max_unit),
        normal_min_value: toDecimalOrNull(entry.normal_min_value),
        normal_max_value: toDecimalOrNull(entry.normal_max_value),
        critical_min_value: toDecimalOrNull(entry.critical_min_value),
        critical_max_value: toDecimalOrNull(entry.critical_max_value),
        reference_text: toOptionalText(entry.reference_text),
        notes: toOptionalText(entry.notes),
        sort_order: index,
      };
    })
    .filter((entry) => entry);
};

const normalizeLabUnitOptions = (value = []) => {
  if (!Array.isArray(value)) return [];
  const normalized = value
    .map((entry, index) => {
      if (!entry || typeof entry !== 'object') return null;
      const unit = toOptionalText(entry.unit);
      if (!unit) return null;
      return {
        label: toOptionalText(entry.label),
        unit,
        ucum_code: toOptionalText(entry.ucum_code),
        is_default:
          typeof entry.is_default === 'boolean' ? entry.is_default : index === 0,
        sort_order: index,
      };
    })
    .filter((entry) => entry);

  if (!normalized.length) return [];

  const defaultIndex = normalized.findIndex((entry) => entry.is_default);
  if (defaultIndex < 0) {
    normalized[0].is_default = true;
  } else {
    normalized.forEach((entry, index) => {
      entry.is_default = index === defaultIndex;
    });
  }

  return normalized;
};

const normalizeResultOptionAliases = (value) => {
  if (Array.isArray(value)) {
    return value
      .map((entry) => toText(entry))
      .filter(Boolean);
  }

  const normalized = toText(value);
  if (!normalized) return [];
  return normalized
    .split(',')
    .map((entry) => toText(entry))
    .filter(Boolean);
};

const normalizeLabResultOptions = (value = []) => {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry, index) => {
      if (!entry || typeof entry !== 'object') return null;
      const optionValue = toText(entry.value).toUpperCase();
      if (!optionValue) return null;
      return {
        value: optionValue,
        label: toOptionalText(entry.label),
        aliases_json: normalizeResultOptionAliases(entry.aliases_json || entry.aliases),
        status: toText(entry.status).toUpperCase() || 'ABNORMAL',
        result_flag: toOptionalText(entry.result_flag),
        is_positive:
          typeof entry.is_positive === 'boolean' ? entry.is_positive : false,
        sort_order: index,
      };
    })
    .filter((entry) => entry);
};

const normalizeLabPanelItems = (value = []) => {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry, index) => {
      if (!entry || typeof entry !== 'object') return null;
      return {
        lab_test_id: toOptionalText(entry.lab_test_id),
        is_required:
          typeof entry.is_required === 'boolean' ? entry.is_required : true,
        instructions: toOptionalText(entry.instructions),
        sort_order: index,
      };
    })
    .filter((entry) => entry && entry.lab_test_id);
};

module.exports = {
  buildLabReferenceRangeRowSummary,
  buildLabReferenceRangeSummary,
  normalizeAgeUnitValue,
  normalizeGenderValue,
  normalizeLabPanelItems,
  normalizeLabResultOptions,
  normalizeLabReferenceRanges,
  normalizeLabUnitOptions,
  normalizeResultOptionAliases,
  toDecimalOrNull,
  toIntegerOrNull,
  toOptionalText,
};
