/**
 * Rebuild app_fr.arb from app_en.arb using cached + parallel API translation.
 *
 * Usage (from repo root):
 *   node backend/scripts/rebuild-app-fr-arb.js
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');
const { offlineTranslate } = require('./generate-fr-locale-offline');

const repoRoot = path.join(__dirname, '..', '..');
const cachePath = path.join(__dirname, '.fr-translation-cache.json');
const enPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_en.arb');
const frPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_fr.arb');

const KEEP_UNCHANGED = new Set([
  'HOSSPI HMS',
  'HOSSPI',
  'HH:MM',
  'HH',
  'MM',
  'SS',
  '12H',
  '24H',
  'IBAN',
  'M-Pesa',
  'Vodacom M-Pesa',
  'Orange Money',
  'Zamtel Kwacha',
  'MTN Mobile Money',
  'Airtel Money',
  'Tigo / Mixx by Yas',
]);

const CONCURRENCY = 12;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const loadCache = () => {
  if (!fs.existsSync(cachePath)) {
    return {};
  }
  try {
    return JSON.parse(fs.readFileSync(cachePath, 'utf8'));
  } catch {
    return {};
  }
};

const saveCache = (cache) => {
  fs.writeFileSync(cachePath, JSON.stringify(cache, null, 2));
};

const readBraceSegment = (text, startIndex) => {
  let depth = 0;
  let end = startIndex;
  while (end < text.length) {
    if (text[end] === '{') depth += 1;
    if (text[end] === '}') {
      depth -= 1;
      if (depth === 0) {
        end += 1;
        break;
      }
    }
    end += 1;
  }
  return text.slice(startIndex, end);
};

const isIcuSegment = (segment) => /,\s*(plural|select)\s*,/.test(segment);

const translateWithGtx = (text) => new Promise((resolve, reject) => {
  const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=fr&dt=t&q=${encodeURIComponent(text)}`;
  https.get(url, { headers: { 'User-Agent': 'hms-rebuild-fr/1.0' } }, (response) => {
    let body = '';
    response.on('data', (chunk) => { body += chunk; });
    response.on('end', () => {
      if (body.trim().startsWith('<')) {
        reject(new Error('HTML response'));
        return;
      }
      try {
        const parsed = JSON.parse(body);
        const translated = Array.isArray(parsed?.[0])
          ? parsed[0].map((entry) => entry?.[0] ?? '').join('')
          : '';
        if (!translated) {
          reject(new Error('empty'));
          return;
        }
        resolve(translated);
      } catch (error) {
        reject(error);
      }
    });
  }).on('error', reject);
});

const translateLiteral = async (text, cache) => {
  const trimmed = text.trim();
  if (!trimmed || KEEP_UNCHANGED.has(trimmed)) {
    return text;
  }

  if (cache[trimmed] && cache[trimmed] !== trimmed) {
    return cache[trimmed];
  }

  const offline = offlineTranslate(trimmed);
  if (offline !== trimmed) {
    cache[trimmed] = offline;
    return offline;
  }

  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const translated = (await translateWithGtx(trimmed)).trim();
      if (translated && translated !== trimmed) {
        cache[trimmed] = translated;
        return translated;
      }
    } catch {
      // retry
    }
    // eslint-disable-next-line no-await-in-loop
    await sleep(200 * (attempt + 1));
  }

  cache[trimmed] = trimmed;
  return trimmed;
};

const translateIcuSegment = async (segment, cache) => {
  const pluralMatch = segment.match(/^\{([^,]+),\s*plural,(.*)\}$/s);
  if (pluralMatch) {
    const variable = pluralMatch[1];
    const body = pluralMatch[2];
    let translatedBody = body;
    const parts = [...body.matchAll(/(=\d+|\w+)\s*\{([^{}]*)\}/g)];
    for (const match of parts) {
      const keyword = match[1];
      const content = match[2];
      // eslint-disable-next-line no-await-in-loop
      const translatedContent = await translateLiteral(content, cache);
      translatedBody = translatedBody.replace(
        `${keyword} {${content}}`,
        `${keyword} {${translatedContent}}`,
      );
    }
    return `{${variable}, plural,${translatedBody}}`;
  }

  const selectMatch = segment.match(/^\{([^,]+),\s*select,(.*)\}$/s);
  if (selectMatch) {
    const variable = selectMatch[1];
    const body = selectMatch[2];
    let translatedBody = body;
    const parts = [...body.matchAll(/(\w+)\s*\{([^{}]*)\}/g)];
    for (const match of parts) {
      const keyword = match[1];
      const content = match[2];
      // eslint-disable-next-line no-await-in-loop
      const translatedContent = await translateLiteral(content, cache);
      translatedBody = translatedBody.replace(
        `${keyword} {${content}}`,
        `${keyword} {${translatedContent}}`,
      );
    }
    return `{${variable}, select,${translatedBody}}`;
  }

  return segment;
};

const translateMessage = async (english, cache) => {
  if (!english || typeof english !== 'string') {
    return english;
  }

  const trimmed = english.trim();
  if (!trimmed || KEEP_UNCHANGED.has(trimmed)) {
    return english;
  }

  if (cache[trimmed] && cache[trimmed] !== trimmed) {
    return cache[trimmed];
  }

  if (!english.includes('{')) {
    const translated = await translateLiteral(trimmed, cache);
    cache[trimmed] = translated;
    return translated;
  }

  let result = '';
  let index = 0;
  while (index < english.length) {
    if (english[index] !== '{') {
      const nextBrace = english.indexOf('{', index);
      const end = nextBrace === -1 ? english.length : nextBrace;
      const literal = english.slice(index, end);
      // eslint-disable-next-line no-await-in-loop
      result += literal.trim() ? await translateLiteral(literal, cache) : literal;
      index = end;
      continue;
    }

    const segment = readBraceSegment(english, index);
    if (isIcuSegment(segment)) {
      // eslint-disable-next-line no-await-in-loop
      result += await translateIcuSegment(segment, cache);
    } else {
      result += segment;
    }
    index += segment.length;
  }

  cache[trimmed] = result;
  return result;
};

const mapWithConcurrency = async (items, worker) => {
  let index = 0;
  const results = new Array(items.length);
  const runners = Array.from({ length: CONCURRENCY }, async () => {
    while (index < items.length) {
      const current = index;
      index += 1;
      // eslint-disable-next-line no-await-in-loop
      results[current] = await worker(items[current], current);
    }
  });
  await Promise.all(runners);
  return results;
};

const main = async () => {
  const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
  const cache = loadCache();
  const messageKeys = Object.keys(en).filter((key) => !key.startsWith('@') && key !== '@@locale');
  const uniqueEnglish = [...new Set(messageKeys.map((key) => en[key]).filter((v) => typeof v === 'string' && v.trim()))];

  console.log(`[rebuild-app-fr] translating ${uniqueEnglish.length} unique strings...`);

  let completed = 0;
  await mapWithConcurrency(uniqueEnglish, async (englishValue) => {
    await translateMessage(englishValue, cache);
    completed += 1;
    if (completed % 100 === 0) {
      saveCache(cache);
      console.log(`[rebuild-app-fr] ${completed}/${uniqueEnglish.length}`);
    }
  });

  saveCache(cache);

  const fr = { '@@locale': 'fr' };
  for (const key of Object.keys(en)) {
    if (key === '@@locale') continue;
    if (key.startsWith('@')) {
      fr[key] = en[key];
      continue;
    }
    const english = en[key];
    if (typeof english !== 'string') {
      fr[key] = english;
      continue;
    }
    const trimmed = english.trim();
    const cached = cache[trimmed];
    fr[key] = cached && cached !== trimmed ? cached : await translateMessage(english, cache);
  }

  fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);
  console.log(`[rebuild-app-fr] wrote ${frPath}`);

  const fixScript = path.join(repoRoot, 'frontend', 'tool', 'fix_fr_arb_icu.js');
  if (fs.existsSync(fixScript)) {
    execSync(`node "${fixScript}"`, { stdio: 'inherit' });
  }

  const same = messageKeys.filter((key) => en[key] === fr[key]);
  console.log(`[rebuild-app-fr] identical to English: ${same.length}/${messageKeys.length}`);
};

main().catch((error) => {
  console.error('[rebuild-app-fr] failed:', error);
  process.exitCode = 1;
});
