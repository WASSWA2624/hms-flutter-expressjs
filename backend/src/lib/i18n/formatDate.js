/**
 * Locale-aware date formatter
 */

const { resolveLocale } = require('@lib/i18n/translate');

/**
 * Format date using Intl.DateTimeFormat.
 *
 * @param {Date|string|number} date - Date to format
 * @param {string} locale - Locale code
 * @param {Object} [options] - Intl.DateTimeFormat options
 * @returns {string} Formatted date string
 */
const formatDate = (date, locale, options = {}) => {
  const resolvedLocale = resolveLocale(locale);
  const value = date instanceof Date ? date : new Date(date);
  return new Intl.DateTimeFormat(resolvedLocale, options).format(value);
};

module.exports = { formatDate };
