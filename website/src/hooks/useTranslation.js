/**
 * useTranslation Hook
 *
 * Reads translations from I18nProvider cache when available; otherwise loads once.
 * @file src/hooks/useTranslation.js
 */
'use client';

import { useState, useEffect, useCallback } from 'react';
import { getLocaleFromBrowser, setLocaleCookie, getTranslations } from '@/lib/i18n';
import { SUPPORTED_LOCALES } from '@/lib/constants';
import { useI18nContext } from '@/components/common/I18nProvider';

/**
 * Translate from a translations object
 * @param {Object} translations
 * @param {string} key
 * @param {Object} params
 * @param {string} locale
 * @param {string} namespace
 * @returns {string}
 */
function translateFromObject(translations, key, params, locale, namespace) {
  const keys = key.split('.');
  let value = translations;

  for (const k of keys) {
    value = value?.[k];
  }

  if (value) {
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

    if (typeof value === 'string') {
      return value.replace(/\{\{(\w+)\}\}/g, (match, paramKey) => {
        return params[paramKey] !== undefined ? String(params[paramKey]) : match;
      });
    }
  }

  if (process.env.NODE_ENV === 'development') {
    console.warn(`Translation missing: ${locale}/${namespace}/${key}`);
  }

  return key;
}

/**
 * Translation hook for client components
 * @param {string} namespace - Translation namespace (default: 'common')
 * @returns {Object} Translation functions and locale state
 */
export function useTranslation(namespace = 'common') {
  const i18n = useI18nContext();
  const locale = i18n?.locale || getLocaleFromBrowser();
  const cached = i18n?.getCachedNamespace?.(locale, namespace) || null;

  const [translations, setTranslations] = useState(cached || {});
  const [loading, setLoading] = useState(!cached);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      if (i18n?.ensureNamespace) {
        const fromProvider = i18n.getCachedNamespace(locale, namespace);
        if (fromProvider) {
          if (!cancelled) {
            setTranslations(fromProvider);
            setLoading(false);
          }
          return;
        }

        setLoading(true);
        try {
          const loaded = await i18n.ensureNamespace(locale, namespace);
          if (!cancelled) {
            setTranslations(loaded);
          }
        } catch (error) {
          console.error('Failed to load translations:', error);
          if (!cancelled) {
            setTranslations({});
          }
        } finally {
          if (!cancelled) {
            setLoading(false);
          }
        }
        return;
      }

      // Fallback when outside I18nProvider
      setLoading(true);
      try {
        const loaded = await getTranslations(locale, namespace);
        if (!cancelled) {
          setTranslations(loaded);
        }
      } catch (error) {
        console.error('Failed to load translations:', error);
        if (!cancelled) {
          setTranslations({});
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    load();
    return () => {
      cancelled = true;
    };
  }, [i18n, locale, namespace, cached]);

  const t = useCallback(
    (key, params = {}) => translateFromObject(translations, key, params, locale, namespace),
    [translations, locale, namespace]
  );

  const changeLocale = useCallback(
    (newLocale) => {
      if (i18n?.changeLocale) {
        i18n.changeLocale(newLocale);
        return;
      }

      if (SUPPORTED_LOCALES.includes(newLocale) && newLocale !== locale) {
        setLocaleCookie(newLocale);
        window.location.reload();
      }
    },
    [i18n, locale]
  );

  return {
    t,
    locale,
    changeLocale,
    loading,
    translations,
  };
}
