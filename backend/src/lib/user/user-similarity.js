/**
 * User duplicate / similarity helpers.
 *
 * Comprehensive multi-signal similarity across contact identity (email, phone),
 * person name (first / last / full / swapped / initials / email-local),
 * position title (with hospital-role aliases), and facility affinity within a
 * tenant. Same-tenant exact email or exact phone digits hard-block create;
 * softer near matches surface for review and can be overridden with
 * `confirm_similar`. Reuses tenant-similarity text scoring primitives so
 * behaviour matches the role/tenant review dialogs.
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
/** Phone must clear this before diluting the composite score. */
const PHONE_COMPOSITE_MIN = 85;
/** Name-led soft review when identity support is only moderate. */
const NAME_LED_THRESHOLD = 88;
const IDENTITY_SUPPORT_THRESHOLD = 60;
const TOKEN_MATCH_THRESHOLD = 85;
const TOKEN_SUBSET_THRESHOLD = 78;

const EMAIL_WEIGHT = 34;
const PHONE_WEIGHT = 20;
const FULL_NAME_WEIGHT = 24;
const POSITION_TITLE_WEIGHT = 14;
const FACILITY_WEIGHT = 8;

const NAME_FILLER_TOKENS = new Set([
  'a',
  'an',
  'and',
  'dr',
  'jr',
  'md',
  'miss',
  'mr',
  'mrs',
  'ms',
  'of',
  'prof',
  'sir',
  'sr',
  'the'
]);

/** Hospital position aliases — aligned with role-similarity expansions. */
const POSITION_ALIAS_EXPANSIONS = Object.freeze({
  cna: 'certified nursing assistant',
  dr: 'doctor',
  hca: 'health care assistant',
  hcw: 'health care worker',
  lpn: 'licensed practical nurse',
  md: 'medical doctor',
  mo: 'medical officer',
  np: 'nurse practitioner',
  pa: 'physician assistant',
  rn: 'registered nurse',
  rns: 'registered nurse',
  sho: 'senior house officer'
});

const nullIfEmpty = (value) => {
  const trimmed = String(value == null ? '' : value).trim();
  return trimmed ? trimmed : null;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Public UI label — never surface raw UUIDs. */
const publicLabel = (value) => {
  const trimmed = nullIfEmpty(value);
  if (!trimmed) return null;
  if (UUID_PATTERN.test(trimmed)) return null;
  return trimmed;
};

const tokensOf = (value) =>
  String(value || '')
    .split(/\s+/)
    .filter(Boolean);

const significantNameTokens = (value) =>
  tokensOf(value).filter((token) => !NAME_FILLER_TOKENS.has(token));

const normalizeUserEmail = (value) => normalizeEmail(value);
const normalizeUserPhoneDigits = (value) => normalizePhone(value);

const canonicalizePersonName = (value) => {
  const normalized = normalizeText(value);
  if (!normalized) return '';
  return significantNameTokens(normalized).join(' ');
};

const canonicalizeUserPositionTitle = (value) => {
  const normalized = normalizeText(value);
  if (!normalized) return '';

  const expanded = [];
  for (const token of tokensOf(normalized)) {
    const alias = POSITION_ALIAS_EXPANSIONS[token];
    if (alias) {
      expanded.push(...tokensOf(alias));
    } else if (!NAME_FILLER_TOKENS.has(token)) {
      expanded.push(token);
    }
  }
  return expanded.join(' ');
};

const compactKey = (value) => String(value || '').replace(/\s+/g, '');

const sortedTokenKey = (value) => significantNameTokens(value).sort().join(' ');

const initialsKey = (value) => {
  const tokens = significantNameTokens(value);
  if (tokens.length < 2) return '';
  return tokens.map((token) => token[0]).join('');
};

const joinPersonName = ({ firstName, middleName, lastName } = {}) =>
  [firstName, middleName, lastName]
    .map((part) => String(part == null ? '' : part).trim())
    .filter(Boolean)
    .join(' ');

const emailLocalPart = (email) => {
  const normalized = normalizeUserEmail(email);
  if (!normalized) return '';
  const at = normalized.indexOf('@');
  return at > 0 ? normalized.slice(0, at) : normalized;
};

const canonicalizeEmailLocalAsName = (email) => {
  const local = emailLocalPart(email);
  if (!local) return '';
  return canonicalizePersonName(local.replace(/[._+\-0-9]+/g, ' '));
};

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const profileOf = (user) => user?.profile || user?.user_profile || null;

const buildCandidateSnapshot = (user) => {
  const profile = profileOf(user);
  const firstName =
    user?.first_name || user?.firstName || profile?.first_name || null;
  const middleName =
    user?.middle_name || user?.middleName || profile?.middle_name || null;
  const lastName =
    user?.last_name || user?.lastName || profile?.last_name || null;
  const fullName =
    user?.profile_name ||
    user?.profileName ||
    nullIfEmpty(joinPersonName({ firstName, middleName, lastName }));

  return {
    id: user?.id || null,
    human_friendly_id: user?.human_friendly_id || null,
    display_id: publicLabel(
      user?.human_friendly_id || user?.display_id || null
    ),
    tenant_id: user?.tenant_id || user?.tenant?.id || null,
    facility_id: user?.facility_id || user?.facility?.id || null,
    tenant_name: user?.tenant_name || user?.tenant?.name || null,
    facility_name: user?.facility_name || user?.facility?.name || null,
    email: user?.email || null,
    phone: user?.phone || null,
    position_title: user?.position_title || user?.positionTitle || null,
    first_name: firstName,
    middle_name: middleName,
    last_name: lastName,
    full_name: fullName
  };
};

const levenshteinSimilarityPercent = (left, right) =>
  textSimilarityScore(left, right, { includeTokenSimilarity: false });

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
  const leftTokens = significantNameTokens(left);
  const rightTokens = significantNameTokens(right);
  if (!leftTokens.length || !rightTokens.length) return 0;
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
  const jaccard =
    union === 0 ? 0 : Math.round((fuzzyIntersection / union) * 100);
  return Math.max(averageDirectional, jaccard);
};

