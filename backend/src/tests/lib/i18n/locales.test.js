const fs = require('fs');
const path = require('path');
const { SUPPORTED_LOCALES, DEFAULT_LOCALE } = require('@config/constants');
const { checkLocales } = require('../../../../scripts/check-locales');

const REQUIRED_APP_LOCALES = ['en', 'fr'];

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
    expect(actualFiles).toContain('fr.json');
  });

  test('locale check script validates supported locale files and french parity', () => {
    const result = checkLocales();

    expect(result.supported_locales).toEqual(['en', 'fr']);
    expect(result.locale_files).toContain('en.json');
    expect(result.locale_files).toContain('fr.json');

    const enMessages = JSON.parse(
      fs.readFileSync(path.join(localesDir, 'en.json'), 'utf8'),
    );
    const frMessages = JSON.parse(
      fs.readFileSync(path.join(localesDir, 'fr.json'), 'utf8'),
    );
    const enKeys = Object.keys(enMessages).sort();
    const frKeys = Object.keys(frMessages).sort();

    expect(frKeys).toEqual(enKeys);
    expect(frMessages['messages.abac_policy.create_success']).not.toBe(
      enMessages['messages.abac_policy.create_success'],
    );
  });
});
