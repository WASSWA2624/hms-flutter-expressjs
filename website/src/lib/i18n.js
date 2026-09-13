/**
 * Internationalization (i18n) Utilities
 * 
 * Provides utilities for locale detection, translation loading, and locale management.
 * @file src/lib/i18n.js
 */

import { SUPPORTED_LOCALES, DEFAULT_LOCALE } from './constants';

/**
 * Resolve locale from an x-locale header value or cookie fallback
 * @param {string|null|undefined} headerLocale
 * @param {string|null|undefined} cookieLocale
 * @returns {string}
 */
export function resolveLocale(headerLocale, cookieLocale) {
  if (headerLocale && SUPPORTED_LOCALES.includes(headerLocale)) {
    return headerLocale;
  }
  if (cookieLocale && SUPPORTED_LOCALES.includes(cookieLocale)) {
    return cookieLocale;
  }
  return DEFAULT_LOCALE;
}

/**
 * Detect locale from Accept-Language header
 * @param {string} acceptLanguage - Accept-Language header value
 * @returns {string|null} Detected locale code or null
 */
function detectLocale(acceptLanguage) {
  if (!acceptLanguage) return null;
  
  const languages = acceptLanguage
    .split(',')
    .map(lang => {
      const [locale, q = '1'] = lang.trim().split(';q=');
      return { locale: locale.split('-')[0], quality: parseFloat(q) };
    })
    .sort((a, b) => b.quality - a.quality);
  
  for (const { locale } of languages) {
    if (SUPPORTED_LOCALES.includes(locale)) {
      return locale;
    }
  }
  
  return null;
}

/**
 * Get locale from request (server-side)
 * Priority: Cookie → Accept-Language → Default
 * @param {Request} request - Next.js request object
 * @returns {string} Locale code
 */
export function getLocaleFromRequest(request) {
  // 1. Check cookie (user preference)
  const cookieLocale = request.cookies?.get('locale')?.value;
  if (cookieLocale && SUPPORTED_LOCALES.includes(cookieLocale)) {
    return cookieLocale;
  }
  
  // 2. Check Accept-Language header (device/browser settings)
  const acceptLanguage = request.headers?.get('accept-language');
  if (acceptLanguage) {
    const detected = detectLocale(acceptLanguage);
    if (detected) return detected;
  }
  
  // 3. Default locale
  return DEFAULT_LOCALE;
}

/**
 * Get locale from browser (client-side)
 * Priority: Cookie → navigator.language → Default
 * @returns {string} Locale code
 */
export function getLocaleFromBrowser() {
  if (typeof window === 'undefined') return DEFAULT_LOCALE;
  
  // 1. Check cookie (user preference)
  const cookieLocale = getCookie('locale');
  if (cookieLocale && SUPPORTED_LOCALES.includes(cookieLocale)) {
    return cookieLocale;
  }
  
  // 2. Check navigator.language (device/browser settings)
  const browserLocale = navigator.language?.split('-')[0];
  if (browserLocale && SUPPORTED_LOCALES.includes(browserLocale)) {
    return browserLocale;
  }
  
  // 3. Default locale
  return DEFAULT_LOCALE;
}

/**
 * Get cookie value by name (client-side)
 * @param {string} name - Cookie name
 * @returns {string|null} Cookie value or null
 */
function getCookie(name) {
  if (typeof document === 'undefined') return null;
  
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) {
    return parts.pop().split(';').shift();
  }
  return null;
}

/**
 * Set locale cookie (client-side)
 * @param {string} locale - Locale code
 */
export function setLocaleCookie(locale) {
  if (typeof document === 'undefined') return;
  
  if (SUPPORTED_LOCALES.includes(locale)) {
    // Set cookie with proper options - using max-age for better compatibility
    const maxAge = 60 * 60 * 24 * 365; // 1 year
    document.cookie = `locale=${locale}; path=/; max-age=${maxAge}; SameSite=Lax`;
  }
}

