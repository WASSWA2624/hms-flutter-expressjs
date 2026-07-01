/**
 * Build app_fr.arb from app_en.arb using translation cache + offline fallback.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { offlineTranslate } = require('./generate-fr-locale-offline');

const repoRoot = path.join(__dirname, '..', '..');
const cachePath = path.join(__dirname, '.fr-translation-cache.json');
const enPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_en.arb');
const frPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_fr.arb');

const KEEP = new Set(['HOSSPI HMS', 'HH:MM', 'HH', 'MM', 'SS', '12H', '24H', 'IBAN']);

const cache = JSON.parse(fs.readFileSync(cachePath, 'utf8'));
const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
const fr = { '@@locale': 'fr' };

const resolve = (english) => {
  if (typeof english !== 'string') return english;
  const trimmed = english.trim();
  if (!trimmed || KEEP.has(trimmed)) return english;
  const cached = cache[trimmed];
  if (cached && cached !== trimmed) return cached;
  const offline = offlineTranslate(english);
  return offline !== english ? offline : english;
};

for (const key of Object.keys(en)) {
  if (key === '@@locale') continue;
  if (key.startsWith('@')) {
    fr[key] = en[key];
    continue;
  }
  fr[key] = resolve(en[key]);
}

fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);

const fixScript = path.join(repoRoot, 'frontend', 'tool', 'fix_fr_arb_icu.js');
if (fs.existsSync(fixScript)) {
  execSync(`node "${fixScript}"`, { stdio: 'inherit' });
}

const keys = Object.keys(en).filter((k) => !k.startsWith('@') && k !== '@@locale');
const same = keys.filter((k) => en[k] === fr[k]);
console.log(`[build-fr-from-cache] identical ${same.length}/${keys.length}`);
