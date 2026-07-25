/**
 * Radiology test duplicate / similarity helpers.
 *
 * Composite percentage similarity across name, code, and modality.
 */

const SIMILARITY_THRESHOLD = 80;
const TOKEN_MATCH_THRESHOLD = 85;
const NAME_WEIGHT = 50;
const CODE_WEIGHT = 30;
const MODALITY_WEIGHT = 20;

const normalizeName = (value) => String(value || '')
  .toLowerCase()
  .trim()
  .replace(/[^a-z0-9\s]/g, '')
  .replace(/\s+/g, ' ');

const normalizeCode = (value) => String(value || '').trim().toUpperCase();

const normalizeCodeForSimilarity = (value) => normalizeCode(value).replace(/[^A-Z0-9]/g, '');

const normalizeModality = (value) => normalizeName(value);

const tokensOf = (value) => String(value || '')
  .split(/\s+/)
  .filter(Boolean);

const levenshteinDistance = (left, right) => {
  if (left === right) return 0;
  if (!left) return right.length;
  if (!right) return left.length;

  const previous = Array.from({ length: right.length + 1 }, (_, index) => index);
  const current = new Array(right.length + 1);

  for (let i = 0; i < left.length; i += 1) {
    current[0] = i + 1;
    for (let j = 0; j < right.length; j += 1) {
      const substitutionCost = left[i] === right[j] ? 0 : 1;
      current[j + 1] = Math.min(
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + substitutionCost
      );
    }
    for (let j = 0; j <= right.length; j += 1) {
      previous[j] = current[j];
    }
  }

  return previous[right.length];
};

const levenshteinSimilarityPercent = (left, right) => {
  if (left === right) return 100;
  if (!left || !right) return 0;
  const distance = levenshteinDistance(left, right);
  const maxLength = Math.max(left.length, right.length);
  return Math.round(((maxLength - distance) / maxLength) * 100);
};

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

