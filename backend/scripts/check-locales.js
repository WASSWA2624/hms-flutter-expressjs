const fs = require('fs');
const path = require('path');

const { DEFAULT_LOCALE, SUPPORTED_LOCALES } = require('../src/config/constants');

const backendRoot = path.join(__dirname, '..');
const localesDir = path.join(backendRoot, 'src', 'locales');
const sourceRoots = [
  path.join(backendRoot, 'src'),
  path.join(backendRoot, 'scripts'),
];
const translationKeyPattern = /['"`]((?:errors|messages|labels)\.[A-Za-z0-9_.-]+)['"`]/g;

const resolveLocale = (locale) => {
  if (!locale || typeof locale !== 'string') {
    return DEFAULT_LOCALE;
  }

  const trimmed = locale.trim().replace(/_/g, '-');
  if (!trimmed) {
    return DEFAULT_LOCALE;
  }

  const parts = trimmed.split('-').filter(Boolean);
  if (!parts.length) {
    return DEFAULT_LOCALE;
  }

  const normalized = [
    parts[0].toLowerCase(),
    parts[1] ? parts[1].toUpperCase() : null,
  ].filter(Boolean).join('-');

  if (SUPPORTED_LOCALES.includes(normalized)) {
    return normalized;
  }

  const base = normalized.split('-')[0];
  if (SUPPORTED_LOCALES.includes(base)) {
    return base;
  }

  return DEFAULT_LOCALE;
};

const walkFiles = (targetPath, predicate) => {
  if (!fs.existsSync(targetPath)) return [];

  const stat = fs.statSync(targetPath);
  if (stat.isFile()) {
    return predicate(targetPath) ? [targetPath] : [];
  }

  return fs.readdirSync(targetPath, { withFileTypes: true }).flatMap((entry) => {
    const nextPath = path.join(targetPath, entry.name);
    if (entry.isDirectory()) {
      return walkFiles(nextPath, predicate);
    }
    return predicate(nextPath) ? [nextPath] : [];
  });
};

const collectUsedTranslationKeys = () => {
  const files = sourceRoots.flatMap((root) =>
    walkFiles(root, (filePath) => {
      if (!/\.(js|json|ya?ml)$/i.test(filePath)) {
        return false;
      }

      const normalizedPath = path.normalize(filePath);
      if (normalizedPath.includes(`${path.sep}src${path.sep}tests${path.sep}`)) {
        return false;
      }
      return !normalizedPath.includes(`${path.sep}src${path.sep}locales${path.sep}`);
    })
  );
  const usedKeys = new Set();

  files.forEach((filePath) => {
    const content = fs.readFileSync(filePath, 'utf8');
    const matches = content.matchAll(translationKeyPattern);
    for (const match of matches) {
      const key = match[1];
      if (key && !key.endsWith('.')) {
        usedKeys.add(key);
      }
    }
  });

  try {
    const {
      STAFF_POSITION_CATALOG,
      PRACTITIONER_TYPE_CATALOG,
      COMPENSATION_PAY_TYPE_CATALOG,
    } = require('../src/lib/hr/reference-data');
    for (const entry of [
      ...STAFF_POSITION_CATALOG,
      ...PRACTITIONER_TYPE_CATALOG,
      ...COMPENSATION_PAY_TYPE_CATALOG,
    ]) {
      if (entry?.labelKey) {
        usedKeys.add(entry.labelKey);
      }
    }
  } catch {
    // HR reference catalog is optional for locale checks.
  }

  return Array.from(usedKeys).sort();
};

const checkLocales = () => {
  const errors = [];
  const warnings = [];

  if (!SUPPORTED_LOCALES.includes(DEFAULT_LOCALE)) {
    errors.push(`DEFAULT_LOCALE "${DEFAULT_LOCALE}" must be included in SUPPORTED_LOCALES.`);
  }

  if (resolveLocale('en-GB') !== 'en' || resolveLocale('EN_gb') !== 'en') {
    errors.push('en-GB regional variants must resolve deterministically to "en".');
  }

  if (resolveLocale('sw') !== DEFAULT_LOCALE) {
    errors.push('Unsupported locales must resolve deterministically to the default locale.');
  }

  const localeFiles = fs.existsSync(localesDir)
    ? fs.readdirSync(localesDir).filter((fileName) => fileName.endsWith('.json')).sort()
    : [];
  const expectedFiles = SUPPORTED_LOCALES.map((locale) => `${locale}.json`).sort();

  expectedFiles.forEach((expectedFile) => {
    if (!localeFiles.includes(expectedFile)) {
      errors.push(`Required locale file ${expectedFile} is missing from src/locales.`);
    }
  });

  const extraLocaleFiles = localeFiles.filter((fileName) => !expectedFiles.includes(fileName));
  if (extraLocaleFiles.length > 0) {
    errors.push(
      `Unexpected locale files found: ${extraLocaleFiles.join(', ')}. Supported locales: ${SUPPORTED_LOCALES.join(', ')}.`
    );
  }

  const defaultLocalePath = path.join(localesDir, `${DEFAULT_LOCALE}.json`);
  const defaultMessages = fs.existsSync(defaultLocalePath)
    ? JSON.parse(fs.readFileSync(defaultLocalePath, 'utf8'))
    : {};
  const definedKeys = Object.keys(defaultMessages).sort();
  const usedKeys = collectUsedTranslationKeys();

  const missingKeys = usedKeys.filter((key) => !definedKeys.includes(key));
  const unusedKeys = definedKeys.filter((key) => !usedKeys.includes(key));

  if (missingKeys.length > 0) {
    errors.push(`Missing translation keys in ${DEFAULT_LOCALE}.json: ${missingKeys.slice(0, 20).join(', ')}${missingKeys.length > 20 ? ' ...' : ''}`);
  }

  if (unusedKeys.length > 0) {
    warnings.push(`Unused translation keys detected in ${DEFAULT_LOCALE}.json: ${unusedKeys.length}`);
  }

  SUPPORTED_LOCALES
    .filter((locale) => locale !== DEFAULT_LOCALE)
    .forEach((locale) => {
      const localePath = path.join(localesDir, `${locale}.json`);
      if (!fs.existsSync(localePath)) {
        return;
      }

      const localeMessages = JSON.parse(fs.readFileSync(localePath, 'utf8'));
      const localeKeys = Object.keys(localeMessages).sort();
      const missingInLocale = definedKeys.filter((key) => !localeKeys.includes(key));
      const extraInLocale = localeKeys.filter((key) => !definedKeys.includes(key));

      if (missingInLocale.length > 0) {
        errors.push(
          `Missing translation keys in ${locale}.json: ${missingInLocale.slice(0, 20).join(', ')}${missingInLocale.length > 20 ? ' ...' : ''}`
        );
      }

      if (extraInLocale.length > 0) {
        warnings.push(`Extra translation keys detected in ${locale}.json: ${extraInLocale.length}`);
      }
    });

  return {
    ok: errors.length === 0,
    errors,
    warnings,
    supported_locales: SUPPORTED_LOCALES,
    locale_files: localeFiles,
    used_key_count: usedKeys.length,
    defined_key_count: definedKeys.length,
    missing_keys: missingKeys,
    unused_keys: unusedKeys,
  };
};

const main = () => {
  const result = checkLocales();

  if (result.ok) {
    console.log(`[i18n] locale configuration OK for ${result.supported_locales.join(', ')}`);
  } else {
    console.error('[i18n] locale configuration check failed:');
    result.errors.forEach((entry) => console.error(` - ${entry}`));
  }

  result.warnings.forEach((entry) => console.warn(`[i18n] ${entry}`));

  if (!result.ok) {
    process.exitCode = 1;
  }
};

if (require.main === module) {
  main();
}

module.exports = {
  checkLocales,
  collectUsedTranslationKeys,
};
