/**
 * Role duplicate / similarity helpers.
 *
 * Multi-signal similarity across name, display name, and description —
 * including cross-field identity, compact keys, sorted token bags, token
 * Jaccard, filler stripping, hospital-role aliases, and initials.
 * Same-scope exact identity hard-blocks; cross-scope peers are still scored
 * and surfaced for review. Reuses tenant-similarity text scoring primitives.
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
const TOKEN_MATCH_THRESHOLD = 85;
const TOKEN_SUBSET_THRESHOLD = 78;

const NAME_WEIGHT = 45;
const DISPLAY_NAME_WEIGHT = 35;
const DESCRIPTION_WEIGHT = 20;
const CROSS_IDENTITY_WEIGHT = 25;

const FILLER_TOKENS = new Set([
  'a',
  'an',
  'and',
  'for',
  'of',
  'role',
  'roles',
  'the',
  'to'
]);

const ALIAS_EXPANSIONS = Object.freeze({
  cna: 'certified nursing assistant',
  dr: 'doctor',
  hca: 'health care assistant',
  hcw: 'health care worker',
  lpn: 'licensed practical nurse',
  md: 'medical doctor',
  mo: 'medical officer',
  np: 'nurse practitioner',
  pa: 'physician assistant',
  rn: 'registered nurse',
  rns: 'registered nurse',
  sho: 'senior house officer'
});

const nullIfEmpty = (value) => {
  const trimmed = String(value || '').trim();
  return trimmed ? trimmed : null;
};

/**
 * Platform / tenant / facility scope equality for duplicate checks.
 */
const roleScopesMatch = ({
  leftTenantId = null,
  leftFacilityId = null,
  rightTenantId = null,
  rightFacilityId = null
} = {}) => {
  const leftTenant = nullIfEmpty(leftTenantId);
  const leftFacility = nullIfEmpty(leftFacilityId);
  const rightTenant = nullIfEmpty(rightTenantId);
  const rightFacility = nullIfEmpty(rightFacilityId);

  if (leftFacility != null || rightFacility != null) {
    if (leftFacility !== rightFacility) return false;
    if (leftTenant != null && rightTenant != null && leftTenant !== rightTenant) {
      return false;
    }
    return true;
  }

  return leftTenant === rightTenant;
};

const tokensOf = (value) => String(value || '')
  .split(/\s+/)
  .filter(Boolean);

const significantTokens = (value) => tokensOf(value)
  .filter((token) => !FILLER_TOKENS.has(token));

/**
 * Expands known abbreviations and drops filler tokens for identity compare.
 */
const canonicalizeRoleText = (value) => {
  const normalized = normalizeText(value);
  if (!normalized) return '';

  const expanded = [];
  for (const token of tokensOf(normalized)) {
    const alias = ALIAS_EXPANSIONS[token];
    if (alias) {
      expanded.push(...tokensOf(alias));
    } else if (!FILLER_TOKENS.has(token)) {
      expanded.push(token);
    }
  }
  return expanded.join(' ');
};

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
  canonicalizeRoleText(value).replace(/\s+/g, '');

/**
 * Order-insensitive token bag for "Ward Clerk" vs "Clerk Ward".
 */
const normalizeRoleSortedTokens = (value) => {
  const tokens = significantTokens(canonicalizeRoleText(value)).sort();
  return tokens.join(' ');
};

const roleInitialsKey = (value) => {
  const tokens = significantTokens(canonicalizeRoleText(value));
  if (tokens.length < 2) return '';
  return tokens.map((token) => token[0]).join('');
};

const levenshteinSimilarityPercent = (left, right) =>
  textSimilarityScore(left, right, { includeTokenSimilarity: false });

const averageBestTokenScore = (source, target) => {
  if (!source.length || !target.length) return 0;
  let total = 0;
  for (const token of source) {
    let best = 0;
    for (const candidate of target) {
      best = Math.max(best, levenshteinSimilarityPercent(token, candidate));
    }
    total += best;
  }
  return Math.round(total / source.length);
};

