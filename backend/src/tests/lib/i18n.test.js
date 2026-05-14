jest.mock('@lib/logging', () => ({
  logger: {
    warn: jest.fn(),
    info: jest.fn(),
    error: jest.fn()
  }
}));

const { DEFAULT_LOCALE } = require('@config/constants');
const { getLocale } = require('@lib/i18n/getLocale');
const { translate, resolveLocale, getDirection, getResponseMeta, applyLocaleHeader } = require('@lib/i18n');

describe('i18n utilities', () => {
  test('resolves locale from query param', () => {
    const req = { query: { locale: 'en-GB' }, headers: {} };
    expect(getLocale(req)).toBe('en');
  });

  test('normalizes query locale casing', () => {
    const req = { query: { locale: 'EN_gb' }, headers: {} };
    expect(getLocale(req)).toBe('en');
  });

  test('resolves locale from x-locale header', () => {
    const req = { query: {}, headers: { 'x-locale': 'en-GB' } };
    expect(getLocale(req)).toBe('en');
  });

  test('resolves locale from Accept-Language header using supported locale', () => {
    const req = { query: {}, headers: { 'accept-language': 'en-GB,en;q=0.8' } };
    expect(getLocale(req)).toBe('en');
  });

  test('falls back to default locale when unsupported regional locales are provided', () => {
    const req = { query: {}, headers: { 'accept-language': 'fr-ZZ,sw;q=0.8' } };
    expect(getLocale(req)).toBe('en');
  });

  test('falls back to default locale when Accept-Language is wildcard', () => {
    const req = { query: {}, headers: { 'accept-language': '*' } };
    expect(getLocale(req)).toBe(DEFAULT_LOCALE);
  });

  test('falls back to default locale on invalid locale', () => {
    const req = { query: { locale: 'invalid' }, headers: {} };
    expect(getLocale(req)).toBe(DEFAULT_LOCALE);
  });

  test('translate falls back to key when missing', () => {
    const value = translate('messages.__definitely_missing_key__', 'en');
    expect(value).toBe('messages.__definitely_missing_key__');
  });

  test('resolveLocale handles base locale fallback', () => {
    expect(resolveLocale('en-ZZ')).toBe('en');
    expect(resolveLocale('en_zz')).toBe('en');
    expect(resolveLocale('fr-ZZ')).toBe('en');
    expect(resolveLocale('ln-ZZ')).toBe('en');
  });

  test('translate falls back to english for unsupported locales', () => {
    expect(translate('messages.health.check', 'fr')).toBe(translate('messages.health.check', 'en'));
    expect(translate('messages.health.check', 'sw')).toBe(translate('messages.health.check', 'en'));
  });

  test('getDirection returns ltr for the supported development locale', () => {
    expect(getDirection('en')).toBe('ltr');
  });

  test('getResponseMeta reads from res.locals', () => {
    const res = { locals: { locale: 'en', direction: 'ltr' } };
    expect(getResponseMeta(res)).toEqual({ locale: 'en', direction: 'ltr' });
  });

  test('applyLocaleHeader sets content-language only for non-default locale', () => {
    const headers = {};
    const res = {
      setHeader: (name, value) => {
        headers[name] = value;
      },
      removeHeader: (name) => {
        delete headers[name];
      }
    };

    applyLocaleHeader(res, 'en');
    expect(headers['Content-Language']).toBeUndefined();

    applyLocaleHeader(res, 'en-zz');
    expect(headers['Content-Language']).toBeUndefined();

    applyLocaleHeader(res, 'en-GB');
    expect(headers['Content-Language']).toBeUndefined();
  });
});
