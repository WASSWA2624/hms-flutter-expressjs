/**
 * Staff position duplicate / similarity helpers.
 *
 * Facility-scoped (when facility_id is set) or tenant-scoped name matching.
 * Reuses tenant-similarity text scoring primitives.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore
} = require('@lib/tenant/tenant-similarity');

const NAME_WEIGHT = 90;
const STATUS_WEIGHT = 10;

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const buildCandidateSnapshot = (position) => ({
  id: position?.id || null,
  human_friendly_id: position?.human_friendly_id || null,
  display_id:
    position?.display_id || position?.human_friendly_id || position?.id || null,
  tenant_id: position?.tenant_id || null,
  facility_id: position?.facility_id || null,
  name: position?.name || null,
  description: position?.description || null,
  is_active: position?.is_active !== false
});

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
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
 * @param {boolean|null|undefined} params.isActive
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludePositionId]
 */
const checkStaffPositionDuplicates = ({
  name,
  isActive,
  existing = [],
  excludePositionId = null
}) => {
  const normalizedName = normalizeText(name);
  const normalizedActive = isActive === false ? false : true;
  const excludeId = String(excludePositionId || '').trim();

  let exactNameConflict = false;
  const matches = [];

  for (const position of existing) {
    const snapshot = buildCandidateSnapshot(position);
    const positionId = String(snapshot.id || '').trim();
    const positionFriendly = String(snapshot.human_friendly_id || '').trim();
    const positionDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (positionId === excludeId ||
        positionFriendly === excludeId ||
        positionDisplay === excludeId)
    ) {
      continue;
    }

    const positionName = normalizeText(snapshot.name);
    const positionActive = snapshot.is_active !== false;
    const nameExact = Boolean(normalizedName) && positionName === normalizedName;
    const statusExact = positionActive === normalizedActive;

    let nameScore = null;
    let statusScore = null;
    const reasons = [];

    if (normalizedName && positionName) {
      nameScore = nameExact
        ? 100
        : textSimilarityScore(normalizedName, positionName);
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    statusScore = statusExact ? 100 : 0;
    if (statusExact) {
      reasons.push('status');
    }

    if (!reasons.includes('name')) {
      continue;
    }

    const score = compositeSimilarityScore({ nameScore, statusScore });
    const fieldComparisons = [
      buildFieldComparison({
        field: 'name',
        inputValue: name,
        candidateValue: snapshot.name,
        score: nameScore,
        exact: nameExact
      }),
      buildFieldComparison({
        field: 'status',
        inputValue: normalizedActive ? 'ACTIVE' : 'INACTIVE',
        candidateValue: positionActive ? 'ACTIVE' : 'INACTIVE',
        score: statusScore,
        exact: statusExact
      })
    ];

    if (nameExact) {
      exactNameConflict = true;
    }

    matches.push({
      position: snapshot,
      score,
      reasons: [...new Set(reasons)],
      isExact: nameExact,
      exactNameConflict: nameExact,
      nameScore,
      statusScore,
      fieldComparisons
    });
  }

  matches.sort((left, right) => {
    if (right.exactNameConflict !== left.exactNameConflict) {
      return right.exactNameConflict ? 1 : -1;
    }
    return (right.score || 0) - (left.score || 0);
  });

  return {
    exactNameConflict,
    similarMatches: matches,
    overridableMatches: matches.filter((match) => !match.exactNameConflict)
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  checkStaffPositionDuplicates,
  buildCandidateSnapshot,
  normalizeText
};
