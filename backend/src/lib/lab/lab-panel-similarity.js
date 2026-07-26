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

/** Lower bar for surfacing near-duplicate panels in review (slight overlaps). */
const PANEL_SIMILARITY_REVIEW_THRESHOLD = 50;
/** Composition overlap that still warrants a review signal (shared members). */
const PANEL_COMPOSITION_REVIEW_THRESHOLD = 20;

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

const addIdMembershipKey = (keys, value) => {
  const raw = String(value || '').trim().toUpperCase();
  if (!raw) return;
  keys.add(`ID:${raw}`);
  const compact = raw.replace(/[^A-Z0-9]/g, '');
  if (compact && compact !== raw) {
    keys.add(`ID:${compact}`);
  }
};

const membershipTokensForItem = (item) => {
  const tokens = new Set();
  const codeCandidates = [
    item?.test_code,
    item?.testCode,
    item?.code,
    item?.lab_test?.code
  ];
  for (const candidate of codeCandidates) {
    const code = normalizeCodeForSimilarity(candidate);
    if (code) {
      tokens.add(`CODE:${code}`);
    }
  }

  // Prefer lab-test identifiers; do not use panel_item row ids — those are not
  // shared across panels and would block identity matching.
  addIdMembershipKey(tokens, item?.lab_test_id);
  addIdMembershipKey(tokens, item?.labTestId);
  addIdMembershipKey(tokens, item?.lab_test?.id);
  addIdMembershipKey(tokens, item?.lab_test?.human_friendly_id);
  addIdMembershipKey(tokens, item?.lab_test?.display_id);
  return tokens;
};

const panelItemsFromPanel = (panel) => {
  if (Array.isArray(panel?.panel_items)) return panel.panel_items;
  if (Array.isArray(panel?.panelItems)) return panel.panelItems;
  return [];
};

/**
 * Collect flat membership keys (debug / key inspection). Prefer
 * `panelMembershipUnits` + `compositionOverlapPercent` for scoring so that
 * dual CODE/ID tokens on the same member do not inflate Jaccard unions.
 */
const panelMembershipKeys = (panel) => {
  const keys = new Set();
  for (const item of panelItemsFromPanel(panel)) {
    for (const token of membershipTokensForItem(item)) {
      keys.add(token);
    }
  }
  return keys;
};

/**
 * One unit per panel member. A proposed member matches an existing member when
 * any identity token overlaps (same lab_test_id and/or same test code).
 */
const panelMembershipUnits = (panel) => {
  const units = [];
  for (const item of panelItemsFromPanel(panel)) {
    const tokens = membershipTokensForItem(item);
    if (tokens.size) {
      units.push(tokens);
    }
  }
  return units;
};

const setsIntersect = (left, right) => {
  for (const value of left) {
    if (right.has(value)) return true;
  }
  return false;
};

/**
 * Jaccard overlap over member *units* (not raw token sets). Matching is by
 * shared code or id so id-only payloads still score 100% against the same
 * membership after enrich, without dual-key union inflation.
 */
const compositionOverlapPercent = (leftUnits, rightUnits) => {
  const left = leftUnits instanceof Set
    ? [...leftUnits].map((key) => new Set([key]))
    : (leftUnits || []);
  const right = rightUnits instanceof Set
    ? [...rightUnits].map((key) => new Set([key]))
    : (rightUnits || []);

  if (!left.length || !right.length) return 0;

  const usedRight = new Set();
  let matched = 0;
  for (const leftUnit of left) {
    for (let index = 0; index < right.length; index += 1) {
      if (usedRight.has(index)) continue;
      if (setsIntersect(leftUnit, right[index])) {
        usedRight.add(index);
        matched += 1;
        break;
      }
    }
  }

  const union = left.length + right.length - matched;
  if (!union) return 0;
  return Math.round((matched / union) * 100);
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
  const proposedUnits = panelMembershipUnits({ panel_items: panelItems });

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
    const existingUnits = panelMembershipUnits(panel);

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
      if (nameExact || nameScore >= PANEL_SIMILARITY_REVIEW_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (similarityCode && panelSimilarityCode) {
      codeScore = codeExact
        ? 100
        : textSimilarityScore(similarityCode, panelSimilarityCode, {
          includeTokenSimilarity: false
        });
      if (codeExact || codeScore >= PANEL_SIMILARITY_REVIEW_THRESHOLD) {
        reasons.push('code');
      }
    }

    if (normalizedCategory && panelCategory) {
      categoryScore = categoryExact
        ? 100
        : textSimilarityScore(normalizedCategory, panelCategory, {
          includeTokenSimilarity
        });
      if (categoryExact || categoryScore >= PANEL_SIMILARITY_REVIEW_THRESHOLD) {
        reasons.push('category');
      }
    }

    if (proposedUnits.length && existingUnits.length) {
      compositionScore = compositionOverlapPercent(proposedUnits, existingUnits);
      if (compositionScore >= PANEL_COMPOSITION_REVIEW_THRESHOLD) {
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
    const reviewFieldSignal = (
      (nameScore != null && nameScore >= PANEL_SIMILARITY_REVIEW_THRESHOLD)
      || (codeScore != null && codeScore >= PANEL_SIMILARITY_REVIEW_THRESHOLD)
      || (categoryScore != null && categoryScore >= PANEL_SIMILARITY_REVIEW_THRESHOLD)
      || (compositionScore != null
        && compositionScore >= PANEL_COMPOSITION_REVIEW_THRESHOLD)
    );
    const compositeSignal = score >= PANEL_SIMILARITY_REVIEW_THRESHOLD;
    if (!strongFieldSignal && !reviewFieldSignal && !compositeSignal) {
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
  PANEL_SIMILARITY_REVIEW_THRESHOLD,
  PANEL_COMPOSITION_REVIEW_THRESHOLD,
  NAME_WEIGHT,
  CODE_WEIGHT,
  CATEGORY_WEIGHT,
  COMPOSITION_WEIGHT,
  compositePanelSimilarityScore,
  panelMembershipKeys,
  panelMembershipUnits,
  compositionOverlapPercent,
  checkLabPanelDuplicates,
  mergePanelDuplicateChecks
};
