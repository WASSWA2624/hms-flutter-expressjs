/**
 * i18n utilities barrel export
 */

const { getLocale } = require('@lib/i18n/getLocale');
const { translate, resolveLocale, getDirection, loadTranslations, isTranslationKey, applyLocaleHeader, getResponseMeta } = require('@lib/i18n/translate');
const { formatDate } = require('@lib/i18n/formatDate');
const { formatNumber } = require('@lib/i18n/formatNumber');

module.exports = {
  getLocale,
  translate,
  resolveLocale,
  getDirection,
  loadTranslations,
  isTranslationKey,
  applyLocaleHeader,
  getResponseMeta,
  formatDate,
  formatNumber
};