const roleTokenSimilarityPercent = (left, right) => {
  const leftTokens = significantTokens(left);
  const rightTokens = significantTokens(right);
  if (!leftTokens.length || !rightTokens.length) return 0;
  if (leftTokens.length === 1 && rightTokens.length === 1) {
    return levenshteinSimilarityPercent(leftTokens[0], rightTokens[0]);
  }

  const forward = averageBestTokenScore(leftTokens, rightTokens);
  const reverse = averageBestTokenScore(rightTokens, leftTokens);
  const averageDirectional = Math.round((forward + reverse) / 2);

  const used = Array.from({ length: rightTokens.length }, () => false);
  let fuzzyIntersection = 0;
  for (const leftToken of leftTokens) {
    let bestIndex = -1;
    let bestScore = -1;
    for (let i = 0; i < rightTokens.length; i += 1) {
      if (used[i]) continue;
      const score = levenshteinSimilarityPercent(leftToken, rightTokens[i]);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0 && bestScore >= TOKEN_MATCH_THRESHOLD) {
      used[bestIndex] = true;
      fuzzyIntersection += 1;
    }
  }

  const union = leftTokens.length + rightTokens.length - fuzzyIntersection;
  const jaccard = union === 0
    ? 0
    : Math.round((fuzzyIntersection / union) * 100);
  return Math.max(averageDirectional, jaccard);
};

const roleTokenSubsetScore = (left, right) => {
  const leftTokens = significantTokens(left);
  const rightTokens = significantTokens(right);
  if (!leftTokens.length || !rightTokens.length) return null;

  const [shorter, longer] =
    leftTokens.length <= rightTokens.length
      ? [leftTokens, rightTokens]
      : [rightTokens, leftTokens];
  if (shorter.length < 2) return null;

  const longerSet = new Set(longer);
  const covered = shorter.filter((token) => longerSet.has(token)).length;
  if (covered !== shorter.length) return null;

  const coverage = shorter.length / longer.length;
  return Math.min(99, Math.round(TOKEN_SUBSET_THRESHOLD + coverage * 20));
};

const scoreTextPair = (left, right) => {
  if (!left || !right) return null;
  if (left === right) return 100;

  const canonicalLeft = canonicalizeRoleText(left);
  const canonicalRight = canonicalizeRoleText(right);
  if (!canonicalLeft || !canonicalRight) return null;
  if (canonicalLeft === canonicalRight) return 100;

  const direct = textSimilarityScore(canonicalLeft, canonicalRight);
  const compactLeft = normalizeRoleCompactKey(canonicalLeft);
  const compactRight = normalizeRoleCompactKey(canonicalRight);
  const compact =
    compactLeft && compactRight
      ? compactLeft === compactRight
        ? 100
        : textSimilarityScore(compactLeft, compactRight, {
          includeTokenSimilarity: false
        })
      : 0;

  const sortedLeft = normalizeRoleSortedTokens(canonicalLeft);
  const sortedRight = normalizeRoleSortedTokens(canonicalRight);
  const sorted =
    sortedLeft && sortedRight
      ? sortedLeft === sortedRight
        ? 100
        : textSimilarityScore(sortedLeft, sortedRight, {
          includeTokenSimilarity: false
        })
      : 0;

  const tokenScore = roleTokenSimilarityPercent(canonicalLeft, canonicalRight);
  const subsetScore = roleTokenSubsetScore(canonicalLeft, canonicalRight) || 0;

  const leftInitials = roleInitialsKey(canonicalLeft);
  const rightInitials = roleInitialsKey(canonicalRight);
  let initialsScore = 0;
  if (
    leftInitials &&
    (leftInitials === compactRight || leftInitials === rightInitials)
  ) {
    initialsScore = 100;
  } else if (rightInitials && rightInitials === compactLeft) {
    initialsScore = 100;
  }

  return Math.max(
    direct,
    compact,
    sorted,
    tokenScore,
    subsetScore,
    initialsScore
  );
};

const isExactTextMatch = (left, right) => {
  if (!left || !right) return false;
  const canonicalLeft = canonicalizeRoleText(left);
  const canonicalRight = canonicalizeRoleText(right);
  if (!canonicalLeft || !canonicalRight) return false;
  if (canonicalLeft === canonicalRight) return true;
  if (normalizeRoleCompactKey(canonicalLeft) === normalizeRoleCompactKey(canonicalRight)) {
    return true;
  }
  const sortedLeft = normalizeRoleSortedTokens(canonicalLeft);
  const sortedRight = normalizeRoleSortedTokens(canonicalRight);
  if (sortedLeft && sortedLeft === sortedRight) return true;

  const leftInitials = roleInitialsKey(canonicalLeft);
  const rightCompact = normalizeRoleCompactKey(canonicalRight);
  const rightInitials = roleInitialsKey(canonicalRight);
  const leftCompact = normalizeRoleCompactKey(canonicalLeft);
  if (leftInitials && leftInitials === rightCompact) return true;
  if (rightInitials && rightInitials === leftCompact) return true;
  return false;
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
 * @param {string|null|undefined} params.tenantId
 * @param {string|null|undefined} params.facilityId
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeRoleId]
 */
