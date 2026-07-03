/**
 * Complete missing French translations where values still match English.
 *
 * Usage (from repo root):
 *   node backend/scripts/complete-fr-locale.js
 *   node backend/scripts/complete-fr-locale.js --target backend
 *   node backend/scripts/complete-fr-locale.js --target frontend
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

const repoRoot = path.join(__dirname, '..', '..');
const cachePath = path.join(__dirname, '.fr-translation-cache.json');

const KEEP_UNCHANGED = new Set([
  'HOSSPI HMS',
  'HOSSPI',
  'ICU',
  'OPD',
  'IPD',
  'PACS',
  'ABAC',
  'API',
  'HR',
  'OT',
  'OK',
  'N/A',
]);

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
    if (text[end] === '{') {
      depth += 1;
    }
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

const CONCURRENCY = 20;
const REQUEST_DELAY_MS = 40;

const translateWithGtx = (text) => new Promise((resolve, reject) => {
  const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=fr&dt=t&q=${encodeURIComponent(text)}`;

  https.get(url, { headers: { 'User-Agent': 'hms-locale-complete/1.0' } }, (response) => {
    let body = '';
    response.on('data', (chunk) => {
      body += chunk;
    });
    response.on('end', () => {
      if (response.statusCode && response.statusCode >= 400) {
        reject(new Error(`HTTP ${response.statusCode}`));
        return;
      }

      if (body.trim().startsWith('<')) {
        reject(new Error('Unexpected HTML response'));
        return;
      }

      try {
        const parsed = JSON.parse(body);
        const translated = Array.isArray(parsed?.[0])
          ? parsed[0].map((entry) => entry?.[0] ?? '').join('')
          : '';
        if (!translated) {
          reject(new Error('Missing translated text'));
          return;
        }
        resolve(translated);
      } catch (error) {
        reject(error);
      }
    });
  }).on('error', reject);
});

const translateWithMyMemory = (text) => new Promise((resolve, reject) => {
  const query = encodeURIComponent(text);
  const url = `https://api.mymemory.translated.net/get?q=${query}&langpair=en|fr`;

  https.get(url, { headers: { 'User-Agent': 'hms-locale-complete/1.0' } }, (response) => {
    let body = '';
    response.on('data', (chunk) => {
      body += chunk;
    });
    response.on('end', () => {
      try {
        const parsed = JSON.parse(body);
        const translated = parsed?.responseData?.translatedText;
        if (!translated || typeof translated !== 'string') {
          reject(new Error('Missing translated text'));
          return;
        }
        if (translated.toUpperCase().includes('MYMEMORY WARNING')) {
          reject(new Error('MyMemory quota warning'));
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
  if (!trimmed) {
    return text;
  }

  if (cache[trimmed] && cache[trimmed] !== trimmed) {
    return cache[trimmed];
  }

  const providers = [translateWithGtx, translateWithMyMemory];
  let translated = trimmed;
  let translatedSuccessfully = false;

  for (const provider of providers) {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
         
        const candidate = await provider(trimmed);
        if (candidate && candidate.trim() && candidate.trim() !== trimmed) {
          translated = candidate.trim();
          translatedSuccessfully = true;
          break;
        }
      } catch {
        // try next attempt/provider
      }
       
      await sleep(250 * (attempt + 1));
    }
    if (translatedSuccessfully) {
      break;
    }
  }

  if (!translatedSuccessfully) {
    const { offlineTranslate } = require('./generate-fr-locale-offline');
    const offline = offlineTranslate(trimmed);
    if (offline.trim() && offline.trim() !== trimmed) {
      translated = offline.trim();
      translatedSuccessfully = true;
    }
  }

  cache[trimmed] = translatedSuccessfully ? translated : trimmed;
  return cache[trimmed];
};

const mapWithConcurrency = async (items, worker, concurrency = CONCURRENCY) => {
  let index = 0;
  const results = new Array(items.length);

  const runners = Array.from({ length: concurrency }, async () => {
    while (index < items.length) {
      const current = index;
      index += 1;
       
      results[current] = await worker(items[current], current);
       
      await sleep(REQUEST_DELAY_MS);
    }
  });

  await Promise.all(runners);
  return results;
};

const translateUniqueValues = async (englishValues, cache, label) => {
  const uniqueValues = [...new Set(englishValues)];
  console.log(`[complete-fr] ${label} unique pending strings: ${uniqueValues.length}`);

  let completed = 0;
  await mapWithConcurrency(uniqueValues, async (englishValue) => {
    await translateMessage(englishValue, cache);
    completed += 1;
    if (completed % 50 === 0) {
      saveCache(cache);
      console.log(`[complete-fr] ${label} ${completed}/${uniqueValues.length}`);
    }
  });

  saveCache(cache);
  return uniqueValues;
};

const translateIcuSegment = async (segment, cache) => {
  const pluralMatch = segment.match(/^\{([^,]+),\s*plural,(.*)\}$/s);
  if (pluralMatch) {
    const variable = pluralMatch[1];
    const body = pluralMatch[2];
    const parts = body.matchAll(/(=\d+|\w+)\s*\{([^{}]*)\}/g);
    let translatedBody = body;

    for (const match of parts) {
      const keyword = match[1];
      const content = match[2];
       
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
    const parts = body.matchAll(/(\w+)\s*\{([^{}]*)\}/g);
    let translatedBody = body;

    for (const match of parts) {
      const keyword = match[1];
      const content = match[2];
       
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
    const leading = english.match(/^\s*/)?.[0] ?? '';
    const trailing = english.match(/\s*$/)?.[0] ?? '';
    const core = english.trim();
    const translatedCore = await translateLiteral(core, cache);
    const result = `${leading}${translatedCore}${trailing}`;
    cache[trimmed] = result.trim() === trimmed ? translatedCore : result;
    return cache[trimmed];
  }

  let result = '';
  let index = 0;

  while (index < english.length) {
    if (english[index] !== '{') {
      const nextBrace = english.indexOf('{', index);
      const end = nextBrace === -1 ? english.length : nextBrace;
      const literal = english.slice(index, end);
       
      result += literal.trim() ? await translateLiteral(literal, cache) : literal;
      index = end;
      continue;
    }

    const segment = readBraceSegment(english, index);
    if (isIcuSegment(segment)) {
       
      result += await translateIcuSegment(segment, cache);
    } else {
      result += segment;
    }
    index += segment.length;
  }

  cache[trimmed] = result;
  if (result === english) {
    const { offlineTranslate } = require('./generate-fr-locale-offline');
    const offline = offlineTranslate(english);
    if (offline !== english) {
      cache[trimmed] = offline;
      return offline;
    }
  }
  return result;
};

