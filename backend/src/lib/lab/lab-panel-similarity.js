/**
 * Lab panel duplicate / similarity helpers.
 *
 * Composite percentage similarity across name, code, category, and member-test
 * composition overlap.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeName,
  normalizeCode,
  normalizeCodeForSimilarity,
  normalizeCategory,
  textSimilarityScore
} = require('@lib/lab/lab-test-similarity');

const NAME_WEIGHT = 40;
const CODE_WEIGHT = 25;
const CATEGORY_WEIGHT = 15;
const COMPOSITION_WEIGHT = 20;

const compositePanelSimilarityScore = ({
  nameScore = null,
  codeScore = null,
  categoryScore = null,
  compositionScore = null
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
  if (categoryScore != null) {
    weightedTotal += categoryScore * CATEGORY_WEIGHT;
    weightSum += CATEGORY_WEIGHT;
  }
  if (compositionScore != null) {
    weightedTotal += compositionScore * COMPOSITION_WEIGHT;
    weightSum += COMPOSITION_WEIGHT;
  }

  if (!weightSum) return 0;
  return Math.round(weightedTotal / weightSum);
};

const normalizePanelTestKey = (value) => {
  const asCode = normalizeCodeForSimilarity(value);
  if (asCode) return `CODE:${asCode}`;
  const asId = String(value || '').trim().toUpperCase();
  return asId ? `ID:${asId}` : '';
};

/**
 * Collect stable membership keys from panel_items (test id and/or code).
 * Prefers code when present so standard/tenant id formats still overlap.
 */
const panelMembershipKeys = (panel) => {
  const keys = new Set();
  const items = Array.isArray(panel?.panel_items)
    ? panel.panel_items
    : Array.isArray(panel?.panelItems)
      ? panel.panelItems
      : [];

  for (const item of items) {
    const codeKey = normalizePanelTestKey(
      item?.test_code
      || item?.testCode
      || item?.code
      || item?.lab_test?.code
    );
    const idKey = normalizePanelTestKey(
      item?.lab_test_id
      || item?.labTestId
      || item?.lab_test?.human_friendly_id
      || item?.lab_test?.id
      || item?.id
    );
    if (codeKey.startsWith('CODE:')) {
      keys.add(codeKey);
      continue;
    }
    if (idKey) {
      keys.add(idKey);
    }
  }
  return keys;
};

const compositionOverlapPercent = (leftKeys, rightKeys) => {
  if (!leftKeys.size || !rightKeys.size) return 0;
  let intersection = 0;
  for (const key of leftKeys) {
    if (rightKeys.has(key)) intersection += 1;
  }
  const union = leftKeys.size + rightKeys.size - intersection;
  if (!union) return 0;
  return Math.round((intersection / union) * 100);
};

const matchesExcludeId = (panel, excludePanelId, excludePanelIds = []) => {
  const excluded = new Set(
    [excludePanelId, ...(excludePanelIds || [])]
      .map((value) => String(value || '').trim())
      .filter(Boolean)
  );
  if (!excluded.size) return false;
  const candidates = [
    panel?.id,
    panel?.display_id,
    panel?.human_friendly_id,
    panel?.apiId,
    panel?.api_id
  ]
    .map((value) => String(value || '').trim())
    .filter(Boolean);
  for (const candidate of candidates) {
    for (const excludedId of excluded) {
      if (
        candidate === excludedId
        || candidate.toUpperCase() === excludedId.toUpperCase()
      ) {
        return true;
      }
    }
  }
  return false;
};

/**
 * @param {Object} params
 * @param {string} params.name
 * @param {string|null|undefined} params.code
 * @param {string|null|undefined} params.category
 * @param {Array} [params.panelItems]
 * @param {Array} params.existing
 * @param {string|null} [params.excludePanelId]
 * @param {string[]} [params.excludePanelIds]
 * @param {boolean} [params.includeTokenSimilarity]
 */
