/**
 * Facility duplicate / similarity helpers.
 *
 * Weighted multi-field similarity across identity, type/status, and contacts.
 * Reuses tenant-similarity text scoring primitives.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  normalizeEmail,
  normalizePhone,
  textSimilarityScore
} = require('@lib/tenant/tenant-similarity');

const NAME_WEIGHT = 35;
const TYPE_WEIGHT = 12;
const STATUS_WEIGHT = 8;
const EMAIL_WEIGHT = 15;
const PHONE_WEIGHT = 15;
const ADDRESS_WEIGHT = 10;
const CITY_WEIGHT = 3;
const COUNTRY_WEIGHT = 2;

const normalizeFacilityType = (value) =>
  String(value || '')
    .trim()
    .toUpperCase();

const normalizeAddress = (value) => normalizeText(value);

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const pickPrimaryContactValue = (contacts = [], type) => {
  const matches = contacts.filter(
    (entry) =>
      String(entry?.contact_type || '').toUpperCase() === type &&
      entry?.deleted_at == null
  );
  if (!matches.length) return null;
  const primary = matches.find((entry) => entry.is_primary === true);
  return String((primary || matches[0]).value || '').trim() || null;
};

const pickAddress = (addresses = []) => {
  const active = addresses.filter((entry) => entry?.deleted_at == null);
  if (!active.length) return null;
  return active[0];
};

const buildCandidateSnapshot = (facility) => {
  const contacts = Array.isArray(facility?.contacts) ? facility.contacts : [];
  const addresses = Array.isArray(facility?.addresses) ? facility.addresses : [];
  const address = pickAddress(addresses);
  return {
    id: facility?.id || null,
    human_friendly_id: facility?.human_friendly_id || null,
    display_id:
      facility?.display_id || facility?.human_friendly_id || facility?.id || null,
    tenant_id: facility?.tenant_id || null,
    name: facility?.name || null,
    facility_type: facility?.facility_type || null,
    is_active: facility?.is_active !== false,
    phone: facility?.phone || pickPrimaryContactValue(contacts, 'PHONE'),
    email: facility?.email || pickPrimaryContactValue(contacts, 'EMAIL'),
    address_line1: facility?.address_line1 || address?.line1 || null,
    city: facility?.city || address?.city || null,
    country: facility?.country || address?.country || null
  };
};

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
    [scores.typeScore, TYPE_WEIGHT],
    [scores.statusScore, STATUS_WEIGHT],
    [scores.emailScore, EMAIL_WEIGHT],
    [scores.phoneScore, PHONE_WEIGHT],
    [scores.addressScore, ADDRESS_WEIGHT],
    [scores.cityScore, CITY_WEIGHT],
    [scores.countryScore, COUNTRY_WEIGHT]
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

/**
 * @param {Object} params
 * @param {string} params.name
 * @param {string|null|undefined} params.facilityType
 * @param {boolean|null|undefined} params.isActive
 * @param {string|null|undefined} params.phone
 * @param {string|null|undefined} params.email
 * @param {string|null|undefined} params.addressLine1
 * @param {string|null|undefined} params.city
 * @param {string|null|undefined} params.country
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeFacilityId]
 */
