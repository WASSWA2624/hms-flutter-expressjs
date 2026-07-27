/**
 * Role duplicate / similarity helpers.
 *
 * Scope-matched weighted similarity across name, display name, and description.
 * Reuses tenant-similarity text scoring primitives.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore
} = require('@lib/tenant/tenant-similarity');

const NAME_WEIGHT = 50;
const DISPLAY_NAME_WEIGHT = 30;
const DESCRIPTION_WEIGHT = 20;

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const buildCandidateSnapshot = (role) => ({
  id: role?.id || null,
  human_friendly_id: role?.human_friendly_id || null,
  display_id:
    role?.display_id || role?.human_friendly_id || role?.id || null,
  tenant_id: role?.tenant_id || null,
  facility_id: role?.facility_id || null,
  name: role?.name || null,
  display_name: role?.display_name || null,
  description: role?.description || null
});

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
    [scores.displayNameScore, DISPLAY_NAME_WEIGHT],
    [scores.descriptionScore, DESCRIPTION_WEIGHT]
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

const sameScopeFacility = (left, right) => {
  const leftId = left == null || String(left).trim() === '' ? null : String(left).trim();
  const rightId =
    right == null || String(right).trim() === '' ? null : String(right).trim();
  return leftId === rightId;
};

/**
 * @param {Object} params
 * @param {string} params.name
 * @param {string|null|undefined} params.displayName
 * @param {string|null|undefined} params.description
 * @param {string|null|undefined} params.facilityId
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeRoleId]
 */
const checkRoleDuplicates = ({
  name,
  displayName,
  description,
  facilityId = null,
  existing = [],
  excludeRoleId = null
}) => {
  const normalizedName = normalizeText(name);
  const normalizedDisplayName = normalizeText(displayName);
  const normalizedDescription = normalizeText(description);
  const excludeId = String(excludeRoleId || '').trim();

  let exactNameConflict = false;
  const matches = [];

  for (const role of existing) {
    const snapshot = buildCandidateSnapshot(role);
    if (!sameScopeFacility(facilityId, snapshot.facility_id)) {
      continue;
    }

    const roleId = String(snapshot.id || '').trim();
    const roleFriendly = String(snapshot.human_friendly_id || '').trim();
    const roleDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (roleId === excludeId ||
        roleFriendly === excludeId ||
        roleDisplay === excludeId)
    ) {
      continue;
    }

    const roleName = normalizeText(snapshot.name);
    const roleDisplayName = normalizeText(snapshot.display_name);
    const roleDescription = normalizeText(snapshot.description);

    const nameExact = Boolean(normalizedName) && roleName === normalizedName;
    const displayNameExact =
      Boolean(normalizedDisplayName) &&
      Boolean(roleDisplayName) &&
      roleDisplayName === normalizedDisplayName;
    const descriptionExact =
      Boolean(normalizedDescription) &&
      Boolean(roleDescription) &&
      roleDescription === normalizedDescription;

    let nameScore = null;
    let displayNameScore = null;
    let descriptionScore = null;
    const reasons = [];

    if (normalizedName && roleName) {
      nameScore = nameExact
        ? 100
        : textSimilarityScore(normalizedName, roleName);
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (normalizedDisplayName && roleDisplayName) {
      displayNameScore = displayNameExact
        ? 100
        : textSimilarityScore(normalizedDisplayName, roleDisplayName);
      if (displayNameExact || displayNameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('display_name');
      }
    }

    if (normalizedDescription && roleDescription) {
      descriptionScore = descriptionExact
        ? 100
        : textSimilarityScore(normalizedDescription, roleDescription);
      if (descriptionExact || descriptionScore >= SIMILARITY_THRESHOLD) {
        reasons.push('description');
      }
    }

    const score = compositeSimilarityScore({
      nameScore,
      displayNameScore,
      descriptionScore
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
        field: 'display_name',
        inputValue: displayName,
        candidateValue: snapshot.display_name,
        score: displayNameScore,
        exact: displayNameExact
      }),
      buildFieldComparison({
        field: 'description',
        inputValue: description,
        candidateValue: snapshot.description,
        score: descriptionScore,
        exact: descriptionExact
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
      (displayNameScore != null && displayNameScore >= SIMILARITY_THRESHOLD);
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
      displayNameScore,
      descriptionScore,
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
  DISPLAY_NAME_WEIGHT,
  DESCRIPTION_WEIGHT,
  compositeSimilarityScore,
  checkRoleDuplicates,
  buildCandidateSnapshot
};