const tokenSubsetScore = (left, right) => {
  const leftTokens = significantNameTokens(left);
  const rightTokens = significantNameTokens(right);
  if (!leftTokens.length || !rightTokens.length) return null;

  const [shorter, longer] =
    leftTokens.length <= rightTokens.length
      ? [leftTokens, rightTokens]
      : [rightTokens, leftTokens];
  if (shorter.length < 2) return null;

  const longerSet = new Set(longer);
  const covered = shorter.filter((token) => longerSet.has(token)).length;
  if (covered !== shorter.length) return null;

  const coverage = shorter.length / longer.length;
  return Math.min(99, Math.round(TOKEN_SUBSET_THRESHOLD + coverage * 20));
};

/**
 * Intelligent person/position text score: exact, compact, sorted tokens,
 * initials, token Jaccard / subset, and Levenshtein.
 */
const scorePersonTextPair = (leftRaw, rightRaw) => {
  const left = canonicalizePersonName(leftRaw);
  const right = canonicalizePersonName(rightRaw);
  if (!left || !right) return null;
  if (left === right) return 100;

  const direct = textSimilarityScore(left, right);
  const leftCompact = compactKey(left);
  const rightCompact = compactKey(right);
  const compact =
    leftCompact && rightCompact
      ? leftCompact === rightCompact
        ? 100
        : levenshteinSimilarityPercent(leftCompact, rightCompact)
      : 0;

  const leftSorted = sortedTokenKey(left);
  const rightSorted = sortedTokenKey(right);
  const sorted =
    leftSorted && rightSorted
      ? leftSorted === rightSorted
        ? 100
        : levenshteinSimilarityPercent(leftSorted, rightSorted)
      : 0;

  const leftInitials = initialsKey(left);
  const rightInitials = initialsKey(right);
  const initials =
    leftInitials && rightInitials && leftInitials === rightInitials ? 82 : 0;

  const tokenScore = tokenSimilarityPercent(left, right);
  const subset = tokenSubsetScore(left, right) || 0;

  return Math.max(direct, compact, sorted, initials, tokenScore, subset);
};

const scorePositionPair = (leftRaw, rightRaw) => {
  const left = canonicalizeUserPositionTitle(leftRaw);
  const right = canonicalizeUserPositionTitle(rightRaw);
  if (!left || !right) return null;
  if (left === right) return 100;
  return scorePersonTextPair(left, right);
};

/**
 * Phone scoring that prefers national-number / suffix equivalence and avoids
 * noisy mid-range Levenshtein hits on unrelated numbers.
 */
const scorePhonePair = (leftDigits, rightDigits) => {
  if (!leftDigits || !rightDigits) return null;
  if (leftDigits === rightDigits) return 100;

  const [shorter, longer] =
    leftDigits.length <= rightDigits.length
      ? [leftDigits, rightDigits]
      : [rightDigits, leftDigits];

  if (shorter.length >= 9 && longer.endsWith(shorter)) return 100;
  if (shorter.length >= 7 && longer.endsWith(shorter)) return 94;

  const leftTail9 = leftDigits.slice(-9);
  const rightTail9 = rightDigits.slice(-9);
  if (leftTail9.length === 9 && leftTail9 === rightTail9) return 98;

  const leftTail7 = leftDigits.slice(-7);
  const rightTail7 = rightDigits.slice(-7);
  if (leftTail7.length === 7 && leftTail7 === rightTail7) return 90;

  const soft = levenshteinSimilarityPercent(leftDigits, rightDigits);
  // Unrelated numbers often land ~30–50%; ignore those for identity.
  if (soft < 88) return soft < 50 ? 0 : soft;
  return soft;
};

