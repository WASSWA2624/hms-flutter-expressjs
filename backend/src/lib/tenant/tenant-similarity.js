/**
 * Tenant duplicate / similarity helpers.
 *
 * Weighted multi-field similarity across identity and contact/config fields.
 */

const SIMILARITY_THRESHOLD = 80;
const TOKEN_MATCH_THRESHOLD = 85;

const {
  resolveTenantContact,
} = require('@lib/tenant/resolve-tenant-contact');

const NAME_WEIGHT = 30;
const SLUG_WEIGHT = 25;
const EMAIL_WEIGHT = 15;
const PHONE_WEIGHT = 15;
const CONTACT_NAME_WEIGHT = 8;
const CURRENCY_WEIGHT = 4;
const FEE_WEIGHT = 3;

const normalizeText = (value) => String(value || '')
  .toLowerCase()
  .trim()
  .replace(/[^a-z0-9\s]/g, '')
  .replace(/\s+/g, ' ');

const normalizeSlug = (value) => String(value || '')
  .toLowerCase()
  .trim()
  .replace(/[^a-z0-9\s-]/g, '')
  .replace(/\s+/g, '-')
  .replace(/-+/g, '-')
  .replace(/^-|-$/g, '');

const normalizeEmail = (value) => String(value || '').trim().toLowerCase();

const normalizePhone = (value) => String(value || '').replace(/\D+/g, '');

const normalizeCurrency = (value) => String(value || '').trim().toUpperCase();

const normalizeFee = (value) => {
  if (value == null || value === '') return null;
  const parsed = Number(String(value).replace(/,/g, '').trim());
  if (!Number.isFinite(parsed)) return null;
  return parsed;
};

const tokensOf = (value) => String(value || '')
  .split(/\s+/)
  .filter(Boolean);

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

const levenshteinSimilarityPercent = (left, right) => {
  if (left === right) return 100;
  if (!left || !right) return 0;
  const distance = levenshteinDistance(left, right);
  const maxLength = Math.max(left.length, right.length);
  return Math.round(((maxLength - distance) / maxLength) * 100);
};

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
  const leftTokens = tokensOf(left);
  const rightTokens = tokensOf(right);
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
  const jaccard = union === 0
    ? 0
    : Math.round((fuzzyIntersection / union) * 100);

  return Math.max(averageDirectional, jaccard);
};

/**
 * Boost near-duplicates where one normalized value embeds the other
 * (e.g. "test" vs "testing", "lab" vs "laboratory").
 */
const containmentSimilarityPercent = (left, right) => {
  if (!left || !right || left === right) {
    return left && right && left === right ? 100 : 0;
  }

  const [shorter, longer] =
    left.length <= right.length ? [left, right] : [right, left];
  if (shorter.length < 3) {
    return 0;
  }
  if (!longer.includes(shorter)) {
    return 0;
  }

  const coverage = shorter.length / longer.length;
  return Math.min(99, Math.round(72 + coverage * 28));
};

const textSimilarityScore = (
  left,
  right,
  { includeTokenSimilarity = true } = {}
) => {
  if (left === right) return 100;
  if (!left || !right) return 0;
  const fullScore = levenshteinSimilarityPercent(left, right);
  const containmentScore = containmentSimilarityPercent(left, right);
  if (!includeTokenSimilarity) {
    return Math.max(fullScore, containmentScore);
  }
  return Math.max(
    fullScore,
    containmentScore,
    tokenSimilarityPercent(left, right)
  );
};

