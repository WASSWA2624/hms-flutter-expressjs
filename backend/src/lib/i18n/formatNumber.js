/**
 * Locale-aware number formatter
 */

const { resolveLocale } = require('@lib/i18n/translate');

/**
 * Format numbers using Intl.NumberFormat.
 *
 * @param {number} value - Number to format
 * @param {string} locale - Locale code
 * @param {Object} [options] - Intl.NumberFormat options
 * @returns {string} Formatted number string
 */
const formatNumber = (value, locale, options = {}) => {
  const resolvedLocale = resolveLocale(locale);
  return new Intl.NumberFormat(resolvedLocale, options).format(value);
};

module.exports = { formatNumber };
