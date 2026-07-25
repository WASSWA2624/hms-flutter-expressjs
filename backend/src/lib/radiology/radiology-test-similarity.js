/**
 * Radiology test duplicate / similarity helpers.
 *
 * Mirrors frontend Levenshtein-based catalog similarity (threshold 80).
 */

const SIMILARITY_THRESHOLD = 80;

const normalizeName = (value) => String(value || '')
  .toLowerCase()
  .trim()
  .replace(/[^a-z0-9\s]/g, '')
  .replace(/\s+/g, ' ');

const normalizeCode = (value) => String(value || '').trim().toUpperCase();

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

const nameSimilarityScore = (left, right) => {
  if (left === right) return 100;
  if (!left || !right) return 0;
  const distance = levenshteinDistance(left, right);
  const maxLength = Math.max(left.length, right.length);
  return Math.round(((maxLength - distance) / maxLength) * 100);
};

/**
 * @param {Object} params
 * @param {string} params.name
 * @param {string|null|undefined} params.code
 * @param {Array<{id?: string, name?: string, code?: string, modality?: string}>} params.existing
 * @param {string|null} [params.excludeTestId]
 */
const checkRadiologyTestDuplicates = ({
  name,
  code,
  existing = [],
  excludeTestId = null
}) => {
  const normalizedName = normalizeName(name);
  const normalizedCode = normalizeCode(code);

  let exactNameConflict = false;
  let exactCodeConflict = false;
  const matches = [];

  for (const test of existing) {
    if (excludeTestId && test?.id === excludeTestId) {
      continue;
    }

    const testName = normalizeName(test?.name);
    const testCode = normalizeCode(test?.code);
    const nameExact = Boolean(normalizedName) && testName === normalizedName;
    const codeExact = Boolean(normalizedCode)
      && Boolean(testCode)
      && testCode === normalizedCode;

    if (nameExact || codeExact) {
      if (nameExact) exactNameConflict = true;
      if (codeExact) exactCodeConflict = true;
      matches.push({
        id: test?.id || null,
        name: test?.name || null,
        code: test?.code || null,
        modality: test?.modality || null,
        score: 100,
        reasons: [
          ...(nameExact ? ['name'] : []),
          ...(codeExact ? ['code'] : [])
        ],
        isExact: true
      });
      continue;
    }

    if (!normalizedName || !testName) {
      continue;
    }

    const score = nameSimilarityScore(normalizedName, testName);
    if (score >= SIMILARITY_THRESHOLD) {
      matches.push({
        id: test?.id || null,
        name: test?.name || null,
        code: test?.code || null,
        modality: test?.modality || null,
        score,
        reasons: ['name'],
        isExact: false
      });
    }
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
  normalizeName,
  normalizeCode,
  nameSimilarityScore,
  checkRadiologyTestDuplicates
};
