const getByPath = (source, key) => {
  if (!source || typeof source !== 'object') return undefined;
  return String(key || '')
    .split('.')
    .filter(Boolean)
    .reduce((value, part) => (value && typeof value === 'object' ? value[part] : undefined), source);
};

const normalizeArray = (value) => {
  if (Array.isArray(value)) {
    return value.filter((entry) => entry !== undefined && entry !== null);
  }
  if (value === undefined || value === null) {
    return [];
  }
  return [value];
};

const matchValue = (actual, expected) => {
  if (expected === undefined) return true;
  if (expected === '*') return true;

  if (Array.isArray(expected)) {
    return expected.some((entry) => matchValue(actual, entry));
  }

  if (expected && typeof expected === 'object' && !Array.isArray(expected)) {
    if (Object.prototype.hasOwnProperty.call(expected, 'any_of')) {
      return normalizeArray(expected.any_of).some((entry) => matchValue(actual, entry));
    }
    if (Object.prototype.hasOwnProperty.call(expected, 'all_of')) {
      return normalizeArray(expected.all_of).every((entry) => matchValue(actual, entry));
    }
    if (Object.prototype.hasOwnProperty.call(expected, 'not')) {
      return !matchValue(actual, expected.not);
    }
    if (Object.prototype.hasOwnProperty.call(expected, 'includes')) {
      return normalizeArray(actual).some((entry) => normalizeArray(expected.includes).includes(entry));
    }
    if (Object.prototype.hasOwnProperty.call(expected, 'exists')) {
      return expected.exists ? actual !== undefined && actual !== null : actual === undefined || actual === null;
    }
  }

  if (Array.isArray(actual)) {
    return actual.some((entry) => matchValue(entry, expected));
  }

  return String(actual) === String(expected);
};

const matchConditions = (conditions, source) => {
  if (!conditions || typeof conditions !== 'object' || Array.isArray(conditions)) {
    return true;
  }

  return Object.entries(conditions).every(([key, expected]) => {
    const actual = getByPath(source, key);
    return matchValue(actual, expected);
  });
};

const sortPolicies = (policies = []) =>
  [...policies].sort((left, right) => {
    const priorityGap = Number(left?.priority || 0) - Number(right?.priority || 0);
    if (priorityGap !== 0) return priorityGap;
    if (left?.effect === right?.effect) return 0;
    return left?.effect === 'DENY' ? -1 : 1;
  });

const evaluatePolicies = ({
  policies = [],
  subject = {},
  object = {},
  environment = {},
} = {}) => {
  const matches = sortPolicies(policies).filter((policy) =>
    matchConditions(policy.subject_conditions_json, subject) &&
    matchConditions(policy.object_conditions_json, object) &&
    matchConditions(policy.environment_conditions_json, environment)
  );

  const winner = matches[0] || null;
  return {
    winner,
    matched: matches,
    allowed: winner ? winner.effect === 'ALLOW' : null,
  };
};

module.exports = {
  evaluatePolicies,
  getByPath,
  matchConditions,
  matchValue,
};