const scoreFacilityPair = (leftFacilityId, rightFacilityId) => {
  const left = nullIfEmpty(leftFacilityId);
  const right = nullIfEmpty(rightFacilityId);
  if (!left || !right) return null;
  return left === right ? 100 : 0;
};

const compositeUserSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.emailScore, EMAIL_WEIGHT],
    [scores.phoneScore, PHONE_WEIGHT],
    [scores.fullNameScore, FULL_NAME_WEIGHT],
    [scores.positionScore, POSITION_TITLE_WEIGHT],
    [scores.facilityScore, FACILITY_WEIGHT]
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
 * @param {string|null|undefined} [params.firstName]
 * @param {string|null|undefined} [params.middleName]
 * @param {string|null|undefined} [params.lastName]
 * @param {string|null|undefined} [params.facilityId]
 * @param {string|null|undefined} [params.facilityName]
 * @param {string|null|undefined} [params.tenantId]
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeUserId]
 */
const checkUserDuplicates = ({
  email,
  phone,
  positionTitle,
  firstName = null,
  middleName = null,
  lastName = null,
  facilityId = null,
  facilityName = null,
  tenantId = null,
  existing = [],
  excludeUserId = null
}) => {
  const normalizedEmail = normalizeUserEmail(email);
  const normalizedPhone = normalizeUserPhoneDigits(phone);
  const normalizedPosition = canonicalizeUserPositionTitle(positionTitle);
  const inputFirst = canonicalizePersonName(firstName);
  const inputMiddle = canonicalizePersonName(middleName);
  const inputLast = canonicalizePersonName(lastName);
  const inputFullRaw = joinPersonName({ firstName, middleName, lastName });
  const inputFull = canonicalizePersonName(inputFullRaw);
  const inputSwapped = canonicalizePersonName(
    joinPersonName({ firstName: lastName, lastName: firstName })
  );
  const inputEmailLocalName = canonicalizeEmailLocalAsName(email);
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
    const peerFirst = canonicalizePersonName(snapshot.first_name);
    const peerMiddle = canonicalizePersonName(snapshot.middle_name);
    const peerLast = canonicalizePersonName(snapshot.last_name);
    const peerFullRaw =
      snapshot.full_name ||
      joinPersonName({
        firstName: snapshot.first_name,
        middleName: snapshot.middle_name,
        lastName: snapshot.last_name
      });
    const peerFull = canonicalizePersonName(peerFullRaw);

    const emailExact =
      Boolean(normalizedEmail) && Boolean(peerEmail) && peerEmail === normalizedEmail;
    const phoneExact =
      Boolean(normalizedPhone) && Boolean(peerPhone) && peerPhone === normalizedPhone;
    const positionExact =
      Boolean(normalizedPosition) &&
      Boolean(peerPosition) &&
      peerPosition === normalizedPosition;
    const firstExact =
      Boolean(inputFirst) && Boolean(peerFirst) && inputFirst === peerFirst;
    const lastExact =
      Boolean(inputLast) && Boolean(peerLast) && inputLast === peerLast;
    const fullExact =
      Boolean(inputFull) && Boolean(peerFull) && inputFull === peerFull;

    let emailScore = null;
    let phoneScore = null;
    let phoneScoreForComposite = null;
    let firstNameScore = null;
    let lastNameScore = null;
    let fullNameScore = null;
    let positionScore = null;
    let facilityScore = null;
    let emailLocalNameScore = null;
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
      phoneScore = scorePhonePair(normalizedPhone, peerPhone);
      if (phoneExact || (phoneScore != null && phoneScore >= PHONE_COMPOSITE_MIN)) {
        phoneScoreForComposite = phoneScore;
      }
      if (phoneExact || (phoneScore != null && phoneScore >= REVIEW_FIELD_THRESHOLD)) {
        reasons.push('phone');
      }
    }

    if (inputFirst && peerFirst) {
      firstNameScore = firstExact ? 100 : scorePersonTextPair(inputFirst, peerFirst);
    }
    if (inputLast && peerLast) {
      lastNameScore = lastExact ? 100 : scorePersonTextPair(inputLast, peerLast);
    }
    if (inputMiddle && peerMiddle) {
      const middleScore = scorePersonTextPair(inputMiddle, peerMiddle);
      if (middleScore != null) {
        firstNameScore = maxScore(firstNameScore, middleScore);
      }
    }

    const nameCandidates = [];
    if (inputFull && peerFull) {
      nameCandidates.push(fullExact ? 100 : scorePersonTextPair(inputFull, peerFull));
    }
    if (inputSwapped && peerFull) {
      nameCandidates.push(scorePersonTextPair(inputSwapped, peerFull));
    }
    if (firstNameScore != null && lastNameScore != null) {
      nameCandidates.push(Math.round((firstNameScore + lastNameScore) / 2));
    } else if (firstNameScore != null) {
      nameCandidates.push(firstNameScore);
    } else if (lastNameScore != null) {
      nameCandidates.push(lastNameScore);
    }
    fullNameScore = maxScore(...nameCandidates);

    if (inputEmailLocalName && peerFull) {
      emailLocalNameScore = scorePersonTextPair(inputEmailLocalName, peerFull);
      if (emailLocalNameScore != null) {
        fullNameScore = maxScore(fullNameScore, emailLocalNameScore);
      }
    }

    if (
      fullNameScore != null &&
      (fullExact || fullNameScore >= REVIEW_FIELD_THRESHOLD)
    ) {
      reasons.push('full_name');
    }
    if (
      firstNameScore != null &&
      (firstExact || firstNameScore >= REVIEW_FIELD_THRESHOLD)
    ) {
      reasons.push('first_name');
    }
    if (
      lastNameScore != null &&
      (lastExact || lastNameScore >= REVIEW_FIELD_THRESHOLD)
    ) {
      reasons.push('last_name');
    }
    if (
      emailLocalNameScore != null &&
      emailLocalNameScore >= REVIEW_FIELD_THRESHOLD
    ) {
      reasons.push('email_local_name');
    }

    if (normalizedPosition && peerPosition) {
      positionScore = positionExact
        ? 100
        : scorePositionPair(positionTitle, snapshot.position_title);
      if (positionExact || positionScore >= REVIEW_FIELD_THRESHOLD) {
        reasons.push('position_title');
      }
    }

    facilityScore = scoreFacilityPair(facilityId, snapshot.facility_id);
    if (facilityScore === 100) {
      reasons.push('facility');
    }

    const score = compositeUserSimilarityScore({
      emailScore,
      phoneScore: phoneScoreForComposite,
      fullNameScore,
      positionScore,
      facilityScore: facilityScore === 100 ? 100 : null
    });
    const strongestField = maxScore(
      emailScore,
      phoneScoreForComposite,
      fullNameScore,
      positionScore,
      facilityScore === 100 ? 100 : null
    );

    const fieldComparisons = [
      buildFieldComparison({
        field: 'first_name',
        inputValue: firstName,
        candidateValue: snapshot.first_name,
        score: firstNameScore,
        exact: firstExact
      }),
      buildFieldComparison({
        field: 'last_name',
        inputValue: lastName,
        candidateValue: snapshot.last_name,
        score: lastNameScore,
        exact: lastExact
      }),
      buildFieldComparison({
        field: 'full_name',
        inputValue: inputFullRaw || null,
        candidateValue: peerFullRaw || snapshot.full_name,
        score: fullNameScore,
        exact: fullExact
      }),
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
        field: 'facility',
        inputValue: publicLabel(facilityName),
        candidateValue: publicLabel(snapshot.facility_name),
        score: facilityScore,
        exact: facilityScore === 100
      }),
      buildFieldComparison({
        field: 'display_id',
        inputValue: null,
        candidateValue: publicLabel(
          snapshot.human_friendly_id || snapshot.display_id
        ),
        score: null,
        exact: false
      })
    ].filter((entry) => entry.input_value != null || entry.candidate_value != null);

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
    const nameLedSignal =
      fullNameScore != null &&
      fullNameScore >= NAME_LED_THRESHOLD &&
      ((emailScore != null && emailScore >= IDENTITY_SUPPORT_THRESHOLD) ||
        (phoneScoreForComposite != null &&
          phoneScoreForComposite >= IDENTITY_SUPPORT_THRESHOLD) ||
        (positionScore != null && positionScore >= IDENTITY_SUPPORT_THRESHOLD) ||
        facilityScore === 100);

    if (
      !isExact &&
      !strongIdentitySignal &&
      !compositeSignal &&
      !softCompositeSignal &&
      !nameLedSignal
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
      firstNameScore,
      lastNameScore,
      fullNameScore,
      positionScore,
      facilityScore,
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
  PHONE_COMPOSITE_MIN,
  EMAIL_WEIGHT,
  PHONE_WEIGHT,
  FULL_NAME_WEIGHT,
  POSITION_TITLE_WEIGHT,
  FACILITY_WEIGHT,
  normalizeUserEmail,
  normalizeUserPhoneDigits,
  canonicalizeUserPositionTitle,
  canonicalizePersonName,
  scorePhonePair,
  scorePersonTextPair,
  publicLabel,
  compositeUserSimilarityScore,
  buildCandidateSnapshot,
  checkUserDuplicates
};
