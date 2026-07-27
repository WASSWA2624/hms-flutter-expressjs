/**
 * User duplicate / similarity helpers.
 *
 * Scored multi-signal similarity across contact identity (email, phone) and
 * position title within a tenant scope. Same-tenant exact email or exact phone
 * digits hard-block create; softer near matches surface for review and can be
 * overridden with `confirm_similar`. Reuses tenant-similarity text scoring
 * primitives so behaviour matches the role/tenant review dialogs.
 */

const {
  SIMILARITY_THRESHOLD,
  normalizeText,
  normalizeEmail,
  normalizePhone,
  textSimilarityScore
} = require('@lib/tenant/tenant-similarity');

/** Soft floor for review when at least one field is strongly similar. */
const REVIEW_COMPOSITE_THRESHOLD = 72;
/** Field strength required to open a soft composite review. */
const REVIEW_FIELD_THRESHOLD = 75;

const EMAIL_WEIGHT = 50;
const PHONE_WEIGHT = 30;
const POSITION_TITLE_WEIGHT = 20;

const nullIfEmpty = (value) => {
  const trimmed = String(value == null ? '' : value).trim();
  return trimmed ? trimmed : null;
};

const normalizeUserEmail = (value) => normalizeEmail(value);
const normalizeUserPhoneDigits = (value) => normalizePhone(value);
const canonicalizeUserPositionTitle = (value) => normalizeText(value);

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const buildCandidateSnapshot = (user) => ({
  id: user?.id || null,
  human_friendly_id: user?.human_friendly_id || null,
  display_id: user?.display_id || user?.human_friendly_id || user?.id || null,
  tenant_id: user?.tenant_id || user?.tenant?.id || null,
  facility_id: user?.facility_id || user?.facility?.id || null,
  tenant_name: user?.tenant_name || user?.tenant?.name || null,
  facility_name: user?.facility_name || user?.facility?.name || null,
  email: user?.email || null,
  phone: user?.phone || null,
  position_title: user?.position_title || null
});

const compositeUserSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.emailScore, EMAIL_WEIGHT],
    [scores.phoneScore, PHONE_WEIGHT],
    [scores.positionScore, POSITION_TITLE_WEIGHT]
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
 * @param {string|null|undefined} params.email
 * @param {string|null|undefined} params.phone
 * @param {string|null|undefined} params.positionTitle
 * @param {string|null|undefined} [params.tenantId]
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeUserId]
 */