const checkFacilityDuplicates = ({
  name,
  facilityType,
  isActive,
  phone,
  email,
  addressLine1,
  city,
  country,
  existing = [],
  excludeFacilityId = null
}) => {
  const normalizedName = normalizeText(name);
  const normalizedType = normalizeFacilityType(facilityType);
  const normalizedPhone = normalizePhone(phone);
  const normalizedEmail = normalizeEmail(email);
  const normalizedAddress = normalizeAddress(addressLine1);
  const normalizedCity = normalizeAddress(city);
  const normalizedCountry = normalizeAddress(country);
  const normalizedActive = isActive === false ? false : true;
  const excludeId = String(excludeFacilityId || '').trim();

  let exactNameConflict = false;
  const matches = [];

  for (const facility of existing) {
    const snapshot = buildCandidateSnapshot(facility);
    const facilityId = String(snapshot.id || '').trim();
    const facilityFriendly = String(snapshot.human_friendly_id || '').trim();
    const facilityDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (facilityId === excludeId ||
        facilityFriendly === excludeId ||
        facilityDisplay === excludeId)
    ) {
      continue;
    }

    const facilityName = normalizeText(snapshot.name);
    const facilityTypeValue = normalizeFacilityType(snapshot.facility_type);
    const facilityPhone = normalizePhone(snapshot.phone);
    const facilityEmail = normalizeEmail(snapshot.email);
    const facilityAddress = normalizeAddress(snapshot.address_line1);
    const facilityCity = normalizeAddress(snapshot.city);
    const facilityCountry = normalizeAddress(snapshot.country);
    const facilityActive = snapshot.is_active !== false;

    const nameExact = Boolean(normalizedName) && facilityName === normalizedName;
    const typeExact =
      Boolean(normalizedType) &&
      Boolean(facilityTypeValue) &&
      facilityTypeValue === normalizedType;
    const statusExact = facilityActive === normalizedActive;
    const phoneExact =
      Boolean(normalizedPhone) &&
      Boolean(facilityPhone) &&
      facilityPhone === normalizedPhone;
    const emailExact =
      Boolean(normalizedEmail) &&
      Boolean(facilityEmail) &&
      facilityEmail === normalizedEmail;
    const addressExact =
      Boolean(normalizedAddress) &&
      Boolean(facilityAddress) &&
      facilityAddress === normalizedAddress;
    const cityExact =
      Boolean(normalizedCity) &&
      Boolean(facilityCity) &&
      facilityCity === normalizedCity;
    const countryExact =
      Boolean(normalizedCountry) &&
      Boolean(facilityCountry) &&
      facilityCountry === normalizedCountry;

    let nameScore = null;
    let typeScore = null;
    let statusScore = null;
    let emailScore = null;
    let phoneScore = null;
    let addressScore = null;
    let cityScore = null;
    let countryScore = null;
    const reasons = [];

    if (normalizedName && facilityName) {
      nameScore = nameExact ? 100 : textSimilarityScore(normalizedName, facilityName);
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (normalizedType && facilityTypeValue) {
      typeScore = typeExact ? 100 : 0;
      if (typeExact) {
        reasons.push('facility_type');
      }
    }

    statusScore = statusExact ? 100 : 0;
    if (statusExact) {
      reasons.push('status');
    }

    if (normalizedEmail && facilityEmail) {
      emailScore = emailExact
        ? 100
        : textSimilarityScore(normalizedEmail, facilityEmail, {
            includeTokenSimilarity: false
          });
      if (emailExact || emailScore >= SIMILARITY_THRESHOLD) {
        reasons.push('email');
      }
    }

    if (normalizedPhone && facilityPhone) {
      phoneScore = phoneExact
        ? 100
        : textSimilarityScore(normalizedPhone, facilityPhone, {
            includeTokenSimilarity: false
          });
      if (phoneExact || phoneScore >= SIMILARITY_THRESHOLD) {
        reasons.push('phone');
      }
    }

    if (normalizedAddress && facilityAddress) {
      addressScore = addressExact
        ? 100
        : textSimilarityScore(normalizedAddress, facilityAddress);
      if (addressExact || addressScore >= SIMILARITY_THRESHOLD) {
        reasons.push('address');
      }
    }

    if (normalizedCity && facilityCity) {
      cityScore = cityExact
        ? 100
        : textSimilarityScore(normalizedCity, facilityCity);
      if (cityExact || cityScore >= SIMILARITY_THRESHOLD) {
        reasons.push('city');
      }
    }

    if (normalizedCountry && facilityCountry) {
      countryScore = countryExact
        ? 100
        : textSimilarityScore(normalizedCountry, facilityCountry);
      if (countryExact || countryScore >= SIMILARITY_THRESHOLD) {
        reasons.push('country');
      }
    }

    const score = compositeSimilarityScore({
      nameScore,
      typeScore,
      statusScore,
      emailScore,
      phoneScore,
      addressScore,
      cityScore,
      countryScore
    });

    const fieldComparisons = [
      buildFieldComparison({
        field: 'name',
        inputValue: name,
        candidateValue: snapshot.name,
        score: nameScore,
        exact: nameExact
      }),
      buildFieldComparison({
        field: 'facility_type',
        inputValue: facilityType,
        candidateValue: snapshot.facility_type,
        score: typeScore,
        exact: typeExact
      }),
      buildFieldComparison({
        field: 'status',
        inputValue: normalizedActive ? 'active' : 'inactive',
        candidateValue: facilityActive ? 'active' : 'inactive',
        score: statusScore,
        exact: statusExact
      }),
      buildFieldComparison({
        field: 'phone',
        inputValue: phone,
        candidateValue: snapshot.phone,
        score: phoneScore,
        exact: phoneExact
      }),
      buildFieldComparison({
        field: 'email',
        inputValue: email,
        candidateValue: snapshot.email,
        score: emailScore,
        exact: emailExact
      }),
      buildFieldComparison({
        field: 'address_line1',
        inputValue: addressLine1,
        candidateValue: snapshot.address_line1,
        score: addressScore,
        exact: addressExact
      }),
      buildFieldComparison({
        field: 'city',
        inputValue: city,
        candidateValue: snapshot.city,
        score: cityScore,
        exact: cityExact
      }),
      buildFieldComparison({
        field: 'country',
        inputValue: country,
        candidateValue: snapshot.country,
        score: countryScore,
        exact: countryExact
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

    const isExact = nameExact;
    const strongIdentitySignal =
      (nameScore != null && nameScore >= SIMILARITY_THRESHOLD) ||
      (emailScore != null && emailScore >= SIMILARITY_THRESHOLD) ||
      (phoneScore != null && phoneScore >= SIMILARITY_THRESHOLD) ||
      (addressScore != null && addressScore >= SIMILARITY_THRESHOLD);
    const compositeSignal = score >= SIMILARITY_THRESHOLD;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    matches.push({
      ...snapshot,
      score,
      reasons: reasons.length ? reasons : ['name'],
      isExact,
      exactNameConflict: nameExact,
      nameScore,
      typeScore,
      statusScore,
      emailScore,
      phoneScore,
      addressScore,
      cityScore,
      countryScore,
      field_comparisons: fieldComparisons
    });
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactNameConflict,
    hasExactConflict: exactNameConflict,
    similarMatches: matches,
    nonExactSimilarMatches: matches.filter((match) => !match.isExact),
    overridableMatches: matches.filter((match) => !match.exactNameConflict)
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  NAME_WEIGHT,
  TYPE_WEIGHT,
  STATUS_WEIGHT,
  EMAIL_WEIGHT,
  PHONE_WEIGHT,
  ADDRESS_WEIGHT,
  CITY_WEIGHT,
  COUNTRY_WEIGHT,
  normalizeFacilityType,
  normalizeAddress,
  compositeSimilarityScore,
  checkFacilityDuplicates,
  buildCandidateSnapshot
};
