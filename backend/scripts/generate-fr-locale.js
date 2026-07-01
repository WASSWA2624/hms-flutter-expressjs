/**
 * Generate French locale files from English sources.
 *
 * Usage (from repo root):
 *   node backend/scripts/generate-fr-locale.js
 *   node backend/scripts/generate-fr-locale.js --target backend
 *   node backend/scripts/generate-fr-locale.js --target frontend
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const repoRoot = path.join(__dirname, '..', '..');
const cachePath = path.join(__dirname, '.fr-translation-cache.json');

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

const protectPlaceholders = (text) => {
  const tokens = [];
  const protectedText = text.replace(/\{[^}]+\}/g, (match) => {
    const token = `__PH${tokens.length}__`;
    tokens.push(match);
    return token;
  });

  return { protectedText, tokens };
};

const restorePlaceholders = (text, tokens) => {
  let restored = text;
  tokens.forEach((token, index) => {
    restored = restored.replace(`__PH${index}__`, token);
  });
  return restored;
};

const translateWithMyMemory = (text) => new Promise((resolve, reject) => {
  const query = encodeURIComponent(text);
  const url = `https://api.mymemory.translated.net/get?q=${query}&langpair=en|fr`;

  https.get(url, { headers: { 'User-Agent': 'hms-locale-generator/1.0' } }, (response) => {
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

const translateWithRetries = async (text, attempts = 4) => {
  let lastError;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      // eslint-disable-next-line no-await-in-loop
      return await translateWithMyMemory(text);
    } catch (error) {
      lastError = error;
      // eslint-disable-next-line no-await-in-loop
      await sleep(400 * (attempt + 1));
    }
  }

  throw lastError;
};

const translateText = async (text, cache) => {
  if (!text || typeof text !== 'string') {
    return text;
  }

  const trimmed = text.trim();
  if (!trimmed) {
    return text;
  }

  if (cache[trimmed]) {
    return cache[trimmed];
  }

  const { protectedText, tokens } = protectPlaceholders(trimmed);

  let translated = protectedText;
  const chunkSize = 1200;
  const chunks = [];
  for (let index = 0; index < protectedText.length; index += chunkSize) {
    chunks.push(protectedText.slice(index, index + chunkSize));
  }

  const translatedChunks = [];
  for (const chunk of chunks) {
    try {
      // eslint-disable-next-line no-await-in-loop
      const next = await translateWithRetries(chunk);
      translatedChunks.push(next);
    } catch {
      translatedChunks.push(chunk);
    }
    // eslint-disable-next-line no-await-in-loop
    await sleep(250);
  }

  translated = restorePlaceholders(translatedChunks.join(''), tokens);
  cache[trimmed] = translated;
  return translated;
};

const translateEntries = async (entries, onProgress) => {
  const cache = loadCache();
  const output = {};
  const keys = Object.keys(entries);
  let completed = 0;

  for (const key of keys) {
    const value = entries[key];
    if (typeof value === 'string') {
      // eslint-disable-next-line no-await-in-loop
      output[key] = await translateText(value, cache);
    } else {
      output[key] = value;
    }

    completed += 1;
    if (completed % 25 === 0) {
      saveCache(cache);
      onProgress?.(completed, keys.length);
    }
  }

  saveCache(cache);
  onProgress?.(completed, keys.length);
  return output;
};

const generateBackendFr = async () => {
  const sourcePath = path.join(repoRoot, 'backend', 'src', 'locales', 'en.json');
  const targetPath = path.join(repoRoot, 'backend', 'src', 'locales', 'fr.json');
  const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));

  console.log(`[fr] Translating ${Object.keys(source).length} backend keys...`);
  const translated = await translateEntries(source, (done, total) => {
    console.log(`[fr] backend ${done}/${total}`);
  });

  fs.writeFileSync(targetPath, `${JSON.stringify(translated, null, 2)}\n`);
  console.log(`[fr] Wrote ${targetPath}`);
};

const generateFrontendFr = async () => {
  const sourcePath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_en.arb');
  const targetPath = path.join(repoRoot, 'frontend', 'lib', 'l10n', 'app_fr.arb');
  const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
  const output = { '@@locale': 'fr' };

  const messageKeys = Object.keys(source).filter((key) => !key.startsWith('@'));
  console.log(`[fr] Translating ${messageKeys.length} frontend message keys...`);

  let completed = 0;
  const cache = loadCache();

  for (const key of messageKeys) {
    const value = source[key];
    if (typeof value === 'string') {
      // eslint-disable-next-line no-await-in-loop
      output[key] = await translateText(value, cache);
    } else {
      output[key] = value;
    }

    const metadataKey = `@${key}`;
    if (Object.prototype.hasOwnProperty.call(source, metadataKey)) {
      output[metadataKey] = source[metadataKey];
    }

    completed += 1;
    if (completed % 25 === 0) {
      saveCache(cache);
      console.log(`[fr] frontend ${completed}/${messageKeys.length}`);
    }
  }

  saveCache(cache);
  fs.writeFileSync(targetPath, `${JSON.stringify(output, null, 2)}\n`);
  console.log(`[fr] Wrote ${targetPath}`);

  const { execSync } = require('child_process');
  const fixScript = path.join(repoRoot, 'frontend', 'tool', 'fix_fr_arb_icu.js');
  if (fs.existsSync(fixScript)) {
    console.log('[fr] Repairing ICU placeholders in app_fr.arb...');
    execSync(`node "${fixScript}"`, { stdio: 'inherit', cwd: path.join(repoRoot, 'frontend') });
  }
};

const main = async () => {
  const args = new Set(process.argv.slice(2));
  const target = args.has('--target') ? process.argv[process.argv.indexOf('--target') + 1] : 'all';

  if (target === 'backend' || target === 'all') {
    await generateBackendFr();
  }

  if (target === 'frontend' || target === 'all') {
    await generateFrontendFr();
  }
};

if (require.main === module) {
  main().catch((error) => {
    console.error('[fr] generation failed:', error);
    process.exitCode = 1;
  });
}

module.exports = {
  generateBackendFr,
  generateFrontendFr,
  translateText,
};
