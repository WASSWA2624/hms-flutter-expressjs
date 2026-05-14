/**
 * Translation utilities
 *
 * Loads locale files at startup and provides translate helpers.
 * Per internationalization.mdc: translation files are loaded once at boot.
 */

const fs = require('fs');
const path = require('path');
const { logger } = require('@lib/logging');
const { DEFAULT_LOCALE, SUPPORTED_LOCALES } = require('@config/constants');
const { NODE_ENV } = require('@config/env');

const translations = new Map();
const localesDir = path.join(process.cwd(), 'src', 'locales');

/**
 * Determine if a string looks like a translation key.
 *
 * @param {string} value - Value to check
 * @returns {boolean} True if value is a translation key
 */
const isTranslationKey = (value) => {
  return typeof value === 'string' && (
    value.startsWith('errors.') ||
    value.startsWith('messages.') ||
    value.startsWith('labels.')
  );
};

/**
 * Load translation JSON files into memory.
 */
const loadTranslations = () => {
  try {
    if (!fs.existsSync(localesDir)) {
      logger.warn('Locales directory missing, translations will be empty', {
        path: localesDir
      });
      return;
    }

    translations.clear();

    SUPPORTED_LOCALES.forEach((locale) => {
      const filePath = path.join(localesDir, `${locale}.json`);
      if (!fs.existsSync(filePath)) {
        logger.warn('Supported locale file missing', {
          locale,
          path: filePath
        });
        return;
      }

      try {
        const raw = fs.readFileSync(filePath, 'utf8');
        const data = JSON.parse(raw);
        translations.set(locale, data);
      } catch (err) {
        logger.warn('Failed to load locale file', {
          locale,
          error: err.message
        });
      }
    });
  } catch (err) {
    logger.warn('Failed to initialize translations', {
      error: err.message
    });
  }
};

// Load translations once at startup
loadTranslations();

/**
 * Resolve a locale against supported locales.
 *
 * @param {string} locale - Locale candidate
 * @returns {string} Resolved locale
 */
const resolveLocale = (locale) => {
  if (!locale || typeof locale !== 'string') {
    return DEFAULT_LOCALE;
  }

  const trimmed = locale.trim().replace(/_/g, '-');
  if (!trimmed) {
    return DEFAULT_LOCALE;
  }

  const parts = trimmed.split('-').filter(Boolean);
  if (!parts.length) {
    return DEFAULT_LOCALE;
  }

  const normalized = [
    parts[0].toLowerCase(),
    parts[1] ? parts[1].toUpperCase() : null
  ].filter(Boolean).join('-');

  if (SUPPORTED_LOCALES.includes(normalized)) {
    return normalized;
  }

  const base = normalized.split('-')[0];
  if (SUPPORTED_LOCALES.includes(base)) {
    return base;
  }

  return DEFAULT_LOCALE;
};

/**
 * Determine text direction for a locale.
 *
 * @param {string} locale - Locale code
 * @returns {string} "rtl" or "ltr"
 */
const getDirection = (locale) => {
  void locale;
  return 'ltr';
};

/**
 * Translate a key for the provided locale.
 *
 * @param {string} key - Translation key
 * @param {string} locale - Locale code
 * @param {Object} [params] - Template parameters
 * @returns {string} Translated string
 */
const translate = (key, locale, params = {}) => {
  const resolvedLocale = resolveLocale(locale);
  const primary = translations.get(resolvedLocale) || {};
  const fallback = translations.get(DEFAULT_LOCALE) || {};
  let value = primary[key] || fallback[key];

  if (!value) {
    if (NODE_ENV !== 'production') {
      logger.warn('Missing translation key', {
        key,
        locale: resolvedLocale
      });
    }
    value = key;
  }

  if (params && typeof value === 'string') {
    Object.keys(params).forEach((paramKey) => {
      const token = new RegExp(`\\{\\{\\s*${paramKey}\\s*\\}\\}`, 'g');
      value = value.replace(token, String(params[paramKey]));
    });
  }

  return value;
};

/**
 * Apply Content-Language header using resolved locale.
 *
 * @param {Object} res - Express response
 * @param {string} locale - Resolved locale
 */
const applyLocaleHeader = (res, locale) => {
  const resolvedLocale = resolveLocale(locale);
  if (!res) return;

  if (resolvedLocale !== DEFAULT_LOCALE && typeof res.setHeader === 'function') {
    res.setHeader('Content-Language', resolvedLocale);
    return;
  }

  if (resolvedLocale === DEFAULT_LOCALE && typeof res.removeHeader === 'function') {
    res.removeHeader('Content-Language');
  }
};

/**
 * Get response meta from res.locals.
 *
 * @param {Object} res - Express response
 * @returns {{locale: string, direction: string}} Locale metadata
 */
const getResponseMeta = (res) => {
  const locale = res?.locals?.locale || DEFAULT_LOCALE;
  const direction = res?.locals?.direction || getDirection(locale);
  return { locale, direction };
};

module.exports = {
  translate,
  resolveLocale,
  getDirection,
  loadTranslations,
  isTranslationKey,
  applyLocaleHeader,
  getResponseMeta
};
