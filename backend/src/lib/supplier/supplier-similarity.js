/**
 * Supplier duplicate / similarity helpers (tenant-scoped).
 *
 * Weighted multi-field similarity across name, contact email, phone, and location.
 * Reuses tenant-similarity text scoring primitives (same stack as facility/pharmacy).
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  normalizeEmail,
  normalizePhone,
  textSimilarityScore,
} = require('@lib/tenant/tenant-similarity');

const NAME_WEIGHT = 50;
const EMAIL_WEIGHT = 20;
const PHONE_WEIGHT = 20;
const LOCATION_WEIGHT = 10;

const normalizeLocation = (value) => normalizeText(value);

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const pickAddressLine = (addresses = []) => {
  const active = (Array.isArray(addresses) ? addresses : []).filter(
    (entry) => entry?.deleted_at == null
  );
  if (!active.length) return null;
  return String(active[0]?.line1 || '').trim() || null;
};

const buildCandidateSnapshot = (supplier) => {
  const addresses = Array.isArray(supplier?.addresses) ? supplier.addresses : [];
  return {
    id: supplier?.id || null,
    human_friendly_id: supplier?.human_friendly_id || null,
    display_id:
      supplier?.display_id || supplier?.human_friendly_id || supplier?.id || null,
    tenant_id: supplier?.tenant_id || null,
    name: supplier?.name || null,
    contact_email: supplier?.contact_email || null,
    phone: supplier?.phone || null,
    location: supplier?.location || pickAddressLine(addresses),
  };
};

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
    [scores.emailScore, EMAIL_WEIGHT],
    [scores.phoneScore, PHONE_WEIGHT],
    [scores.locationScore, LOCATION_WEIGHT],
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
  exact = false,
}) => ({
  field,
  input_value: inputValue == null || inputValue === '' ? null : String(inputValue),
  candidate_value:
    candidateValue == null || candidateValue === '' ? null : String(candidateValue),
  score: score == null ? null : score,
  status: comparisonStatus(score, { exact }),
});

/**
 * @param {Object} params
 * @param {string} params.name
 * @param {string|null|undefined} params.contactEmail
 * @param {string|null|undefined} params.phone
 * @param {string|null|undefined} params.location
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeSupplierId]
 */
const checkSupplierDuplicates = ({
  name,
  contactEmail,
  phone,
  location,
  existing = [],
  excludeSupplierId = null,
}) => {
  const normalizedName = normalizeText(name);
  const normalizedEmail = normalizeEmail(contactEmail);
  const normalizedPhone = normalizePhone(phone);
  const normalizedLocation = normalizeLocation(location);
  const excludeId = String(excludeSupplierId || '').trim();

  let exactNameConflict = false;
  let exactEmailConflict = false;
  let exactPhoneConflict = false;
  const matches = [];

  for (const supplier of existing) {
    const snapshot = buildCandidateSnapshot(supplier);
    const supplierId = String(snapshot.id || '').trim();
    const supplierFriendly = String(snapshot.human_friendly_id || '').trim();
    const supplierDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (supplierId === excludeId ||
        supplierFriendly === excludeId ||
        supplierDisplay === excludeId)
    ) {
      continue;
    }

    const supplierName = normalizeText(snapshot.name);
    const supplierEmail = normalizeEmail(snapshot.contact_email);
    const supplierPhone = normalizePhone(snapshot.phone);
    const supplierLocation = normalizeLocation(snapshot.location);

    const nameExact = Boolean(normalizedName) && supplierName === normalizedName;
    const emailExact =
      Boolean(normalizedEmail) &&
      Boolean(supplierEmail) &&
      supplierEmail === normalizedEmail;
    const phoneExact =
      Boolean(normalizedPhone) &&
      Boolean(supplierPhone) &&
      supplierPhone === normalizedPhone;
    const locationExact =
      Boolean(normalizedLocation) &&
      Boolean(supplierLocation) &&
      supplierLocation === normalizedLocation;

    let nameScore = null;
    let emailScore = null;
    let phoneScore = null;
    let locationScore = null;
    const reasons = [];

    if (normalizedName && supplierName) {
      nameScore = nameExact ? 100 : textSimilarityScore(normalizedName, supplierName);
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (normalizedEmail && supplierEmail) {
      emailScore = emailExact
        ? 100
        : textSimilarityScore(normalizedEmail, supplierEmail, {
            includeTokenSimilarity: false,
          });
      if (emailExact || emailScore >= SIMILARITY_THRESHOLD) {
        reasons.push('contact_email');
      }
    }

    if (normalizedPhone && supplierPhone) {
      phoneScore = phoneExact
        ? 100
        : textSimilarityScore(normalizedPhone, supplierPhone, {
            includeTokenSimilarity: false,
          });
      if (phoneExact || phoneScore >= SIMILARITY_THRESHOLD) {
        reasons.push('phone');
      }
    }

    if (normalizedLocation && supplierLocation) {
      locationScore = locationExact
        ? 100
        : textSimilarityScore(normalizedLocation, supplierLocation);
      if (locationExact || locationScore >= SIMILARITY_THRESHOLD) {
        reasons.push('location');
      }
    }

    const score = compositeSimilarityScore({
      nameScore,
      emailScore,
      phoneScore,
      locationScore,
    });

    const fieldComparisons = [
      buildFieldComparison({
        field: 'name',
        inputValue: name,
        candidateValue: snapshot.name,
        score: nameScore,
        exact: nameExact,
      }),
      buildFieldComparison({
        field: 'contact_email',
        inputValue: contactEmail || null,
        candidateValue: snapshot.contact_email,
        score: emailScore,
        exact: emailExact,
      }),
      buildFieldComparison({
        field: 'phone',
        inputValue: phone || null,
        candidateValue: snapshot.phone,
        score: phoneScore,
        exact: phoneExact,
      }),
      buildFieldComparison({
        field: 'location',
        inputValue: location || null,
        candidateValue: snapshot.location,
        score: locationScore,
        exact: locationExact,
      }),
    ].filter((entry) => entry.input_value != null || entry.candidate_value != null);

    if (nameExact) exactNameConflict = true;
    if (emailExact) exactEmailConflict = true;
    if (phoneExact) exactPhoneConflict = true;

    const isExact = nameExact || emailExact || phoneExact;
    const strongIdentitySignal =
      (nameScore != null && nameScore >= SIMILARITY_THRESHOLD) ||
      emailExact ||
      phoneExact;
    const compositeSignal = score >= SIMILARITY_THRESHOLD && reasons.length > 0;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    matches.push({
      supplier: snapshot,
      score,
      reasons: reasons.length ? reasons : ['name'],
      is_exact: isExact,
      exact_name_conflict: nameExact,
      exact_email_conflict: emailExact,
      exact_phone_conflict: phoneExact,
      name_score: nameScore,
      email_score: emailScore,
      phone_score: phoneScore,
      location_score: locationScore,
      field_comparisons: fieldComparisons,
    });
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactNameConflict,
    exactEmailConflict,
    exactPhoneConflict,
    similarMatches: matches,
    closestScore: matches.length ? matches[0].score : 0,
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  NAME_WEIGHT,
  EMAIL_WEIGHT,
  PHONE_WEIGHT,
  LOCATION_WEIGHT,
  compositeSimilarityScore,
  checkSupplierDuplicates,
  buildCandidateSnapshot,
};