/**
 * Get nested value from object using dot notation
 * @param {Object} obj - Object to search
 * @param {string} path - Dot notation path (e.g., 'button.submit')
 * @returns {*} Value or undefined
 */
function getNestedValue(obj, path) {
  return path.split('.').reduce((current, key) => current?.[key], obj);
}

/**
 * Interpolate parameters in translation string
 * @param {string} template - Template string with {{param}} placeholders
 * @param {Object} params - Parameters object
 * @returns {string} Interpolated string
 */
function interpolate(template, params = {}) {
  if (typeof template !== 'string') return template;
  
  return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
    return params[key] !== undefined ? String(params[key]) : match;
  });
}

/**
 * Load translations for a locale and namespace
 * @param {string} locale - Locale code
 * @param {string} namespace - Translation namespace
 * @returns {Promise<Object>} Translation object
 */
export async function getTranslations(locale, namespace) {
  try {
    const translations = await import(`@/locales/${locale}/${namespace}.json`);
    return translations.default || translations;
  } catch (error) {
    console.error(`Failed to load translations: ${locale}/${namespace}`, error);
    
    // Fallback to default locale
    if (locale !== DEFAULT_LOCALE) {
      try {
        const fallback = await import(`@/locales/${DEFAULT_LOCALE}/${namespace}.json`);
        return fallback.default || fallback;
      } catch (fallbackError) {
        console.error(`Failed to load fallback translations: ${DEFAULT_LOCALE}/${namespace}`, fallbackError);
      }
    }
    
    return {};
  }
}

/**
 * Get server translations (for Server Components)
 * @param {string} locale - Locale code
 * @param {string} namespace - Translation namespace
 * @returns {Promise<Object>} Translation object
 */
export async function getServerTranslations(locale, namespace) {
  return getTranslations(locale, namespace);
}

/**
 * Translate a key with optional parameters
 * @param {string} locale - Locale code
 * @param {string} namespace - Translation namespace
 * @param {string} key - Translation key (supports dot notation)
 * @param {Object} params - Parameters for interpolation
 * @returns {Promise<string>} Translated string
 */
export async function translate(locale, namespace, key, params = {}) {
  try {
    const translations = await getTranslations(locale, namespace);
    let value = getNestedValue(translations, key);
    
    if (!value) {
      if (process.env.NODE_ENV === 'development') {
        console.warn(`Translation missing: ${locale}/${namespace}/${key}`);
      }
      return key; // Fallback to key
    }
    
    // Handle pluralization if value is an object
    if (typeof value === 'object' && params.count !== undefined) {
      const count = Number(params.count);
      if (count === 0 && value.zero) {
        value = value.zero;
      } else if (count === 1 && value.one) {
        value = value.one;
      } else if (value.other) {
        value = value.other;
      } else {
        value = value.many || value.few || value.other || key;
      }
    }
    
    // Interpolate parameters
    return interpolate(value, params);
  } catch (error) {
    console.error('Translation error:', error);
    return key;
  }
}

/**
 * Check if locale is RTL (Right-to-Left)
 * @param {string} locale - Locale code
 * @returns {boolean} True if RTL
 */
export function isRTL(locale) {
  const rtlLocales = ['ar', 'he', 'fa', 'ur'];
  return rtlLocales.includes(locale);
}

/**
 * Get locale direction (ltr or rtl)
 * @param {string} locale - Locale code
 * @returns {string} 'ltr' or 'rtl'
 */
export function getLocaleDirection(locale) {
  return isRTL(locale) ? 'rtl' : 'ltr';
}

/**
 * Get translated company constants
 * @param {string} locale - Locale code
 * @returns {Promise<Object>} Translated company constants
 */
export async function getTranslatedCompanyConstants(locale) {
  const t = await getServerTranslations(locale, 'about');
  
  return {
    name: t.companyName || 'HOSSPI',
    description: t.companyDescription || '',
    mission: t.companyMission || '',
    vision: t.companyVision || '',
    values: t.companyValues || [],
    history: t.companyHistory || [],
  };
}

