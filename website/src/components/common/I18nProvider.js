/**
 * I18nProvider - Shared translation cache for client components
 *
 * Preloads namespaces once per locale and shares them with useTranslation.
 * @file src/components/common/I18nProvider.js
 */
'use client';

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { getTranslations, setLocaleCookie } from '@/lib/i18n';
import { DEFAULT_LOCALE, SUPPORTED_LOCALES } from '@/lib/constants';

const I18nContext = createContext(null);

/**
 * @param {Object} props
 * @param {string} [props.locale] - Initial locale from the server
 * @param {Object} [props.initialNamespaces] - Preloaded { namespace: translations }
 * @param {React.ReactNode} props.children
 */
export function I18nProvider({
  locale: initialLocale = DEFAULT_LOCALE,
  initialNamespaces = {},
  children,
}) {
  const [locale, setLocaleState] = useState(initialLocale);
  const cacheRef = useRef({
    [initialLocale]: { ...initialNamespaces },
  });
  const [, setCacheVersion] = useState(0);

  useEffect(() => {
    setLocaleState(initialLocale);
    cacheRef.current[initialLocale] = {
      ...(cacheRef.current[initialLocale] || {}),
      ...initialNamespaces,
    };
    setCacheVersion((v) => v + 1);
    // Only re-seed when locale changes; namespaces object identity changes every render
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialLocale]);

  const getCachedNamespace = useCallback((targetLocale, namespace) => {
    return cacheRef.current[targetLocale]?.[namespace] || null;
  }, []);

  const ensureNamespace = useCallback(async (targetLocale, namespace) => {
    const cached = cacheRef.current[targetLocale]?.[namespace];
    if (cached) {
      return cached;
    }

    const translations = await getTranslations(targetLocale, namespace);
    cacheRef.current[targetLocale] = {
      ...(cacheRef.current[targetLocale] || {}),
      [namespace]: translations,
    };
    setCacheVersion((v) => v + 1);
    return translations;
  }, []);

  const changeLocale = useCallback((newLocale) => {
    if (!SUPPORTED_LOCALES.includes(newLocale) || newLocale === locale) {
      return;
    }
    setLocaleCookie(newLocale);
    setLocaleState(newLocale);
    // Reload so server components pick up the new locale cookie/header
    window.location.reload();
  }, [locale]);

  const value = useMemo(
    () => ({
      locale,
      changeLocale,
      getCachedNamespace,
      ensureNamespace,
    }),
    [locale, changeLocale, getCachedNamespace, ensureNamespace]
  );

  return (
    <I18nContext.Provider value={value}>
      {children}
    </I18nContext.Provider>
  );
}

I18nProvider.displayName = 'I18nProvider';

/**
 * Access shared i18n context. Returns null when outside provider (hook falls back).
 * @returns {Object|null}
 */
export function useI18nContext() {
  return useContext(I18nContext);
}
