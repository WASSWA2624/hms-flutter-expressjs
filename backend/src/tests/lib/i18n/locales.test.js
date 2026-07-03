const fs = require('fs');
const path = require('path');
const { SUPPORTED_LOCALES, DEFAULT_LOCALE } = require('@config/constants');
const { checkLocales } = require('../../../../scripts/check-locales');

const localesDir = path.join(process.cwd(), 'src', 'locales');

describe('locale coverage', () => {
  test('supported locales are english only', () => {
    expect(DEFAULT_LOCALE).toBe('en');
    expect(SUPPORTED_LOCALES).toEqual(['en']);
  });

  test('locale directory contains only the canonical english locale file', () => {
    const actualFiles = fs.readdirSync(localesDir)
      .filter((fileName) => fileName.endsWith('.json'))
      .sort();

    expect(actualFiles).toEqual(['en.json']);
  });

  test('locale check script validates supported locale files', () => {
    const result = checkLocales();

    expect(result.supported_locales).toEqual(['en']);
    expect(result.locale_files).toEqual(['en.json']);
    expect(result.locale_files).not.toContain('fr.json');
  });
});
