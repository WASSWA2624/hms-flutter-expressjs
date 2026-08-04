const normalizeCatalogValue = (value) =>
  String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const normalizeUnit = (value) =>
  String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '');

const normalizeOptionValue = (value) =>
  String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');

const assertArray = (value, label) => {
  if (!Array.isArray(value)) {
    throw new TypeError(`${label} must be an array`);
  }
};

const assertUniqueFields = (catalog, { label = 'catalog', fields = [] } = {}) => {
  assertArray(catalog, label);

  for (const field of fields) {
    const seen = new Map();
    for (const [index, entry] of catalog.entries()) {
      const normalized = normalizeCatalogValue(entry?.[field]);
      if (!normalized) {
        throw new Error(`${label}[${index}] is missing ${field}`);
      }
      if (seen.has(normalized)) {
        throw new Error(
          `${label} has duplicate ${field} "${entry[field]}" at indexes ${seen.get(normalized)} and ${index}`
        );
      }
      seen.set(normalized, index);
    }
  }
};

const assertBoundOrder = (range, minimumField, maximumField, context) => {
  const minimum = range?.[minimumField];
  const maximum = range?.[maximumField];
  if (minimum == null || maximum == null) return;
  if (Number(minimum) > Number(maximum)) {
    throw new Error(`${context} has ${minimumField} greater than ${maximumField}`);
  }
};

const assertFiniteNumber = (range, field, context) => {
  if (range?.[field] == null) return;
  if (!Number.isFinite(Number(range[field]))) {
    throw new Error(`${context}.${field} must be a finite number`);
  }
};

const assertAgePair = (range, valueField, unitField, context) => {
  const hasValue = range?.[valueField] != null;
  const hasUnit = Boolean(range?.[unitField]);
  if (hasValue !== hasUnit) {
    throw new Error(`${context} must provide ${valueField} and ${unitField} together`);
  }
  if (hasValue && (!Number.isInteger(Number(range[valueField])) || Number(range[valueField]) < 0)) {
    throw new Error(`${context}.${valueField} must be a non-negative integer`);
  }
};

const AGE_UNIT_DAYS = Object.freeze({
  DAY: 1,
  WEEK: 7,
  MONTH: 30.4375,
  YEAR: 365.25,
});

const buildRangeSelectorKey = (range) =>
  [
    normalizeUnit(range?.unit),
    normalizeCatalogValue(range?.method),
    normalizeCatalogValue(range?.gender),
    range?.age_min_value ?? '',
    normalizeCatalogValue(range?.age_min_unit),
    range?.age_max_value ?? '',
    normalizeCatalogValue(range?.age_max_unit),
    range?.effective_from ? new Date(range.effective_from).toISOString() : '',
    range?.effective_to ? new Date(range.effective_to).toISOString() : '',
    range?.version ?? 1,
  ].join('|');