const needsTranslation = (english, french) => {
  if (typeof english !== 'string') {
    return false;
  }

  const trimmed = english.trim();
  if (!trimmed || KEEP_UNCHANGED.has(trimmed)) {
    return false;
  }

  return english === french;
};

const completeBackend = async () => {
  const enPath = path.join(repoRoot, 'backend', 'src', 'locales', 'en.json');
  const frPath = path.join(repoRoot, 'backend', 'src', 'locales', 'fr.json');
  const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
  const fr = JSON.parse(fs.readFileSync(frPath, 'utf8'));
  const cache = loadCache();
  const pendingKeys = Object.keys(en).filter((key) => needsTranslation(en[key], fr[key]));
  const pendingValues = pendingKeys.map((key) => en[key]);

  console.log(`[complete-fr] backend pending ${pendingKeys.length}/${Object.keys(en).length}`);
  await translateUniqueValues(pendingValues, cache, 'backend');

  pendingKeys.forEach((key) => {
    const english = en[key];
    const trimmed = typeof english === 'string' ? english.trim() : english;
    const cached = cache[trimmed];
    fr[key] = cached && cached !== trimmed ? cached : english;
  });

  fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);
  console.log(`[complete-fr] Wrote ${frPath}`);
};

const completeFrontend = async () => {
  const enPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_en.arb');
  const frPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_fr.arb');
  const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
  const fr = JSON.parse(fs.readFileSync(frPath, 'utf8'));
  const cache = loadCache();
  const pendingKeys = Object.keys(en).filter(
    (key) => !key.startsWith('@') && key !== '@@locale' && needsTranslation(en[key], fr[key]),
  );
  const pendingValues = pendingKeys.map((key) => en[key]);

  console.log(`[complete-fr] frontend pending ${pendingKeys.length}`);
  await translateUniqueValues(pendingValues, cache, 'frontend');

  pendingKeys.forEach((key) => {
    const english = en[key];
    const trimmed = typeof english === 'string' ? english.trim() : english;
    const cached = cache[trimmed];
    fr[key] = cached && cached !== trimmed ? cached : english;
  });

  fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);
  console.log(`[complete-fr] Wrote ${frPath}`);

  const fixScript = path.join(repoRoot, 'frontend', 'tool', 'fix_fr_arb_icu.js');
  if (fs.existsSync(fixScript)) {
    execSync(`node "${fixScript}"`, { stdio: 'inherit' });
  }
};

const main = async () => {
  const args = new Set(process.argv.slice(2));
  const target = args.has('--target') ? process.argv[process.argv.indexOf('--target') + 1] : 'all';

  if (target === 'backend' || target === 'all') {
    await completeBackend();
  }

  if (target === 'frontend' || target === 'all') {
    await completeFrontend();
  }
};

if (require.main === module) {
  main().catch((error) => {
    console.error('[complete-fr] failed:', error);
    process.exitCode = 1;
  });
}

module.exports = {
  completeBackend,
  completeFrontend,
  translateMessage,
  loadCache,
  saveCache,
};
