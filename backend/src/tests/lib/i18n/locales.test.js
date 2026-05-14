const fs = require('fs');
const path = require('path');
const { SUPPORTED_LOCALES, DEFAULT_LOCALE } = require('@config/constants');
const { checkLocales } = require('../../../../scripts/check-locales');

const REQUIRED_APP_LOCALES = ['en'];

const localesDir = path.join(process.cwd(), 'src', 'locales');

describe('locale coverage', () => {
  test('supported locales exactly match the app locale set', () => {
    expect(DEFAULT_LOCALE).toBe('en');
    expect(SUPPORTED_LOCALES).toEqual(REQUIRED_APP_LOCALES);
  });

  test('locale directory contains the canonical english locale file', () => {
    const actualFiles = fs.readdirSync(localesDir)
      .filter((fileName) => fileName.endsWith('.json'))
      .sort();

    expect(actualFiles).toContain('en.json');
  });

  test('locale check script validates runtime configuration and english coverage', () => {
    const result = checkLocales();

    expect(result.ok).toBe(true);
    expect(result.supported_locales).toEqual(['en']);
    expect(result.locale_files).toContain('en.json');
    expect(result.missing_keys).toEqual([]);
  });
});