const checkLabPanelDuplicates = ({
  name,
  code,
  category,
  panelItems = [],
  existing = [],
  excludePanelId = null,
  excludePanelIds = [],
  includeTokenSimilarity = true
}) => {
  const normalizedName = normalizeName(name);
  const normalizedCode = normalizeCode(code);
  const similarityCode = normalizeCodeForSimilarity(code);
  const normalizedCategory = normalizeCategory(category);
  const proposedKeys = panelMembershipKeys({ panel_items: panelItems });

  let exactNameConflict = false;
  let exactCodeConflict = false;
  const matches = [];

  for (const panel of existing) {
    if (matchesExcludeId(panel, excludePanelId, excludePanelIds)) {
      continue;
    }

    const panelName = normalizeName(panel?.name);
    const panelCode = normalizeCode(panel?.code);
    const panelSimilarityCode = normalizeCodeForSimilarity(panel?.code);
    const panelCategory = normalizeCategory(panel?.category);
    const existingKeys = panelMembershipKeys(panel);

    const nameExact = Boolean(normalizedName) && panelName === normalizedName;
    const codeExact = Boolean(normalizedCode)
      && Boolean(panelCode)
      && (
        panelCode === normalizedCode
        || (Boolean(similarityCode) && panelSimilarityCode === similarityCode)
      );
    const categoryExact = Boolean(normalizedCategory)
      && Boolean(panelCategory)
      && normalizedCategory === panelCategory;

    let nameScore = null;
    let codeScore = null;
    let categoryScore = null;
    let compositionScore = null;
    const reasons = [];

    if (normalizedName && panelName) {
      nameScore = nameExact
        ? 100
        : textSimilarityScore(normalizedName, panelName, { includeTokenSimilarity });
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (similarityCode && panelSimilarityCode) {
      codeScore = codeExact
        ? 100
        : textSimilarityScore(similarityCode, panelSimilarityCode, {
          includeTokenSimilarity: false
        });
      if (codeExact || codeScore >= SIMILARITY_THRESHOLD) {
        reasons.push('code');
      }
    }

    if (normalizedCategory && panelCategory) {
      categoryScore = categoryExact
        ? 100
        : textSimilarityScore(normalizedCategory, panelCategory, {
          includeTokenSimilarity
        });
      if (categoryExact || categoryScore >= SIMILARITY_THRESHOLD) {
        reasons.push('category');
      }
    }

    if (proposedKeys.size && existingKeys.size) {
      compositionScore = compositionOverlapPercent(proposedKeys, existingKeys);
      if (compositionScore >= SIMILARITY_THRESHOLD) {
        reasons.push('composition');
      }
    }

    const score = compositePanelSimilarityScore({
      nameScore,
      codeScore,
      categoryScore,
      compositionScore
    });

    const hardNameConflict = nameExact;
    const isExact = hardNameConflict || codeExact;
    if (isExact) {
      if (hardNameConflict) exactNameConflict = true;
      if (codeExact) exactCodeConflict = true;
      matches.push({
        id: panel?.id || null,
        name: panel?.name || null,
        code: panel?.code || null,
        category: panel?.category || null,
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
        categoryScore,
        compositionScore
      });
      continue;
    }

    const strongFieldSignal = (
      (nameScore != null && nameScore >= SIMILARITY_THRESHOLD)
      || (codeScore != null && codeScore >= SIMILARITY_THRESHOLD)
      || (compositionScore != null && compositionScore >= SIMILARITY_THRESHOLD)
    );
    const compositeSignal = score >= SIMILARITY_THRESHOLD;
    if (!strongFieldSignal && !compositeSignal) {
      continue;
    }

    matches.push({
      id: panel?.id || null,
      name: panel?.name || null,
      code: panel?.code || null,
      category: panel?.category || null,
      score,
      reasons: reasons.length ? reasons : ['name'],
      isExact: false,
      nameScore,
      codeScore,
      categoryScore,
      compositionScore
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

const mergePanelDuplicateChecks = (...checks) => {
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
  NAME_WEIGHT,
  CODE_WEIGHT,
  CATEGORY_WEIGHT,
  COMPOSITION_WEIGHT,
  compositePanelSimilarityScore,
  panelMembershipKeys,
  compositionOverlapPercent,
  checkLabPanelDuplicates,
  mergePanelDuplicateChecks
};
