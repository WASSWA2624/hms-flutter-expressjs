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
      if (match[1]) {
        usedKeys.add(match[1]);
      }
    }
  });

  return Array.from(usedKeys).sort();
};

const checkLocales = () => {
  const errors = [];
  const warnings = [];

  if (DEFAULT_LOCALE !== 'en') {
    errors.push(`DEFAULT_LOCALE must be "en" but found "${DEFAULT_LOCALE}".`);
  }

  if (JSON.stringify(SUPPORTED_LOCALES) !== JSON.stringify(['en'])) {
    errors.push(`SUPPORTED_LOCALES must be ["en"] during development but found ${JSON.stringify(SUPPORTED_LOCALES)}.`);
  }

  if (resolveLocale('en-GB') !== 'en' || resolveLocale('EN_gb') !== 'en') {
    errors.push('en-GB regional variants must resolve deterministically to "en".');
  }

  if (resolveLocale('sw') !== 'en') {
    errors.push('Unsupported locales must resolve deterministically to the default locale.');
  }

  const localeFiles = fs.existsSync(localesDir)
    ? fs.readdirSync(localesDir).filter((fileName) => fileName.endsWith('.json')).sort()
    : [];
  const expectedFile = `${DEFAULT_LOCALE}.json`;

  if (!localeFiles.includes(expectedFile)) {
    errors.push(`Required locale file ${expectedFile} is missing from src/locales.`);
  }

  const extraLocaleFiles = localeFiles.filter((fileName) => fileName !== expectedFile);
  if (extraLocaleFiles.length > 0) {
    errors.push(
      `Only ${expectedFile} is allowed during development. Remove extra locale files: ${extraLocaleFiles.join(', ')}.`
    );
  }

  const defaultLocalePath = path.join(localesDir, expectedFile);
  const defaultMessages = fs.existsSync(defaultLocalePath)
    ? JSON.parse(fs.readFileSync(defaultLocalePath, 'utf8'))
    : {};
  const definedKeys = Object.keys(defaultMessages).sort();
  const usedKeys = collectUsedTranslationKeys();

  const missingKeys = usedKeys.filter((key) => !definedKeys.includes(key));
  const unusedKeys = definedKeys.filter((key) => !usedKeys.includes(key));

  if (missingKeys.length > 0) {
    errors.push(`Missing translation keys in ${expectedFile}: ${missingKeys.slice(0, 20).join(', ')}${missingKeys.length > 20 ? ' ...' : ''}`);
  }

  if (unusedKeys.length > 0) {
    warnings.push(`Unused translation keys detected in ${expectedFile}: ${unusedKeys.length}`);
  }

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