const checkRoleDuplicates = ({
  name,
  displayName,
  description,
  tenantId = null,
  facilityId = null,
  existing = [],
  excludeRoleId = null
}) => {
  const normalizedName = canonicalizeRoleText(name);
  const normalizedDisplayName = canonicalizeRoleText(displayName);
  const normalizedDescription = canonicalizeRoleText(description);
  const excludeId = String(excludeRoleId || '').trim();

  let exactNameConflict = false;
  let exactDisplayNameConflict = false;
  const matches = [];
  const seenRoleKeys = new Set();

  for (const role of existing) {
    const snapshot = buildCandidateSnapshot(role);
    // Same-scope matches can hard-block create. Cross-scope peers are still
    // scored and surfaced in review so names like "Testing" are not missed
    // when they already exist at another Platform / Tenant / Facility level.
    const sameScope = roleScopesMatch({
      leftTenantId: tenantId,
      leftFacilityId: facilityId,
      rightTenantId: snapshot.tenant_id,
      rightFacilityId: snapshot.facility_id
    });

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

    const roleKey = roleId || roleFriendly || roleDisplay || snapshot.name || '';
    if (roleKey && seenRoleKeys.has(roleKey)) {
      continue;
    }
    if (roleKey) {
      seenRoleKeys.add(roleKey);
    }

    const roleName = canonicalizeRoleText(snapshot.name);
    const roleDisplayName = canonicalizeRoleText(snapshot.display_name);
    const roleDescription = canonicalizeRoleText(snapshot.description);

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
      const inputIdentity = canonicalizeRoleText(
        `${normalizedName} ${normalizedDisplayName}`
      );
      const candidateIdentity = canonicalizeRoleText(
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

    const identityExact =
      nameExact ||
      displayNameExact ||
      nameMatchesCandidateDisplay ||
      displayMatchesCandidateName;
    // Only same-scope exact identity blocks proceed / confirm_similar bypass.
    const blockingNameConflict =
      sameScope &&
      (nameExact || nameMatchesCandidateDisplay || displayMatchesCandidateName);
    const blockingDisplayNameConflict = sameScope && displayNameExact;
    if (blockingNameConflict) {
      exactNameConflict = true;
    }
    if (blockingDisplayNameConflict) {
      exactDisplayNameConflict = true;
    }

    const isExact = sameScope && identityExact;

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
    const tokenSubsetSignal =
      (nameScore != null && nameScore >= TOKEN_SUBSET_THRESHOLD) ||
      (displayNameScore != null && displayNameScore >= TOKEN_SUBSET_THRESHOLD);

    if (
      !identityExact &&
      !strongIdentitySignal &&
      !strongFieldSignal &&
      !compositeSignal &&
      !softCompositeSignal &&
      !descriptionLedSignal &&
      !tokenSubsetSignal
    ) {
      continue;
    }

    matches.push({
      ...snapshot,
      score,
      reasons: reasons.length ? [...new Set(reasons)] : ['name'],
      isExact,
      exactNameConflict: blockingNameConflict,
      exactDisplayNameConflict: blockingDisplayNameConflict,
      nameScore,
      displayNameScore,
      descriptionScore,
      crossIdentityScore,
      field_comparisons: fieldComparisons
    });
  }

  matches.sort((left, right) => {
    const leftBlocking =
      left.exactNameConflict || left.exactDisplayNameConflict ? 1 : 0;
    const rightBlocking =
      right.exactNameConflict || right.exactDisplayNameConflict ? 1 : 0;
    const byBlocking = rightBlocking - leftBlocking;
    if (byBlocking !== 0) return byBlocking;
    const byScore = right.score - left.score;
    if (byScore !== 0) return byScore;
    return Number(right.isExact) - Number(left.isExact);
  });

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
  FILLER_TOKENS,
  ALIAS_EXPANSIONS,
  canonicalizeRoleText,
  normalizeRoleCompactKey,
  normalizeRoleSortedTokens,
  roleInitialsKey,
  roleScopesMatch,
  scoreTextPair,
  compositeSimilarityScore,
  checkRoleDuplicates,
  buildCandidateSnapshot
};
