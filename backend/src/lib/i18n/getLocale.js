/**
 * Locale detection helper
 *
 * Detects locale from query parameter or Accept-Language header.
 */

const { localeSchema } = require('@lib/validation/zod');
const { resolveLocale } = require('@lib/i18n/translate');

/**
 * Normalize locale candidate into a canonical format.
 * Examples: "EN_zz" -> "en-ZZ", "fr-zz" -> "fr-ZZ"
 *
 * @param {string} value - Raw locale candidate
 * @returns {string|null} Canonical locale candidate
 */
const normalizeLocaleCandidate = (value) => {
  if (!value || typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim().replace(/_/g, '-');
  if (!trimmed || trimmed === '*') {
    return null;
  }

  const parts = trimmed.split('-').filter(Boolean);
  if (!parts.length) {
    return null;
  }

  const [language, region, ...rest] = parts;
  const normalized = [
    language.toLowerCase(),
    region ? region.toUpperCase() : null,
    ...rest
  ].filter(Boolean);

  return normalized.join('-');
};

/**
 * Parse Accept-Language header into ordered list of locale candidates.
 *
 * @param {string} header - Accept-Language header value
 * @returns {string[]} Locales in priority order
 */
const parseAcceptLanguage = (header) => {
  if (!header || typeof header !== 'string') {
    return [];
  }

  return header
    .split(',')
    .map((entry) => {
      const [localePart, ...params] = entry.split(';').map((part) => part.trim());
      const locale = normalizeLocaleCandidate(localePart);
      const qParam = params.find((param) => param.startsWith('q='));
      const qValue = qParam ? Number(qParam.slice(2)) : 1;
      const quality = Number.isFinite(qValue) ? qValue : 1;
      return { locale, quality };
    })
    .filter((item) => Boolean(item.locale))
    .sort((a, b) => b.quality - a.quality)
    .map((item) => item.locale);
};

/**
 * Detect locale from request.
 *
 * @param {Object} req - Express request
 * @returns {string} Resolved locale
 */
const getLocale = (req) => {
  const queryLocale = normalizeLocaleCandidate(req?.query?.locale);
  if (queryLocale) {
    const parsed = localeSchema.safeParse(queryLocale);
    if (parsed.success) {
      return resolveLocale(parsed.data);
    }
  }

  const headerLocale = normalizeLocaleCandidate(req?.headers?.['x-locale']);
  if (headerLocale) {
    const parsed = localeSchema.safeParse(headerLocale);
    if (parsed.success) {
      return resolveLocale(parsed.data);
    }
  }

  const headerLocales = parseAcceptLanguage(req?.headers?.['accept-language']);
  for (const candidate of headerLocales) {
    const parsed = localeSchema.safeParse(candidate);
    if (parsed.success) {
      return resolveLocale(parsed.data);
    }
  }

  return resolveLocale(null);
};

module.exports = { getLocale };
