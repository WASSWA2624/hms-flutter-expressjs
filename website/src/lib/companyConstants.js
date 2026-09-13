/**
 * Company Constants Helper
 * 
 * Provides helper functions to get translated company constants.
 * Use these functions instead of importing constants directly when translations are needed.
 * @file src/lib/companyConstants.js
 */

import { getTranslatedCompanyConstants } from './i18n';
import { DEFAULT_LOCALE } from './constants';

/**
 * Get translated company mission
 * @param {string} locale - Locale code
 * @returns {Promise<string>} Translated mission
 */
export async function getCompanyMission(locale = DEFAULT_LOCALE) {
  const constants = await getTranslatedCompanyConstants(locale);
  return constants.mission;
}

/**
 * Get translated company vision
 * @param {string} locale - Locale code
 * @returns {Promise<string>} Translated vision
 */
export async function getCompanyVision(locale = DEFAULT_LOCALE) {
  const constants = await getTranslatedCompanyConstants(locale);
  return constants.vision;
}

/**
 * Get translated company values
 * @param {string} locale - Locale code
 * @returns {Promise<Array<string>>} Translated values array
 */
export async function getCompanyValues(locale = DEFAULT_LOCALE) {
  const constants = await getTranslatedCompanyConstants(locale);
  return constants.values;
}

/**
 * Get translated company history
 * @param {string} locale - Locale code
 * @returns {Promise<Array<Object>>} Translated history array
 */
export async function getCompanyHistory(locale = DEFAULT_LOCALE) {
  const constants = await getTranslatedCompanyConstants(locale);
  return constants.history;
}

/**
 * Get translated company name
 * @param {string} locale - Locale code
 * @returns {Promise<string>} Translated company name
 */
export async function getCompanyName(locale = DEFAULT_LOCALE) {
  const constants = await getTranslatedCompanyConstants(locale);
  return constants.name;
}

/**
 * Get translated company description
 * @param {string} locale - Locale code
 * @returns {Promise<string>} Translated company description
 */
export async function getCompanyDescription(locale = DEFAULT_LOCALE) {
  const constants = await getTranslatedCompanyConstants(locale);
  return constants.description;
}