const assertLabCatalogIntegrity = ({ tests, panels }) => {
  assertUniqueFields(tests, {
    label: 'LAB_TEST_CATALOG',
    fields: ['key', 'name', 'code'],
  });
  assertUniqueFields(panels, {
    label: 'LAB_PANEL_CATALOG',
    fields: ['key', 'name', 'code'],
  });

  const testKeys = new Set(tests.map((test) => test.key));
  const allowedKinds = new Set(['NUMERIC', 'QUALITATIVE', 'TEXT']);
  const allowedAgeUnits = new Set(['DAY', 'WEEK', 'MONTH', 'YEAR']);
  const allowedGenders = new Set(['MALE', 'FEMALE', 'OTHER', 'UNKNOWN']);

  for (const test of tests) {
    const context = `LAB_TEST_CATALOG.${test.key}`;
    if (!allowedKinds.has(test.result_kind)) {
      throw new Error(`${context} has unsupported result_kind ${test.result_kind}`);
    }

    assertArray(test.unit_options, `${context}.unit_options`);
    assertArray(test.reference_ranges, `${context}.reference_ranges`);
    assertArray(test.result_options, `${context}.result_options`);
    if (test.reference_ranges.length > 25) {
      throw new Error(`${context} exceeds the API limit of 25 reference ranges`);
    }

    const unitTokens = new Set();
    let defaultUnitCount = 0;
    for (const option of test.unit_options) {
      const token = normalizeUnit(option?.unit);
      if (!token) throw new Error(`${context} has a unit option without a unit`);
      if (unitTokens.has(token)) throw new Error(`${context} has duplicate unit option ${option.unit}`);
      unitTokens.add(token);
      if (option.is_default) defaultUnitCount += 1;
    }
    if (defaultUnitCount > 1) {
      throw new Error(`${context} has more than one default unit`);
    }
    if (test.unit && test.unit_options.length > 0 && !unitTokens.has(normalizeUnit(test.unit))) {
      throw new Error(`${context}.unit is not present in unit_options`);
    }

    const selectors = new Set();
    for (const [index, range] of test.reference_ranges.entries()) {
      const rangeContext = `${context}.reference_ranges[${index}]`;
      assertAgePair(range, 'age_min_value', 'age_min_unit', rangeContext);
      assertAgePair(range, 'age_max_value', 'age_max_unit', rangeContext);
      if (range.age_min_unit && !allowedAgeUnits.has(range.age_min_unit)) {
        throw new Error(`${rangeContext} has invalid age_min_unit ${range.age_min_unit}`);
      }
      if (range.age_max_unit && !allowedAgeUnits.has(range.age_max_unit)) {
        throw new Error(`${rangeContext} has invalid age_max_unit ${range.age_max_unit}`);
      }
      if (range.gender && !allowedGenders.has(range.gender)) {
        throw new Error(`${rangeContext} has invalid gender ${range.gender}`);
      }
      if (range.unit && unitTokens.size > 0 && !unitTokens.has(normalizeUnit(range.unit))) {
        throw new Error(`${rangeContext}.unit is not present in ${context}.unit_options`);
      }

      assertBoundOrder(range, 'normal_min_value', 'normal_max_value', rangeContext);
      assertBoundOrder(range, 'critical_min_value', 'critical_max_value', rangeContext);
      for (const field of [
        'normal_min_value',
        'normal_max_value',
        'critical_min_value',
        'critical_max_value',
      ]) {
        assertFiniteNumber(range, field, rangeContext);
      }
      if (range.age_min_value != null && range.age_max_value != null) {
        const minimumDays =
          Number(range.age_min_value) * AGE_UNIT_DAYS[range.age_min_unit];
        const maximumDays =
          Number(range.age_max_value) * AGE_UNIT_DAYS[range.age_max_unit];
        if (minimumDays > maximumDays) {
          throw new Error(`${rangeContext} has a minimum age greater than its maximum age`);
        }
      }

      const selector = buildRangeSelectorKey(range);
      if (selectors.has(selector)) {
        throw new Error(`${rangeContext} duplicates an age/gender/unit/method selector`);
      }
      selectors.add(selector);
    }

    if (test.result_kind === 'QUALITATIVE') {
      const values = new Set();
      for (const option of test.result_options) {
        const token = normalizeOptionValue(option?.value);
        if (!token) throw new Error(`${context} has a result option without a value`);
        if (values.has(token)) throw new Error(`${context} has duplicate result option ${option.value}`);
        values.add(token);
      }
    }
  }

  const panelMemberships = new Map();
  for (const panel of panels) {
    const context = `LAB_PANEL_CATALOG.${panel.key}`;
    assertArray(panel.test_keys, `${context}.test_keys`);
    const panelKeys = new Set();
    for (const testKey of panel.test_keys) {
      if (!testKeys.has(testKey)) {
        throw new Error(`${context} references unknown test key ${testKey}`);
      }
      if (panelKeys.has(testKey)) {
        throw new Error(`${context} contains duplicate test key ${testKey}`);
      }
      panelKeys.add(testKey);
    }

    const membership = [...panelKeys].sort().join('|');
    if (panelMemberships.has(membership)) {
      throw new Error(
        `${context} duplicates the membership of LAB_PANEL_CATALOG.${panelMemberships.get(membership)}`
      );
    }
    panelMemberships.set(membership, panel.key);
  }
};

module.exports = {
  assertLabCatalogIntegrity,
  assertUniqueFields,
  normalizeCatalogValue,
};