const checkUserDuplicates = ({
  email,
  phone,
  positionTitle,
  tenantId = null,
  existing = [],
  excludeUserId = null
}) => {
  const normalizedEmail = normalizeUserEmail(email);
  const normalizedPhone = normalizeUserPhoneDigits(phone);
  const normalizedPosition = canonicalizeUserPositionTitle(positionTitle);
  const excludeId = String(excludeUserId || '').trim();

  let exactEmailConflict = false;
  let exactPhoneConflict = false;
  const matches = [];
  const seenUserKeys = new Set();
  const peers = Array.isArray(existing) ? existing : [];

  for (const user of peers) {
    const snapshot = buildCandidateSnapshot(user);
    const userId = String(snapshot.id || '').trim();
    const userFriendly = String(snapshot.human_friendly_id || '').trim();
    const userDisplay = String(snapshot.display_id || '').trim();
    if (
      excludeId &&
      (userId === excludeId ||
        userFriendly === excludeId ||
        userDisplay === excludeId)
    ) {
      continue;
    }

    const userKey = userId || userFriendly || userDisplay || snapshot.email || '';
    if (userKey && seenUserKeys.has(userKey)) {
      continue;
    }
    if (userKey) {
      seenUserKeys.add(userKey);
    }

    const peerEmail = normalizeUserEmail(snapshot.email);
    const peerPhone = normalizeUserPhoneDigits(snapshot.phone);
    const peerPosition = canonicalizeUserPositionTitle(snapshot.position_title);

    const emailExact =
      Boolean(normalizedEmail) && Boolean(peerEmail) && peerEmail === normalizedEmail;
    const phoneExact =
      Boolean(normalizedPhone) && Boolean(peerPhone) && peerPhone === normalizedPhone;
    const positionExact =
      Boolean(normalizedPosition) &&
      Boolean(peerPosition) &&
      peerPosition === normalizedPosition;

    let emailScore = null;
    let phoneScore = null;
    let positionScore = null;
    const reasons = [];

    if (normalizedEmail && peerEmail) {
      emailScore = emailExact
        ? 100
        : textSimilarityScore(normalizedEmail, peerEmail, {
          includeTokenSimilarity: false
        });
      if (emailExact || emailScore >= REVIEW_FIELD_THRESHOLD) {
        reasons.push('email');
      }
    }

    if (normalizedPhone && peerPhone) {
      phoneScore = phoneExact
        ? 100
        : textSimilarityScore(normalizedPhone, peerPhone, {
          includeTokenSimilarity: false
        });
      if (phoneExact || phoneScore >= REVIEW_FIELD_THRESHOLD) {
        reasons.push('phone');
      }
    }

    if (normalizedPosition && peerPosition) {
      positionScore = positionExact
        ? 100
        : textSimilarityScore(normalizedPosition, peerPosition);
      if (positionExact || positionScore >= REVIEW_FIELD_THRESHOLD) {
        reasons.push('position_title');
      }
    }

    const score = compositeUserSimilarityScore({
      emailScore,
      phoneScore,
      positionScore
    });
    const strongestField = maxScore(emailScore, phoneScore, positionScore);

    const fieldComparisons = [
      buildFieldComparison({
        field: 'email',
        inputValue: email,
        candidateValue: snapshot.email,
        score: emailScore,
        exact: emailExact
      }),
      buildFieldComparison({
        field: 'phone',
        inputValue: phone,
        candidateValue: snapshot.phone,
        score: phoneScore,
        exact: phoneExact
      }),
      buildFieldComparison({
        field: 'position_title',
        inputValue: positionTitle,
        candidateValue: snapshot.position_title,
        score: positionScore,
        exact: positionExact
      }),
      buildFieldComparison({
        field: 'display_id',
        inputValue: null,
        candidateValue: snapshot.display_id,
        score: null,
        exact: false
      })
    ].filter((entry) => entry.input_value != null || entry.candidate_value != null);

    // Exact contact within the tenant is a hard uniqueness conflict.
    if (emailExact) {
      exactEmailConflict = true;
    }
    if (phoneExact) {
      exactPhoneConflict = true;
    }

    const isExact = emailExact || phoneExact;
    const strongIdentitySignal =
      strongestField != null && strongestField >= SIMILARITY_THRESHOLD;
    const compositeSignal = score >= SIMILARITY_THRESHOLD;
    const softCompositeSignal =
      score >= REVIEW_COMPOSITE_THRESHOLD &&
      strongestField != null &&
      strongestField >= REVIEW_FIELD_THRESHOLD;

    if (
      !isExact &&
      !strongIdentitySignal &&
      !compositeSignal &&
      !softCompositeSignal
    ) {
      continue;
    }

    matches.push({
      ...snapshot,
      score,
      reasons: reasons.length ? [...new Set(reasons)] : ['email'],
      isExact,
      exactEmailConflict: emailExact,
      exactPhoneConflict: phoneExact,
      emailScore,
      phoneScore,
      positionScore,
      field_comparisons: fieldComparisons
    });
  }

  matches.sort((left, right) => {
    const leftBlocking =
      left.exactEmailConflict || left.exactPhoneConflict ? 1 : 0;
    const rightBlocking =
      right.exactEmailConflict || right.exactPhoneConflict ? 1 : 0;
    const byBlocking = rightBlocking - leftBlocking;
    if (byBlocking !== 0) return byBlocking;
    const byScore = right.score - left.score;
    if (byScore !== 0) return byScore;
    return Number(right.isExact) - Number(left.isExact);
  });

  const hasExactConflict = exactEmailConflict || exactPhoneConflict;

  return {
    tenantId: nullIfEmpty(tenantId),
    exactEmailConflict,
    exactPhoneConflict,
    hasExactConflict,
    similarMatches: matches,
    nonExactSimilarMatches: matches.filter((match) => !match.isExact),
    overridableMatches: matches.filter(
      (match) => !match.exactEmailConflict && !match.exactPhoneConflict
    )
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  REVIEW_COMPOSITE_THRESHOLD,
  REVIEW_FIELD_THRESHOLD,
  EMAIL_WEIGHT,
  PHONE_WEIGHT,
  POSITION_TITLE_WEIGHT,
  normalizeUserEmail,
  normalizeUserPhoneDigits,
  canonicalizeUserPositionTitle,
  compositeUserSimilarityScore,
  buildCandidateSnapshot,
  checkUserDuplicates
};
