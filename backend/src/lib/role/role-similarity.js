/**
 * Role duplicate / similarity helpers.
 *
 * Scope-matched, multi-signal similarity across name, display name, and
 * description — including cross-field identity, compact keys, and sorted
 * token bags. Reuses tenant-similarity text scoring primitives.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore
} = require('@lib/tenant/tenant-similarity');

/** Soft floor for review when at least one field is strongly similar. */
const REVIEW_COMPOSITE_THRESHOLD = 72;
/** Field strength required to open a soft composite review. */
const REVIEW_FIELD_THRESHOLD = 75;
/** Description-led review when identity fields are only moderately close. */
const DESCRIPTION_LED_THRESHOLD = 85;
const IDENTITY_SUPPORT_THRESHOLD = 60;

const NAME_WEIGHT = 45;
const DISPLAY_NAME_WEIGHT = 35;
const DESCRIPTION_WEIGHT = 20;
const CROSS_IDENTITY_WEIGHT = 25;

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

/**
 * Compact identity key: lowercase alphanumerics only (no spaces).
 * Catches WARDCLERK vs "ward clerk" / "WARD_CLERK".
 */
const normalizeRoleCompactKey = (value) =>
  normalizeText(value).replace(/\s+/g, '');

/**
 * Order-insensitive token bag for "Ward Clerk" vs "Clerk Ward".
 */
const normalizeRoleSortedTokens = (value) => {
  const normalized = normalizeText(value);
  if (!normalized) return '';
  return normalized.split(/\s+/).filter(Boolean).sort().join(' ');
};

const scoreTextPair = (left, right) => {
  if (!left || !right) return null;
  if (left === right) return 100;

  const direct = textSimilarityScore(left, right);
  const compactLeft = normalizeRoleCompactKey(left);
  const compactRight = normalizeRoleCompactKey(right);
  const compact =
    compactLeft && compactRight
      ? compactLeft === compactRight
        ? 100
        : textSimilarityScore(compactLeft, compactRight)
      : 0;

  const sortedLeft = normalizeRoleSortedTokens(left);
  const sortedRight = normalizeRoleSortedTokens(right);
  const sorted =
    sortedLeft && sortedRight
      ? sortedLeft === sortedRight
        ? 100
        : textSimilarityScore(sortedLeft, sortedRight)
      : 0;

  return Math.max(direct, compact, sorted);
};

const isExactTextMatch = (left, right) => {
  if (!left || !right) return false;
  if (left === right) return true;
  if (normalizeRoleCompactKey(left) === normalizeRoleCompactKey(right)) {
    return true;
  }
  const sortedLeft = normalizeRoleSortedTokens(left);
  const sortedRight = normalizeRoleSortedTokens(right);
  return Boolean(sortedLeft) && sortedLeft === sortedRight;
};

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
    [scores.displayNameScore, DISPLAY_NAME_WEIGHT],
    [scores.descriptionScore, DESCRIPTION_WEIGHT],
    [scores.crossIdentityScore, CROSS_IDENTITY_WEIGHT]
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