const tokenSimilarityPercent = (left, right) => {
  const leftTokens = tokensOf(left);
  const rightTokens = tokensOf(right);
  if (!leftTokens.length || !rightTokens.length) return 0;
  // Single-token pairs: use edit distance directly so misspellings
  // do not collapse to 100% via Jaccard.
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

const textSimilarityScore = (
  left,
  right,
  { includeTokenSimilarity = true } = {}
) => {
  if (left === right) return 100;
  if (!left || !right) return 0;

  // Always compute the real edit/token score so misspellings surface in the
  // composite % even when they sit below the match threshold.
  const fullScore = levenshteinSimilarityPercent(left, right);
  if (!includeTokenSimilarity) return fullScore;
  return Math.max(fullScore, tokenSimilarityPercent(left, right));
};

const compositeSimilarityScore = ({
  nameScore = null,
  codeScore = null,
  modalityScore = null
} = {}) => {
  let weightedTotal = 0;
  let weightSum = 0;

  if (nameScore != null) {
    weightedTotal += nameScore * NAME_WEIGHT;
    weightSum += NAME_WEIGHT;
  }
  if (codeScore != null) {
    weightedTotal += codeScore * CODE_WEIGHT;
    weightSum += CODE_WEIGHT;
  }
  if (modalityScore != null) {
    weightedTotal += modalityScore * MODALITY_WEIGHT;
    weightSum += MODALITY_WEIGHT;
  }

  if (!weightSum) return 0;
  return Math.round(weightedTotal / weightSum);
};

/** @deprecated Prefer textSimilarityScore; kept for existing imports/tests. */
const nameSimilarityScore = (left, right) => textSimilarityScore(left, right);

/**
 * @param {Object} params
 * @param {string} params.name
 * @param {string|null|undefined} params.code
 * @param {string|null|undefined} params.modality
 * @param {Array<{id?: string, name?: string, code?: string, modality?: string}>} params.existing
 * @param {string|null} [params.excludeTestId]
 * @param {boolean} [params.includeTokenSimilarity]
 */
const checkRadiologyProcedureDuplicates = ({
  name,
  code,
  modality,
  existing = [],
  excludeTestId = null,
  includeTokenSimilarity = true
}) => {
  const normalizedName = normalizeName(name);
  const normalizedCode = normalizeCode(code);
  const similarityCode = normalizeCodeForSimilarity(code);
  const normalizedModality = normalizeModality(modality);

  let exactNameConflict = false;
  let exactCodeConflict = false;
  const matches = [];

  for (const test of existing) {
    if (
      excludeTestId
      && (
        test?.id === excludeTestId
        || test?.display_id === excludeTestId
        || test?.human_friendly_id === excludeTestId
      )
    ) {
      continue;
    }

    const testName = normalizeName(test?.name);
    const testCode = normalizeCode(test?.code);
    const testSimilarityCode = normalizeCodeForSimilarity(test?.code);
    const testModality = normalizeModality(test?.modality);

    const nameExact = Boolean(normalizedName) && testName === normalizedName;
    const codeExact = Boolean(normalizedCode)
      && Boolean(testCode)
      && (
        testCode === normalizedCode
        || (Boolean(similarityCode) && testSimilarityCode === similarityCode)
      );
    const modalityExact = Boolean(normalizedModality)
      && Boolean(testModality)
      && normalizedModality === testModality;

    let nameScore = null;
    let codeScore = null;
    let modalityScore = null;
    const reasons = [];

    if (normalizedName && testName) {
      nameScore = nameExact
        ? 100
        : textSimilarityScore(normalizedName, testName, { includeTokenSimilarity });
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (similarityCode && testSimilarityCode) {
      codeScore = codeExact
        ? 100
        : textSimilarityScore(similarityCode, testSimilarityCode, {
          includeTokenSimilarity: false
        });
      if (codeExact || codeScore >= SIMILARITY_THRESHOLD) {
        reasons.push('code');
      }
    }

    if (normalizedModality && testModality) {
      modalityScore = modalityExact
        ? 100
        : textSimilarityScore(normalizedModality, testModality, {
          includeTokenSimilarity
        });
      if (modalityExact || modalityScore >= SIMILARITY_THRESHOLD) {
        reasons.push('modality');
      }
    }

    const score = compositeSimilarityScore({
      nameScore,
      codeScore,
      modalityScore
    });

    // Same name with a different modality is a near match, not a hard block.
    // Composite % still weights every available parameter, including misspellings.
    const bothModalitiesPresent = Boolean(normalizedModality)
      && Boolean(testModality);
    const hardNameConflict = nameExact
      && (!bothModalitiesPresent || modalityExact);
    const isExact = hardNameConflict || codeExact;
    if (isExact) {
      if (hardNameConflict) exactNameConflict = true;
      if (codeExact) exactCodeConflict = true;
      matches.push({
        id: test?.id || null,
        name: test?.name || null,
        code: test?.code || null,
        modality: test?.modality || null,
        score,
        reasons: reasons.length
          ? reasons
          : [
            ...(hardNameConflict ? ['name'] : []),
            ...(codeExact ? ['code'] : [])
          ],
        isExact: true,
        nameScore,
        codeScore,
        modalityScore
      });
      continue;
    }

    const strongFieldSignal = (
      (nameScore != null && nameScore >= SIMILARITY_THRESHOLD)
      || (codeScore != null && codeScore >= SIMILARITY_THRESHOLD)
      || (modalityScore != null && modalityScore >= SIMILARITY_THRESHOLD)
    );
    const compositeSignal = score >= SIMILARITY_THRESHOLD;
    if (!strongFieldSignal && !compositeSignal) {
      continue;
    }

    matches.push({
      id: test?.id || null,
      name: test?.name || null,
      code: test?.code || null,
      modality: test?.modality || null,
      score,
      reasons: reasons.length ? reasons : ['name'],
      isExact: false,
      nameScore,
      codeScore,
      modalityScore
    });
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactNameConflict,
    exactCodeConflict,
    hasExactConflict: exactNameConflict || exactCodeConflict,
    similarMatches: matches,
    nonExactSimilarMatches: matches.filter((match) => !match.isExact)
  };
};

const mergeDuplicateChecks = (...checks) => {
  const matches = [];
  let exactNameConflict = false;
  let exactCodeConflict = false;

  for (const check of checks) {
    exactNameConflict = exactNameConflict || check.exactNameConflict;
    exactCodeConflict = exactCodeConflict || check.exactCodeConflict;
    matches.push(...(check.similarMatches || []));
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactNameConflict,
    exactCodeConflict,
    hasExactConflict: exactNameConflict || exactCodeConflict,
    similarMatches: matches,
    nonExactSimilarMatches: matches.filter((match) => !match.isExact)
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  TOKEN_MATCH_THRESHOLD,
  NAME_WEIGHT,
  CODE_WEIGHT,
  MODALITY_WEIGHT,
  normalizeName,
  normalizeCode,
  normalizeCodeForSimilarity,
  normalizeModality,
  nameSimilarityScore,
  textSimilarityScore,
  compositeSimilarityScore,
  checkRadiologyProcedureDuplicates,
  mergeDuplicateChecks
};
