/**
 * Repair ICU placeholder names in app_fr.arb using app_en.arb as structure source.
 *
 * Usage (from frontend/):
 *   node tool/fix_fr_arb_icu.js
 */

const fs = require('fs');
const path = require('path');

const l10nDir = path.join(__dirname, '..', 'lib', 'l10n');
const enPath = path.join(l10nDir, 'app_en.arb');
const frPath = path.join(l10nDir, 'app_fr.arb');

const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
const fr = JSON.parse(fs.readFileSync(frPath, 'utf8'));

const skipIcuBlock = (text, startIndex) => {
  let depth = 0;
  for (let index = startIndex; index < text.length; index += 1) {
    const char = text[index];
    if (char === '{') {
      depth += 1;
    } else if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        return index - startIndex + 1;
      }
    }
  }
  return text.length - startIndex;
};

const extractPlaceholderSequence = (text) => {
  const sequence = [];
  let index = 0;

  while (index < text.length) {
    if (text[index] !== '{') {
      index += 1;
      continue;
    }

    const icuMatch = text.slice(index).match(/^\{([a-zA-Z_][a-zA-Z0-9_]*),\s*(plural|select)/);
    if (icuMatch) {
      sequence.push({ kind: 'icu', name: icuMatch[1] });
      index += skipIcuBlock(text, index);
      continue;
    }

    const simpleMatch = text.slice(index).match(/^\{([a-zA-Z_][a-zA-Z0-9_]*)\}/);
    if (simpleMatch) {
      sequence.push({ kind: 'simple', name: simpleMatch[1] });
      index += simpleMatch[0].length;
      continue;
    }

    index += 1;
  }

  return sequence;
};

const replacePlaceholderName = (text, fromName, toName) => {
  if (fromName === toName) {
    return text;
  }

  let next = text;
  next = next.replace(new RegExp(`\\{${fromName},`, 'g'), `{${toName},`);
  next = next.replace(new RegExp(`\\{\\{${fromName}\\}\\}`, 'g'), `{{${toName}}}`);
  next = next.replace(new RegExp(`\\{${fromName}\\}`, 'g'), `{${toName}}`);
  return next;
};

const repairMessage = (key, enValue, frValue) => {
  if (typeof enValue !== 'string' || typeof frValue !== 'string') {
    return frValue;
  }

  if (!enValue.includes('{')) {
    return frValue;
  }

  let fixed = frValue.replace(/\bautre\b/g, 'other');
  const enSequence = extractPlaceholderSequence(enValue);
  const frSequence = extractPlaceholderSequence(fixed);

  if (enSequence.length === 0 || enSequence.length !== frSequence.length) {
    return fixed;
  }

  for (let index = 0; index < enSequence.length; index += 1) {
    const expected = enSequence[index].name;
    const actual = frSequence[index].name;
    fixed = replacePlaceholderName(fixed, actual, expected);
  }

  return fixed;
};

let repairedCount = 0;
const messageKeys = Object.keys(fr).filter((key) => !key.startsWith('@') && key !== '@@locale');

for (const key of messageKeys) {
  const enValue = en[key];
  const frValue = fr[key];
  const repaired = repairMessage(key, enValue, frValue);

  if (repaired !== frValue) {
    fr[key] = repaired;
    repairedCount += 1;
  }
}

fs.writeFileSync(frPath, `${JSON.stringify(fr, null, 2)}\n`);
console.log(`[fix_fr_arb_icu] Repaired ${repairedCount} message keys in ${frPath}`);