const compositeSimilarityScore = (scores = {}) => {
  const weighted = [
    [scores.nameScore, NAME_WEIGHT],
    [scores.slugScore, SLUG_WEIGHT],
    [scores.emailScore, EMAIL_WEIGHT],
    [scores.phoneScore, PHONE_WEIGHT],
    [scores.contactNameScore, CONTACT_NAME_WEIGHT],
    [scores.currencyScore, CURRENCY_WEIGHT],
    [scores.feeScore, FEE_WEIGHT]
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

const comparisonStatus = (score, { exact = false } = {}) => {
  if (exact || score === 100) return 'MATCH';
  if (score == null) return 'MISSING';
  if (score >= SIMILARITY_THRESHOLD) return 'SIMILAR';
  return 'DIFFERENT';
};

const readExtensionContact = (tenant) => resolveTenantContact(tenant);

const readExtensionCurrency = (tenant) => {
  const extension = tenant?.extension_json;
  if (!extension || typeof extension !== 'object') return null;
  return extension.currency || null;
};

const readExtensionFee = (tenant) => {
  const extension = tenant?.extension_json;
  if (!extension || typeof extension !== 'object') return null;
  const billing = extension.billing && typeof extension.billing === 'object'
    ? extension.billing
    : {};
  return billing.standard_consultation_fee ?? null;
};

const buildCandidateSnapshot = (tenant) => {
  const contact = readExtensionContact(tenant);
  return {
    id: tenant?.id || null,
    human_friendly_id: tenant?.human_friendly_id || null,
    display_id: tenant?.display_id || tenant?.human_friendly_id || tenant?.id || null,
    name: tenant?.name || null,
    slug: tenant?.slug || null,
    is_active: tenant?.is_active !== false,
    contact_name: contact.name,
    contact_email: contact.email,
    contact_phone: contact.phone,
    currency: readExtensionCurrency(tenant),
    standard_consultation_fee: readExtensionFee(tenant)
  };
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
 * @param {string|null|undefined} params.slug
 * @param {string|null|undefined} params.contactName
 * @param {string|null|undefined} params.contactEmail
 * @param {string|null|undefined} params.contactPhone
 * @param {string|null|undefined} params.currency
 * @param {string|number|null|undefined} params.standardConsultationFee
 * @param {Array<Object>} params.existing
 * @param {string|null} [params.excludeTenantId]
 */
const checkTenantDuplicates = ({
  name,
  slug,
  contactName,
  contactEmail,
  contactPhone,
  currency,
  standardConsultationFee,
  existing = [],
  excludeTenantId = null
}) => {
  const normalizedName = normalizeText(name);
  const normalizedSlug = normalizeSlug(slug || name);
  const normalizedContactName = normalizeText(contactName);
  const normalizedEmail = normalizeEmail(contactEmail);
  const normalizedPhone = normalizePhone(contactPhone);
  const normalizedCurrency = normalizeCurrency(currency);
  const normalizedFee = normalizeFee(standardConsultationFee);
  const excludeId = String(excludeTenantId || '').trim();

  let exactNameConflict = false;
  let exactSlugConflict = false;
  const matches = [];

  for (const tenant of existing) {
    const tenantId = String(tenant?.id || '').trim();
    if (excludeId && tenantId && tenantId === excludeId) {
      continue;
    }

    const snapshot = buildCandidateSnapshot(tenant);
    const tenantName = normalizeText(snapshot.name);
    const tenantSlug = normalizeSlug(snapshot.slug);
    const tenantContactName = normalizeText(snapshot.contact_name);
    const tenantEmail = normalizeEmail(snapshot.contact_email);
    const tenantPhone = normalizePhone(snapshot.contact_phone);
    const tenantCurrency = normalizeCurrency(snapshot.currency);
    const tenantFee = normalizeFee(snapshot.standard_consultation_fee);

    const nameExact = Boolean(normalizedName) && tenantName === normalizedName;
    const slugExact = Boolean(normalizedSlug) && tenantSlug === normalizedSlug;
    const emailExact = Boolean(normalizedEmail)
      && Boolean(tenantEmail)
      && tenantEmail === normalizedEmail;
    const phoneExact = Boolean(normalizedPhone)
      && Boolean(tenantPhone)
      && tenantPhone === normalizedPhone;
    const contactNameExact = Boolean(normalizedContactName)
      && Boolean(tenantContactName)
      && tenantContactName === normalizedContactName;
    const currencyExact = Boolean(normalizedCurrency)
      && Boolean(tenantCurrency)
      && tenantCurrency === normalizedCurrency;
    const feeExact = normalizedFee != null
      && tenantFee != null
      && normalizedFee === tenantFee;

    let nameScore = null;
    let slugScore = null;
    let emailScore = null;
    let phoneScore = null;
    let contactNameScore = null;
    let currencyScore = null;
    let feeScore = null;
    const reasons = [];

    if (normalizedName && tenantName) {
      nameScore = nameExact
        ? 100
        : textSimilarityScore(normalizedName, tenantName);
      if (nameExact || nameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('name');
      }
    }

    if (normalizedSlug && tenantSlug) {
      slugScore = slugExact
        ? 100
        : textSimilarityScore(normalizedSlug, tenantSlug, {
          includeTokenSimilarity: false
        });
      if (slugExact || slugScore >= SIMILARITY_THRESHOLD) {
        reasons.push('slug');
      }
    }

    if (normalizedEmail && tenantEmail) {
      emailScore = emailExact
        ? 100
        : textSimilarityScore(normalizedEmail, tenantEmail, {
          includeTokenSimilarity: false
        });
      if (emailExact || emailScore >= SIMILARITY_THRESHOLD) {
        reasons.push('email');
      }
    }

    if (normalizedPhone && tenantPhone) {
      phoneScore = phoneExact
        ? 100
        : textSimilarityScore(normalizedPhone, tenantPhone, {
          includeTokenSimilarity: false
        });
      if (phoneExact || phoneScore >= SIMILARITY_THRESHOLD) {
        reasons.push('phone');
      }
    }

    if (normalizedContactName && tenantContactName) {
      contactNameScore = contactNameExact
        ? 100
        : textSimilarityScore(normalizedContactName, tenantContactName);
      if (contactNameExact || contactNameScore >= SIMILARITY_THRESHOLD) {
        reasons.push('contact_name');
      }
    }

    if (normalizedCurrency && tenantCurrency) {
      currencyScore = currencyExact ? 100 : 0;
      if (currencyExact) {
        reasons.push('currency');
      }
    }

    if (normalizedFee != null && tenantFee != null) {
      if (feeExact) {
        feeScore = 100;
        reasons.push('consultation_fee');
      } else {
        const maxFee = Math.max(Math.abs(normalizedFee), Math.abs(tenantFee), 1);
        const distance = Math.abs(normalizedFee - tenantFee);
        feeScore = Math.max(0, Math.round(((maxFee - distance) / maxFee) * 100));
        if (feeScore >= SIMILARITY_THRESHOLD) {
          reasons.push('consultation_fee');
        }
      }
    }

    const score = compositeSimilarityScore({
      nameScore,
      slugScore,
      emailScore,
      phoneScore,
      contactNameScore,
      currencyScore,
      feeScore
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
        field: 'slug',
        inputValue: slug || normalizedSlug,
        candidateValue: snapshot.slug,
        score: slugScore,
        exact: slugExact
      }),
      buildFieldComparison({
        field: 'contact_name',
        inputValue: contactName,
        candidateValue: snapshot.contact_name,
        score: contactNameScore,
        exact: contactNameExact
      }),
      buildFieldComparison({
        field: 'contact_phone',
        inputValue: contactPhone,
        candidateValue: snapshot.contact_phone,
        score: phoneScore,
        exact: phoneExact
      }),
      buildFieldComparison({
        field: 'contact_email',
        inputValue: contactEmail,
        candidateValue: snapshot.contact_email,
        score: emailScore,
        exact: emailExact
      }),
      buildFieldComparison({
        field: 'currency',
        inputValue: currency,
        candidateValue: snapshot.currency,
        score: currencyScore,
        exact: currencyExact
      }),
      buildFieldComparison({
        field: 'consultation_fee',
        inputValue: standardConsultationFee,
        candidateValue: snapshot.standard_consultation_fee,
        score: feeScore,
        exact: feeExact
      })
    ].filter((entry) => entry.input_value != null || entry.candidate_value != null);

    // Slug remains a hard uniqueness conflict and cannot be overridden.
    if (slugExact) {
      exactSlugConflict = true;
    }
    if (nameExact) {
      exactNameConflict = true;
    }

    const isExact = nameExact || slugExact;
    const strongIdentitySignal = (
      (nameScore != null && nameScore >= SIMILARITY_THRESHOLD)
      || (slugScore != null && slugScore >= SIMILARITY_THRESHOLD)
      || (emailScore != null && emailScore >= SIMILARITY_THRESHOLD)
      || (phoneScore != null && phoneScore >= SIMILARITY_THRESHOLD)
    );
    const compositeSignal = score >= SIMILARITY_THRESHOLD;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    matches.push({
      ...snapshot,
      score,
      reasons: reasons.length ? reasons : (isExact ? ['name'] : ['name']),
      isExact,
      exactSlugConflict: slugExact,
      exactNameConflict: nameExact,
      nameScore,
      slugScore,
      emailScore,
      phoneScore,
      contactNameScore,
      currencyScore,
      feeScore,
      field_comparisons: fieldComparisons
    });
  }

  matches.sort((left, right) => right.score - left.score);

  return {
    exactNameConflict,
    exactSlugConflict,
    hasExactConflict: exactNameConflict || exactSlugConflict,
    similarMatches: matches,
    nonExactSimilarMatches: matches.filter((match) => !match.isExact),
    overridableMatches: matches.filter((match) => !match.exactSlugConflict)
  };
};

module.exports = {
  SIMILARITY_THRESHOLD,
  TOKEN_MATCH_THRESHOLD,
  NAME_WEIGHT,
  SLUG_WEIGHT,
  EMAIL_WEIGHT,
  PHONE_WEIGHT,
  CONTACT_NAME_WEIGHT,
  CURRENCY_WEIGHT,
  FEE_WEIGHT,
  normalizeText,
  normalizeSlug,
  normalizeEmail,
  normalizePhone,
  normalizeCurrency,
  normalizeFee,
  textSimilarityScore,
  containmentSimilarityPercent,
  compositeSimilarityScore,
  checkTenantDuplicates,
  buildCandidateSnapshot,
  readExtensionContact,
  readExtensionCurrency,
  readExtensionFee
};
