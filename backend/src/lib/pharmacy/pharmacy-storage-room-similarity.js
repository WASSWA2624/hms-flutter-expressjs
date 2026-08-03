/**
 * Pharmacy storage-room duplicate / similarity helpers (facility-scoped).
 * Weighted score across name + code. Exact flags are advisory; callers gate on confirm.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore} = require('@lib/tenant/tenant-similarity');

const NAME_WEIGHT = 70;
const CODE_WEIGHT = 30;

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const buildCandidateSnapshot = (room) => ({
  id: room?.id || null,
  human_friendly_id: room?.human_friendly_id || null,
  display_id: room?.display_id || room?.human_friendly_id || room?.id || null,
  tenant_id: room?.tenant_id || null,
  facility_id: room?.facility_id || null,
  name: room?.name || null,
  code: room?.code || null,
  is_active: room?.is_active !== false,
  deleted_at: room?.deleted_at || null});

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
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
 * @param {string} params.name
 * @param {string|null|undefined} params.code
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeRoomId]
 */
const checkPharmacyStorageRoomDuplicates = ({
  name,
  code,
  existing = [],
  excludeRoomId = null}) => {
  const normalizedName = normalizeText(name);
  const normalizedCode = normalizeText(code);
  const excludeId = String(excludeRoomId || '').trim();

  let exactNameConflict = false;
  let exactCodeConflict = false;
  const matches = [];

  for (const room of existing) {
    const snapshot = buildCandidateSnapshot(room);
    const roomId = String(snapshot.id || '').trim();
    const roomFriendly = String(snapshot.human_friendly_id || '').trim();
    const roomDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (roomId === excludeId || roomFriendly === excludeId || roomDisplay === excludeId)
    ) {
      continue;
    }

    const roomName = normalizeText(snapshot.name);
    const roomCode = normalizeText(snapshot.code);

    const nameExact = Boolean(normalizedName) && roomName === normalizedName;
    const codeExact =
      Boolean(normalizedCode) && Boolean(roomCode) && roomCode === normalizedCode;

    let nameScore = null;
    let codeScore = null;
    const reasons = [];

    if (normalizedName && roomName) {
      nameScore = nameExact ? 100 : textSimilarityScore(normalizedName, roomName);
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (normalizedCode && roomCode) {
      codeScore = codeExact ? 100 : textSimilarityScore(normalizedCode, roomCode);
      if (codeExact || codeScore >= SIMILARITY_THRESHOLD) {
        reasons.push('code');
      }
    }

    const score = compositeSimilarityScore({ nameScore, codeScore });
    const fieldComparisons = [
      buildFieldComparison({
        field: 'name',
        inputValue: name,
        candidateValue: snapshot.name,
        score: nameScore,
        exact: nameExact}),
      buildFieldComparison({
        field: 'code',
        inputValue: code || null,
        candidateValue: snapshot.code,
        score: codeScore,
        exact: codeExact})].filter((entry) => entry.input_value != null || entry.candidate_value != null);

    if (nameExact) {
      exactNameConflict = true;
    }
    if (codeExact) {
      exactCodeConflict = true;
    }

    const isExact = nameExact || codeExact;
    const isSimilar = !isExact && score >= SIMILARITY_THRESHOLD && reasons.length > 0;
    if (!isExact && !isSimilar) {
      continue;
    }

    matches.push({
      room: snapshot,
      score,
      reasons,
      is_exact: isExact,
      exact_name_conflict: nameExact,
      exact_code_conflict: codeExact,
      name_score: nameScore,
      code_score: codeScore,
      field_comparisons: fieldComparisons});
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactNameConflict,
    exactCodeConflict,
    similarMatches: matches,
    closestScore: matches.length ? matches[0].score : 0};
};

module.exports = {
  SIMILARITY_THRESHOLD,
  checkPharmacyStorageRoomDuplicates};
