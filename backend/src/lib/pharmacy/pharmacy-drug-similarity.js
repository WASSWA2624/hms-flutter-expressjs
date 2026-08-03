/**
 * Pharmacy drug duplicate / similarity helpers (tenant-scoped).
 * Weighted score across generic/name, brand, code, form, and strength.
 * Exact code or clinical identity flags are advisory; callers gate on confirm.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  textSimilarityScore} = require('@lib/tenant/tenant-similarity');

const GENERIC_WEIGHT = 35;
const BRAND_WEIGHT = 15;
const CODE_WEIGHT = 30;
const FORM_WEIGHT = 10;
const STRENGTH_WEIGHT = 10;

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const buildCandidateSnapshot = (drug) => ({
  id: drug?.id || null,
  human_friendly_id: drug?.human_friendly_id || null,
  display_id: drug?.display_id || drug?.human_friendly_id || drug?.id || null,
  tenant_id: drug?.tenant_id || null,
  name: drug?.name || null,
  brand_name: drug?.brand_name || null,
  generic_name: drug?.generic_name || null,
  code: drug?.code || null,
  form: drug?.form || null,
  strength: drug?.strength || null,
  deleted_at: drug?.deleted_at || null});

const resolveGenericLabel = (drug) => {
  const generic = normalizeText(drug?.generic_name);
  if (generic) return String(drug.generic_name || '').trim();
  return String(drug?.name || '').trim();
};

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.genericScore, GENERIC_WEIGHT],
    [scores.brandScore, BRAND_WEIGHT],
    [scores.codeScore, CODE_WEIGHT],
    [scores.formScore, FORM_WEIGHT],
    [scores.strengthScore, STRENGTH_WEIGHT]];

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
 * @param {string|null|undefined} params.genericName
 * @param {string|null|undefined} params.brandName
 * @param {string|null|undefined} params.code
 * @param {string|null|undefined} params.form
 * @param {string|null|undefined} params.strength
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeDrugId]
 */
