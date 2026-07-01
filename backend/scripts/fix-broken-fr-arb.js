/**
 * Re-translate broken hybrid English/French strings in app_fr.arb.
 */
const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

const repoRoot = path.join(__dirname, '..', '..');
const cachePath = path.join(__dirname, '.fr-translation-cache.json');
const enPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_en.arb');
const frPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_fr.arb');

const BROKEN_PATTERN = /\b(the|is|are|has|been|not|this|that|will|was|were|took|too|long|open|accept|begin|and|or|for|with|from|has been|does not|do not|can not|cannot|should|would|could|available|ready|workflow|workspace|request|patient has|system will|actuel backend|local-only|you are|how would|right now|on this|all linked|higher plan|any time)\b/i;
const CONCURRENCY = 16;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

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
  https.get(url, { headers: { 'User-Agent': 'hms-fix-fr/1.0' } }, (response) => {
    let body = '';
    response.on('data', (chunk) => { body += chunk; });
    response.on('end', () => {
      if (body.trim().startsWith('<')) {
        reject(new Error('html'));
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

const translateLiteral = async (text) => {
  const trimmed = text.trim();
  if (!trimmed) return text;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const translated = (await translateWithGtx(trimmed)).trim();
      if (translated) return translated;
    } catch {
      // retry
    }
    // eslint-disable-next-line no-await-in-loop
    await sleep(150 * (attempt + 1));
  }
  return text;
};

const translateIcuSegment = async (segment) => {
  const pluralMatch = segment.match(/^\{([^,]+),\s*plural,(.*)\}$/s);
  if (pluralMatch) {
    const variable = pluralMatch[1];
    const body = pluralMatch[2];
    let translatedBody = body;
    for (const match of body.matchAll(/(=\d+|\w+)\s*\{([^{}]*)\}/g)) {
      const keyword = match[1];
      const content = match[2];
      // eslint-disable-next-line no-await-in-loop
      const translatedContent = await translateLiteral(content);
      translatedBody = translatedBody.replace(
        `${keyword} {${content}}`,
        `${keyword} {${translatedContent}}`,
      );
    }
    return `{${variable}, plural,${translatedBody}}`;
  }
  return segment;
};

const translateMessage = async (english) => {
  if (!english || typeof english !== 'string') return english;
  if (!english.includes('{')) {
    return translateLiteral(english);
  }

  let result = '';
  let index = 0;
  while (index < english.length) {
    if (english[index] !== '{') {
      const nextBrace = english.indexOf('{', index);
      const end = nextBrace === -1 ? english.length : nextBrace;
      const literal = english.slice(index, end);
      // eslint-disable-next-line no-await-in-loop
      result += literal.trim() ? await translateLiteral(literal) : literal;
      index = end;
      continue;
    }
    const segment = readBraceSegment(english, index);
    if (isIcuSegment(segment)) {
      // eslint-disable-next-line no-await-in-loop
      result += await translateIcuSegment(segment);
    } else {
      result += segment;
    }
    index += segment.length;
  }
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
  const fr = JSON.parse(fs.readFileSync(frPath, 'utf8'));
  const cache = fs.existsSync(cachePath)
    ? JSON.parse(fs.readFileSync(cachePath, 'utf8'))
    : {};

  const messageKeys = Object.keys(en).filter((key) => !key.startsWith('@') && key !== '@@locale');
  const targets = messageKeys.filter((key) => {
    const french = fr[key];
    const english = en[key];
    if (typeof french !== 'string' || typeof english !== 'string') return false;
    if (french === english) return false;
    return BROKEN_PATTERN.test(french);
  });

  console.log(`[fix-broken-fr] retranslating ${targets.length} keys...`);

  let completed = 0;
  await mapWithConcurrency(targets, async (key) => {
    const english = en[key];
    delete cache[english.trim()];
    const translated = await translateMessage(english);
    if (translated && translated !== english && !BROKEN_PATTERN.test(translated)) {
      fr[key] = translated;
      cache[english.trim()] = translated;
    }
    completed += 1;
    if (completed % 25 === 0) {
      fs.writeFileSync(cachePath, JSON.stringify(cache, null, 2));
      console.log(`[fix-broken-fr] ${completed}/${targets.length}`);
    }
  });

  fs.writeFileSync(cachePath, JSON.stringify(cache, null, 2));
  fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);

  const fixScript = path.join(repoRoot, 'frontend', 'tool', 'fix_fr_arb_icu.js');
  if (fs.existsSync(fixScript)) {
    execSync(`node "${fixScript}"`, { stdio: 'inherit' });
  }

  const broken = messageKeys.filter((key) => BROKEN_PATTERN.test(fr[key] ?? ''));
  const same = messageKeys.filter((key) => en[key] === fr[key]);
  console.log(`[fix-broken-fr] remaining broken ${broken.length}, identical ${same.length}`);
};

main().catch((error) => {
  console.error('[fix-broken-fr] failed:', error);
  process.exitCode = 1;
});
