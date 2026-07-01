/**
 * Final pass for French strings that still match English.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { offlineTranslate } = require('./generate-fr-locale-offline');
const { translateMessage, loadCache, saveCache } = require('./complete-fr-locale');

const repoRoot = path.join(__dirname, '..', '..');

const applyRemaining = async (target) => {
  const isFrontend = target === 'frontend';
  const enPath = isFrontend
    ? path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_en.arb')
    : path.join(repoRoot, 'backend', 'src', 'locales', 'en.json');
  const frPath = isFrontend
    ? path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_fr.arb')
    : path.join(repoRoot, 'backend', 'src', 'locales', 'fr.json');

  const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
  const fr = JSON.parse(fs.readFileSync(frPath, 'utf8'));
  const cache = loadCache();

  const keys = Object.keys(en).filter((key) => {
    if (isFrontend && (key.startsWith('@') || key === '@@locale')) {
      return false;
    }
    return en[key] === fr[key] && typeof en[key] === 'string' && en[key].trim();
  });

  console.log(`[apply-remaining-fr] ${target} pending ${keys.length}`);

  for (const key of keys) {
    const english = en[key];
    const trimmed = english.trim();
    let translated = cache[trimmed];

    if (!translated || translated === trimmed) {
      translated = offlineTranslate(english);
    }

    if (translated !== english) {
      cache[trimmed] = translated;
    }

    fr[key] = translated;
  }

  saveCache(cache);
  fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);

  if (isFrontend) {
    const fixScript = path.join(repoRoot, 'frontend', 'tool', 'fix_fr_arb_icu.js');
    if (fs.existsSync(fixScript)) {
      execSync(`node "${fixScript}"`, { stdio: 'inherit' });
    }
  }
};

const main = async () => {
  const target = process.argv.includes('--target')
    ? process.argv[process.argv.indexOf('--target') + 1]
    : 'all';

  if (target === 'backend' || target === 'all') {
    await applyRemaining('backend');
  }
  if (target === 'frontend' || target === 'all') {
    await applyRemaining('frontend');
  }
};

if (require.main === module) {
  main().catch((error) => {
    console.error('[apply-remaining-fr] failed:', error);
    process.exitCode = 1;
  });
}