const checkPharmacyDrugDuplicates = ({
  name,
  genericName,
  brandName,
  code,
  form,
  strength,
  existing = [],
  excludeDrugId = null}) => {
  const inputGenericRaw =
    String(genericName || '').trim() || String(name || '').trim();
  const normalizedGeneric = normalizeText(inputGenericRaw);
  const normalizedBrand = normalizeText(brandName);
  const normalizedCode = normalizeText(code);
  const normalizedForm = normalizeText(form);
  const normalizedStrength = normalizeText(strength);
  const excludeId = String(excludeDrugId || '').trim();

  let exactIdentityConflict = false;
  let exactCodeConflict = false;
  const matches = [];

  for (const drug of existing) {
    const snapshot = buildCandidateSnapshot(drug);
    const drugId = String(snapshot.id || '').trim();
    const drugFriendly = String(snapshot.human_friendly_id || '').trim();
    const drugDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (drugId === excludeId ||
        drugFriendly === excludeId ||
        drugDisplay === excludeId)
    ) {
      continue;
    }

    const candidateGenericRaw = resolveGenericLabel(snapshot);
    const candidateGeneric = normalizeText(candidateGenericRaw);
    const candidateBrand = normalizeText(snapshot.brand_name);
    const candidateCode = normalizeText(snapshot.code);
    const candidateForm = normalizeText(snapshot.form);
    const candidateStrength = normalizeText(snapshot.strength);

    const genericExact =
      Boolean(normalizedGeneric) &&
      Boolean(candidateGeneric) &&
      candidateGeneric === normalizedGeneric;
    const brandExact =
      Boolean(normalizedBrand) &&
      Boolean(candidateBrand) &&
      candidateBrand === normalizedBrand;
    const codeExact =
      Boolean(normalizedCode) &&
      Boolean(candidateCode) &&
      candidateCode === normalizedCode;
    const formExact =
      Boolean(normalizedForm) &&
      Boolean(candidateForm) &&
      candidateForm === normalizedForm;
    const strengthExact =
      Boolean(normalizedStrength) &&
      Boolean(candidateStrength) &&
      candidateStrength === normalizedStrength;

    // Clinical identity: same generic + form + strength (when form/strength present).
    const identityExact =
      genericExact &&
      (normalizedForm ? formExact : true) &&
      (normalizedStrength ? strengthExact : true) &&
      Boolean(normalizedGeneric);

    let genericScore = null;
    let brandScore = null;
    let codeScore = null;
    let formScore = null;
    let strengthScore = null;
    const reasons = [];

    if (normalizedGeneric && candidateGeneric) {
      genericScore = genericExact
        ? 100
        : textSimilarityScore(normalizedGeneric, candidateGeneric);
      if (genericExact || genericScore >= SIMILARITY_THRESHOLD) {
        reasons.push('generic_name');
      }
    }

    if (normalizedBrand && candidateBrand) {
      brandScore = brandExact
        ? 100
        : textSimilarityScore(normalizedBrand, candidateBrand);
      if (brandExact || brandScore >= SIMILARITY_THRESHOLD) {
        reasons.push('brand_name');
      }
    }

    if (normalizedCode && candidateCode) {
      codeScore = codeExact
        ? 100
        : textSimilarityScore(normalizedCode, candidateCode);
      if (codeExact || codeScore >= SIMILARITY_THRESHOLD) {
        reasons.push('code');
      }
    }

    if (normalizedForm && candidateForm) {
      formScore = formExact
        ? 100
        : textSimilarityScore(normalizedForm, candidateForm);
      if (formExact || formScore >= SIMILARITY_THRESHOLD) {
        reasons.push('form');
      }
    }

    if (normalizedStrength && candidateStrength) {
      strengthScore = strengthExact
        ? 100
        : textSimilarityScore(normalizedStrength, candidateStrength);
      if (strengthExact || strengthScore >= SIMILARITY_THRESHOLD) {
        reasons.push('strength');
      }
    }

    const score = compositeSimilarityScore({
      genericScore,
      brandScore,
      codeScore,
      formScore,
      strengthScore});

    const fieldComparisons = [
      buildFieldComparison({
        field: 'generic_name',
        inputValue: inputGenericRaw || null,
        candidateValue: candidateGenericRaw || null,
        score: genericScore,
        exact: genericExact}),
      buildFieldComparison({
        field: 'brand_name',
        inputValue: brandName || null,
        candidateValue: snapshot.brand_name,
        score: brandScore,
        exact: brandExact}),
      buildFieldComparison({
        field: 'code',
        inputValue: code || null,
        candidateValue: snapshot.code,
        score: codeScore,
        exact: codeExact}),
      buildFieldComparison({
        field: 'form',
        inputValue: form || null,
        candidateValue: snapshot.form,
        score: formScore,
        exact: formExact}),
      buildFieldComparison({
        field: 'strength',
        inputValue: strength || null,
        candidateValue: snapshot.strength,
        score: strengthScore,
        exact: strengthExact})].filter((entry) => entry.input_value != null || entry.candidate_value != null);

    if (identityExact) {
      exactIdentityConflict = true;
    }
    if (codeExact) {
      exactCodeConflict = true;
    }

    const isExact = identityExact || codeExact;
    const isSimilar = !isExact && score >= SIMILARITY_THRESHOLD && reasons.length > 0;
    if (!isExact && !isSimilar) {
      continue;
    }

    matches.push({
      drug: snapshot,
      score,
      reasons,
      is_exact: isExact,
      exact_identity_conflict: identityExact,
      exact_code_conflict: codeExact,
      generic_score: genericScore,
      brand_score: brandScore,
      code_score: codeScore,
      form_score: formScore,
      strength_score: strengthScore,
      field_comparisons: fieldComparisons});
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactIdentityConflict,
    exactCodeConflict,
    similarMatches: matches,
    closestScore: matches.length ? matches[0].score : 0};
};

module.exports = {
  SIMILARITY_THRESHOLD,
  checkPharmacyDrugDuplicates};
