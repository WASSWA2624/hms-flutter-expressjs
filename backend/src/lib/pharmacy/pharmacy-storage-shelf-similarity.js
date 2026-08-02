/**
 * Pharmacy storage-shelf duplicate / similarity helpers (room-scoped).
 * Weighted score across label + shelf_code. Exact conflicts are hard blocks.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore} = require('@lib/tenant/tenant-similarity');

const LABEL_WEIGHT = 70;
const CODE_WEIGHT = 30;

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const buildCandidateSnapshot = (shelf) => ({
  id: shelf?.id || null,
  human_friendly_id: shelf?.human_friendly_id || null,
  display_id: shelf?.display_id || shelf?.human_friendly_id || shelf?.id || null,
  tenant_id: shelf?.tenant_id || null,
  facility_id: shelf?.facility_id || null,
  storage_room_id: shelf?.storage_room_id || null,
  shelf_code: shelf?.shelf_code || null,
  label: shelf?.label || null,
  is_active: shelf?.is_active !== false,
  deleted_at: shelf?.deleted_at || null});

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.labelScore, LABEL_WEIGHT],
    [scores.codeScore, CODE_WEIGHT]];

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
  exact = false}) => ({
  field,
  input_value: inputValue == null || inputValue === '' ? null : String(inputValue),
  candidate_value:
    candidateValue == null || candidateValue === '' ? null : String(candidateValue),
  score: score == null ? null : score,
  status: comparisonStatus(score, { exact })});

/**
 * @param {Object} params
 * @param {string} params.label
 * @param {string|null|undefined} params.shelfCode
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeShelfId]
 */
const checkPharmacyStorageShelfDuplicates = ({
  label,
  shelfCode,
  existing = [],
  excludeShelfId = null}) => {
  const normalizedLabel = normalizeText(label);
  const normalizedCode = normalizeText(shelfCode);
  const excludeId = String(excludeShelfId || '').trim();

  let exactLabelConflict = false;
  let exactCodeConflict = false;
  const matches = [];

  for (const shelf of existing) {
    const snapshot = buildCandidateSnapshot(shelf);
    const shelfId = String(snapshot.id || '').trim();
    const shelfFriendly = String(snapshot.human_friendly_id || '').trim();
    const shelfDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (shelfId === excludeId ||
        shelfFriendly === excludeId ||
        shelfDisplay === excludeId)
    ) {
      continue;
    }

    const shelfLabel = normalizeText(snapshot.label);
    const shelfCodeValue = normalizeText(snapshot.shelf_code);

    const labelExact = Boolean(normalizedLabel) && shelfLabel === normalizedLabel;
    const codeExact =
      Boolean(normalizedCode) &&
      Boolean(shelfCodeValue) &&
      shelfCodeValue === normalizedCode;

    let labelScore = null;
    let codeScore = null;
    const reasons = [];

    if (normalizedLabel && shelfLabel) {
      labelScore = labelExact ? 100 : textSimilarityScore(normalizedLabel, shelfLabel);
      if (labelExact || labelScore >= SIMILARITY_THRESHOLD) {
        reasons.push('label');
      }
    }

    if (normalizedCode && shelfCodeValue) {
      codeScore = codeExact ? 100 : textSimilarityScore(normalizedCode, shelfCodeValue);
      if (codeExact || codeScore >= SIMILARITY_THRESHOLD) {
        reasons.push('shelf_code');
      }
    }

    const score = compositeSimilarityScore({ labelScore, codeScore });
    const fieldComparisons = [
      buildFieldComparison({
        field: 'label',
        inputValue: label,
        candidateValue: snapshot.label,
        score: labelScore,
        exact: labelExact}),
      buildFieldComparison({
        field: 'shelf_code',
        inputValue: shelfCode || null,
        candidateValue: snapshot.shelf_code,
        score: codeScore,
        exact: codeExact})].filter((entry) => entry.input_value != null || entry.candidate_value != null);

    if (labelExact) {
      exactLabelConflict = true;
    }
    if (codeExact) {
      exactCodeConflict = true;
    }

    const isExact = labelExact || codeExact;
    const isSimilar = !isExact && score >= SIMILARITY_THRESHOLD && reasons.length > 0;
    if (!isExact && !isSimilar) {
      continue;
    }

    matches.push({
      shelf: snapshot,
      score: isExact ? 100 : score,
      reasons,
      is_exact: isExact,
      exact_label_conflict: labelExact,
      exact_code_conflict: codeExact,
      label_score: labelScore,
      code_score: codeScore,
      field_comparisons: fieldComparisons});
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactLabelConflict,
    exactCodeConflict,
    similarMatches: matches,
    closestScore: matches.length ? matches[0].score : 0};
};

module.exports = {
  SIMILARITY_THRESHOLD,
  checkPharmacyStorageShelfDuplicates};