const maxScore = (...scores) => {
  const present = scores.filter((score) => score != null);
  if (!present.length) return null;
  return Math.max(...present);
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
  let exactDisplayNameConflict = false;
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

    const nameExact = isExactTextMatch(normalizedName, roleName);
    const displayNameExact = isExactTextMatch(
      normalizedDisplayName,
      roleDisplayName
    );
    const descriptionExact = isExactTextMatch(
      normalizedDescription,
      roleDescription
    );
    const nameMatchesCandidateDisplay = isExactTextMatch(
      normalizedName,
      roleDisplayName
    );
    const displayMatchesCandidateName = isExactTextMatch(
      normalizedDisplayName,
      roleName
    );

    let nameScore = null;
    let displayNameScore = null;
    let descriptionScore = null;
    let crossIdentityScore = null;
    const reasons = [];

    if (normalizedName && roleName) {
      nameScore = nameExact ? 100 : scoreTextPair(normalizedName, roleName);
      if (nameExact || (nameScore != null && nameScore >= REVIEW_FIELD_THRESHOLD)) {
        reasons.push('name');
      }
    }

    if (normalizedDisplayName && roleDisplayName) {
      displayNameScore = displayNameExact
        ? 100
        : scoreTextPair(normalizedDisplayName, roleDisplayName);
      if (
        displayNameExact ||
        (displayNameScore != null && displayNameScore >= REVIEW_FIELD_THRESHOLD)
      ) {
        reasons.push('display_name');
      }
    }

    if (normalizedDescription && roleDescription) {
      descriptionScore = descriptionExact
        ? 100
        : scoreTextPair(normalizedDescription, roleDescription);
      if (
        descriptionExact ||
        (descriptionScore != null &&
          descriptionScore >= REVIEW_FIELD_THRESHOLD)
      ) {
        reasons.push('description');
      }
    }

    // Cross-field identity: machine name ↔ human display name.
    const crossScores = [];
    if (normalizedName && roleDisplayName) {
      crossScores.push(
        nameMatchesCandidateDisplay
          ? 100
          : scoreTextPair(normalizedName, roleDisplayName)
      );
    }
    if (normalizedDisplayName && roleName) {
      crossScores.push(
        displayMatchesCandidateName
          ? 100
          : scoreTextPair(normalizedDisplayName, roleName)
      );
    }
    if (normalizedName && normalizedDisplayName && roleName && roleDisplayName) {
      // Combined identity strings (name+display) catch reordered labels.
      const inputIdentity = normalizeText(
        `${normalizedName} ${normalizedDisplayName}`
      );
      const candidateIdentity = normalizeText(
        `${roleName} ${roleDisplayName}`
      );
      crossScores.push(scoreTextPair(inputIdentity, candidateIdentity));
    }
    crossIdentityScore = maxScore(...crossScores);
    if (
      crossIdentityScore != null &&
      crossIdentityScore >= REVIEW_FIELD_THRESHOLD
    ) {
      reasons.push('cross_identity');
    }

    const score = compositeSimilarityScore({
      nameScore,
      displayNameScore,
      descriptionScore,
      crossIdentityScore
    });

    const strongestIdentity = maxScore(
      nameScore,
      displayNameScore,
      crossIdentityScore
    );
    const strongestField = maxScore(
      nameScore,
      displayNameScore,
      descriptionScore,
      crossIdentityScore
    );

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
        field: 'cross_identity',
        inputValue:
          [name, displayName].filter((value) => String(value || '').trim())
            .join(' / ') || null,
        candidateValue:
          [snapshot.name, snapshot.display_name]
            .filter((value) => String(value || '').trim())
            .join(' / ') || null,
        score: crossIdentityScore,
        exact:
          nameMatchesCandidateDisplay ||
          displayMatchesCandidateName ||
          (crossIdentityScore === 100)
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
    if (displayNameExact || nameMatchesCandidateDisplay || displayMatchesCandidateName) {
      // Treat swapped/exact display identity as a hard conflict too.
      if (displayNameExact) {
        exactDisplayNameConflict = true;
      }
      if (nameMatchesCandidateDisplay || displayMatchesCandidateName) {
        exactNameConflict = true;
      }
    }

    const isExact =
      nameExact ||
      displayNameExact ||
      nameMatchesCandidateDisplay ||
      displayMatchesCandidateName;

    const strongIdentitySignal =
      (strongestIdentity != null &&
        strongestIdentity >= SIMILARITY_THRESHOLD);
    const strongFieldSignal =
      strongestField != null && strongestField >= SIMILARITY_THRESHOLD;
    const compositeSignal = score >= SIMILARITY_THRESHOLD;
    const softCompositeSignal =
      score >= REVIEW_COMPOSITE_THRESHOLD &&
      strongestField != null &&
      strongestField >= REVIEW_FIELD_THRESHOLD;
    const descriptionLedSignal =
      descriptionScore != null &&
      descriptionScore >= DESCRIPTION_LED_THRESHOLD &&
      strongestIdentity != null &&
      strongestIdentity >= IDENTITY_SUPPORT_THRESHOLD;

    if (
      !isExact &&
      !strongIdentitySignal &&
      !strongFieldSignal &&
      !compositeSignal &&
      !softCompositeSignal &&
      !descriptionLedSignal
    ) {
      continue;
    }

    matches.push({
      ...snapshot,
      score,
      reasons: reasons.length ? [...new Set(reasons)] : ['name'],
      isExact,
      exactNameConflict: nameExact || nameMatchesCandidateDisplay || displayMatchesCandidateName,
      exactDisplayNameConflict: displayNameExact,
      nameScore,
      displayNameScore,
      descriptionScore,
      crossIdentityScore,
      field_comparisons: fieldComparisons
    });
  }

  matches.sort((left, right) => right.score - left.score);

  const hasExactConflict = exactNameConflict || exactDisplayNameConflict;

  return {
    exactNameConflict: hasExactConflict,
    exactDisplayNameConflict,
    hasExactConflict,
    similarMatches: matches,
    nonExactSimilarMatches: matches.filter((match) => !match.isExact),
    overridableMatches: matches.filter(
      (match) => !match.exactNameConflict && !match.exactDisplayNameConflict
    )
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  REVIEW_COMPOSITE_THRESHOLD,
  REVIEW_FIELD_THRESHOLD,
  DESCRIPTION_LED_THRESHOLD,
  NAME_WEIGHT,
  DISPLAY_NAME_WEIGHT,
  DESCRIPTION_WEIGHT,
  CROSS_IDENTITY_WEIGHT,
  normalizeRoleCompactKey,
  normalizeRoleSortedTokens,
  scoreTextPair,
  compositeSimilarityScore,
  checkRoleDuplicates,
  buildCandidateSnapshot
};
