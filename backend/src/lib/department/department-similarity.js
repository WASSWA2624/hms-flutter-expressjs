/**
 * Department duplicate / similarity helpers.
 *
 * Facility-scoped weighted similarity across name, short name, type, and status.
 * Reuses tenant-similarity text scoring primitives.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore
} = require('@lib/tenant/tenant-similarity');

const NAME_WEIGHT = 50;
const SHORT_NAME_WEIGHT = 20;
const TYPE_WEIGHT = 20;
const STATUS_WEIGHT = 10;

const normalizeDepartmentType = (value) =>
  String(value || '')
    .trim()
    .toUpperCase();

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const buildCandidateSnapshot = (department) => ({
  id: department?.id || null,
  human_friendly_id: department?.human_friendly_id || null,
  display_id:
    department?.display_id || department?.human_friendly_id || department?.id || null,
  tenant_id: department?.tenant_id || null,
  facility_id: department?.facility_id || null,
  name: department?.name || null,
  short_name: department?.short_name || null,
  department_type: department?.department_type || null,
  is_active: department?.is_active !== false
});

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
    [scores.shortNameScore, SHORT_NAME_WEIGHT],
    [scores.typeScore, TYPE_WEIGHT],
    [scores.statusScore, STATUS_WEIGHT]
  ];

  let weightedTotal = 0;
  let weightSum = 0;
  for (const [score, weight] of weighted) {
    if (score == null) continue;
    weightedTotal += score * weight;
    weightSum += weight;
  }
  if (!weightSum) return 0;
  return Math.round(weightedTotal / weightSum);
};

const buildFieldComparison = ({
  field,
  inputValue,
  candidateValue,
  score,
  exact = false
}) => ({
  field,
  input_value: inputValue == null || inputValue === '' ? null : String(inputValue),
  candidate_value:
    candidateValue == null || candidateValue === '' ? null : String(candidateValue),
  score: score == null ? null : score,
  status: comparisonStatus(score, { exact })
});

/**
 * @param {Object} params
 * @param {string} params.name
 * @param {string|null|undefined} params.shortName
 * @param {string|null|undefined} params.departmentType
 * @param {boolean|null|undefined} params.isActive
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeDepartmentId]
 */
const checkDepartmentDuplicates = ({
  name,
  shortName,
  departmentType,
  isActive,
  existing = [],
  excludeDepartmentId = null
}) => {
  const normalizedName = normalizeText(name);
  const effectiveShortName =
    String(shortName || '').trim() || String(name || '').trim();
  const normalizedShortName = normalizeText(effectiveShortName);
  const normalizedType = normalizeDepartmentType(departmentType);
  const normalizedActive = isActive === false ? false : true;
  const excludeId = String(excludeDepartmentId || '').trim();

  let exactNameConflict = false;
  const matches = [];

  for (const department of existing) {
    const snapshot = buildCandidateSnapshot(department);
    const departmentId = String(snapshot.id || '').trim();
    const departmentFriendly = String(snapshot.human_friendly_id || '').trim();
    const departmentDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (departmentId === excludeId ||
        departmentFriendly === excludeId ||
        departmentDisplay === excludeId)
    ) {
      continue;
    }

    const departmentName = normalizeText(snapshot.name);
    const departmentShortName = normalizeText(
      snapshot.short_name || snapshot.name
    );
    const departmentTypeValue = normalizeDepartmentType(snapshot.department_type);
    const departmentActive = snapshot.is_active !== false;

    const nameExact = Boolean(normalizedName) && departmentName === normalizedName;
    const shortNameExact =
      Boolean(normalizedShortName) &&
      Boolean(departmentShortName) &&
      departmentShortName === normalizedShortName;
    const typeExact =
      Boolean(normalizedType) &&
      Boolean(departmentTypeValue) &&
      departmentTypeValue === normalizedType;
    const statusExact = departmentActive === normalizedActive;

    let nameScore = null;
    let shortNameScore = null;
    let typeScore = null;
    let statusScore = null;
    const reasons = [];

    if (normalizedName && departmentName) {
      nameScore = nameExact
        ? 100
        : textSimilarityScore(normalizedName, departmentName);
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (normalizedShortName && departmentShortName) {
      shortNameScore = shortNameExact
        ? 100
        : textSimilarityScore(normalizedShortName, departmentShortName);
      if (shortNameExact || shortNameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('short_name');
      }
    }

    if (normalizedType && departmentTypeValue) {
      typeScore = typeExact ? 100 : 0;
      if (typeExact) {
        reasons.push('department_type');
      }
    }

    statusScore = statusExact ? 100 : 0;
    if (statusExact) {
      reasons.push('status');
    }

    const score = compositeSimilarityScore({
      nameScore,
      shortNameScore,
      typeScore,
      statusScore
    });

    const fieldComparisons = [
      buildFieldComparison({
        field: 'name',
        inputValue: name,
        candidateValue: snapshot.name,
        score: nameScore,
        exact: nameExact
      }),
      buildFieldComparison({
        field: 'short_name',
        inputValue: effectiveShortName,
        candidateValue: snapshot.short_name || snapshot.name,
        score: shortNameScore,
        exact: shortNameExact
      }),
      buildFieldComparison({
        field: 'department_type',
        inputValue: departmentType,
        candidateValue: snapshot.department_type,
        score: typeScore,
        exact: typeExact
      }),
      buildFieldComparison({
        field: 'status',
        inputValue: normalizedActive ? 'active' : 'inactive',
        candidateValue: departmentActive ? 'active' : 'inactive',
        score: statusScore,
        exact: statusExact
      }),
      buildFieldComparison({
        field: 'display_id',
        inputValue: null,
        candidateValue: snapshot.display_id,
        score: null,
        exact: false
      })
    ].filter((entry) => entry.input_value != null || entry.candidate_value != null);

    if (nameExact) {
      exactNameConflict = true;
    }

    const isExact = nameExact;
    const strongIdentitySignal =
      (nameScore != null && nameScore >= SIMILARITY_THRESHOLD) ||
      (shortNameScore != null && shortNameScore >= SIMILARITY_THRESHOLD);
    const compositeSignal = score >= SIMILARITY_THRESHOLD;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    matches.push({
      ...snapshot,
      score,
      reasons: reasons.length ? reasons : ['name'],
      isExact,
      exactNameConflict: nameExact,
      nameScore,
      shortNameScore,
      typeScore,
      statusScore,
      field_comparisons: fieldComparisons
    });
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactNameConflict,
    hasExactConflict: exactNameConflict,
    similarMatches: matches,
    nonExactSimilarMatches: matches.filter((match) => !match.isExact),
    overridableMatches: matches.filter((match) => !match.exactNameConflict)
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  NAME_WEIGHT,
  SHORT_NAME_WEIGHT,
  TYPE_WEIGHT,
  STATUS_WEIGHT,
  normalizeDepartmentType,
  compositeSimilarityScore,
  checkDepartmentDuplicates,
  buildCandidateSnapshot
};
